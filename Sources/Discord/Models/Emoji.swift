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

/// Represents a Discord guild emoji.
public struct Emoji : Object, CustomStringConvertible, Hashable {
    
    /// Emoji ID.
    public let id: Snowflake
    
    /// The guild this emoji belongs to.
    public var guild: Guild { bot!.getGuild(guildId)! }
    
    /// Emoji name.
    public internal(set) var name: String
    
    /// Roles allowed to use this emoji.  If this is empty, everyone is allowed to use it.
    public var roles: [Role] {
        get {
            var returnedRoles = [Role]()
            for roleStr in rolesData {
                let roleSnowflake = Conversions.snowflakeToUInt(roleStr)
                if let role = guild.getRole(roleSnowflake) { returnedRoles.append(role) }
            }
            return returnedRoles
        }
    }
    
    /// User that created this emoji.
    public let user: User?
    
    /// Whether this emoji must be wrapped in colons to use.
    public let requireColons: Bool
    
    /// Whether this emoji is managed by an integration.
    public let managed: Bool
    
    /// Whether this emoji is animated.
    public let animated: Bool
    
    /// Whether this emoji can be used. May be false due to a loss of Server Boosts.
    public internal(set) var available: Bool

    /// Your bot instance.
    public weak private(set) var bot: Discord?

    // ------------------------------ API Separated -----------------------------------
    
    /**
     The actual representation of the emoji.
     
     ```swift
     let crownEmoji = guild.getEmoji(1234567890123456789)
     channel.send(crownEmoji.description)
     // Sends 👑
     ```
     */
    public let description: String
    
    /// The URL of the emoji.
    public let url: String
    
    /// The `PartialEmoji` representation of the emoji.
    public var asPartial: PartialEmoji { PartialEmoji(id: id, name: name, animated: animated) }
    
    // --------------------------------------------------------------------------------
    
    private let rolesData: [String]
    private let guildId: Snowflake
    
    public static func == (lhs: Emoji, rhs: Emoji) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    init(bot: Discord, guildId: Snowflake, emojiData: JSON) {
        self.bot = bot
        self.guildId = guildId
        id = Conversions.snowflakeToUInt(emojiData["id"])
        name = emojiData["name"] as! String

        // emojiData["roles"] is just an array of string containing the role IDs
        rolesData = emojiData["roles"] as! [String]

        let userData = emojiData["user"] as? JSON
        user = userData != nil ? User(userData: userData!) : nil

        requireColons = emojiData["require_colons"] as! Bool
        managed = emojiData["managed"] as! Bool
        animated = emojiData["animated"] as! Bool
        available = emojiData["available"] as! Bool
        description = animated ? "<a:\(name):\(id)>" : "<:\(name):\(id)>"
        url = APIRoute.cdn.rawValue + "/emojis/\(id).\(animated ? "gif" : "png")"
    }
    
    /// Edit the emoji.
    /// - Parameters:
    ///   - edits: The enum containing all values to be updated for the emoji.
    ///   - reason: The reason for editing the emoji. This shows up in the guilds audit log.
    /// - Returns: The updated emoji.
    @discardableResult
    public func edit(_ edits: Emoji.Edit..., reason: String? = nil) async throws -> Emoji {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }
        
        var payload: JSON = [:]
        for edit in edits {
            switch edit {
            case .name(let name):
                payload["name"] = name
            case .roles(let roles):
                payload["roles"] = roles.map({ $0.id })
            }
        }
        return try await bot!.http.modifyGuildEmoji(guildId: guild.id, emojiId: id, payload: payload, reason: reason)
    }
    
    /// Deletes the emoji.
    /// - Parameter reason: The reason for deleting the emoji.
    public func delete(reason: String? = nil) async throws {
        try await bot!.http.deleteGuildEmoji(guildId: guild.id, emojiId: id, reason: reason)
    }
}

extension Emoji {
    
    /// Represents the values that should be edited in a ``Emoji``.
    public enum Edit {
        
        /// The emoji name.
        case name(String)
        
        /// Which roles can use the emoji. Can be an empty array to allow everyone to use it.
        case roles([Role])
    }
}

/// Represents a partial emoji on Discord.
public struct PartialEmoji {
    
    /// Guild emoji ID. If created via ``PartialEmoji/init(_:)``, this will be `nil`.
    public let id: Snowflake?
    
    /// Emoji name. If created via ``DiscordEvent/messageReactionAdd`` or ``DiscordEvent/messageReactionRemove``, this
    /// property may be `nil` when custom emoji data is not available (for example, if it was deleted from the guild).
    public let name: String?
    
    /// Whether this emoji is animated. If created via ``PartialEmoji/init(_:)``, this will be `nil`. This is typically available
    /// when this was created via ``DiscordEvent/messageReactionAdd``.
    public private(set) var animated: Bool?
    
    /// Returns the raw representation of the partial emoji.
    public var description: String? {
        get {
            if id == nil && name == nil { return nil }
            else {
                // Guild emoji
                if let name, let id {
                    if let isAnim = animated {
                        return isAnim ? "<a:\(name):\(id)>" : "<:\(name):\(id)>"
                    }
                    else { return "<:\(name):\(id)>" }
                }
                
                // Unicode emoji
                if name != nil && id == nil {
                    return name!
                }
            }
            return nil
        }
    }
    
    init(partialEmojiData: JSON) {
        id = Conversions.snowflakeToOptionalUInt(partialEmojiData["id"])
        name = partialEmojiData["name"] as? String
        animated = partialEmojiData["animated"] as? Bool
    }
    
    /// Create a partial standard emoji. When creating a standard emoji, `id` and `animated` will be `nil`.
    /// - Parameter emoji: A standard emoji. Standard emojis are unicode emojis such as "😎"
    public init(_ emoji: String) {
        name = emoji
        id = nil
        animated = nil
    }
    
    /// Create a partial guild emoji.
    /// - Parameters:
    ///   - id: The ID of the guild emoji.
    ///   - name: Name of the guild emoji.
    ///   - animated: Whether the guild emoji is animated.
    public init(id: Snowflake, name: String, animated: Bool) {
        self.id = id
        self.name = name
        self.animated = animated
    }
    
    func convert() -> JSON {
        var payload: JSON = [:]
        payload["id"] = nullable(id)
        payload["name"] = name
        if let animated { payload["animated"] = animated }
        return payload
    }

    /// Converts a string into a `PartialEmoji`.
    /// - Parameter emoji: A guild emoji or a standard unicode emoji.
    /// - Returns: The converted string.
    public static func fromString(_ emoji: String) -> PartialEmoji {
        
        // Guild emoji
        if let range = emoji.firstRange(of: #/<a?:.+?:[0-9]{17,20}>/#) {
            let emojiSubStr = emoji[range]
            
            let nameRange = emojiSubStr.firstRange(of: #/:.+?:/#)!
            var emojiName = String(emojiSubStr[nameRange])
            emojiName.replace(":", with: String.empty)
            
            let idRange = emojiSubStr.firstRange(of: #/[0-9]{17,20}/#)!
            let emojiId = Conversions.snowflakeToUInt(String(emojiSubStr[idRange]))
            
            let isAnimated = emojiSubStr.starts(with: "<a:")
            
            return PartialEmoji(id: emojiId, name: emojiName, animated: isAnimated)
        }
        else {
            return PartialEmoji(emoji)
        }
    }
}

/// Represents a reaction on a message.
public class Reaction {
    
    /// Times this emoji has been used to react.
    public internal(set) var count: Int
    
    /// Whether the bot reacted using this emoji.
    public internal(set) var userReacted: Bool
    
    /// Emoji information.
    public let emoji: PartialEmoji
    
    /// The message this reaction is attached to.
    public let message: Message
    
    /// Your bot instance.
    public private(set) weak var bot: Discord?
    
    init(bot: Discord, reactionData: JSON, messageId: Snowflake) {
        self.bot = bot
        count = reactionData["count"] as! Int
        userReacted = reactionData["me"] as! Bool
        emoji = PartialEmoji(partialEmojiData: reactionData["emoji"] as! JSON)
        message = bot.getMessage(messageId)!
    }
    
    /**
     Request all users who reacted with this reaction.
     
     Below is an example on how to request users:
     ```swift
     do {
         for try await users in reaction.users() {
             // ...
         }
     } catch {
         // Handle error
     }
     ```
     Each iteration of the async for-loop contains batched users. Meaning `users` will be an array of at most 100 users. You will receive batched users until
     all users matching the function parameters are fully received.
     
     - Parameters:
        - limit: The amount of users to return. If `nil`, all users will be returned. The more users, the longer this will take.
        - after: Users to retrieve after the specified date.
     */
    public func users(limit: Int? = 100, after: Date? = nil) -> AsyncUsers {
        return AsyncUsers(message: message, emoji: emoji.description!, limit: limit, after: after)
    }
}

extension Reaction {
    
    /// Represents an asynchronous iterator used for  ``Reaction/users(limit:after:)``.
    public struct AsyncUsers : AsyncSequence, AsyncIteratorProtocol {
        
        public typealias Element = [User]

        let message: Message
        let emoji: String
        let indefinite = -1
        var remaining = 0
        var afterSnowflakeTime: Snowflake
        var hasMore = true

        init(message: Message, emoji: String, limit: Int?, after: Date?) {
            self.message = message
            self.emoji = emoji
            self.remaining = limit ?? indefinite
            self.afterSnowflakeTime = after?.asSnowflake ?? 0
        }
        
        private func req(limit: Int, after: Snowflake) async throws -> [JSON] {
            return try await message.bot!.http.getUsersForReaction(
                channelId: message.channelId,
                messageId: message.id,
                emoji: emoji,
                limit: limit,
                after: after
            )
        }
        
        public mutating func next() async throws -> Element? {
            if !hasMore { return nil }
            
            var users = [User]()
            let requestAmount = (remaining == indefinite ? 100 : Swift.min(remaining, 100))
            let data = try await req(limit: requestAmount, after: afterSnowflakeTime)
            
            // If the amount of users received is less 100, theres no more data after it, so set
            // this to false to prevent an extra HTTP request that is not needed.
            if data.count < 100 {
                hasMore = false
            }
            
            for obj in data {
                users.append(.init(userData: obj))
                if remaining != indefinite {
                    remaining -= 1
                    if remaining == 0 {
                        hasMore = false
                        return users
                    }
                }
            }
            afterSnowflakeTime = users.last?.id ?? 0
            return users
        }
        
        public func makeAsyncIterator() -> AsyncUsers {
            self
        }
    }
}
