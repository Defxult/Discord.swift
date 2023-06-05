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

/// Represents a Discord role.
public class Role : Object, Hashable {
    
    /// Role ID.
    public let id: Snowflake

    /// The guild the role belongs to.
    public var guild: Guild { bot!.getGuild(guildId)! }
    
    /// Role name.
    public internal(set) var name: String
    
    /// Role color.
    public internal(set) var color: Color?
    
    /// If this role is pinned in the user listing.
    public internal(set) var hoist: Bool
    
    /// The role avatar.
    public internal(set) var icon: Asset?
    
    /// Position of this role.
    public internal(set) var position: Int
    
    /// Permissions for the role.
    public internal(set) var permissions: Permissions
    
    /// Whether this role is managed by an integration.
    public let managed: Bool
    
    /// Whether this role is mentionable.
    public internal(set) var mentionable: Bool
    
    /// The tags this role has.
    public internal(set) var tags: Tag?

    /// Your bot instance.
    public weak private(set) var bot: Discord?
    
    // Needed for .delete() & .guild
    private let guildId: Snowflake
    
    // Hashable extras
    public static func == (lhs: Role, rhs: Role) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // ------------------------------ API Separated -----------------------------------
    
    /// All members who currently have this role.
    public var members: [Member] {
        get {
            var withRole = [Member]()
            for m in guild.members {
                if m.roles.contains(where: { $0.id == id }) { withRole.append(m) }
            }
            return withRole
        }
    }

    /// Mention the role.
    public let mention: String

    // --------------------------------------------------------------------------------

    init(bot: Discord, roleData: JSON, guildId: Snowflake) {
        self.bot = bot
        id = Conversions.snowflakeToUInt(roleData["id"])
        name = roleData["name"] as! String
        
        color = Color.getPayloadColor(value: roleData["color"] as? Int)
        hoist = roleData["hoist"] as! Bool

        let iconHash = roleData["icon"] as? String
        icon = iconHash != nil ? Asset(hash: iconHash!, fullURL: "/role-icons/\(id)/\(Asset.determineImageTypeURL(hash: iconHash!))") : nil

        position = roleData["position"] as! Int
        
        let permValue = Int(Conversions.snowflakeToUInt(roleData["permissions"]))
        permissions = Permissions(permsValue: permValue)
        
        managed = roleData["managed"] as! Bool
        mentionable = roleData["mentionable"] as! Bool

        if let tempTagsData = roleData["tags"] as? JSON {
            tags = Tag(tagData: tempTagsData)
        }
        
        mention = (id == guildId ? "@everyone" : Markdown.mentionRole(id: id))
        self.guildId = guildId
    }
    
    /// Delete the role.
    /// - Parameter reason: The reason for deleting the role. This shows up in the guilds audit-logs.
    public func delete(reason: String? = nil) async throws {
        try await bot!.http.deleteGuildRole(guildId: guild.id, roleId: id, reason: reason)
    }
    
    /// Edit the role.
    /// - Parameters:
    ///   - edits: The enum containing all values to be updated for the role.
    ///   - reason: The reason for editing the role. This shows up in the guilds audit log.
    /// - Returns: The updated role.
    @discardableResult
    public func edit(_ edits: Edit..., reason: String? = nil) async throws -> Role {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }
        
        var payload: JSON = [:]
        for e in edits {
            switch e {
            case .name(let name):
                payload["name"] = name
            case .permissions(let perms):
                payload["permissions"] = perms.value
            case .color(let color):
                payload["color"] = color.value
            case .hoist(let hoist):
                payload["hoist"] = hoist
            case .icon(let icon):
                payload["icon"] = icon.asImageData
            case .mentionable(let mentionable):
                payload["mentionable"] = mentionable
            }
        }
        
        return try await bot!.http.modifyGuildRole(guildId: guild.id, roleId: id, data: payload, reason: reason)
    }

    static func toSnowflakes(_ roles: [Role]) -> [Snowflake] {
        return roles.map({ $0.id })
    }
}

extension Role {
    
    /// Represents the tag belonging to a role.
    public struct Tag {
        
        /// The ID of the bot this role belongs to
        public let botId: Snowflake?
        
        /// The ID of the integration this role belongs to.
        public let integrationId: Snowflake?

        /// Whether this is the guild's premium subscriber role, aka the "Nitro Booster" role.
        public let isPremiumSubscriber: Bool

        init(tagData: JSON) {
            botId = Conversions.snowflakeToOptionalUInt(tagData["bot_id"])
            integrationId = Conversions.snowflakeToOptionalUInt(tagData["integration_id"])

            // So the API is weird here. Basically the value for `premium_subscriber` by default is `nil` if the value IS present.
            // But checking if it exists (tagData["premium_subscriber"]), I would have to use `as? Any`, but if it's missing, its `nil`,
            // and if it's there, it's still `nil` (WTF). Basically to get around this, I just check if the value `premium_subscriber` is in the
            // dictionary at all. If it is, regardless of if the value is `nil`, as long as it's there that's equivalent to `true`. If it's
            // missing, that's equivalent to `false`.
            isPremiumSubscriber = tagData.contains(where: { $0.key == "premium_subscriber" })
        }
    }
    
    /// Represents the values that should be edited in a ``Role``.
    public enum Edit {
        
        /// The role name.
        case name(String)
        
        /// The role permissions.
        case permissions(Permissions)
        
        /// The color for the role.
        case color(Color)
        
        /// If this role is pinned in the user listing.
        case hoist(Bool)
        
        /// The role icon.
        case icon(File)
        
        /// Whether this role is mentionable.
        case mentionable(Bool)
    }
}
