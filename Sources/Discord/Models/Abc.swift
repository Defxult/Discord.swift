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

typealias JSON = [String: Any]

/// Represents a Discord ID.
public typealias Snowflake = UInt

/// Discord's Unix timestamp, the first second of 2015.
public let discordEpoch: Snowflake = 1420070400000

protocol Updateable {
    func update(_ data: JSON)
}

/// Represents a base Discord object.
public protocol Object {
    
    /// The ID of the object.
    var id: Snowflake { get }
}

extension Object {
    
    /// The creation date converted from the objects snowflake.
    public var created: Date { snowflakeDate(id) }
}

/// Represents a channel where messages are able to be sent.
public protocol Messageable : Object {
    
    /// Your bot instance.
    var bot: Discord? { get }
}

extension Messageable {
    
    /**
     Delete multiple messages at once.
     
     - Parameters:
        - toDelete: The messages to delete (2 minimum, 100 maximum)
        - reason: The reason for deleting the messages.
     */
    public func bulkDeleteMessages(_ toDelete: [Message], reason: String? = nil) async throws {
        try await bot!.http.bulkDeleteMessages(channelId: id, messagesToDelete: toDelete, reason: reason)
    }
    
    /**
     Recieve the channels message history.
     
     - Parameters:
        - limit: Max number of messages to return (1-100).
        - search: What to search by. Either before, after, or around a specified message. If `nil`, no filter is used.
     - Returns: The messages matching the limit/search query.
     */
    public func history(limit: Int = 50, search: Message.History? = nil) async throws -> [Message] {
        if let search {
            switch search {
            case .before(let beforeId):
                return try await bot!.http.getChannelMessages(channelId: id, limit: limit, before: beforeId)
            case .after(let afterId):
                return try await bot!.http.getChannelMessages(channelId: id, limit: limit, after: afterId)
            case .around(let aroundId):
                return try await bot!.http.getChannelMessages(channelId: id, limit: limit, around: aroundId)
            }
        }
        return try await bot!.http.getChannelMessages(channelId: id, limit: limit)
    }
    
    
    /// Request a message in the channel.
    /// - Parameter id: ID of the message.
    /// - Returns: The requested message.
    public func requestMessage(_ id: Snowflake) async throws -> Message {
        return try await bot!.http.getChannelMessage(channelId: self.id, messageId: id)
    }
    
    /**
     Send a message to the channel.
     
     - Parameters:
        - content: The message contents.
        - tts: Whether this message should be sent as a TTS message.
        - embeds: Embeds attached to the message (10 max).
        - allowedMentions: Controls the mentions allowed when this message is sent.
        - ui: The UI for the message. Contains things such as a ``Button`` or ``SelectMenu``.
        - files: Files to attach to the message.
        - stickers: Stickers to attach to the message (3 max).
        - reference: The message to reply to.
     - Returns: The message that was sent.
     - Throws: `HTTPError.forbidden` You don't have the proper permissions to send a message. `HTTPError.base` Sending the message failed.
    */
    @discardableResult
    public func send(
        _ content: String? = nil,
        tts: Bool = false,
        embeds: [Embed]? = nil,
        allowedMentions: AllowedMentions = Discord.allowedMentions,
        ui: UI? = nil,
        files: [File]? = nil,
        stickers: [GuildSticker]? = nil,
        reference: Message.Reference? = nil
    ) async throws -> Message {
        var payload: JSON = ["tts": tts]
        
        if let content {
            payload["content"] = content
            payload["allowed_mentions"] = allowedMentions.convert(content: content)
        }
        
        if let embeds { payload["embeds"] = Embed.convert(embeds) }
        if let reference { payload["message_reference"] = reference.convert() }
        if let ui { payload["components"] = try ui.convert() }
        if let stickers { payload["sticker_ids"] = stickers.map({ $0.id }) }
        
        let message = try await bot!.http.createMessage(channelId: id, json: payload, files: files)
        UI.setUI(message: message, ui: ui)
        return message
    }
    
    /// Trigger the typing indicator in the channel. Each trigger lasts 10 seconds unless a message is sent sooner.
    public func triggerTyping() async throws {
        try await bot!.http.triggerTypingIndicator(channelId: id)
    }
}
