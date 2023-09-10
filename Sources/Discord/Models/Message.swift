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

/// Represents a Discord message.
public class Message : Object, Hashable, Updateable {
    
    /// ID of the message.
    public let id: Snowflake
    
    /// The channel the message was sent in.
    public var channel: Messageable {
        if let channel = bot!.getChannel(channelId) {
            return channel as! Messageable
        } else {
            // If the channel is not found in the cache, that should be mean it's a new DM message.
            // Discord doesnt provide the needed information to create a full `DMChannel` via `.onMessageCreate`,
            // only truly creating a DMChannel (.createDm()) does that. But we do have the channel ID and thats
            // pretty much all thats needed in order to create a `DMChannel`, so create the most basic `dmData` ourselves.
            let dmData: JSON = ["id": channelId.description]
            return DMChannel(bot: bot!, dmData: dmData)
        }
    }
    
    /// The guild the message was sent in. Will be `nil` if the message was sent in a DM or the message was ephemeral.
    public var guild: Guild? { guildId != nil ? bot!.getGuild(guildId!) : nil }
    
    /// The author of this message. If you need the ``Member`` object instead, see the ``member`` property.
    public let author: User
    
    /// Contents of the message.
    public private(set) var content: String
    
    /// When this message was sent.
    public let createdAt: Date

    /// When this message was edited or `nil` if never.
    public private(set) var lastEdited: Date?

    /// Whether this was a TTS message.
    public let tts: Bool
    
    /// Whether this message mentions everyone.
    public let mentionedEveryone: Bool
    
    /// Users who were mentioned in the message.
    public private(set) var mentionedUsers = [User]()

    /// Roles mentioned in this message. If the message was sent in a DM, this will always be empty.
    public var mentionedRoles: [Role] {
        guard !isDmMessage else { return [] }
        
        var roles = [Role]()
        for str in mentionRoleStrings {
            let roleId = Conversions.snowflakeToUInt(str)
            if let cachedRole = guild?.getRole(roleId) {
                roles.append(cachedRole)
            }
        }
        return roles
    }

    /// Channels mentioned in this message. If the message was sent in a DM, this will always be empty.
    /// - Note: This is determined by if the ``content`` of the message contains the following regex: `<#[0-9]{17,20}>`.
    ///         If there's a match, the channel is retrieved from the cache.
    public var mentionedChannels: [GuildChannel] {
        // NOTE: This can't return `GuildChannelMessageable`. Although most channels are messageable,
        // not all are. For example, a mentioned `ForumChannel` matches the channel regex, but it's not messageable.
        
        guard !isDmMessage else { return [] }
        
        var channels = [GuildChannel]()
        let channelRegex = #/<#[0-9]{17,20}>/#
        
        for match in content.matches(of: channelRegex) {
            let sub = content[match.range].description
            let channelId = Conversions.snowflakeToUInt(sub.replacing(#/[@#<>]/#, with: String.empty))
            if let channelFound = guild!.getChannel(channelId) {
                channels.append(channelFound)
            }
        }
        return channels
    }
    
    /// Files attached to the message.
    public private(set) var attachments = [Attachment]()
    
    /// Embeds in the message.
    public private(set) var embeds = [Embed]()
    
    /// Reactions to the message.
    public internal(set) var reactions = [Reaction]()
    
    /// A random number used for validating if a message was sent.
    /// - Note: This is only present on the initial success of message delivery and will be `nil` if requested.
    public let nonce: String?
    
    /// Whether this message is pinned.
    public private(set) var isPinned: Bool
    
    /// If the message is generated by a webhook, this is the webhook's ID.
    public let webhookId: Snowflake?
    
    /// Type of message.
    public let type: MessageType
    
    /// The activity associated with the message. Sent with rich presence-related chat embeds.
    public private(set) var activity: Activity?
    
    /// The application associated with the message. Sent with rich presence-related chat embeds.
    public internal(set) var application: Application?

    /// If the message is an Interaction or application-owned webhook, this is the ID of the application.
    public internal(set) var applicationId: Snowflake?
    
    /// Data showing the source of a crosspost, channel follow add, pin, or reply message.
    public internal(set) var reference: Reference?

    /// The flags this message contains.
    public internal(set) var flags: [Message.Flag]

    /// Message associated with the message reference. This relates to replying to messages.
    public internal(set) var referencedMessage: Message?

    /// Sent if the message is a response to an ``Interaction``.
    public internal(set) var interaction: Message.Interaction?

    /// The thread that was started from this message.
    public internal(set) var thread: ThreadChannel?

    /// The UI elements on the message such as a ``Button`` or ``SelectMenu``.
    public internal(set) var ui: UI?
    
    /// Stickers sent with the message.
    public internal(set) var stickers = [Sticker.Item]()

    /// The referenced representation of the message.
    public var asReference: Reference { Reference(messageId: id, channelId: channel.id, guildId: guild?.id) }
    
    // Hashable
    public static func == (lhs: Message, rhs: Message) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // ------------------------------ API Separated -----------------------------------
    
    /// The ``author`` of this message but optionally returns their ``Member`` object instead. This depends on whether the member has been cached in the guild.
    /// If the member is not cached, the proper ``Bot/intents`` were not set. You can also get the member object via ``Guild/requestMember(_:)``.
    public var member: Member? { guild?.getMember(author.id) }

    /// Whether the message was sent in a DM.
    public var isDmMessage: Bool { guild == nil }
    
    /// Whether the message was ephemeral.
    public var isEphemeral: Bool { flags.contains(.ephemeral) }

    /// The direct URL for the message.
    public var jumpUrl: String {
        let url = "https://discord.com/channels/" + (isDmMessage ? "@me" : String(guild!.id)) + "/\(channel.id)/\(id)"
        return Markdown.suppressLinkEmbed(url: url)
    }
    
    /// Mention the message.
    public var mention: String { jumpUrl.replacing(#/[<>]/#, with: String.empty) }

    // --------------------------------------------------------------------------------
    
    /// Your bot instance.
    public weak private(set) var bot: Bot?
    
    static var cacheExpire: Date { Calendar.current.date(byAdding: .hour, value: 3, to: .now)! }
    var cacheExpireTimer: Timer? = nil
    
    let channelId: Snowflake
    var guildId: Snowflake?
    let mentionRoleStrings: [String]
    var expires: Date
    let temp: JSON
    
    init(bot: Bot, messageData: JSON) {
        temp = messageData
        self.bot = bot
        id = Conversions.snowflakeToUInt(messageData["id"])
        channelId = Conversions.snowflakeToUInt(messageData["channel_id"])
        guildId = Conversions.snowflakeToOptionalUInt(messageData["guild_id"])
        author = User(userData: messageData["author"] as! JSON)
        content = messageData["content"] as! String
        createdAt = Conversions.stringDateToDate(iso8601: messageData["timestamp"] as! String)!
        
        if let edited = messageData["edited_timestamp"] as? String {
            lastEdited = Conversions.stringDateToDate(iso8601: edited)
        }

        tts = messageData["tts"] as! Bool
        mentionedEveryone = messageData["mention_everyone"] as! Bool
        mentionRoleStrings = messageData["mention_roles"] as! [String]
        
        for userObj in messageData["mentions"] as! [JSON] {
            mentionedUsers.append(.init(userData: userObj))
        }
        
        let attachedObjs = messageData["attachments"] as! [JSON]
        for a in attachedObjs {
            attachments.append(.init(attachmentData: a))
        }
        
        let embedObjs = messageData["embeds"] as! [JSON]
        for e in embedObjs {
            embeds.append(.init(embedData: e))
        }

        nonce = messageData["nonce"] as? String
        isPinned = messageData["pinned"] as! Bool
        webhookId = Conversions.snowflakeToOptionalUInt(messageData["webhook_id"])
        type = Message.MessageType(rawValue: messageData["type"] as! Int)!
        
        if let activityObj = messageData["activity"] as? JSON {
            activity = .init(activityData: activityObj)
        }

        if let appObj = messageData["application"] as? JSON {
            application = .init(appData: appObj)
        }

        applicationId = Conversions.snowflakeToOptionalUInt(messageData["application_id"])

        if let refObj = messageData["message_reference"] as? JSON {
            let mId = Conversions.snowflakeToOptionalUInt(refObj["message_id"])
            let cId = Conversions.snowflakeToOptionalUInt(refObj["channel_id"])
            let gId = Conversions.snowflakeToOptionalUInt(refObj["guild_id"])
            reference = .init(messageId: mId, channelId: cId, guildId: gId)
        }

        if let refMessage = messageData["referenced_message"] as? JSON {
            referencedMessage = Message(bot: bot, messageData: refMessage)
        }

        flags = Message.Flag.get(messageData["flags"] as! Int)

        if let interactionObj = messageData["interaction"] as? JSON {
            interaction = Message.Interaction(bot: bot, guildId: guildId, msgInteractionData: interactionObj)
        }

        if let threadObj = messageData["thread"] as? JSON {
            // Threads can't be in DMs, so it's safe to force cast `guildId`
            thread = ThreadChannel(bot: bot, threadData: threadObj, guildId: guildId!)
        }
        
        ui = UI.convertFromPayload((messageData["components"] as? [JSON] ?? []))

        if let stickerObjs = messageData["sticker_items"] as? [JSON] {
            for stickerObj in stickerObjs {
                stickers.append(.init(itemData: stickerObj))
            }
        }
        
        expires = Message.cacheExpire
        setExpires()
        
        // This was moved to the end because `self` cannot be used before all stored proprties have been initalized.
        if let reactionObjs = messageData["reactions"] as? [JSON] {
            for reactionObj in reactionObjs {
                reactions.append(Reaction(bot: bot, reactionData: reactionObj, message: self))
            }
        }
    }
    
    /// Updates the properties for the message. This method is called via event ``DiscordEvent/messageUpdate``.
    func update(_ data: JSON) {
        for (k, v) in data {
            switch k {
            case "content":
                content = v as! String
            case "edited_timestamp":
                lastEdited = v as? String == nil ? nil : Conversions.stringDateToDate(iso8601: v as! String)
            case "mentions":
                let userObjs = v as! [JSON]
                mentionedUsers.removeAll()
                for userObj in userObjs {
                    mentionedUsers.append(.init(userData: userObj))
                }
            case "attachments":
                let attachmentObjects = v as! [JSON]
                attachments.removeAll()
                for attchObj in attachmentObjects {
                    attachments.append(.init(attachmentData: attchObj))
                }
            case "embeds":
                let embedObjs = v as! [JSON]
                embeds.removeAll()
                for embedObj in embedObjs {
                    embeds.append(.init(embedData: embedObj))
                }
            case "components":
                let newUI = UI.convertFromPayload((v as? [JSON]) ?? [])
                newUI?.onInteraction = ui?.onInteraction ?? { _ in }
                ui = newUI
            case "pinned":
                isPinned = v as! Bool
            default:
                break
            }
        }
    }
    
    /**
     Add a reaction to a message.
     
     Example:
     ```swift
     // Add a unicode emoji
     try await message.addReaction("😄")
     
     // Add a guild emoji
     try await message.addReaction("<:swift:1082497874874617881>")
     ```
     - Parameter emoji: Emoji to add.
     */
    public func addReaction(_ emoji: String) async throws {
        try await bot!.http.createReaction(channelId: channel.id, messageId: id, emoji: emoji)
    }
    
    /// Create a thread from the message.
    /// - Parameters:
    ///   - name: Name of the thread.
    ///   - autoArchiveDuration: Duration to automatically archive the thread after recent activity.
    ///   - slowmode: Amount of seconds a user has to wait before sending another message.
    ///   - reason: The reason for creating the thread. This shows up in the guilds audit log.
    /// - Returns: The newly created thread.
    public func createThread(name: String, autoArchiveDuration: ThreadChannel.ArchiveDuration = .twentyfourHours, slowmode: Int? = nil, reason: String? = nil) async throws -> ThreadChannel {
        if isDmMessage { throw HTTPError.badRequest("Cannot create threads in DMs")  }
        return try await bot!.http.startThreadFromMessage(
            channelId: channel.id,
            guildId: guildId!,
            messageId: id,
            threadName: name,
            autoArchiveDuration: autoArchiveDuration,
            slowmodeInSeconds: slowmode,
            reason: reason
        )
    }
    
    /// Edit the message.
    /// - Parameters:
    ///   - edits: The enum containing all values to be updated or removed for the message.
    ///   - keeping: The attachments that should stay on the message. If set to an empty array, all attachments that were previously attached will be removed.
    /// - Returns: The updated message.
    @discardableResult
    public func edit(_ edits: Message.Edit..., keeping: [Attachment]? = nil) async throws -> Message {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }
        
        var payload: JSON = [:]
        var maybeNewFiles: [File]? = nil
        
        // NOTE: Editing stickers in/out is not supported
        for edit in edits {
            switch edit {
            case .content(let content):
                payload["content"] = content
            
            case .embeds(let embeds):
                if let embeds { payload["embeds"] = Embed.convert(embeds) }
            
            case .allowedMentions(let allowedMentions):
                payload["allowed_mentions"] = allowedMentions.convert()
                
            case .files(let files):
                if files.isEmpty {
                    // Removes all files
                    let empty = [JSON]() // "Empty collection literal requires an explicit type"
                    payload["attachments"] = empty
                } else {
                    var toAttach = [JSON]()
                    maybeNewFiles = []
                    maybeNewFiles!.append(contentsOf: files)
                    
                    if let keeping {
                        let keptAttachments = keeping.map({ $0.convert() })
                        toAttach.append(contentsOf: keptAttachments)
                    }
                    
                    for (i, _) in maybeNewFiles!.enumerated() {
                        toAttach.append(["id": i])
                    }
                    payload["attachments"] = toAttach
                }
                
            case .ui(let ui):
                self.ui = ui
                payload["components"] = try ui.convert()
                
            case .flags(let flags):
                let finalFlags = self.flags + Array(flags)
                payload["flags"] = Conversions.bitfield(finalFlags.map({ $0.rawValue }))
            }
        }
        
        let editedMessage = try await bot!.http.editMessage(channelId: channel.id, messageId: id, json: payload, files: maybeNewFiles)
        UI.setInteraction(message: editedMessage, ui: ui)
        return editedMessage
    }
    
    /// Delete the message.
    /// - Parameters:
    ///   - after: The amount of seconds to wait before deleting the message.
    ///   - reason: The reason for deleting the message. This shows up in the guilds audit log.
    public func delete(after: TimeInterval = 0, reason: String? = nil) async throws {
        let after = max(0, after)
        if after > 0 {
            Task {
                await sleep(Int(after * 1000))
                
                // Since this is in the background, the message could have possibly been already deleted, so silently
                // ignore any errors that may arise.
                try? await self.bot!.http.deleteMessage(channelId: self.channel.id, messageId: self.id, reason: reason)
            }
        } else {
            try await bot!.http.deleteMessage(channelId: channel.id, messageId: id, reason: reason)
        }
    }
    
    /// Get a reaction that's on the message.
    /// - Parameter emoji: Emoji matching the reaction.
    /// - Returns: The matching reaction.
    public func getReaction(_ emoji: String) -> Reaction? {
        return reactions.first(where: { $0.emoji.description == emoji })
    }
    
    /// Pins the message to the channel. Only 50 messages can be pinned per channel.
    /// - Parameter reason: The reason for pinning the message.
    public func pin(reason: String? = nil) async throws {
        try await bot!.http.pinMessage(channelId: channel.id, messageId: id, reason: reason)
    }
    
    /// Publish the message to the announcement channel.
    public func publish() async throws {
        try await bot!.http.crosspostMessage(channelId: channel.id, messageId: id)
    }
    
    func setExpires() {
        expires = Message.cacheExpire
        cacheExpireTimer?.invalidate()
        DispatchQueue.main.async {
            self.cacheExpireTimer = .scheduledTimer(withTimeInterval: self.expires.timeIntervalSince(.now), repeats: false, block: { [self] _ in
                bot!.removeCachedMessage(id)
            })
        }
    }
    
    /// Remove all reactions from the message or all reactions for a single emoji.
    /// - Parameter emoji: The emoji to remove. If `nil`, all emojis are removed.
    public func removeAllReactions(emoji: String? = nil) async throws {
        if let emoji {
            try await bot!.http.deleteAllReactionsForEmoji(channelId: channelId, messageId: id, emoji: emoji)
            reactions.removeAll(where: { $0.emoji.description! == emoji })
        } else {
            try await bot!.http.deleteAllReactions(channelId: channelId, messageId: id)
            reactions.removeAll()
        }
    }
    
    /// Remove a reaction by the specified user.
    /// - Parameters:
    ///   - emoji: Emoji to remove.
    ///   - by: The user the emoji belongs to.
    public func removeReaction(emoji: String, by: User) async throws {
        if by.id == bot!.user!.id {
            try await bot!.http.deleteOwnReaction(channelId: channelId, messageId: id, emoji: emoji)
        } else {
            try await bot!.http.deleteUserReaction(channelId: channelId, messageId: id, emoji: emoji, userId: by.id)
        }
    }
    
    /// Reply to a message.
    /// - Parameters:
    ///   - content: The message contents.
    ///   - tts: Whether this message should be sent as a TTS message.
    ///   - embeds: Embeds attached to the message (10 max).
    ///   - allowedMentions: Controls the mentions allowed when this message is sent.
    ///   - ui: The UI for the message. Contains things such as a ``Button`` or ``SelectMenu``.
    ///   - files: Files to attach to the message.
    /// - Returns: The message that was sent.
    @discardableResult
    public func reply(
        _ content: String? = nil,
        tts: Bool = false,
        embeds: [Embed]? = nil,
        allowedMentions: AllowedMentions = Bot.allowedMentions,
        ui: UI? = nil,
        files: [File]? = nil
    ) async throws -> Message {
        return try await channel.send(content, tts: tts, embeds: embeds, allowedMentions: allowedMentions, ui: ui, files: files, reference: asReference)
    }
    
    /// Unpin the message from the channel.
    /// - Parameter reason: The reason for unpinning the message from the channel.
    public func unpin(reason: String? = nil) async throws {
        try await bot!.http.unpinMessage(channelId: channel.id, messageId: id, reason: reason)
    }
}

extension Message {

    /// Represents the values that can be edited in a ``Message``.
    public enum Edit {
        
        /// Content for the message. Can be `nil` to remove all content.
        case content(String?)
        
        /// Embeds for the message. Can be `nil` to remove all embeds.
        case embeds([Embed]?)
        
        /// What mentions are allowed in the message.
        case allowedMentions(AllowedMentions)
        
        /// Files attached to the message. To remove all files, provide an empty array.
        case files([File])
        
        /// The new UI for the message.
        case ui(UI)
        
        /// The new flags to set. When editing someone elses message, the only flag that can be set currently  is ``Message/Flag/suppressEmbeds``.
        case flags(Set<Flag>)
    }

    /// Represents the message type.
    public enum MessageType : Int, CaseIterable {
        case `default`
        case recipientAdd
        case recipientRemove
        case call
        case channelNameChange
        case channelIconChange
        case channelPinnedMessage
        case guildMemberJoin
        case userPremiumGuildSubscription
        case userPremiumGuildSubscriptionTier1
        case userPremiumGuildSubscriptionTier2
        case userPremiumGuildSubscriptionTier3
        case channelFollowAdd
        case guildDiscoveryDisqualified = 14
        case guildDiscoveryRequalified
        case guildDiscoveryGracePeriodInitialWarning
        case guildDiscoveryGracePeriodFinalWarning
        case threadCreated
        case reply
        case chatInputCommand
        case threadStarterMessage
        case guildInviteReminder
        case contextMenuCommand
        case autoModerationAction
        case roleSubscriptionPurchase
        case interactionPremiumUpsell
        case stageStart
        case stageEnd
        case stageSpeaker
        case stageTopic = 31
        case guildApplicationPremiumSubscription
    }

    /// Represents a message attachment.
    public struct Attachment : Downloadable {
        
        /// Attachment ID.
        public let id: Snowflake
        
        /// Name of file attached.
        public let filename: String
        
        /// Description for the file.
        public let description: String?
        
        /// The attachment's [media type](https://en.wikipedia.org/wiki/Media_type).
        public let contentType: String?
        
        /// Size of file in bytes.
        public let size: Int
        
        /// Source URL of file.
        public let url: String
        
        /// A proxied URL of file.
        public let proxyUrl: String
        
        /// Height of file (if image).
        public let height: Int?
        
        /// Width of file (if image).
        public let width: Int?
        
        /// Whether this attachment is ephemeral.
        public let ephemeral: Bool
        
        // ------------ API Separated ------------
        
        /// Whether this attachment is marked as a spoiler.
        public let spoiler: Bool
        
        // ---------------------------------------

        init(attachmentData: JSON) {
            id = Conversions.snowflakeToUInt(attachmentData["id"])
            filename = attachmentData["filename"] as! String
            description = attachmentData["description"] as? String
            contentType = attachmentData["content_type"] as? String
            size = attachmentData["size"] as! Int
            url = attachmentData["url"] as! String
            proxyUrl = attachmentData["proxy_url"] as! String
            height = attachmentData["height"] as? Int
            width = attachmentData["width"] as? Int
            ephemeral = Conversions.optionalBooltoBool(attachmentData["ephemeral"])
            spoiler = filename.starts(with: "SPOILER_")
        }
        
        func convert() -> JSON {
            return [
                "id": id,
                "filename": filename,
                "description": description as Any,
                "content_type": contentType as Any,
                "size": size,
                "url": url,
                "proxy_url": proxyUrl,
                "height": height as Any,
                "weight": width as Any,
                "ephemeral": ephemeral
            ]
        }
    }
    
    /// Represents a message interaction.
    public struct Interaction {
        
        /// ID of the interaction.
        public let id: Snowflake
        
        /// Type of interaction.
        public let type: InteractionType
        
        /// Name of the application command, including subcommands and subcommand groups.
        public let name: String
        
        /// The ``User`` who invoked the interaction. Will be ``Member`` if invoked it was invoked from a guild.
        public let user: Object
        
        init(bot: Bot, guildId: Snowflake?, msgInteractionData: JSON) {
            id = Conversions.snowflakeToUInt(msgInteractionData["id"])
            type = InteractionType(rawValue: msgInteractionData["type"] as! Int)!
            name = msgInteractionData["name"] as! String
            
            if let memberObj = msgInteractionData["member"] as? JSON {
                user = Member(bot: bot, memberData: memberObj, guildId: guildId!)
            } else {
                user = User(userData: msgInteractionData["user"] as! JSON)
            }
        }
    }
    
    /// The activity associated with the message. Sent with rich presence-related chat embeds.
    public struct Activity {
        
        /// The activity type.
        public let type: ActivityType
        
        /// The  party ID from a riich presence event.
        public let partyId: String?
        
        init(activityData: JSON) {
            type = ActivityType.get(activityData["type"] as! Int)
            partyId = activityData["party_id"] as? String
        }
    }

    /// Represents the flags on a message.
    public enum Flag : Int, CaseIterable {

        /// This message has been published to subscribed channels (via Channel Following).
        case crossposted = 1
        
        /// This message originated from a message in another channel (via Channel Following).
        case isCrosspost = 2
        
        /// Do not include any embeds when serializing this message.
        case suppressEmbeds = 4
        
        /// The source message for this crosspost has been deleted (via Channel Following).
        case sourceMessageDeleted = 8
        
        /// This message came from the urgent message system.
        case urgent = 16
        
        /// This message has an associated thread, with the same ID as the message.
        case hasThread = 32
        
        /// This message is only visible to the user who invoked the Interaction.
        case ephemeral = 64
        
        /// This message is an Interaction Response and the bot is "thinking".
        case loading = 128
        
        /// This message failed to mention some roles and add their members to the thread.
        case failedToMentionSomeRolesInThread = 256
        
        /// This message will not trigger push and desktop notifications.
        case suppressNotifications = 4096
        
        /// This message is a voice message.
        case isVoiceMessage = 8192
        
        /// Convert the flag value to an array of message flags.
        static func get(_ messageFlagValue: Int) -> [Message.Flag] {
            var flags = [Message.Flag]()
            for flag in Message.Flag.allCases {
                if (messageFlagValue & flag.rawValue) == flag.rawValue {
                    flags.append(flag)
                }
            }
            return flags
        }
    }

    /// Represents a reference to a message.
    public struct Reference {

        /// ID of the originating message.
        public let messageId: Snowflake?

        /// ID of the originating message's channel.
        public let channelId: Snowflake?

        /// ID of the originating message's guild.
        public let guildId: Snowflake?

        /// When sending, whether to error if the referenced message doesn't exist instead of sending as a normal (non-reply) message.
        public var failIfNotExists = true

        init(messageId: Snowflake?, channelId: Snowflake?, guildId: Snowflake?) {
            self.messageId = messageId
            self.channelId = channelId
            self.guildId = guildId
        }

        func convert() -> JSON {
            var payload: JSON = ["fail_if_not_exists": failIfNotExists]
            if let messageId = messageId { payload["message_id"] = messageId }
            if let channelId = channelId { payload["channel_id"] = channelId }
            if let guildId = guildId { payload["guild_id"] = guildId }
            if let messageId = messageId { payload["message_id"] = messageId }
            return payload
        }
    }
    
    /// Represents the parameters used when requesting a channels message history.
    public enum History {
        case before(Snowflake)
        case after(Snowflake)
        case around(Snowflake)
    }
}

extension Message.Activity {
    
    /// Represents a messages activity type.
    public enum ActivityType : Int {
        case join = 1
        case spectate
        case listen
        case joinRequest = 5
        case unknown = -1
        
        /// Convert the type value to its appropriate type.
        static func get(_ type: Int) -> ActivityType {
            if let match = ActivityType(rawValue: type) { return match }
            else { return .unknown }
        }
    }
}

/// Represents what mentions are allowed in a message.
public struct AllowedMentions {
    
    /// If users can be mentioned in a message.
    public var users = true
    
    /// If roles can be mentioned in a message.
    public var roles = false
    
    /// If the user to the message that is being replied to are allowed to be mentioned in a message.
    public var repliedUser = true
    
    /// If `@everyone` or `@here` are allowed to be mentioned in a message.
    public var everyone = false
    
    /// The **only** users that can be mentioned in a message.
    public var exemptUsers = Set<User>()
    
    /// The **only** roles that can be mentioned in a message.
    public var exemptRoles = Set<Role>()
    
    /// An `AllowedMentions` object with everything enabled.
    public static let all = AllowedMentions(users: true, roles: true, repliedUser: true, everyone: true)
    
    /// An `AllowedMentions` object with only `users` and `repliedUser` enabled.
    public static let `default` = AllowedMentions(users: true, roles: false, repliedUser: true, everyone: false)
    
    /// An `AllowedMentions` object with everything disabled.
    public static let none = AllowedMentions(users: false, roles: false, repliedUser: false, everyone: false)
    
    /// Initializes a new allowed mentions object.
    /// - Parameters:
    ///   - users: If users can be mentioned in a message.
    ///   - roles: If roles can be mentioned in a message.
    ///   - repliedUser: If the user to the message that is being replied to are allowed to be mentioned in a message.
    ///   - everyone: If `@everyone` or `@here` are allowed to be mentioned in a message.
    public init(users: Bool, roles: Bool, repliedUser: Bool, everyone: Bool) {
        self.users = users
        self.roles = roles
        self.repliedUser = repliedUser
        self.everyone = everyone
    }
    
    /// Initializes a new allowed mentions object.
    /// - Parameters:
    ///   - users: The **only** users that can be mentioned in a message.
    ///   - roles: The **only** roles that can be mentioned in a message.
    public init(users: Set<User>, roles: Set<Role>) {
        exemptUsers = users
        exemptRoles = roles
    }
    
    func convert() -> JSON {
        var parse = [String]()
        
        if users { parse.append("users") }
        if roles { parse.append("roles") }
        if everyone { parse.append("everyone") }
        
        // users/roles must be removed or else an invalidation error will occur because of mutual exclusivity
        if !exemptUsers.isEmpty && users { parse.removeAll(where: { $0 == "users" }) }
        if !exemptRoles.isEmpty && roles { parse.removeAll(where: { $0 == "roles" }) }
        
        return [
            "parse": parse,
            "roles": exemptRoles.map({ $0.id.description }),
            "users": exemptUsers.map({ $0.id.description }),
            "replied_user": repliedUser
        ]
    }
}
