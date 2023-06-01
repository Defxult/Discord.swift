/**
The MIT License (MIT)

Copyright (c) 2023-present Defxult

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/

import Foundation

/// Represents a Discord bot.
public class Discord {
    
    /// Version of the library.
    public let version = Version()
    
    /// Intents currently set for the bot.
    public let intents: Set<Intents>
    
    /// Event listeners that have been added to the bot.
    public internal(set) var listeners = [EventListener]()
    
    /// The bots user object. Will be `nil` if the bot is not connected to Discord.
    public internal(set) var user: ClientUser?
    
    /// The private messages currently opened between the bot and a user.
    public internal(set) var dms = Set<DMChannel>()
    
    /// All guilds the bot is a member of.
    public var guilds: [Guild] { guildsCache.values.map({ $0 }) }
    
    /// All users the bot can see.
    public var users: [User] { usersCache.values.map({ $0 }) }
    
    /// Messages the bot has cached.
    public internal(set) var cachedMessages = Set<Message>()
    
    /// Whether automatic sharding is enabled. If your bot is in 2500 or more guilds, this *must* be enabled.
    public internal(set) var sharding: Bool
    
    /// The authentification token for the bot.
    /// - Warning: The token should be kept private. Unauthorized access to your token could have devastating consequences.
    public let token: String
    
    /// The global allowed mentions.
    public static var allowedMentions: AllowedMentions = .default
    
    /// All emojis the bot has accesss to.
    public var emojis: Set<Emoji> {
        get {
            var e = Set<Emoji>()
            for guild in guilds {
                e.formUnion(guild.emojis)
            }
            return e
        }
    }
    
    var pendingApplicationCommands = [PendingAppCommand]()
    var pendingModals = [String: (Interaction) async -> Void]()
    let messagesCacheMaxSize: Int
    var usersCache = [Snowflake: User]()
    var guildsCache = [Snowflake: Guild]()
    var wsg: WSGateway? = nil
    var http: HTTPClient!
    var msgCacheLock = NSLock()
    
    /// Initializes the Discord bot.
    /// - Parameters:
    ///   - token: The authentification token for the bot.
    ///   - intents: Gateway events the bot is subscribed to. Additional intents may need to be turned on via the Discord [developer portal](https://discord.com/developers/applications). *Applications > Bot > Privileged Gateway Intents*
    ///   - maxMessagesCache: The maximum amount of messages that should be cached.
    ///   - sharding: Whether automatic sharding is enabled. If your bot is in 2500 or more guilds, this **must** be enabled.
    /// - Important: When setting intents, it is highly recommended to at least have the ``Intents/guilds`` intent enabled in order for your bot to function properly.
    public init(token: String, intents: Set<Intents>, maxMessagesCache: Int = 1500, sharding: Bool = false) {
        self.token = token
        self.intents = intents
        self.sharding = sharding
        messagesCacheMaxSize = max(0, maxMessagesCache)
        http = .init(bot: self, token: token, version: version)
    }
    
    func cacheGuild(_ guild: Guild) {
        guildsCache[guild.id] = guild
    }
    
    func cacheUser(_ user: User) {
        usersCache[user.id] = user
    }
    
    func cacheMessage(_ message: Message) {
        guard !(messagesCacheMaxSize == 0) else { return }
        msgCacheLock.lock()
        
        if cachedMessages.count == messagesCacheMaxSize {
            let oldestMessage = cachedMessages.sorted(by: { $0.expires < $1.expires }).first!
            cachedMessages.remove(oldestMessage)
        }
        cachedMessages.insert(message)
        msgCacheLock.unlock()
    }
    
    func removeCachedMessage(_ messageId: Snowflake) {
        if let message = cachedMessages.first(where: { $0.id == messageId }) {
            message.cacheExpireTimer?.invalidate()
            cachedMessages.remove(message)
        }
    }
    
    /// Update the bots presence.
    /// - Parameters:
    ///   - status: The current status.
    ///   - activity: The activity. Can be set to things such as "Listening to {value}", "Watching {value}", etc. Can be `nil` for no activity.
    /// - Note: Certain combinations are ignored by Discord. Some examples are setting the bots `status` to offline or setting a custom status.
    public func updatePresence(status: User.Status, activity: User.PresenceActivity?) async throws {
        if let wsg {
            var d: JSON = ["status": status.rawValue, "afk": false]
            
            // Requires unix time in milliseconds
            d["since"] = status == .idle ? Date.now.timeIntervalSince1970 * 1000 : NIL
            d["activities"] = activity == nil ? [] : try activity!.convert()
            
            let payload: JSON = ["op": Opcode.presenceUpdate, "d": d]
            try await wsg.ws.send(.data(dictToData(payload)))
        }
    }
    
    /// Retrieve all global application commands.
    /// - Returns: All global application commands.
    public func applicationCommands() async throws -> [ApplicationCommand] {
        return try await http.getGlobalApplicationCommands(botId: try await getClientID())
    }
    
    /// Adds a user command.  The command will not be available unless synced via ``syncApplicationCommands()``.
    /// - Parameters:
    ///   - name: Command name.
    ///   - guildId: Guild ID the command will be available in. If you want this to be a global command, set this to `nil`.
    ///   - onInteraction: The closure that is called when the command is used.
    ///   - defaultMemberPermissions: The permissions a member must have in order to use the command.
    ///   - nameLocalizations: Name localizations for the command.
    ///   - dmPermission: Indicates whether the command is available in DMs with the app, only for globally-scoped commands.
    ///   - nsfw: Indicates whether the command is age-restricted.
    public func addUserCommand(
        name: String,
        guildId: Snowflake?,
        onInteraction: @escaping (Interaction) async -> Void,
        defaultMemberPermissions: Permissions? = nil,
        nameLocalizations: [Locale: String]? = nil,
        dmPermission: Bool = true,
        nsfw: Bool = false) {
            addApplicationCommand(
                type: .user,
                name: name,
                guildId: guildId,
                onInteraction: onInteraction,
                dmPermission: dmPermission,
                description: String.empty,
                options: nil,
                defaultMemberPermissions: defaultMemberPermissions,
                nameLocalizations: nameLocalizations,
                descriptionLocalizations: nil,
                nsfw: nsfw
            )
    }
    
    /// Adds a message command.  The command will not be available unless synced via ``syncApplicationCommands()``.
    /// - Parameters:
    ///   - name: Command name.
    ///   - guildId: Guild ID the command will be available in. If you want this to be a global command, set this to `nil`.
    ///   - onInteraction: The closure that is called when the command is used.
    ///   - defaultMemberPermissions: The permissions a member must have in order to use the command.
    ///   - nameLocalizations: Name localizations for the command.
    ///   - dmPermission: Indicates whether the command is available in DMs with the app, only for globally-scoped commands.
    ///   - nsfw: Indicates whether the command is age-restricted.
    public func addMessageCommand(
        name: String,
        guildId: Snowflake?,
        onInteraction: @escaping (Interaction) async -> Void,
        defaultMemberPermissions: Permissions? = nil,
        nameLocalizations: [Locale: String]? = nil,
        dmPermission: Bool = true,
        nsfw: Bool = false) {
            addApplicationCommand(
                type: .message,
                name: name,
                guildId: guildId,
                onInteraction: onInteraction,
                dmPermission: dmPermission,
                description: String.empty,
                options: nil,
                defaultMemberPermissions: defaultMemberPermissions,
                nameLocalizations: nameLocalizations,
                descriptionLocalizations: nil,
                nsfw: nsfw
            )
        }
    
    /// Adds a slash command.  The command will not be available unless synced via ``syncApplicationCommands()``.
    /// - Parameters:
    ///   - name: Command name.
    ///   - description: The command description.
    ///   - guildId: Guild ID the command will be available in. If you want this to be a global command, set this to `nil`.
    ///   - onInteraction: The closure that is called when the command is used.
    ///   - options: Parameters of the command.
    ///   - dmPermission: Indicates whether the command is available in DMs with the app, only for globally-scoped commands.
    ///   - defaultMemberPermissions: The permissions a member must have in order to use the command.
    ///   - nameLocalizations: Name localizations for the command.
    ///   - descriptionLocalizations: Description localizations for the command.
    ///   - nsfw: Indicates whether the command is age-restricted.
    public func addSlashCommand(
        name: String,
        description: String,
        guildId: Snowflake?,
        onInteraction: @escaping (Interaction) async -> Void,
        options: [ApplicationCommandOption]? = nil,
        dmPermission: Bool = true,
        defaultMemberPermissions: Permissions? = nil,
        nameLocalizations: [Locale: String]? = nil,
        descriptionLocalizations: [Locale: String]? = nil,
        nsfw: Bool = false) {
            addApplicationCommand(
                type: .slashCommand,
                name: ApplicationCommand.verifyName(name),
                guildId: guildId,
                onInteraction: onInteraction,
                dmPermission: dmPermission,
                description: description,
                options: options,
                defaultMemberPermissions: defaultMemberPermissions,
                nameLocalizations: nameLocalizations,
                descriptionLocalizations: descriptionLocalizations,
                nsfw: nsfw
            )
    }
    
    private func addApplicationCommand(
        type: ApplicationCommandType,
        name: String,
        guildId: Snowflake?,
        onInteraction: @escaping (Interaction) async -> Void,
        dmPermission: Bool = true,
        description: String? = nil,
        options: [ApplicationCommandOption]? = nil,
        defaultMemberPermissions: Permissions? = nil,
        nameLocalizations: [Locale: String]? = nil,
        descriptionLocalizations: [Locale: String]? = nil,
        nsfw: Bool = false) {
            pendingApplicationCommands.append(PendingAppCommand(
                type: type,
                name: name,
                guildId: guildId,
                onInteraction: onInteraction,
                defaultMemberPermissions: defaultMemberPermissions,
                nameLocalizations: nameLocalizations,
                descriptionLocalizations: descriptionLocalizations,
                nsfw: nsfw,
                dmPermission: dmPermission,
                description: description,
                options: options)
            )
    }
    
    /// Sync all application commands. This must be called in order for application commands to be visible.
    /// - Returns: All succesfully synced application commands.
    @discardableResult
    public func syncApplicationCommands() async throws -> [ApplicationCommand] {
        var syncedCommands = [ApplicationCommand]()
        let botId = try await getClientID()
        
        // User, message, and slash commands
        for appCommand in pendingApplicationCommands {
            let cmd = try await http.createApplicationCommand(
                name: appCommand.name,
                type: appCommand.type,
                botId: botId,
                guildId: appCommand.guildId,
                dmPermission: appCommand.dmPermission,
                nameLocalizations: appCommand.nameLocalizations,
                description: appCommand.description,
                descriptionLocalizations: appCommand.descriptionLocalizations,
                options: appCommand.options,
                defaultMemberPermissions: appCommand.defaultMemberPermissions,
                nsfw: appCommand.nsfw
            )
            syncedCommands.append(cmd)
        }
        
        return syncedCommands
    }
    
    /// Add event listeners to the bot.
    /// - Parameter listeners: Event listeners to add. The name of all event listeners must be unique.
    public func addListeners(_ listeners: EventListener...) throws {
        for addedListener in listeners {
            let currentListenerNames = self.listeners.map({ $0.name })
            if currentListenerNames.contains(addedListener.name) {
                throw DiscordError.generic("An event listener with the name '\(addedListener.name)' has already been added")
            } else {
                self.listeners.append(addedListener)
            }
        }
    }
    
    func getClientID() async throws -> Snowflake {
        if let user { return user.id }
        else { return (try await applicationInfo()).id }
    }
    
    /// Retrieves the bots application information.
    /// - Returns: The bots application information.
    public func applicationInfo() async throws -> Application {
        return try await http.getCurrentBotApplicationInformation()
    }
    
    /// Connect to Discord.
    /// - Attention: This function is blocking to maintain the connection to Discord.
    public func connect() async throws {
        // Gateway
        let gateway = try await http.getGateway()
        wsg = WSGateway(bot: self, gatewayUrl: gateway.url, shards: gateway.shards)
        
        try await wsg!.handshake(sharding: sharding)
        wsg!.initialHandshakeComplete = true
        wsg!.isConnected = true
        
        Task { try await wsg!.heartbeat() }
        try await wsg!.listen()
    }
    
    /// Immediately disconnects the bot from Discord.
    public func disconnect() {
        if let wsg {
            wsg.ws.cancel(with: .goingAway, reason: nil)
            wsg.isConnected = false
        }
    }
    
    /// Create a guild. Your bot must be in less than 10 guilds to use this.
    /// - Parameters:
    ///   - name: Name of the guild.
    ///   - icon: The guild icon.
    ///   - template: The guild template code if you'd like to create the guild based on a template.
    /// - Returns: The newly created guild.
    public func createGuild(name: String, icon: File? = nil, template: String? = nil) async throws -> Guild {
        if let template {
            return try await http.createGuildFromGuildTemplate(code: template, name: name, icon: icon)
        } else {
            return try await http.createGuild(name: name, icon: icon)
        }
    }
    
    /**
     Creates a DM channel between the bot and the user with the provided ID.
     
     Creating the DM channel does not automatically send the user a DM. That must be done like so:
     ```swift
     try await createDm(with: 123456789012345).send(...)
     ```
     - Parameter with: The  ID of the user to create the DM channel for.
     - Returns: The newly created DM channel.
     */
    public func createDm(with: Snowflake) async throws -> DMChannel {
        let dmCh = try await http.createDm(recipientId: with)
        dms.update(with: dmCh)
        return dmCh
    }
    
    /// Disable all event listeners.
    public func disableAllListeners() {
        for listener in listeners {
            listener.isEnabled = false
        }
    }
    
    /// Enable all event listeners.
    public func enableAllListeners() {
        for listener in listeners {
            listener.isEnabled = true
        }
    }
    
    /// Retrieve a channel from the bots internal cache.
    /// - Parameter id: The ID of the channel to retrieve.
    /// - Returns: The channel matching the provided ID, or `nil` if not found.
    public func getChannel(_ id: Snowflake) -> Channel? {
        if let dm = dms.first(where: { $0.id == id }) {
            return dm
        }
        else {
            for (_, guild) in guildsCache {
                if let channel = guild.getChannel(id) { return channel }
            }
            return nil
        }
    }
    
    /// Retrieve a guild from the bots internal cache.
    /// - Parameter id: The ID of the guild to retrieve.
    /// - Returns: The guild matching the provided ID, or `nil` if not found.
    public func getGuild(_ id: Snowflake) -> Guild? {
        return guildsCache[id]
    }
    
    /// Retrieve an event listener by it's name.
    /// - Parameter name: Name of the event listener.
    /// - Returns: The event listener matching the provided name, or `nil` if not found.
    public func getListener(name: String) -> EventListener? {
        return listeners.first(where: { $0.name == name.lowercased() })
    }
    
    /// Retrieve a message from the bots internal cache.
    /// - Parameter id: The ID of the message.
    /// - Returns: The message matching the provided ID, or `nil` if not found.
    public func getMessage(_ id: Snowflake) -> Message? {
        if let msg = cachedMessages.first(where: { $0.id == id }) {
            msg.setExpires()
            return msg
        }
        return nil
    }
    
    /// Retrieve a user from the bots internal cache.
    /// - Parameter id: The ID of the user to retrieve.
    /// - Returns: The user matching the provided ID, or `nil` if not found.
    public func getUser(_ id: Snowflake)-> User? {
        return usersCache[id]
    }
    
    /// Retrieve a member from the bots internal cache.
    /// - Parameter id: The ID of the member.
    /// - Returns: The member matching the provided ID, or `nil` if not found.
    public func getMember(_ id: Snowflake) -> Member? {
        for guild in guilds {
            if let member = guild.getMember(id) { return member }
        }
        return nil
    }
    
    /// Requests the guild. Unlike ``getGuild(_:)``, this is an API call. For general use purposes, use ``getGuild(_:)`` instead if you have the ``Intents/guilds`` intent enabled.
    /// - Parameters:
    ///   - id: The guild ID.
    ///   - withCounts: If `true`, the returned guild will have properties ``Guild/approximateMemberCount`` and ``Guild/approximatePresenceCount`` available.
    /// - Returns: The requested guild.
    /// - Note: Using this method, the returned guild will not contain ``Guild/channels``, ``Guild/members``, ``Guild/threads``, ``Guild/voiceStates`` amongst other data that might be missing.
    public func requestGuild(_ id: Snowflake, withCounts: Bool = true) async throws -> Guild {
        return try await http.getGuild(guildId: id, withCounts: withCounts)
    }
    
    /// Request a discord invite.
    /// - Parameter code: The invite code
    /// - Throws: `HTTPError.notFound` - The invite could not be found.
    /// - Returns: The partial invite information.
    public func requestInvite(code: String) async throws -> PartialInvite {
        return try await http.getInvite(code: code)
    }
    
    /// Request the sticker packs available with Discord Nitro.
    /// - Returns: The discord nitro sticker pack.
    public func requestNitroStickerPacks() async throws -> [Sticker.Pack] {
        return try await http.getNitroStickerPacks()
    }
    
    /// Request a sticker.
    /// - Parameter id: ID of the sticker.
    /// - Throws: `HTTPError.notFound`- The sticker could not be found.
    /// - Returns: The sticker matching the given ID.
    public func requestSticker(_ id: Snowflake) async throws -> Sticker {
        return try await http.getSticker(stickerId: id)
    }
    
    /// Request a user. Unlike ``getUser(_:)`` this is an API call.
    /// - Parameter id: ID of the user.
    /// - Throws: `HTTPError.notFound` - The user could not be found.
    /// - Returns: The user matching the given ID.
    public func requestUser(_ id: Snowflake) async throws -> User {
        return try await http.getUser(userId: id)
    }
    
    /// Request a guild template based on the provided code. The code is the last parameter of the template URL.
    /// Template URLs look like the following: `https://discord.new/VhauskbbByvn` , where "VhauskbbByvn" is the code.
    /// - Throws: `HTTPError.notFound` - The guild template could not be found.
    /// - Returns: The template matching the given code.
    public func requestTemplate(code: String) async throws -> Guild.Template {
        return try await http.getGuildTemplate(code: code)
    }
    
    /// Request a webhook by its ID.
    /// - Parameter id: The webhooks ID.
    /// - Throws: `HTTPError.notFound` - The webhook could not be found.
    /// - Returns: The webhook matching the given ID.
    public func requestWebhookFrom(id: Snowflake) async throws -> Webhook {
        return try await http.getWebhook(webhookId: id)
    }
    
    /// Request a webhook by its URL. Unlike ``requestWebhookFrom(id:)``, this does not require authentification. Meaning this can be called prior to connecting to Discord via ``connect()``.
    /// - Parameter url: The webhooks URL.
    /// - Throws: `DiscordError.generic` - The URL was not a Discord webhook URL. `HTTPError.notFound` - The webhook was not found.
    /// - Returns: The webhook matching the given URL.
    public func requestWebhookFrom(url: String) async throws -> Webhook {
        let webhookUrlRegex = #/https:\/\/discord[.]com\/api\/webhooks\/[0-9]{17,20}\/.+/#
        guard let _ = url.wholeMatch(of: webhookUrlRegex) else {
            throw DiscordError.generic("Invalid webhook URL")
        }
        let split = Array(url.split(separator: "/").suffix(2))
        let webhookId = split[0].description
        let webhookToken = split[1].description
        
        return try await http.getWebhookWithToken(webhookId: webhookId, webhookToken: webhookToken)
    }
    
    /// Block further execution until the ``EventListener/onReady()`` event has been dispatched.
    public func waitUntilReady() async {
        while wsg?.initialState?.dispatched != true {
            await sleep(150)
        }
    }
}

/// The version of the library.
public struct Version : CustomStringConvertible {
    public let major = 0
    public let minor = 0
    public let patch = 3
    public let releaseLevel = ReleaseLevel.alpha

    /// The string representation of the library version.
    public var description: String { "\(major).\(minor).\(patch) \(releaseLevel)" }
    
    var gateway: (lib: String, os: String) {
        get {
            return ("Discord.swift v\(description)", "macOS \(ProcessInfo().operatingSystemVersionString)")
        }
    }
}

/// The current release level of the library.
public enum ReleaseLevel {
    case preAlpha
    case alpha
    case beta
    case rc
    case final
}
