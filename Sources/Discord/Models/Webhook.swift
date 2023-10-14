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

/// Represents a Discord webhook.
public struct Webhook : Object {
    
    /// The ID of the webhook.
    public let id: Snowflake
    
    /// The type of the webhook.
    public let type: WebhookType

    /// The guild ID this webhook is for, if any.
    public let guildId: Snowflake?

    /// The channel ID this webhook is for, if any.
    public let channelId: Snowflake?

    /// The user this webhook was created by (not returned when getting a webhook with its token).
    public let user: User?

    /// The default name of the webhook.
    public let name: String?

    /// The default user avatar of the webhook.
    public let avatar: Asset?

    /// The secure token of the webhook.
    public let token: String?

    /// The bot/OAuth2 application that created this webhook.
    public let applicationId: Snowflake?

    /// The URL used for executing the webhook.
    public let url: String?
    
    /// Your bot instance.
    public weak private(set) var bot: Bot?
    
    init(bot: Bot, webhookData: JSON) {
        self.bot = bot
        id = Conversions.snowflakeToUInt(webhookData["id"])
        type = WebhookType(rawValue: webhookData["type"] as! Int)!
        guildId = Conversions.snowflakeToOptionalUInt(webhookData["guild_id"])
        channelId = Conversions.snowflakeToOptionalUInt(webhookData["channel_id"])
        
        if let userObj = webhookData["user"] as? JSON { user = User(userData: userObj) }
        else { user = nil }
        
        name = webhookData["name"] as? String
        
        if let avatarHash = webhookData["avatar"] as? String { avatar = Asset(hash: avatarHash, fullURL: "/avatars/\(id)/\(Asset.imageType(hash: avatarHash))") }
        else { avatar = nil }
        
        token = webhookData["token"] as? String
        applicationId = Conversions.snowflakeToOptionalUInt(webhookData["application_id"])
        url = token == nil ? nil : "https://discord.com/api/webhooks/\(id)/\(token!)"
    }
    
    static func extractFromURL(_ url: String) throws -> (id: Snowflake, token: String?) {
        let webhookUrlRegex = #/https://discord\.com/api/webhooks/[0-9]{17,20}/\S+/#
        let invalid = "invalid webhook URL"
        guard let _ = url.wholeMatch(of: webhookUrlRegex) else {
            throw DiscordError.generic(invalid)
        }
        let split = Array(url.split(separator: "/").suffix(2))
        // Verify the first element are all numbers (the ID)
        if !split[0].allSatisfy(\.isNumber) {
            throw DiscordError.generic(invalid)
        }
        let webhookId = split[0].description
        let webhookToken = split.count > 1 ? split[1].description : nil
        return (Conversions.snowflakeToUInt(webhookId), webhookToken)
    }
    
    /// Deletes the webhook.
    public func delete() async throws {
        try await bot!.http.deleteWebhook(webhookId: id)
    }
    
    /// Edit the webhook.
    /// - Parameters:
    ///   - edits: The enum containing all values to be updated or removed for the webhook.
    ///   - reason: The reason for editing the webhook. This shows up in the guilds audit log.
    /// - Returns: The updated webhook.
    @discardableResult
    public func edit(_ edits: Edit..., reason: String? = nil) async throws -> Webhook {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }
        
        var payload: JSON = [:]
        for e in edits {
            switch e {
            case .name(let name):
                payload["name"] = name
            case .avatar(let avatar):
                payload["avatar"] = nullable(avatar?.asImageData)
            case .channel(let channelId):
                payload["channel_id"] = channelId
            }
        }
        return try await bot!.http.modifyWebhook(webhookId: id, data: payload, reason: reason)
    }
    
    /// Send a message via the webhook.
    /// - Parameters:
    ///   - content: The message contents.
    ///   - embeds: Embeds attached to the message (10 max).
    ///   - tts: Whether this message should be sent as a TTS message.
    ///   - allowedMentions: Controls the mentions allowed when this message is sent.
    ///   - ui: The UI for the message. Contains things such as a ``Button`` or ``SelectMenu``. The webhook must be owned by the bot in order to use this.
    ///   - files: Files to attach to the message.
    ///   - threadId: The specified thread within a webhook's channel. The thread will automatically be unarchived.
    ///   - threadName: Name of thread to create (requires the webhook channel to be a forum channel).
    ///   - username: Override the default username of the webhook.
    ///   - avatarUrl: Override the default avatar of the webhook.
    /// - Returns: The message that was sent.
    @discardableResult
    public func send(
        _ content: String? = nil,
        embeds: [Embed]? = nil,
        tts: Bool = false,
        allowedMentions: AllowedMentions = Bot.allowedMentions,
        ui: UI? = nil,
        files: [File]? = nil,
        threadId: Snowflake? = nil,
        threadName: String? = nil,
        username: String? = nil,
        avatarUrl: String? = nil
    ) async throws -> Message {
        if let token {
            var payload: JSON = ["tts": tts, "allowed_mentions": allowedMentions.convert()]
            
            if let content { payload["content"] = content }
            if let embeds { payload["embeds"] = Embed.convert(embeds) }
            if let ui { payload["components"] = try ui.convert() }
            if let threadName { payload["thread_name"] = threadName }
            if let username { payload["username"] = username }
            if let avatarUrl { payload["avatar_url"] = avatarUrl }
            
            let message = try await bot!.http.executeWebhook(webhookId: id, webhookToken: token, json: payload, files: files, threadId: threadId)
            UI.setUI(message: message, ui: ui)
            return message
        }
        throw DiscordError.generic("Webhook.send() cannot be used with this webhook because it has no token")
    }
}

extension Webhook {
    
    /// Represents the values that can be edited in a ``Webhook``.
    public enum Edit {
        
        /// The default name of the webhook.
        case name(String)
        
        /// Image for the default webhook avatar. Can be `nil` to remove the avatar.
        case avatar(File?)
        
        /// The new channel ID this webhook should be moved to.
        case channel(Snowflake)
    }
    
    /// Represents a webhook type.
    public enum WebhookType : Int {
        
        /// Incoming Webhooks can post messages to channels with a generated token.
        case incoming = 1
        
        /// Channel Follower Webhooks are internal webhooks used with Channel Following to post new messages into channels.
        case channelFollower
        
        /// Application webhooks are webhooks used with Interactions.
        case application
    }
}
