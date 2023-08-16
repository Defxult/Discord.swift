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

/// Represents a Discord guild member.
public class Member : Object, Hashable {
    
    /// The members ID.
    public var id: Snowflake { user!.id }
    
    /// The user's guild nickname.
    public internal(set) var nick: String?

    /// The guild the user belongs to.
    public var guild: Guild { bot!.getGuild(guildId)! }
    private let guildId: Snowflake
    
    /// The user's guild avatar.
    public var guildAvatar: Asset? {
        if let guildAvatarHash {
            let baseUrl = "/guilds/\(guild.id)/users/\(user!.id)/avatars/"
            return Asset(hash: guildAvatarHash, fullURL: baseUrl + Asset.imageType(hash: guildAvatarHash))
        }
        return nil
    }
    
    /// All roles applied to the member.
    public var roles: [Role] {
        var returnedRoles = [Role]()
        for role in guild.roles {
            for roleIdStr in memberRoleArrayStr {
                if role.id == Conversions.snowflakeToUInt(roleIdStr) {
                    returnedRoles.append(role)
                }
            }
        }
        return returnedRoles
    }
    
    /// When the user joined the guild.
    public internal(set) var joinedAt: Date
    
    /// When the user started boosting the guild.
    public internal(set) var premiumSince: Date?
    
    /// Whether the user has not yet passed the guild's Membership Screening requirements.
    public internal(set) var isPending: Bool

    /// When the user's timeout will expire and the user will be able to communicate in the guild again.
    public internal(set) var timedOutUntil: Date?
    
    /// User object for the member. Contains information such as their ID, username, avatar, etc.
    public internal(set) var user: User?
    
    /// The members flags. Contains information such as ``Flag/didRejoin`` and more.
    public internal(set) var flags: [Flag]

    /// Your bot instance.
    public weak private(set) var bot: Discord?
    
    // ------------------------------ API Separated -----------------------------------
    
    /// The direct message channel associated with the member, or `nil` if not found.
    public var dmChannel: DMChannel? {
        let dmChs = bot!.dms.filter({ $0.recipientId != nil })
        return dmChs.first(where: { $0.recipientId! == id })
    }
    
    /// The user's voice state. Contains information such as ``VoiceChannel/State/selfMuted`` and more.
    public var voice: VoiceChannel.State? { guild.voiceStates.first(where: { $0.user.id == id }) }
    
    /// All guilds the bot and the member shares.
    ///
    /// This is reliant on whether Privileged Intents have been enabled in your developer portal. As well as
    /// intents ``Intents/guildMembers`` and ``Intents/guildPresences`` being enabled
    /// so that ``Guild/members`` can be fully loaded.
    public var mutualGuilds: [Guild] {
        var mutuals = [Guild]()
        bot!.guilds.forEach({ g in
            if let _ = g.getMember(id) {
                mutuals.append(g)
            }
        })
        return mutuals
    }
    
    // --------------------------------------------------------------------------------
    
    // Hashable
    public static func == (lhs: Member, rhs: Member) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }
    
    var memberRoleArrayStr: [String]
    var guildAvatarHash: String?
    
    init(bot: Discord, memberData: JSON, guildId: Snowflake) {
        self.bot = bot
        self.guildId = guildId
        nick = memberData["nick"] as? String
        memberRoleArrayStr = memberData["roles"] as! [String]
        joinedAt = Conversions.stringDateToDate(iso8601: memberData["joined_at"] as! String)!
        isPending = Conversions.optionalBooltoBool(memberData["pending"] as? Bool)
        guildAvatarHash = memberData["avatar"] as? String
        
        let timedOutDate = memberData["communication_disabled_until"] as? String
        if let timedOutDate { timedOutUntil = Conversions.stringDateToDate(iso8601: timedOutDate) }

        if let userObj = memberData["user"] as? JSON { user = User(userData: userObj) }
        
        flags = Flag.determineFlags(value: memberData["flags"] as! Int)
    }
    
    /// Bans the member from the guild.
    /// - Parameters:
    ///   - deleteMessageSeconds: Number of seconds to delete messages for, between 0 and 604800 (7 days). For example, if set to 172800 (2 days), 2 days worth of messages will be deleted.
    ///   - reason: The reason for banning the member. This shows up in the guilds audit log.
    public func ban(deleteMessageSeconds: Int = 0, reason: String? = nil) async throws {
        try await guild.ban(user: user!, deleteMessageSeconds: deleteMessageSeconds, reason: reason)
    }
    
    /// Edit the member.
    /// - Parameters:
    ///   - edits: The enum containing all values to be updated or removed for the member.
    ///   - reason: The reason for editing the member. This shows up in the guilds audit log.
    /// - Returns: The updated member.
    @discardableResult
    public func edit(_ edits: Edit..., reason: String? = nil) async throws -> Member {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }
        
        var payload: JSON = [:]
        for edit in edits {
            switch edit {
            case .bypassVerification(let value):
                // As of Apr 24, 2023 the only flag that is editable is bypass verification
                payload["flags"] = value ? Member.Flag.bypassesVerification.rawValue : 0
            case .nickname(let name):
                payload["nick"] = nullable(name)
            case .roles(let roles):
                payload["roles"] = Role.toSnowflakes(roles)
            case .mute(let mute):
                payload["mute"] = mute
            case .deafen(let deafen):
                payload["deaf"] = deafen
            case .move(let vc):
                payload["channel_id"] = nullable(vc?.id)
            case .timeout(let date):
                payload["communication_disabled_until"] = nullable(date?.asISO8601)
            }
        }
        
        return try await bot!.http.modifyGuildMember(guildId: guild.id, userId: id, data: payload, reason: reason)
    }
    
    /// Add roles to a member.
    /// - Parameters:
    ///   - roles: Roles to add.
    ///   - reason: The reason for adding the roles. This shows up in the guilds audit log.
    public func addRoles(_ roles: [Role], reason: String? = nil) async throws {
        for r in roles {
            try await bot!.http.addRoleToMember(guildId: guild.id, userId: id, roleId: r.id, reason: reason)
        }
    }
    
    /// Remove roles from a member.
    /// - Parameters:
    ///   - roles: Roles to remove.
    ///   - reason: The reason for removing the roles. This shows up in the guilds audit log.
    public func removeRoles(_ roles: [Role], reason: String? = nil) async throws {
        for r in roles {
            try await bot!.http.removeRoleFromMember(guildId: guild.id, userId: id, roleId: r.id, reason: reason)
        }
    }
    
    /// Removes the member from the guild.
    /// - Parameter reason: The reason for removing the member from the guild. This shows up in the guilds audit log.
    public func kick(reason: String? = nil) async throws  {
        try await bot!.http.removeGuildMember(guildId: guild.id, userId: id, reason: reason)
    }
    
    /// Whether the member was mentioned in the message. See ``User/mentionedIn(_:)`` for the ``User`` variant.
    /// - Parameter message: The message to check if the member was mentioned.
    public func mentionedIn(_ message: Message) -> Bool {
        return message.mentionedUsers.contains(user!)
    }
    
    /// Timeout the member for up to 28 days.
    /// - Parameters:
    ///   - until: When the timeout will expire. Can be set to `nil` to remove timeout.
    ///   - reason: The reason for timing out the member. This shows up in the guilds audit log.
    public func timeout(until: Date?, reason: String? = nil) async throws {
        try await edit(.timeout(until))
    }
}

extension Member {
    
    /// Represents a ``Member``s flags.
    public enum Flag : Int, CaseIterable {
        
        /// Member has left and rejoined the guild.
        case didRejoin = 1
        
        /// Member has completed onboarding.
        case completedonboarding = 2
        
        /// Member is exempt from guild verification requirements.
        case bypassesVerification = 4
        
        /// Member has started onboarding.
        case startedOnboarding = 8
        
        static func determineFlags(value: Int) -> [Flag] {
            var flags = [Flag]()
            for flag in Flag.allCases {
                if (value & flag.rawValue) == flag.rawValue {
                    flags.append(flag)
                }
            }
            return flags
        }
    }
    
    /// Represents the values that can be edited in a ``Member``.
    public enum Edit {
        
        /// Allows a member who does not meet verification requirements to participate in a server.
        case bypassVerification(Bool)
        
        /// The nickname for the member. Set to `nil` to remove the nickname.
        case nickname(String?)
        
        /// The roles to apply to the member. This **replaces** the roles. Use an empty array to remove all roles.
        case roles([Role])
        
        /// Mute the member. This requires them to be in a voice channel.
        case mute(Bool)
        
        /// Deafen the member.
        case deafen(Bool)
        
        /// Voice channel to move the member to if they are connected to voice. Set to `nil` to disconnect the member from the voice channel.
        case move(GuildChannel?)
        
        /// When the members timeout will expire and the user will be able to communicate in the guild again (up to 28 days in the future), set to `nil` to remove the timeout.
        case timeout(Date?)
    }
}
