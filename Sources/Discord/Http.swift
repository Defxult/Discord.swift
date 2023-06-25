import Foundation


/// Some HTTP requests expects the JSON *value* to be `null`. This simply returns `NSNull()` to represent the value of `nil`.
func nullable(_ value: Any?) -> Any { value == nil ? NSNull() : value! }

let NIL = NSNull()
typealias HTTPHeaders = [String: String]

enum HTTPMethod : String {
    case get = "GET"
    case delete = "DELETE"
    case post = "POST"
    case patch = "PATCH"
    case put = "PUT"
}

class MultiPartForm {
    let boundary = UUID().uuidString.replacingOccurrences(of: "-", with: String.empty)
    var data = Data()
    
    // Anything that can upload files
    init(json: JSON, files: [File]) {
        data.append(mpfData("--\(boundary)\r\n"))
        data.append(mpfData("Content-Disposition: form-data; name=\"payload_json\"\r\n"))
        data.append(mpfData("Content-Type: application/json\r\n\r\n"))
        data.append(dictToData(json))
        data.append(mpfData("\r\n"))
        
        for (i, file) in files.enumerated() {
            data.append(mpfData("--\(boundary)\r\n"))
            data.append(mpfData("Content-Disposition: form-data; name=\"files[\(i)]\"; filename=\"\(file.name)\"\r\n"))
            data.append(mpfData("Content-Type: \(file.mimetype)\r\n\r\n"))
            data.append(file.data)
            data.append(mpfData("\r\n"))
        }
    }
    
    // Specifically for Guild.createSticker()
    init(json: JSON, sticker: File) {
        let name = (value: json["name"] as! String, field: "name")
        let desc = (value: json["description"] as! String, field: "description")
        let tags = (value: json["tags"] as! String, field: "tags")
        
        data.append(mpfData("--\(boundary)\r\n"))
        
        for info in [name, desc, tags] {
            data.append(mpfData("Content-Disposition: form-data; name=\"\(info.field)\"\r\n"))
            data.append(mpfData("\r\n\r\n"))
            data.append(mpfData(info.value))
            data.append(mpfData("\r\n"))
            data.append(mpfData("--\(boundary)\r\n"))
        }
        
        data.append(mpfData("Content-Disposition: form-data; name=\"file\"; filename=\"\(sticker.name)\"\r\n"))
        data.append(mpfData("Content-Type: \(sticker.mimetype)\r\n\r\n"))
        data.append(sticker.data)
        data.append(mpfData("\r\n"))
    }

    func encode() -> Data {
        data.append(mpfData("--\(boundary)--"))
        return data
    }
}

fileprivate func mpfData(_ str: String) -> Data {
    str.data(using: .utf8)!
}

struct RateLimit {
    let limit: Int
    let remaining: Int
    let resetTime: TimeInterval
    
    init(limit: Int, remaining: Int, resetTime: TimeInterval) {
        self.limit = limit
        self.remaining = remaining
        self.resetTime = resetTime
    }
}

class HTTPClient {
    
    let bot: Discord
    let token: String
    let session = URLSession.shared
    let staticClientHeaders: HTTPHeaders
    var rateLimits: [String: RateLimit] = [:]
    
    init(bot: Discord, token: String, version: Version) {
        self.bot = bot
        self.token = token
        staticClientHeaders = [
            "User-Agent" : "Discord.swift (https://github.com/Defxult/Discord.swift, \(version.description))",
            "Authorization" : "Bot \(token)",
            "Content-Type" : "application/json"
        ]
    }
    
    static func strJsonToDict(_ str: String) -> JSON {
        return try! JSONSerialization.jsonObject(with: str.data(using: .utf8)!, options: []) as! JSON
    }
    
    static func buildEndpoint(_ path: APIRoute, endpoint: String) -> String {
        guard endpoint.starts(with: "/") else {
            fatalError("Endpoint must start with /")
        }
        return path.rawValue + endpoint
    }
    
    private func withReason(_ reason: String?) -> HTTPHeaders {
        var headers = HTTPHeaders()
        if let reason {
            headers.updateValue(reason, forKey: "X-Audit-Log-Reason")
        }
        return headers
    }
    
    private func handleReaction(_ emoji: String) -> String {
        let customEmojiRegex = "<a?:[a-zA-Z]+:[0-9]{17,20}>"
        
        if let _ = emoji.range(of: customEmojiRegex, options: .regularExpression) {
            let emojiNameRange = emoji.range(of: ":[a-zA-Z]+:", options: .regularExpression)!
            var emojiName = emoji[emojiNameRange]
            emojiName.removeAll(where: { $0 == ":" })
            
            let emojiIdRange = emoji.range(of: #":\d+>"#, options: .regularExpression)!
            var emojiId = emoji[emojiIdRange]
            emojiId.removeAll(where: { $0 == ":" || $0 == ">" })
            return "\(emojiName):\(emojiId)".addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        } else {
            return emoji.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed)!
        }
    }
    
    
    
    // MARK: HTTP Methods
    
    
    
    
    // MARK: Application Commands
    
    /// Fetches permissions for all commands for your application in a guild.
    /// https://discord.com/developers/docs/interactions/application-commands#get-guild-application-command-permissions
    func getGuildApplicationCommandPermissions(botId: Snowflake, guildId: Snowflake) async throws -> [GuildApplicationCommandPermissions] {
        let data = try await request(.get, route("/applications/\(botId)/guilds/\(guildId)/commands/permissions")) as! [JSON]
        var perms = [GuildApplicationCommandPermissions]()
        for permObj in data {
            perms.append(.init(guildAppCommandPermData: permObj))
        }
        return perms
    }
    
    /// Fetches permissions for a specific command for your application in a guild.
    /// https://discord.com/developers/docs/interactions/application-commands#get-application-command-permissions
    func getApplicationCommandPermissions(botId: Snowflake, guildId: Snowflake, commandId: Snowflake) async throws -> GuildApplicationCommandPermissions {
        let data = try await request(.get, route("/applications/\(botId)/guilds/\(guildId)/commands/\(commandId)/permissions")) as! JSON
        return .init(guildAppCommandPermData: data)
    }
    
    // UNUSED
    // Edits command permissions for a specific command for your application in a guild.
    // https://discord.com/developers/docs/interactions/application-commands#edit-application-command-permissions
    // func editApplicationCommandPermissions(botId: Snowflake, guildId: Snowflake, commandId: Snowflake) async throws {}
    
    /// Fetch all of the global commands for your application. Returns an array of application command objects.
    /// https://discord.com/developers/docs/interactions/application-commands#get-global-application-commands
    func getGlobalApplicationCommands(botId: Snowflake) async throws -> [ApplicationCommand] {
        let data = try await request(.get, route("/applications/\(botId)/commands?with_localizations=true")) as! [JSON]
        var globalCommands = [ApplicationCommand]()
        for cmdObj in data {
            globalCommands.append(ApplicationCommand(bot: bot, applicationCommandData: cmdObj))
        }
        return globalCommands
    }
    
    /// Fetch all of the guild commands for your application for a specific guild. Returns an array of application command objects.
    /// https://discord.com/developers/docs/interactions/application-commands#get-guild-application-commands
    func getGuildApplicationCommands(botId: Snowflake, guildId: Snowflake) async throws -> [ApplicationCommand] {
        let data = try await request(.get, route("/applications/\(botId)/guilds/\(guildId)/commands")) as! [JSON]
        var guildCommands = [ApplicationCommand]()
        for cmdObj in data {
            guildCommands.append(ApplicationCommand(bot: bot, applicationCommandData: cmdObj))
        }
        return guildCommands
    }
    
    /// Create a new guild/global command.
    /// https://discord.com/developers/docs/interactions/application-commands#create-guild-application-command
    /// https://discord.com/developers/docs/interactions/application-commands#create-global-application-command
    func createApplicationCommand(
        name: String,
        type: ApplicationCommandType,
        botId: Snowflake,
        guildId: Snowflake?,
        dmPermission: Bool,
        nameLocalizations: [Locale: String]?,
        description: String?,
        descriptionLocalizations: [Locale: String]?,
        options: [ApplicationCommandOption]?,
        defaultMemberPermissions: Permissions?,
        nsfw: Bool
    ) async throws -> ApplicationCommand {
        var payload: JSON = ["name": name, "nsfw": nsfw]
        var endpoint: String
        
        if let guildId {
            endpoint = "/applications/\(botId)/guilds/\(guildId)/commands"
            if let defaultMemberPermissions {
                payload["default_member_permissions"] = String(defaultMemberPermissions.value)
            }
        }
        else {
            endpoint = "/applications/\(botId)/commands"
            payload["dm_permission"] = dmPermission
        }
        
        if let nameLocalizations {
            payload["name_localizations"] = convertFromLocalizations(nameLocalizations)
        }
        
        if let descriptionLocalizations {
            payload["description_localizations"] = convertFromLocalizations(descriptionLocalizations)
        }
        
        switch type {
        case .slashCommand:
            payload["type"] = ApplicationCommandType.slashCommand.rawValue
            payload["description"] = description
            payload["options"] = options?.map({ $0.convert() })
        case .user:
            payload["type"] = ApplicationCommandType.user.rawValue
        case .message:
            payload["type"] = ApplicationCommandType.message.rawValue
        }
        
        let data = try await request(.post, route(endpoint), json: payload) as! JSON
        return ApplicationCommand(bot: bot, applicationCommandData: data)
    }
    
    
    /// Delete an application command.
    /// https://discord.com/developers/docs/interactions/application-commands#delete-global-application-command
    /// https://discord.com/developers/docs/interactions/application-commands#delete-guild-application-command
    func deleteApplicationCommand(botId: Snowflake, commandId: Snowflake, guildId: Snowflake?) async throws {
        var endpoint: String
        if let guildId { endpoint = "/applications/\(botId)/guilds/\(guildId)/commands/\(commandId)" }
        else { endpoint = "/applications/\(botId)/commands/\(commandId)" }
        _ = try await request(.delete, route(endpoint))
    }
    
    /// Create a response to an Interaction from the gateway.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#create-interaction-response
    func createInteractionResponse(interactionId: Snowflake, interactionToken: String, json: JSON, files: [File]?) async throws  {
        _ = try await request(.post, route("/interactions/\(interactionId)/\(interactionToken)/callback"), json: json, files: files)
    }
    
    /// Returns the initial Interaction response.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#get-original-interaction-response
    func getOriginalInteractionResponse(botId: Snowflake, interactionToken: String, threadId: Snowflake?) async throws -> Message {
        var endpoint = "/webhooks/\(botId)/\(interactionToken)/messages/@original"
        if let threadId { endpoint += "?thread_id=\(threadId)" }
        
        let data = try await request(.get, route(endpoint)) as! JSON
        return .init(bot: bot, messageData: data)
    }
    
    /// Edits the initial interaction response.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#edit-original-interaction-response
    func editOriginalInteractionResponse(botId: Snowflake, interactionToken: String, json: JSON, files: [File]?, threadId: Snowflake?) async throws -> Message {
        var endpoint = "/webhooks/\(botId)/\(interactionToken)/messages/@original"
        if let threadId { endpoint += "?thread_id=\(threadId)" }
        
        let data = try await request(.patch, route(endpoint), json: json, files: files) as! JSON
        return .init(bot: bot, messageData: data)
    }
    
    /// Deletes the initial Interaction response.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#delete-original-interaction-response
    func deleteOriginalInteractionResponse(botId: Snowflake, interactionToken: String) async throws {
        _ = try await request(.delete, route("/webhooks/\(botId)/\(interactionToken)/messages/@original"))
    }
    
    /// Create a followup message for an Interaction.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#create-followup-message
    func createFollowupMessage(botId: Snowflake, interactionToken: String, json: JSON, files: [File]?) async throws -> Message {
        let data = try await request(.post, route("/webhooks/\(botId)/\(interactionToken)"), json: json, files: files) as! JSON
        return .init(bot: bot, messageData: data)
    }
    
    /// Returns a followup message for an Interaction.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#get-followup-message
    func getFollowupMessage(botId: Snowflake, interactionToken: String, messageId: Snowflake) async throws -> Message {
        let data = try await request(.get, route("/webhooks/\(botId)/\(interactionToken)/messages/\(messageId)")) as! JSON
        return .init(bot: bot, messageData: data)
    }
    
    /// Edits a followup message for an Interaction.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#edit-followup-message
    func editFollowupMessage(botId: Snowflake, interactionToken: String, messageId: Snowflake, json: JSON, files: [File]?, threadId: Snowflake?) async throws -> Message {
        var endpoint = "/webhooks/\(botId)/\(interactionToken)/messages/\(messageId)"
        if let threadId { endpoint += "?thread_id=\(threadId)" }
        
        let data = try await request(.patch, route(endpoint), json: json, files: files) as! JSON
        return .init(bot: bot, messageData: data)
    }
    
    /// Deletes a followup message for an Interaction.
    /// https://discord.com/developers/docs/interactions/receiving-and-responding#delete-followup-message
    func deleteFollowupMessage(botId: Snowflake, interactionToken: String, messageId: Snowflake) async throws {
        _ = try await request(.delete, route("/webhooks/\(botId)/\(interactionToken)/messages/\(messageId)"))
    }
    
    /// ⚠️ Needs more testing.
    /// Edit the global/guild application command.
    /// https://discord.com/developers/docs/interactions/application-commands#edit-guild-application-command
    /// https://discord.com/developers/docs/interactions/application-commands#edit-global-application-command
    func editApplicationCommand(botId: Snowflake, appCommandId: Snowflake, guildId: Snowflake?, json: JSON) async throws -> ApplicationCommand {
        var endpoint: String
        
        if let guildId { endpoint = "/applications/\(botId)/guilds/\(guildId)/commands/\(appCommandId)" }
        else { endpoint = "/applications/\(botId)/commands/\(appCommandId)" }
        
        let data = try await request(.patch, route(endpoint), json: json) as! JSON
        return .init(bot: bot, applicationCommandData: data)
    }
    
    /// https://discord.com/developers/docs/interactions/application-commands#edit-application-command-permissions
    func editApplicationCommandPermissions() {}
    
    
    // -------------------------------------------------------------------------
    
    
    
    
    // MARK: Other HTTP Methods
    
    /// Returns the guilds onboarding.
    /// https://discord.com/developers/docs/resources/guild#get-guild-onboarding
    func getGuildOnboarding(guildId: Snowflake) async throws -> Guild.Onboarding {
        let data = try await request(.get, route("/guilds/\(guildId)/onboarding")) as! JSON
        return .init(onboardingData: data)
    }
    
    /// Returns the bot's application object.
    /// https://discord.com/developers/docs/topics/oauth2#get-current-bot-application-information
    func getCurrentBotApplicationInformation() async throws -> Application {
        let data = try await request(.get, route("/oauth2/applications/@me")) as! JSON
        return .init(appData: data)
    }
    
    // UNUSED
    // Returns info about the current authorization. Requires authentication with a bearer token.
    // https://discord.com/developers/docs/topics/oauth2#get-current-authorization-information
    // func getCurrentAuthorizationInformation() {}
    
    /// Returns an audit log object for the guild.
    /// https://discord.com/developers/docs/resources/audit-log#get-guild-audit-log
    func getGuildAuditLog(guildId: Snowflake, queryParams: [URLQueryItem]) async throws -> AuditLog {
        var url = URL(string: route("/guilds/\(guildId)/audit-logs"))!
        url.append(queryItems: queryParams)
        let data = try await request(.get, url.absoluteString) as! JSON
        return .init(auditLogData: data)
    }
    
    /// Update a channel's settings and logs the reason.
    /// https://discord.com/developers/docs/resources/channel#modify-channel
    func modifyChannel(channelId: Snowflake, guildId: Snowflake, json: JSON, reason: String?) async throws -> GuildChannel {
        let data = try await request(.patch, route("/channels/\(channelId)"), json: json, additionalHeaders: withReason(reason)) as! JSON
        return determineGuildChannelType(type: data["type"] as! Int, data: data, bot: bot, guildId: guildId)
    }
    
    /// Delete a channel and logs the reason, or close a private message. For Community guilds, the Rules or Guidelines channel and the Community Updates channel cannot be deleted.
    /// https://discord.com/developers/docs/resources/channel#deleteclose-channel
    func deleteChannel(channelId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)"), additionalHeaders: withReason(reason))
    }
    
    private func handleGetChannelMessages(data: [JSON]) -> [Message] {
        var messages = [Message]()
        for msgObj in data {
            messages.append(.init(bot: bot, messageData: msgObj))
        }
        return messages
    }
    
    /// Returns the messages for a channel.
    /// https://discord.com/developers/docs/resources/channel#get-channel-messages
    func getChannelMessages(channelId: Snowflake, limit: Int) async throws -> [Message] {
        let data = try await request(.get, route("/channels/\(channelId)/messages?limit=\(limit)")) as! [JSON]
        return handleGetChannelMessages(data: data)
    }
    
    /// Returns the messages for a channel before a specific snowflake.
    /// https://discord.com/developers/docs/resources/channel#get-channel-messages
    func getChannelMessages(channelId: Snowflake, limit: Int, before: Snowflake) async throws -> [Message] {
        let data = try await request(.get, route("/channels/\(channelId)/messages?limit=\(limit)&before=\(before)")) as! [JSON]
        return handleGetChannelMessages(data: data)
    }
    
    /// Returns the messages for a channel after a specific snowflake.
    /// https://discord.com/developers/docs/resources/channel#get-channel-messages
    func getChannelMessages(channelId: Snowflake, limit: Int, after: Snowflake) async throws -> [Message] {
        let data = try await request(.get, route("/channels/\(channelId)/messages?limit=\(limit)&after=\(after)")) as! [JSON]
        return handleGetChannelMessages(data: data)
    }
    
    /// Returns the messages for a channel around a specific snowflake.
    /// https://discord.com/developers/docs/resources/channel#get-channel-messages
    func getChannelMessages(channelId: Snowflake, limit: Int, around: Snowflake) async throws -> [Message] {
        let data = try await request(.get, route("/channels/\(channelId)/messages?limit=\(limit)&around=\(around)")) as! [JSON]
        return handleGetChannelMessages(data: data)
    }
    
    /// Returns a specific message in the channel.
    /// https://discord.com/developers/docs/resources/channel#get-channel-messages
    func getChannelMessage(channelId: Snowflake, messageId: Snowflake) async throws -> Message {
        let data = try await request(.get, route("/channels/\(channelId)/messages/\(messageId)")) as! JSON
        return .init(bot: bot, messageData: data)
    }
    
    /// Crosspost (publish) a message in a News Channel to following channels.
    /// https://discord.com/developers/docs/resources/channel#crosspost-message
    func crosspostMessage(channelId: Snowflake, messageId: Snowflake) async throws {
        // This returns the same exact message that was crossposted (publushed), but there's
        // no point in returning the same message when you have access to said message to use this method
        _ = try await request(.post, route("/channels/\(channelId)/messages/\(messageId)/crosspost"), json: [:]) as! JSON
    }
    
    /// Delete a reaction the current user has made for the message.
    /// https://discord.com/developers/docs/resources/channel#delete-own-reaction
    func deleteOwnReaction(channelId: Snowflake, messageId: Snowflake, emoji: String) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)/messages/\(messageId)/reactions/\(handleReaction(emoji))/@me"))
    }
    
    /// Delete a reaction the current user has made for the message.
    /// https://discord.com/developers/docs/resources/channel#delete-user-reaction
    func deleteUserReaction(channelId: Snowflake, messageId: Snowflake, emoji: String, userId: Snowflake) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)/messages/\(messageId)/reactions/\(handleReaction(emoji))/\(userId)"))
    }
    
    /// ⚠️ Needs testing with a large amount of reactions.
    /// Get a list of users that reacted with this emoji.
    /// https://discord.com/developers/docs/resources/channel#get-reactions
    func getUsersForReaction(channelId: Snowflake, messageId: Snowflake, emoji: String, limit: Int, after: Snowflake?) async throws -> [JSON] {
        var endpoint = "/channels/\(channelId)/messages/\(messageId)/reactions/\(handleReaction(emoji))?limit=\(limit)"
        if let after { endpoint += "&after=\(after)" }
        return try await request(.get, route(endpoint)) as! [JSON]
    }
    
    /// Deletes all reactions on a message.
    /// https://discord.com/developers/docs/resources/channel#delete-all-reactions
    func deleteAllReactions(channelId: Snowflake, messageId: Snowflake) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)/messages/\(messageId)/reactions"))
    }
    
    /// Deletes all the reactions for a given emoji on a message.
    /// https://discord.com/developers/docs/resources/channel#delete-all-reactions-for-emoji
    func deleteAllReactionsForEmoji(channelId: Snowflake, messageId: Snowflake, emoji: String) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)/messages/\(messageId)/reactions/\(handleReaction(emoji))"))
    }
    
    /// Edit a previously sent message.
    /// https://discord.com/developers/docs/resources/channel#edit-message
    func editMessage(channelId: Snowflake, messageId: Snowflake, json: JSON?, files: [File]?) async throws -> Message {
        let data = try await request(.patch, route("/channels/\(channelId)/messages/\(messageId)"), json: json, files: files) as! JSON
        return .init(bot: bot, messageData: data)
    }
    
    /// Delete a message and log the reason in the audit log.
    /// https://discord.com/developers/docs/resources/channel#delete-message
    /// Note: Docs say this supports REASON, but it hasnt been showing in the audit logs. Did they disable this for deleting messages?  (8/9/2022)
    func deleteMessage(channelId: Snowflake, messageId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)/messages/\(messageId)"), additionalHeaders: withReason(reason))
    }
    
    /// Delete multiple messages in a single request.
    /// https://discord.com/developers/docs/resources/channel#bulk-delete-messages
    func bulkDeleteMessages(channelId: Snowflake, messagesToDelete: [Message], reason: String?) async throws {
        var messagesToDelete = messagesToDelete
        
        // If there are any messages older than 2 weeks, an HTTPError.badRequest will occur
        messagesToDelete = messagesToDelete.filter({ $0.createdAt > Calendar.current.date(byAdding: .day, value: -14, to: .now)! })
        
        // If there are any duplicate snowflakes, an HTTPError.badRequest will occur
        let messageSnowflakesToDelete = Array(Set(messagesToDelete.map({ $0.id })))
        
        _ = try await request(.post, route("/channels/\(channelId)/messages/bulk-delete"), json: ["messages": messageSnowflakesToDelete], additionalHeaders: withReason(reason))
    }
    
    /// Edit the channel permission overwrites for a user or role in a channel
    /// https://discord.com/developers/docs/resources/channel#edit-channel-permissions
    func editChannelPermissions(channelId: Snowflake, overwrites: PermissionOverwrites, reason: String?) async throws {
        _ = try await request(.put, route("/channels/\(channelId)/permissions/\(overwrites.id)"), json: overwrites.convert(), additionalHeaders: withReason(reason))
    }
    
    /// Returns a list of invite objects (with invite metadata) for the channel.
    /// https://discord.com/developers/docs/resources/channel#get-channel-invites
    func getChannelInvites(channelId: Snowflake) async throws -> [Invite] {
        var invites = [Invite] ()
        let data = try await request(.get, route("/channels/\(channelId)/invites")) as! [JSON]
        for inviteObj in data {
            invites.append(.init(bot: bot, inviteData: inviteObj))
        }
        return invites
    }
    
    /// Create a new invite object for the channel.
    /// https://discord.com/developers/docs/resources/channel#create-channel-invite
    func createChannelInvite(
        channelId: Snowflake,
        maxAge: Int,
        maxUses: Int,
        temporary: Bool,
        unique: Bool,
        targetType: Invite.Target?,
        targetUserId: Snowflake?,
        targetApplicationId: Snowflake?,
        reason: String?
    ) async throws -> Invite {
        var payload: JSON = [
            "max_age": maxAge,
            "max_uses": maxUses,
            "temporary": temporary,
            "unique": unique
        ]
        if let targetType {
            payload["target_type"] = targetType.rawValue
        }
        if let targetUserId {
            payload["target_user_id"] = targetUserId
        }
        if let targetApplicationId {
            payload["target_application_id"] = targetApplicationId
        }
        let data = try await request(.post, route("/channels/\(channelId)/invites"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, inviteData: data)
    }
    
    /// Delete a channel permission overwrite for a user or role in a channel.
    /// https://discord.com/developers/docs/resources/channel#delete-channel-permission
    func deleteChannelPermission(channelId: Snowflake, userOrRoleId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)/permissions/\(userOrRoleId)"), additionalHeaders: withReason(reason))
    }
    
    /// Follow an Announcement Channel to send messages to a target channel.
    /// https://discord.com/developers/docs/resources/channel#follow-announcement-channel
    func followAnnouncementChannel(channelToFollow: Snowflake, sendMessagesTo: Snowflake) async throws -> Webhook {
        let data = try await request(.post, route("/channels/\(channelToFollow)/followers"), json: ["webhook_channel_id": sendMessagesTo]) as! JSON
        let webhookId = Conversions.snowflakeToUInt(data["webhook_id"])
        return try await getWebhook(webhookId: webhookId)
    }
    
    /// Post a typing indicator for the specified channel.
    /// https://discord.com/developers/docs/resources/channel#trigger-typing-indicator
    func triggerTypingIndicator(channelId: Snowflake) async throws {
        _ = try await request(.post, route("/channels/\(channelId)/typing"))
    }
    
    /// Returns all pinned messages in the channel. (`TextChannel`, `DMChannel`, `ThreadChannel`)
    /// https://discord.com/developers/docs/resources/channel#get-pinned-messages
    func getPinnedMessages(channelId: Snowflake) async throws -> [Message] {
        let data = try await request(.get, route("/channels/\(channelId)/pins")) as! [JSON]
        var messages = [Message]()
        for msgObj in data {
            messages.append(.init(bot: bot, messageData: msgObj))
        }
        return messages
    }
    
    /// Pin a message in a channel.
    /// https://discord.com/developers/docs/resources/channel#pin-message
    func pinMessage(channelId: Snowflake, messageId: Snowflake, reason: String?) async throws {
        _ = try await request(.put, route("/channels/\(channelId)/pins/\(messageId)"), additionalHeaders: withReason(reason))
    }
    
    /// Unpin a message from a channel.
    /// https://discord.com/developers/docs/resources/channel#unpin-message
    func unpinMessage(channelId: Snowflake, messageId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/channels/\(channelId)/pins/\(messageId)"), additionalHeaders: withReason(reason))
    }
    
    /// Creates a new thread from an existing message.
    /// https://discord.com/developers/docs/resources/channel#start-thread-from-message
    func startThreadFromMessage(
        channelId: Snowflake,
        guildId: Snowflake,
        messageId: Snowflake,
        threadName: String,
        autoArchiveDuration: ThreadChannel.ArchiveDuration? = nil,
        slowmodeInSeconds: Int? = nil,
        reason: String?
    ) async throws -> ThreadChannel {
        var payload: JSON = ["name": threadName]
        if let autoArchiveDuration {
            payload["auto_archive_duration"] = autoArchiveDuration.rawValue
        }
        if let slowmodeInSeconds {
            payload["rate_limit_per_user"] = slowmodeInSeconds
        }
        let data = try await request(.post, route("/channels/\(channelId)/messages/\(messageId)/threads"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, threadData: data, guildId: guildId)
    }
    
    /// Creates a new thread that is not connected to an existing message.
    /// NOTE: Tested and it's only valid for `TextChannel`
    /// https://discord.com/developers/docs/resources/channel#start-thread-without-message
    func startThreadWithoutMessage(
        channelId: Snowflake,
        guildId: Snowflake,
        threadName: String,
        autoArchiveDuration: ThreadChannel.ArchiveDuration,
        slowmodeInSeconds: Int?,
        invitable: Bool,
        reason: String?
    ) async throws -> ThreadChannel {
        var payload: JSON = ["name": threadName, "invitable": invitable]
        payload["auto_archive_duration"] = autoArchiveDuration.rawValue
        
        if let slow = slowmodeInSeconds {
            payload["rate_limit_per_user"] = slow
        }
        
        let data = try await request(.post, route("/channels/\(channelId)/threads"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, threadData: data, guildId: guildId)
    }
    
    /// Creates a new thread in a forum channel, and sends a message within the created thread
    /// https://discord.com/developers/docs/resources/channel#start-thread-in-forum-channel
    public func startThreadInForumChannel(
        channelId: Snowflake,
        guildId: Snowflake,
        name: String,
        archiveDuration: ThreadChannel.ArchiveDuration,
        slowmode: Int?,
        forumThreadMessage: JSON,
        files: [File]?
    ) async throws -> (thread: ThreadChannel, message: Message) {
        let data = try await request(.post, route("/channels/\(channelId)/threads"), json: forumThreadMessage, files: files) as! JSON
        let nestedMessage = Message(bot: bot, messageData: data["message"] as! JSON)
        return (ThreadChannel(bot: bot, threadData: data, guildId: guildId), nestedMessage)
    }
    
    /// Adds the current user to a thread.
    /// https://discord.com/developers/docs/resources/channel#join-thread
    func joinThread(threadId: Snowflake) async throws {
        _ = try await request(.put, route("/channels/\(threadId)/thread-members/@me"))
    }
    
    /// Adds another member to a thread.
    /// https://discord.com/developers/docs/resources/channel#add-thread-member
    func addThreadMember(threadId: Snowflake, userId: Snowflake) async throws {
        _ = try await request(.put, route("/channels/\(threadId)/thread-members/\(userId)"))
    }
    
    /// Removes the current user from a thread.
    /// https://discord.com/developers/docs/resources/channel#leave-thread
    func leaveThread(threadId: Snowflake) async throws {
        _ = try await request(.delete, route("/channels/\(threadId)/thread-members/@me"))
    }
    
    /// Removes another member from a thread.
    /// https://discord.com/developers/docs/resources/channel#remove-thread-member
    func removeThreadMember(threadId: Snowflake, userId: Snowflake) async throws {
        _ = try await request(.delete, route("/channels/\(threadId)/thread-members/\(userId)"))
    }
    
    /// Returns a thread member object for the specified user.
    /// https://discord.com/developers/docs/resources/channel#get-thread-member
    func getThreadMember(threadId: Snowflake, userId: Snowflake) async throws -> ThreadChannel.ThreadMember {
        let data = try await request(.get, route("/channels/\(threadId)/thread-members/\(userId)")) as! JSON
        return .init(threadMemberData: data)
    }
    
    /// Returns thread members.
    /// https://discord.com/developers/docs/resources/channel#list-thread-members
    func getThreadMembers(threadId: Snowflake) async throws -> [ThreadChannel.ThreadMember] {
        let data = try await request(.get, route("/channels/\(threadId)/thread-members")) as! [JSON]
        var threadMembers = [ThreadChannel.ThreadMember]()
        for threadMemberObj in data {
            threadMembers.append(.init(threadMemberData: threadMemberObj))
        }
        return threadMembers
    }
    
    // ⚠️ `hasMore` needs full testing.
    // PUBLIC https://discord.com/developers/docs/resources/channel#list-public-archived-threads
    // PRIVATE https://discord.com/developers/docs/resources/channel#list-private-archived-threads
    // JOINED https://discord.com/developers/docs/resources/channel#list-joined-private-archived-threads
    /// This uses ``TextChannel/AsyncArchivedThreads``.
    func getPublicPrivateJoinedArchivedThreads(
        channelId: Snowflake,
        before: Date,
        limit: Int,
        joined: Bool,
        private: Bool
    ) async throws -> JSON {
        guard !(joined && `private` == false) else {
            throw DiscordError.generic("Parameter 'joined' cannot be true while 'private' is false")
        }
        
        var endpoint = String.empty
        
        if joined {
            endpoint = "/channels/\(channelId)/users/@me/threads/archived/private"
        } else if `private` {
            endpoint = "/channels/\(channelId)/threads/archived/private"
        } else {
            endpoint = "/channels/\(channelId)/threads/archived/public"
        }
        
        endpoint += "?before=\(before.asISO8601)&limit=\(limit)"
        return try await request(.get, route(endpoint)) as! JSON
    }
    
    /// Returns a list of emojis for the given guild.
    /// https://discord.com/developers/docs/resources/emoji#list-guild-emojis
    func getGuildEmojis(guildId: Snowflake) async throws -> [Emoji] {
        let data = try await request(.get, route("/guilds/\(guildId)/emojis")) as! [JSON]
        var emojis = [Emoji]()
        for emojiObj in data {
            emojis.append(.init(bot: bot, guildId: guildId, emojiData: emojiObj))
        }
        return emojis
    }
    
    /// Returns an emoji for the given guild.
    /// https://discord.com/developers/docs/resources/emoji#get-guild-emoji
    func getGuildEmoji(guildId: Snowflake, emojiId: Snowflake) async throws -> Emoji {
        let data = try await request(.get, route("/guilds/\(guildId)/emojis/\(emojiId)")) as! JSON
        return .init(bot: bot, guildId: guildId, emojiData: data)
    }
    
    /// Create a new emoji for the guild.
    /// https://discord.com/developers/docs/resources/emoji#create-guild-emoji
    func createGuildEmoji(guildId: Snowflake, name: String, file: File, roles: [Snowflake]?, reason: String?) async throws -> Emoji {
        let payload: JSON = [
            "name": name,
            "image": file.asImageData,
            "roles": roles ?? []
        ]
        
        let data = try await request(.post, route("/guilds/\(guildId)/emojis"), json: payload, additionalHeaders: withReason(reason))
        return .init(bot: bot, guildId: guildId, emojiData: data as! JSON)
    }
    
    /// Modify the give emoji. Returns the updated emoji on success.
    /// https://discord.com/developers/docs/resources/emoji#modify-guild-emoji
    func modifyGuildEmoji(guildId: Snowflake, emojiId: Snowflake, payload: JSON, reason: String?) async throws -> Emoji {
        let data = try await request(.patch, route("/guilds/\(guildId)/emojis/\(emojiId)"), json: payload, additionalHeaders: withReason(reason))
        return .init(bot: bot, guildId: guildId, emojiData: data as! JSON)
    }
    
    /// Create a new guild. Bot must be in less than 10 guilds.
    /// https://discord.com/developers/docs/resources/guild#create-guild
    func createGuild(name: String, icon: File?) async throws -> Guild {
        var payload: JSON = ["name": name]
        if let icon { payload["icon"] = icon.asImageData }
        let data = try await request(.post, route("/guilds"), json: payload)
        return .init(bot: bot, guildData: data as! JSON)
    }
    
    /// Delete guild emoji.
    /// https://discord.com/developers/docs/resources/emoji#delete-guild-emoji
    func deleteGuildEmoji(guildId: Snowflake, emojiId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/emojis/\(emojiId)"), additionalHeaders: withReason(reason))
    }
    
    /// Get guild.
    /// https://discord.com/developers/docs/resources/guild#get-guild
    func getGuild(guildId: Snowflake, withCounts: Bool) async throws -> Guild {
        let data = try await request(.get, route("/guilds/\(guildId)?with_counts=\(withCounts)")) as! JSON
        return .init(bot: bot, guildData: data)
    }
    
    /// Get the guild preview object.
    /// https://discord.com/developers/docs/resources/guild#get-guild-preview
    func guildPreview(guildId: Snowflake) async throws -> Guild.Preview {
        let data = try await request(.get, route("/guilds/\(guildId)/preview"))
        return .init(bot: bot, previewData: data as! JSON)
    }
    
    /// ⚠️ Needs full testing.
    /// Edit the guild.
    /// https://discord.com/developers/docs/resources/guild#modify-guild
    func modifyGuild(guildId: Snowflake, payload: JSON, reason: String?) async throws -> Guild {
        let data = try await request(.patch, route("/guilds/\(guildId)"), json: payload, additionalHeaders: withReason(reason))
        return .init(bot: bot, guildData: data as! JSON)
    }
    
    /// Delete a guild permanently.
    /// https://discord.com/developers/docs/resources/guild#delete-guild
    func deleteGuild(guildId: Snowflake) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)"))
    }
    
    /// Get all guild channels.
    /// https://discord.com/developers/docs/resources/guild#get-guild-channels
    func getGuildChannels(guildId: Snowflake) async throws -> [GuildChannel] {
        let data = try await request(.get, route("/guilds/\(guildId)/channels")) as! [JSON]
        var channels = [GuildChannel]()
        for channelObj in data {
            let type = channelObj["type"] as! Int
            channels.append(determineGuildChannelType(type: type, data: channelObj, bot: bot, guildId: guildId))
        }
        return channels
    }
    
    /// Create a new text channel for the guild.
    /// https://discord.com/developers/docs/resources/guild#create-guild-channel
    func createGuildTextChannel(
        guildId: Snowflake,
        name: String,
        categoryId: Snowflake?,
        topic: String?,
        slowmode: Int?,
        position: Int?,
        overwrites: [PermissionOverwrites]?,
        nsfw: Bool,
        reason: String?
    ) async throws -> TextChannel {
        let payload: JSON = [
            "name": name,
            "parent_id": nullable(categoryId),
            "type": ChannelType.guildText.rawValue,
            "topic": nullable(topic),
            "rate_limit_per_user": slowmode as Any,
            "position": position as Any,
            "permission_overwrites": overwrites?.map({ $0.convert() }) as Any,
            "nsfw": nsfw
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/channels"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, channelData: data, guildId: guildId)
    }
    
    /// Create a forum channel.
    /// https://discord.com/developers/docs/resources/guild#create-guild-channel
    /// https://discord.com/developers/docs/resources/channel#channel-object-channel-structure
    /// https://discord.com/developers/docs/resources/channel#forum-tag-object
    func createForumChannel(
        guildId: Snowflake,
        name: String,
        categoryId: Snowflake?,
        topicAKAguidelines: String?,
        position: Int?,
        nsfw: Bool,
        overwrites: [PermissionOverwrites]?,
        slowmode: Int?, // the cooldown for thread creation
        defaultArchiveDuration: Int?, // duration for inactive threads
        defaultThreadSlowmode: Int?, // for threads themselves
        defaultReactionEmoji: PartialEmoji?,
        availableTags: [ForumChannel.Tag]?,
        sortOrder: ForumChannel.SortOrder?,
        layout: ForumChannel.Layout,
        reason: String?
    ) async throws -> ForumChannel {
        let payload: JSON = [
            "name": name,
            "parent_id": nullable(categoryId),
            "topic": topicAKAguidelines as Any,
            "position": position as Any,
            "nsfw": nsfw,
            "permission_overwrites": overwrites?.map({ $0.convert() }) as Any,
            "rate_limit_per_user": defaultThreadSlowmode as Any,
            "default_auto_archive_duration": defaultArchiveDuration as Any,
            "default_thread_rate_limit_per_user": slowmode as Any,
            "available_tags": availableTags?.map({ $0.convert() }) as Any,
            "default_sort_order": sortOrder?.rawValue as Any,
            "default_forum_layout": layout.rawValue,
            "default_reaction_emoji": defaultReactionEmoji?.convert() as Any,
            "type": ChannelType.guildForum.rawValue
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/channels"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, fcData: data, guildId: guildId)
    }
    
    /// Create a new voice channel for the guild.
    /// https://discord.com/developers/docs/resources/guild#create-guild-channel
    func createGuildVoiceChannel(
        guildId: Snowflake,
        name: String,
        category: CategoryChannel?,
        bitrate: Int,
        userLimit: Int?,
        position: Int?,
        overwrites: [PermissionOverwrites]?,
        region: VoiceChannel.RtcRegion,
        quality: VoiceChannel.VideoQualityMode,
        nsfw: Bool,
        reason: String?
    ) async throws -> VoiceChannel {
        let payload: JSON = [
            "name": name,
            "parent_id": category?.id as Any,
            "type": ChannelType.guildVoice.rawValue,
            "bitrate": bitrate,
            "user_limit": userLimit as Any,
            "position": position as Any,
            "permission_overwrites": overwrites?.map({ $0.convert() }) as Any,
            "rtc_region": (region == .automatic ? nil : region.rawValue)!,
            "video_quality_mode": quality.rawValue,
            "nsfw": nsfw
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/channels"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, vcData: data, guildId: guildId)
    }
    
    /// Create a new stage channel for the guild.
    /// https://discord.com/developers/docs/resources/guild#create-guild-channel
    func createGuildStageChannel(
        guildId: Snowflake,
        name: String,
        bitrate: Int,
        position: Int?,
        overwrites: [PermissionOverwrites]?,
        region: VoiceChannel.RtcRegion,
        reason: String?
    ) async throws -> StageChannel {
        let payload: JSON = [
            "name": name,
            "type": ChannelType.guildStageVoice.rawValue,
            "bitrate": bitrate,
            "position": position as Any,
            "permission_overwrites": overwrites?.map({ $0.convert() }) as Any,
            "rtc_region": region == .automatic ? NIL : region.rawValue
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/channels"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, scData: data, guildId: guildId)
    }
    
    /// Create a new category for the guild.
    /// https://discord.com/developers/docs/resources/guild#create-guild-channel
    func createGuildCategory(guildId: Snowflake, name: String, position: Int?, overwrites: [PermissionOverwrites]?, reason: String?) async throws -> CategoryChannel {
        let payload: JSON = [
            "name": name,
            "type": ChannelType.guildCategory.rawValue,
            "position": position as Any,
            "permission_overwrites": overwrites?.map({ $0.convert() }) as Any,
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/channels"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, categoryData: data, guildId: guildId)
    }
    
    // UNUSED
    // Modify the positions of channel for the guild.
    // https://discord.com/developers/docs/resources/guild#modify-guild-channel-positions
    // func modifyGuildChannelPositions() {}
    
    /// Returns all active threads in a guild that the current user can access, includes public & private threads.
    /// https://discord.com/developers/docs/resources/guild#list-active-guild-threads
    func getActiveGuildThreads(guildId: Snowflake) async throws -> [ThreadChannel] {
        let data = try await request(.get, route("/guilds/\(guildId)/threads/active")) as! JSON
        let threadObjs = data["threads"] as! [JSON]
        var threads = [ThreadChannel]()
        for threadObj in threadObjs {
            threads.append(.init(bot: bot, threadData: threadObj, guildId: guildId))
        }
        return threads
    }
    
    /// Returns a guild member for the specified user.
    /// https://discord.com/developers/docs/resources/guild#get-guild-member
    func getGuildMember(guildId: Snowflake, userId: Snowflake) async throws -> Member {
        let data = try await request(.get, route("/guilds/\(guildId)/members/\(userId)")) as! JSON
        return .init(bot: bot, memberData: data, guildId: guildId)
    }
    
    /// Returns a list of members in the guild.
    /// https://discord.com/developers/docs/resources/guild#list-guild-members
    func getMultipleGuildMembers(guildId: Snowflake, limit: Int, after: Snowflake?) async throws -> [JSON] {
        let endpoint = "/guilds/\(guildId)/members?limit=\(limit)" + (after == nil ? String.empty : "&after=\(after!)")
        return try await request(.get, route(endpoint)) as! [JSON]
    }
    
    /// Returns a list of members whose username or nickname starts with a provided string.
    /// https://discord.com/developers/docs/resources/guild#search-guild-members
    func searchGuildMembers(guildId: Snowflake, query: String, limit: Int?) async throws -> [Member] {
        let endpoint = limit == nil ? "/guilds/\(guildId)/members/search" : "/guilds/\(guildId)/members/search?query=\(query)&limit=\(limit!)"
        let data = try await request(.get, route(endpoint)) as! [JSON]
        var members = [Member]()
        for memberObj in data {
            members.append(.init(bot: bot, memberData: memberObj, guildId: guildId))
        }
        return members
    }

    /// ⚠️ Needs more testing.
    /// Modifies a guild member
    /// https://discord.com/developers/docs/resources/guild#modify-guild-member
    func modifyGuildMember(guildId: Snowflake, userId: Snowflake, data: JSON, reason: String?) async throws -> Member {
        let data = try await request(.patch, route("/guilds/\(guildId)/members/\(userId)"), json: data, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, memberData: data, guildId: guildId)
    }
    
    /// Adds a role to a guild member.
    /// https://discord.com/developers/docs/resources/guild#add-guild-member-role
    func addRoleToMember(guildId: Snowflake, userId: Snowflake, roleId: Snowflake, reason: String?) async throws {
        _ = try await request(.put, route("/guilds/\(guildId)/members/\(userId)/roles/\(roleId)"), additionalHeaders: withReason(reason))
    }
    
    /// Removes a role from a guild member.
    /// https://discord.com/developers/docs/resources/guild#remove-guild-member-role
    func removeRoleFromMember(guildId: Snowflake, userId: Snowflake, roleId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/members/\(userId)/roles/\(roleId)"), additionalHeaders: withReason(reason))
    }
    
    /// Removes a guild member.
    /// https://discord.com/developers/docs/resources/guild#remove-guild-member
    func removeGuildMember(guildId: Snowflake, userId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/members/\(userId)"), additionalHeaders: withReason(reason))
    }
    
    /// ⚠️ Tested and works for guilds with less than 1000 bans. I'm not in a guild that has 1000+ bans, so the 1000+ functionality has not been tested.
    /// Returns a list of users banned from this guild.
    /// https://discord.com/developers/docs/resources/guild#get-guild-bans
    func getGuildBans(guildId: Snowflake, limit: Int, before: Snowflake?, after: Snowflake?) async throws -> [JSON] {
        var endpoint = "/guilds/\(guildId)/bans?limit=\(limit)"
        if let before {
            endpoint += "&before=\(before)"
        }
        if let after {
            endpoint += "&after=\(after)"
        }
        
        return try await request(.get, route(endpoint)) as! [JSON]
    }
    
    /// Returns a ban object for the given user.
    /// https://discord.com/developers/docs/resources/guild#get-guild-ban
    func getGuildBan(guildId: Snowflake, userId: Snowflake) async throws -> Guild.Ban {
        let data = try await request(.get, route("/guilds/\(guildId)/bans/\(userId)")) as! JSON
        return .init(banData: data)
    }
    
    /// Create a guild ban, and optionally delete previous messages sent by the banned user.
    /// https://discord.com/developers/docs/resources/guild#create-guild-ban
    func createGuildBan(guildId: Snowflake, userId: Snowflake, deleteMessageSeconds: Int, reason: String?) async throws {
        let payload = ["delete_message_seconds" : deleteMessageSeconds]
        _ = try await request(.put, route("/guilds/\(guildId)/bans/\(userId)"), json: payload, additionalHeaders: withReason(reason))
    }
    
    /// Remove the ban for a user.
    /// https://discord.com/developers/docs/resources/guild#remove-guild-ban
    func removeGuildBan(guildId: Snowflake, userId: Snowflake, reason: String?) async throws {
        // Note: for whatever reason, this will error with "invalid json body" if an empty dict is not passed
        _ = try await request(.delete, route("/guilds/\(guildId)/bans/\(userId)"), json: [:], additionalHeaders: withReason(reason))
    }
    
    /// Returns a list of roles for the guild.
    /// https://discord.com/developers/docs/resources/guild#get-guild-roles
    func getGuildRoles(guildId: Snowflake) async throws -> [Role] {
        let data = try await request(.get, route("/guilds/\(guildId)/roles"))
        var roles = [Role]()
        for roleObj in data as! [JSON] {
            roles.append(.init(bot: bot, roleData: roleObj, guildId: guildId))
        }
        return roles
    }

    /// Create a new role for the guild.
    /// https://discord.com/developers/docs/resources/guild#create-guild-role
    func createGuildRole(
        guildId: Snowflake,
        name: String?,
        permissions: Permissions,
        color: Color?,
        hoist: Bool,
        icon: File?,
        emoji: String?,
        mentionable: Bool,
        reason: String?
    ) async throws -> Role {
        
        // Everything in this payload, discord provides a default value on the servers end. I could create `var`
        // and set the values according to what was passed, but it's just easier to do it this way.
        let payload: JSON = [
            "name": name ?? "new role",
            "permissions": "\(permissions.value)",
            "color": color?.value ?? 0,
            "hoist": hoist,
            "icon": nullable(icon?.asImageData),
            "unicode_emoji": nullable(emoji),
            "mentionable": mentionable
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/roles"), json: payload, additionalHeaders: withReason(reason))
        return .init(bot: bot, roleData: data as! JSON, guildId: guildId)
    }

    /// Modify the position of a role for the guild.
    /// https://discord.com/developers/docs/resources/guild#modify-guild-role-positions
    func modifyGuildRolePositions(guildId: Snowflake, positions: [Role: Int], reason: String?) async throws -> [Role] {
        var iterPayload = [JSON]()
        for (role, position) in positions {
            iterPayload.append([
                "id": role.id,
                "position": position
            ])
        }
        let data = try await request(.patch, route("/guilds/\(guildId)/roles"), jsonArray: iterPayload, additionalHeaders: withReason(reason)) as! [JSON]
        var returnedRoles = [Role]()
        for roleObj in data {
            returnedRoles.append(.init(bot: bot, roleData: roleObj, guildId: guildId))
        }
        return returnedRoles
    }

    /// Modify a guild role.
    /// https://discord.com/developers/docs/resources/guild#modify-guild-role
    func modifyGuildRole(guildId: Snowflake, roleId: Snowflake, data: JSON, reason: String?) async throws -> Role {
        let data = try await request(.patch, route("/guilds/\(guildId)/roles/\(roleId)"), json: data) as! JSON
        return .init(bot: bot, roleData: data, guildId: guildId)
    }

    /// Delete a guild role.
    /// https://discord.com/developers/docs/resources/guild#delete-guild-role
    func deleteGuildRole(guildId: Snowflake, roleId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/roles/\(roleId)"), additionalHeaders: withReason(reason))
    }
    
//    /// ❌
//    /// Returns the amount of members that would be pruned.
//    /// https://discord.com/developers/docs/resources/guild#get-guild-prune-count
//    func getGuildPruneCount(guildId: Snowflake, days: Int, includeRoles: [Role]?) async throws -> Int {
//        var endpoint = "/guilds/\(guildId)/prune?days=\(days)"
//        if let includeRoles {
//            endpoint += "&include_roles=\(includeRoles.map({ $0.id.description }).joined(separator: ","))"
//        }
//        let data = try await request(.get, route(endpoint), json: [:]) as! JSON
//        return data["pruned"] as! Int
//    }

    /// ⚠️ Needs testing.
    /// Begin a prune operation.
    /// https://discord.com/developers/docs/resources/guild#begin-guild-prune
    func beginGuildPrune(guildId: Snowflake, days: Int, computePruneCount: Bool, includeRoles: [Role]) async throws -> Int? {
        let payload: JSON = [
            "days": days,
            "compute_prune_count": computePruneCount,
            "include_roles": includeRoles.map({ $0.id })
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/prune"), json: payload) as! JSON
        return data["pruned"] as? Int
    }

    /// Returns a list of invites for the guild.
    /// https://discord.com/developers/docs/resources/guild#get-guild-invites
    func getGuildInvites(guildId: Snowflake) async throws -> [Invite] {
        let data = try await request(.get, route("/guilds/\(guildId)/invites"))
        var invites = [Invite]()
        for inviteObj in data as! [JSON] {
            invites.append(.init(bot: bot, inviteData: inviteObj))
        }
        return invites
    }

    /// Returns a list of integrations for the guild.
    /// https://discord.com/developers/docs/resources/guild#get-guild-integrations
    func getIntegrations(guildId: Snowflake) async throws -> [Guild.Integration] {
        let data = try await request(.get, route("/guilds/\(guildId)/integrations")) as! [JSON]
        var integrations = [Guild.Integration]()
        for integrationObj in data {
            integrations.append(.init(bot: bot, integrationData: integrationObj, guildId: guildId))
        }
        return integrations
    }
    
    /// Delete the attached integration object for the guild. Deletes any associated webhooks and kicks the associated bot if there is one.
    /// https://discord.com/developers/docs/resources/guild#delete-guild-integration
    func deleteGuildIntegration(guildId: Snowflake, integrationId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/integrations/\(integrationId)"), additionalHeaders: withReason(reason))
    }
    
    /// Get the guild widget settings.
    /// https://discord.com/developers/docs/resources/guild#get-guild-widget-settings
    func getGuildWidgetSettings(guildId: Snowflake) async throws -> Guild.Widget.Settings {
        let data = try await request(.get, route("/guilds/\(guildId)/widget")) as! JSON
        return .init(widgetSettingsData: data)
    }

    /// Updates the widget for the guild.
    /// https://discord.com/developers/docs/resources/guild#modify-guild-widget
    func modifyGuildWidget(guildId: Snowflake, enabled: Bool, widgetChannelId: Snowflake?, reason: String?) async throws {
        // Documention (link above) states that this returns the updated guild widget but thats not the case. Looking at the
        // payload thats recieved after the request, the payload is a widget settings object, not a widget object. So in order
        // to get the updated widget, a secondary call to `guild.widget()` must be made.
        let payload: JSON = ["enabled": enabled, "channel_id": nullable(widgetChannelId)]
        _ = try await request(.patch, route("/guilds/\(guildId)/widget"), json: payload, additionalHeaders: withReason(reason)) as! JSON
    }

    /// Returns the widget for the guild.
    /// https://discord.com/developers/docs/resources/guild#get-guild-widget
    func getGuildWidget(guildId: Snowflake) async throws -> Guild.Widget {
        let data = try await request(.get, route("/guilds/\(guildId)/widget.json")) as! JSON
        return .init(bot: bot, widgetData: data)
    }

    /// Returns the guild vanity URL.
    /// https://discord.com/developers/docs/resources/guild#get-guild-vanity-url
    func getGuildVanityUrl(guildId: Snowflake) async throws -> Invite {
        let data = try await request(.get, route("/guilds/\(guildId)/vanity-url")) as! JSON
        return .init(bot: bot, inviteData: data)
    }

    // UNUSED
    // https://discord.com/developers/docs/resources/guild#get-guild-widget-image
    // func getGuildWidgetImage() {}
    
    /// Returns the Welcome Screen object for the guild. If the welcome screen is not enabled, the `MANAGE_GUILD` permission is required.
    /// https://discord.com/developers/docs/resources/guild#get-guild-welcome-screen
    func getGuildWelcomeScreen(guildId: Snowflake) async throws -> Guild.WelcomeScreen {
        let data = try await request(.get, route("/guilds/\(guildId)/welcome-screen")) as! JSON
        return .init(welcomeScreenData: data)
    }
    
    /// Modify the guild's Welcome Screen. Requires the `MANAGE_GUILD` permission.
    /// https://discord.com/developers/docs/resources/guild#modify-guild-welcome-screen
    func modifyGuildWelcomeScreen(guildId: Snowflake, data: JSON, reason: String?) async throws -> Guild.WelcomeScreen {
        let data = try await request(.patch, route("/guilds/\(guildId)/welcome-screen"), json: data, additionalHeaders: withReason(reason)) as! JSON
        return .init(welcomeScreenData: data)
    }

    /// Returns a guild scheduled event for the given guild.
    /// https://discord.com/developers/docs/resources/guild-scheduled-event#get-guild-scheduled-event
    func getScheduledEventForGuild(guildId: Snowflake, eventId: Snowflake) async throws -> Guild.ScheduledEvent {
        let data = try await request(.get, route("/guilds/\(guildId)/scheduled-events/\(eventId)?with_user_count=\(true)")) as! JSON
        return .init(bot: bot, eventData: data)
    }

    /// Returns a list of guild scheduled events for the given guild.
    /// https://discord.com/developers/docs/resources/guild-scheduled-event#list-scheduled-events-for-guild
    func getListScheduledEventsForGuild(guildId: Snowflake) async throws -> [Guild.ScheduledEvent] {
        let data = try await request(.get, route("/guilds/\(guildId)/scheduled-events?with_user_count=\(true)")) as! [JSON]
        var events = [Guild.ScheduledEvent]()
        for eventObj in data {
            events.append(.init(bot: bot, eventData: eventObj))
        }
        return events
    }

    /// Create a guild scheduled event in the guild.
    /// https://discord.com/developers/docs/resources/guild-scheduled-event#create-guild-scheduled-event
    func createScheduledEventForGuild(
        guildId: Snowflake,
        name: String,
        startTime: Date,
        endTime: Date?,
        channelId: Snowflake?,
        location: String?,
        description: String?,
        entityType: Guild.ScheduledEvent.EntityType,
        image: File?,
        reason: String?
    ) async throws -> Guild.ScheduledEvent {
        var payload: JSON = [
            "name": name,
            "scheduled_start_time": startTime.asISO8601,
            "entity_type": entityType.rawValue,
            "privacy_level": Guild.ScheduledEvent.PrivacyLevel.guildOnly.rawValue,
        ]
        if let endTime { payload["scheduled_end_time"] = endTime.asISO8601 }
        if let channelId { payload["channel_id"] = channelId }
        if let location {
            if entityType == .external { payload["entity_metadata"] = ["location": location] }
        }
        if let description { payload["description"] = description }
        if let image { payload["image"] = image.asImageData }

        let data = try await request(.post, route("/guilds/\(guildId)/scheduled-events?with_user_count=\(true)"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, eventData: data)
    }

    /// Modify a guild scheduled event.
    /// https://discord.com/developers/docs/resources/guild-scheduled-event#modify-guild-scheduled-event
    func modifyGuildScheduledEvent(guildId: Snowflake, eventId: Snowflake, data: JSON, reason: String?) async throws -> Guild.ScheduledEvent {
        let data = try await request(.patch, route("/guilds/\(guildId)/scheduled-events/\(eventId)"), json: data, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, eventData: data)
    }

    /// Delete a guild scheduled event.
    /// https://discord.com/developers/docs/resources/guild-scheduled-event#delete-guild-scheduled-event
    func deleteGuildScheduledEvent(guildId: Snowflake, eventId: Snowflake) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/scheduled-events/\(eventId)"))
    }

    /// Get a list of guild scheduled event users subscribed to a guild scheduled event (up to 100 maximum).
    ///  https://discord.com/developers/docs/resources/guild-scheduled-event#get-guild-scheduled-event-users
    func getGuildScheduledEventUsers(guildId: Snowflake, eventId: Snowflake, limit: Int, before: Snowflake?, after: Snowflake?) async throws -> [JSON] {
        // HTTPError.badRequest() if `limit` is above/below expected values
        let limit = (limit > 100 || limit < 1) ? 100 : limit
        
        var endpont = "/guilds/\(guildId)/scheduled-events/\(eventId)/users?limit=\(limit)"
        
        // HTTPError.base() if both `before` & `after` are provided. Discord states that
        // if both are provided, only `before` is respected. I thought that meant `after` would silently
        // be ignored but that's not the case. When tested, it resulted in error: HTTPError.base("HTTPError - 500")
        // if both values are present.
        if let before { endpont += "&before=\(before)" }
        else {
            if let after { endpont += "&after=\(after)" }
        }
        
        return try await request(.get, route(endpont)) as! [JSON]
    }

    /// Returns a guild template for the given code.
    /// https://discord.com/developers/docs/resources/guild-template#get-guild-template
    func getGuildTemplate(code: String) async throws -> Guild.Template {
        let data = try await request(.get, route("/guilds/templates/\(code)")) as! JSON
        return .init(bot: bot, templateData: data)
    }

    /// Returns a guild template.
    /// https://discord.com/developers/docs/resources/guild-template#get-guild-templates
    func getGuildTemplates(guildId: Snowflake) async throws -> [Guild.Template] {
        let data = try await request(.get, route("/guilds/\(guildId)/templates")) as! [JSON]
        var templates = [Guild.Template]()
        for tempData in data {
            templates.append(.init(bot: bot, templateData: tempData))
        }
        return templates
    }

    /// Create a guild template for the given code. This endpoint can be used only by bots in less than 10 guilds.
    /// https://discord.com/developers/docs/resources/guild-template#create-guild-from-guild-template
    func createGuildFromGuildTemplate(code: String, name: String, icon: File?) async throws -> Guild {
        var payload: JSON = ["name": name]
        if let icon = icon { payload["icon"] = icon.asImageData }
        let data = try await request(.post, route("/guilds/templates/\(code)"), json: payload) as! JSON
        return .init(bot: bot, guildData: data)
    }

    /// Creates a template for the guild.
    /// https://discord.com/developers/docs/resources/guild-template#create-guild-template
    func createGuildTemplate(guildId: Snowflake, name: String, description: String?) async throws -> Guild.Template {
        let payload: JSON = [
            "name": name,
            "description": nullable(description)
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/templates"), json: payload) as! JSON
        return .init(bot: bot, templateData: data)
    }

    /// Syncs the template to the guild's current state.
    /// https://discord.com/developers/docs/resources/guild-template#sync-guild-template
    func syncGuildTemplate(guildId: Snowflake, code: String) async throws -> Guild.Template {
        let data = try await request(.put, route("/guilds/\(guildId)/templates/\(code)")) as! JSON
        return .init(bot: bot, templateData: data)
    }

    /// Modifies the template.
    /// https://discord.com/developers/docs/resources/guild-template#modify-guild-template
    func modifyGuildTemplate(guildId: Snowflake, code: String, data: JSON) async throws -> Guild.Template {
        let templateData = try await request(.patch, route("/guilds/\(guildId)/templates/\(code)"), json: data) as! JSON
        return .init(bot: bot, templateData: templateData)
    }

    /// Deletes the template.
    /// https://discord.com/developers/docs/resources/guild-template#delete-guild-template
    func deleteGuildTemplate(guildId: Snowflake, code: String) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/templates/\(code)"))
    }

    /// Returns an `Invite` for the given code.
    /// https://discord.com/developers/docs/resources/invite#get-invite
    func getInvite(code: String) async throws -> PartialInvite {
        let data = try await request(.get, route("/invites/\(code)?with_counts=true&with_expiration=true")) as! JSON
        return .init(partialInviteData: data)
    }

    /// Delete an `Invite` for the given code.
    /// https://discord.com/developers/docs/resources/invite#delete-invite
    func deleteInvite(code: String, reason: String?) async throws {
        _ = try await request(.delete, route("/invites/\(code)"), additionalHeaders: withReason(reason))
    }

    /// Creates a new Stage instance associated to a Stage channel. Returns that Stage instance.
    /// https://discord.com/developers/docs/resources/stage-instance#create-stage-instance
    func createStageInstance(stageChannelId: Snowflake, topic: String, privacyLevel: StageInstance.PrivacyLevel, startNotification: Bool, reason: String?) async throws -> StageInstance {
        let payload: JSON = [
            "channel_id": stageChannelId,
            "topic": topic,
            "privacy_level": privacyLevel.rawValue,
            "send_start_notification": startNotification
        ]
        let data = try await request(.post, route("/stage-instances"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, stageInstanceData: data)
    }
    
    /// Gets the stage instance associated with the Stage channel.
    /// https://discord.com/developers/docs/resources/stage-instance#get-stage-instance
    func getStageInstance(channelId: Snowflake) async throws -> StageInstance {
        let data = try await request(.get, route("/stage-instances/\(channelId)")) as! JSON
        return .init(bot: bot, stageInstanceData: data)
    }
    
    /// Updates fields of an existing Stage instance. Returns the updated Stage instance.
    /// https://discord.com/developers/docs/resources/stage-instance#modify-stage-instance
    func modifyStageInstance(stageChannelId: Snowflake, topic: String, reason: String?) async throws -> StageInstance {
        let data = try await request(.patch, route("/stage-instances/\(stageChannelId)"), json: ["topic": topic], additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, stageInstanceData: data)
    }

    /// Delete the stage instance.
    /// https://discord.com/developers/docs/resources/stage-instance#delete-stage-instance
    func deleteStageInstance(channelId: Snowflake, reason: String?) async throws {
        // Note: for whatever reason, this will error with "invalid json body" if an empty dict is not passed
        _ = try await request(.delete, route("/stage-instances/\(channelId)"), json: [:], additionalHeaders: withReason(reason))
    }

    /// Returns a sticker for the given sticker ID.
    /// https://discord.com/developers/docs/resources/sticker#get-sticker
    func getSticker(stickerId: Snowflake) async throws -> Sticker {
        let data = try await request(.get, route("/stickers/\(stickerId)")) as! JSON
        return .init(stickerData: data)
    }

    /// Returns the list of sticker packs available to Nitro subscribers.
    /// https://discord.com/developers/docs/resources/sticker#list-nitro-sticker-packs
    func getNitroStickerPacks() async throws -> [Sticker.Pack] {
        let data = try await request(.get, route("/sticker-packs")) as! JSON
        let stickerPacksData = data["sticker_packs"] as! [JSON]
        
        var packs = [Sticker.Pack]()
        for packData in stickerPacksData {
            packs.append(.init(packData: packData))
        }
        return packs
    }

    /// Get all guild stickers.
    /// https://discord.com/developers/docs/resources/sticker#list-guild-stickers
    func getAllGuildStickers(guildId: Snowflake) async throws -> [GuildSticker] {
        let data = try await request(.get, route("/guilds/\(guildId)/stickers")) as! [JSON]
        var stickers = [GuildSticker]()
        for stickerObj in data {
            stickers.append(.init(bot: bot, guildStickerData: stickerObj))
        }
        return stickers
    }

    /// Get a guild sticker.
    /// https://discord.com/developers/docs/resources/sticker#get-guild-sticker
    func getGuildSticker(guildId: Snowflake, stickerId: Snowflake) async throws -> GuildSticker {
        let data = try await request(.get, route("/guilds/\(guildId)/stickers/\(stickerId)")) as! JSON
        return .init(bot: bot, guildStickerData: data)
    }

    /// Create a new sticker for the guild.
    /// https://discord.com/developers/docs/resources/sticker#create-guild-sticker
    func createGuildSticker(guildId: Snowflake, name: String, description: String?, tagAKAemoji: String, file: File, reason: String?) async throws -> GuildSticker {
        let payload: JSON = [
            "name": name,
            "description": description ?? String.empty,
            "tags": tagAKAemoji
        ]
        let data = try await request(.post, route("/guilds/\(guildId)/stickers"), json: payload, files: [file], mpUploadType: .sticker, additionalHeaders: withReason(reason))
        return .init(bot: bot, guildStickerData: data as! JSON)
    }

    /// Edit a guild sticker.
    /// https://discord.com/developers/docs/resources/sticker#modify-guild-sticker
    func modifyGuildSticker(guildId: Snowflake, stickerId: Snowflake, data: JSON, reason: String?) async throws -> GuildSticker {
        let guildStickerData = try await request(.patch, route("/guilds/\(guildId)/stickers/\(stickerId)"), json: data, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, guildStickerData: guildStickerData)
    }

    /// Delete a guild sticker
    /// https://discord.com/developers/docs/resources/sticker#delete-guild-sticker
    func deleteGuildSticker(guildId: Snowflake, stickerId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/stickers/\(stickerId)"), additionalHeaders: withReason(reason))
    }

    /// Get a user on Discord
    /// https://discord.com/developers/docs/resources/user#get-user
    func getUser(userId: Snowflake) async throws -> User {
        let data = try await request(.get, route("/users/\(userId)")) as! JSON
        return .init(userData: data)
    }

    /// Leave a guild
    /// https://discord.com/developers/docs/resources/user#leave-guild
    func leaveGuild(guildId: Snowflake) async throws {
        // Note: for whatever reason, this will error with "invalid json body" if an empty dict is not passed
        _ = try await request(.delete, route("/users/@me/guilds/\(guildId)"), json: [:])
    }

    /// Create a webhook
    /// https://discord.com/developers/docs/resources/webhook#create-webhook
    func createWebhook(channelId: Snowflake, name: String, avatar: File?, reason: String?) async throws -> Webhook {
        let payload: JSON = [
            "name": name,
            "avatar": nullable(avatar?.asImageData)
        ]
        let data = try await request(.post, route("/channels/\(channelId)/webhooks"), json: payload, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, webhookData: data)
    }
    
    /// Returns the webhooks on the channel for the given ID.
    /// https://discord.com/developers/docs/resources/webhook#get-channel-webhooks
    func getChannelWebhooks(channelId: Snowflake) async throws -> [Webhook] {
        let data = try await request(.get, route("/channels/\(channelId)/webhooks")) as! [JSON]
        var webhooks = [Webhook]()
        for webhookObj in data {
            webhooks.append(.init(bot: bot, webhookData: webhookObj))
        }
        return webhooks
    }

    /// Returns the webhooks in the guild for the given ID.
    /// https://discord.com/developers/docs/resources/webhook#get-guild-webhooks
    func getGuildWebhooks(guildId: Snowflake) async throws -> [Webhook] {
        let data = try await request(.get, route("/guilds/\(guildId)/webhooks")) as! [JSON]
        var webhooks = [Webhook]()
        for webhookObj in data {
            webhooks.append(.init(bot: bot, webhookData: webhookObj))
        }
        return webhooks
    }

    /// Returns the webhook for the given ID.
    /// https://discord.com/developers/docs/resources/webhook#get-webhook
    func getWebhook(webhookId: Snowflake) async throws -> Webhook {
        let data = try await request(.get, route("/webhooks/\(webhookId)")) as! JSON
        return .init(bot: bot, webhookData: data)
    }
    
    /// Same as ``getWebhook()``, except this call does not require authentication and returns no user in the webhook object.
    /// https://discord.com/developers/docs/resources/webhook#get-webhook-with-token
    func getWebhookWithToken(webhookId: String, webhookToken: String) async throws -> Webhook {
        let data = try await request(.get, route("/webhooks/\(webhookId)/\(webhookToken)")) as! JSON
        return .init(bot: bot, webhookData: data)
    }
    
    /// Modify a webhook. Returns the updated webhook.
    /// https://discord.com/developers/docs/resources/webhook#modify-webhook
    func modifyWebhook(webhookId: Snowflake, data: JSON, reason: String?) async throws -> Webhook {
        let data = try await request(.patch, route("/webhooks/\(webhookId)"), json: data, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, webhookData: data)
    }

    // UNUSED
    // Same as `modifyWebhook()`, except this call does not require authentication, does not accept a `channel_id` parameter in the body, and does not return a user in the webhook object.
    // https://discord.com/developers/docs/resources/webhook#modify-webhook-with-token
    // func modifyWebhookWithToken(...) async throws -> Webhook {}

    /// Delete a webhook permanently.
    /// https://discord.com/developers/docs/resources/webhook#delete-webhook
    func deleteWebhook(webhookId: Snowflake) async throws {
        _ = try await request(.delete, route("/webhooks/\(webhookId)"))
    }
    
    // UNUSED
    // Same as `deleteWebhook()`, except this call does not require authentication.
    // https://discord.com/developers/docs/resources/webhook#delete-webhook-with-token
    // func deleteWebhookWithToken(webhookId: Snowflake, webhookToken: String) async throws {}

    /// Send a message without authentication.
    /// https://discord.com/developers/docs/resources/webhook#execute-webhook
    func executeWebhook(webhookId: Snowflake, webhookToken: String, json: JSON?, files: [File]?, threadId: Snowflake?) async throws -> Message {
        let data = try await request(.post, route("/webhooks/\(webhookId)/\(webhookToken)?wait=true\(threadId != nil ? "&thread_id=\(threadId!)" : String.empty)"), json: json, files: files) as! JSON
        return .init(bot: bot, messageData: data)
    }

    /// Get a list of all rules currently configured for guild.
    /// https://discord.com/developers/docs/resources/auto-moderation#list-auto-moderation-rules-for-guild
    func listAutoModerationRulesForGuild(guildId: Snowflake) async throws -> [AutoModerationRule] {
        let data = try await request(.get, route("/guilds/\(guildId)/auto-moderation/rules")) as! [JSON]
        var rules = [AutoModerationRule]()
        for ruleObj in data {
            rules.append(.init(bot: bot, autoModData: ruleObj))
        }
        return rules
    }

    /// Get a rule currently configured for guild.
    /// https://discord.com/developers/docs/resources/auto-moderation#get-auto-moderation-rule
    func getAutoModerationRule(guildId: Snowflake, ruleId: Snowflake) async throws -> AutoModerationRule {
        let data = try await request(.get, route("/guilds/\(guildId)/auto-moderation/rules/\(ruleId)")) as! JSON
        return .init(bot: bot, autoModData: data)
    }

    /// Create a new rule.
    /// https://discord.com/developers/docs/resources/auto-moderation#create-auto-moderation-rule
    func createAutoModerationRule(guildId: Snowflake, data: JSON, reason: String?) async throws -> AutoModerationRule {
        let data = try await request(.post, route("/guilds/\(guildId)/auto-moderation/rules"), json: data, additionalHeaders: withReason(reason)) as! JSON
        return .init(bot: bot, autoModData: data)
    }

    /// ⚠️ Mostly working, could use some more testing.
    /// Modify an existing rule.
    /// https://discord.com/developers/docs/resources/auto-moderation#modify-auto-moderation-rule
    func modifyAutoModerationRule(guildId: Snowflake, ruleId: Snowflake, data: JSON) async throws -> AutoModerationRule {
        let data = try await request(.patch, route("/guilds/\(guildId)/auto-moderation/rules/\(ruleId)"), json: data) as! JSON
        return .init(bot: bot, autoModData: data)
    }

    /// Delete a rule.
    /// https://discord.com/developers/docs/resources/auto-moderation#delete-auto-moderation-rule
    func deleteAutoModerationRule(guildId: Snowflake, ruleId: Snowflake, reason: String?) async throws {
        _ = try await request(.delete, route("/guilds/\(guildId)/auto-moderation/rules/\(ruleId)"), additionalHeaders: withReason(reason))
    }
    
    /// Create a reaction for the message.
    /// https://discord.com/developers/docs/resources/channel#create-reaction
    func createReaction(channelId: Snowflake, messageId: Snowflake, emoji: String) async throws {
        _ = try await request(.put, route("/channels/\(channelId)/messages/\(messageId)/reactions/\(handleReaction(emoji))/@me"))
    }
    
    /// Post a message to a guild text or DM channel.
    /// https://discord.com/developers/docs/resources/channel#create-message
    func createMessage(channelId: Snowflake, json: JSON, files: [File]?) async throws -> Message {
        let data = try await request(.post, route("/channels/\(channelId)/messages"), json: json, files: files) as! JSON
        let message = Message(bot: bot, messageData: data)
        
        // The guild ID is not returned with this endpoint, but it is set via MESSAGE_CREATE. So grab the message
        // from the cache and manually set the `guildId`.
        if let cached = bot.getMessage(message.id) {
            message.guildId = cached.guildId
        }
        
        // Alternatively, if the message was not found in the cache (expired or `Discord.messagesCacheMaxSize` is zero)
        // this endpoint provides the channel_id. So grab the `guildId` based on the channel.
        else {
            if let channel = bot.getChannel(message.channelId) as? GuildChannel {
                message.guildId = channel.guild.id
            }
        }
        
        return message
    }
    
    /// Create a DM channel between the bot and the user.
    /// https://discord.com/developers/docs/resources/user#create-dm
    func createDm(recipientId: Snowflake) async throws -> DMChannel {
        let data = try await request(.post, route("/users/@me/channels"), json: ["recipient_id": recipientId]) as! JSON
        return DMChannel(bot: bot, dmData: data)
    }
    
    /// Returns an object with a single valid WSS URL.
    /// https://discord.com/developers/docs/topics/gateway#get-gateway
    /// https://discord.com/developers/docs/topics/gateway#get-gateway-bot
    func getGateway() async throws -> (url: String, shards: Int) {
        let data = try await request(.get, route("/gateway/bot")) as! JSON
        let url = data["url"] as! String
        let shards = data["shards"] as! Int
        return (url, shards)
    }
    
    /// Creates the full HTTP endpoint.
    private func route(_ url: String, route: APIRoute = .base) -> String {
        guard url.starts(with: "/") else { fatalError("URL route must begin with /") }
        return route.rawValue + url
    }
    
    private func getAllHeaders(_ passedHeaders: HTTPHeaders?) -> HTTPHeaders {
        // Update any extra header information
        var allHeaders: HTTPHeaders = staticClientHeaders
        if let passedHeaders {
            allHeaders = allHeaders.merging(passedHeaders) { (current, _) in current }
        }
        return allHeaders
    }
    
    func handleResponse(headers: [String: String], endpoint: String) {
        // Some requests don't have ratelimits (such as `Guild.requestRoles(id:)`) so check if the limit headers exists.
        // If so, save their values.
        let XRL = "x-ratelimit-limit"
        if headers.contains(where: { $0.key == XRL}) {
            let limit = Int(headers[XRL]!)!
            let remaining = Int(headers["x-ratelimit-remaining"]!)!
            let resetTime = TimeInterval(headers["x-ratelimit-reset"]!)!
            
            let rateLimit = RateLimit(limit: limit, remaining: remaining, resetTime: resetTime)
            rateLimits[endpoint] = rateLimit
        }
    }
    
    private func makeRequest(
        _ method: HTTPMethod,
        _ endpoint: String,
        json: JSON? = nil,
        jsonArray: [JSON]? = nil,
        files: [File]? = nil,
        mpUploadType: MultipartUploadType = .file,
        additionalHeaders: HTTPHeaders? = nil
    ) async throws -> Any {
        var allHeaders = getAllHeaders(additionalHeaders)
        var req = URLRequest(url: URL(string: endpoint)!)
        req.httpMethod = method.rawValue
        req.allHTTPHeaderFields = allHeaders
        
        if let files {
            var form: MultiPartForm
            switch mpUploadType {
            case .file:
                form = MultiPartForm(json: json ?? [:], files: files)
            case .sticker:
                form = MultiPartForm(json: json!, sticker: files[0])
            }
            allHeaders.updateValue("multipart/form-data; boundary=\(form.boundary)", forKey: "Content-Type")
            req.allHTTPHeaderFields = allHeaders
            req.httpBody = form.encode()
        }
        
        else {
            switch method {
            case .post, .patch, .put:
                if let json {
                    req.httpBody = dictToData(json)
                }
                if let jsonArray {
                    req.httpBody = try JSONSerialization.data(withJSONObject: jsonArray)
                }
            case .get, .delete:
                // GET and DELETE don't require a body
                break
            }
        }
        
        // Actually make the HTTP request
        let result: (data: Data, response: URLResponse) = try await session.data(for: req)
        
        // When it comes to anything reaction based, whether it's GET or POST, the ratelimit for the
        // route is always different because when, for example, adding an emoji, the emoji itself is
        // in the URL. So the endpoint ratelimit can't be saved. I'm guessing this is where a bucket
        // hash would come in handy? But I haven't figured out how to implement that so this will have
        // to do. It's sloppy but...it works. When looping a reaction based endpoint, it always errors
        // with a 429 and a retry after of 0.3s. So, if it's a reaction based endpoint, just sleep for that
        // duration to avoid any 429s.
        if endpoint.contains("/reactions") {
            await sleep(300)
        }

        // Not all endpoints return data (such as `Message.addReactions()`)
        if result.data.isEmpty {
            return JSON()
        }
        
        // Convert the response to its proper type (dict or array dict)
        var object: Any
        object = try JSONSerialization.jsonObject(with: result.data)
        if object is JSON { object = object as! JSON }
        else if object is Array<JSON> { object = object as! [JSON] }
        else { Log.fatal("Unknown data type received") }
        
        // Cast the original response so the status code can be checked
        let response = result.response as! HTTPURLResponse

        var errorMessage = String.empty
        if !(200...299).contains(response.statusCode) {
            errorMessage = (object as! JSON)["message"] as! String
        }
        switch response.statusCode {
        case 200...299:
            break
        case 400:
            throw HTTPError.badRequest(errorMessage)
        case 401:
            throw HTTPError.unauthorized(errorMessage)
        case 403:
            throw HTTPError.forbidden(errorMessage)
        case 404:
            throw HTTPError.notFound(errorMessage)
        case 405:
            throw HTTPError.methodNotAllowed(errorMessage)
        case 429:
            let error = object as! JSON
            let retryAfter = error["retry_after"] as! Double
            Log.message("You are being ratelimited! (retrying after: \(retryAfter)s) Via endpoint: \(method.rawValue) \(endpoint)")
            try await Task.sleep(for: .seconds(retryAfter))
            return try await makeRequest(method, endpoint, json: json, jsonArray: jsonArray, files: files, mpUploadType: mpUploadType, additionalHeaders: allHeaders)
        case 502:
            throw HTTPError.gatewayUnavailable(errorMessage)
        default:
            throw HTTPError.base("HTTPError - Status Code (\(response.statusCode)) - \(errorMessage)")
        }

        // Update/set the rate limit information
        if let responseHeaders = response.allHeaderFields as? [String: String] {
            handleResponse(headers: responseHeaders, endpoint: endpoint)
        }
        
        return object
    }
    
    private func request(
        _ method: HTTPMethod,
        _ endpoint: String,
        json: JSON? = nil,
        jsonArray: [JSON]? = nil,
        files: [File]? = nil,
        mpUploadType: MultipartUploadType = .file,
        additionalHeaders: HTTPHeaders? = nil
    ) async throws -> Any {
        
        let req: () async throws -> Any = {
            return try await self.makeRequest(method, endpoint, json: json, jsonArray: jsonArray, files: files, mpUploadType: mpUploadType, additionalHeaders: self.getAllHeaders(additionalHeaders))
        }
        
        if let rateLimit = rateLimits[endpoint] {
            let currentTime = Date().timeIntervalSince1970
            
            // Rate limit has reset, send the request
            if currentTime >= rateLimit.resetTime {
                return try await req()
                
            // Rate limit allows the request, send it
            } else if rateLimit.remaining > 0 {
                return try await req()
                
            // Rate limit reached, wait until reset time
            } else {
                let delay = rateLimit.resetTime - currentTime
                Log.message("RATELIMIT HIT (delayed: \((delay * 1000.0).rounded() / 1000.0)s) - \(method.rawValue) \(endpoint)")
                try await Task.sleep(for: .seconds(delay))
                return try await req()
            }
        }
        
        // No rate limit information available, send the request
        else {
            return try await req()
        }
    }
}

enum APIRoute : String {
    case base = "https://discord.com/api/v10"
    case cdn = "https://cdn.discordapp.com"
}

enum MultipartUploadType {
    case file
    case sticker
}


// ---------- BEGIN NOTICE ----------

// The following code belongs to GitHub user "onevcat". All credit goes to them for providing this useful code.
// Source: https://github.com/onevcat/MimeType

fileprivate let DEFAULT_MIME_TYPE = "application/octet-stream"
fileprivate let mimeTypes = [
    "html": "text/html",
    "htm": "text/html",
    "shtml": "text/html",
    "css": "text/css",
    "xml": "text/xml",
    "gif": "image/gif",
    "jpeg": "image/jpeg",
    "jpg": "image/jpeg",
    "js": "application/javascript",
    "atom": "application/atom+xml",
    "rss": "application/rss+xml",
    "mml": "text/mathml",
    "txt": "text/plain",
    "jad": "text/vnd.sun.j2me.app-descriptor",
    "wml": "text/vnd.wap.wml",
    "htc": "text/x-component",
    "png": "image/png",
    "tif": "image/tiff",
    "tiff": "image/tiff",
    "wbmp": "image/vnd.wap.wbmp",
    "ico": "image/x-icon",
    "jng": "image/x-jng",
    "bmp": "image/x-ms-bmp",
    "svg": "image/svg+xml",
    "svgz": "image/svg+xml",
    "webp": "image/webp",
    "woff": "application/font-woff",
    "jar": "application/java-archive",
    "war": "application/java-archive",
    "ear": "application/java-archive",
    "json": "application/json",
    "hqx": "application/mac-binhex40",
    "doc": "application/msword",
    "pdf": "application/pdf",
    "ps": "application/postscript",
    "eps": "application/postscript",
    "ai": "application/postscript",
    "rtf": "application/rtf",
    "m3u8": "application/vnd.apple.mpegurl",
    "xls": "application/vnd.ms-excel",
    "eot": "application/vnd.ms-fontobject",
    "ppt": "application/vnd.ms-powerpoint",
    "wmlc": "application/vnd.wap.wmlc",
    "kml": "application/vnd.google-earth.kml+xml",
    "kmz": "application/vnd.google-earth.kmz",
    "7z": "application/x-7z-compressed",
    "cco": "application/x-cocoa",
    "jardiff": "application/x-java-archive-diff",
    "jnlp": "application/x-java-jnlp-file",
    "run": "application/x-makeself",
    "pl": "application/x-perl",
    "pm": "application/x-perl",
    "prc": "application/x-pilot",
    "pdb": "application/x-pilot",
    "rar": "application/x-rar-compressed",
    "rpm": "application/x-redhat-package-manager",
    "sea": "application/x-sea",
    "swf": "application/x-shockwave-flash",
    "sit": "application/x-stuffit",
    "tcl": "application/x-tcl",
    "tk": "application/x-tcl",
    "der": "application/x-x509-ca-cert",
    "pem": "application/x-x509-ca-cert",
    "crt": "application/x-x509-ca-cert",
    "xpi": "application/x-xpinstall",
    "xhtml": "application/xhtml+xml",
    "xspf": "application/xspf+xml",
    "zip": "application/zip",
    "bin": "application/octet-stream",
    "exe": "application/octet-stream",
    "dll": "application/octet-stream",
    "deb": "application/octet-stream",
    "dmg": "application/octet-stream",
    "iso": "application/octet-stream",
    "img": "application/octet-stream",
    "msi": "application/octet-stream",
    "msp": "application/octet-stream",
    "msm": "application/octet-stream",
    "docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
    "xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
    "pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
    "mid": "audio/midi",
    "midi": "audio/midi",
    "kar": "audio/midi",
    "mp3": "audio/mpeg",
    "ogg": "audio/ogg",
    "m4a": "audio/x-m4a",
    "ra": "audio/x-realaudio",
    "3gpp": "video/3gpp",
    "3gp": "video/3gpp",
    "ts": "video/mp2t",
    "mp4": "video/mp4",
    "mpeg": "video/mpeg",
    "mpg": "video/mpeg",
    "mov": "video/quicktime",
    "webm": "video/webm",
    "flv": "video/x-flv",
    "m4v": "video/x-m4v",
    "mng": "video/x-mng",
    "asx": "video/x-ms-asf",
    "asf": "video/x-ms-asf",
    "wmv": "video/x-ms-wmv",
    "avi": "video/x-msvideo"
]

struct MimeType {
    let ext: String?
    var value: String {
        guard let ext = ext else {
            return DEFAULT_MIME_TYPE
        }
        return mimeTypes[ext.lowercased()] ?? DEFAULT_MIME_TYPE
    }
    init(path: String) {
        ext = NSString(string: path).pathExtension
    }

    init(path: NSString) {
        ext = path.pathExtension
    }

    init(url: URL) {
        ext = url.pathExtension
    }
}

// ---------- END NOTICE ----------

