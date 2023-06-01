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

/// Represents a guild application command permission.
public struct GuildApplicationCommandPermissions {
    
    /// ID of the command or the application ID.
    public let id: Snowflake
    
    /// ID of the application the command belongs to.
    public let applicationId: Snowflake
    
    /// ID of the guild.
    public let guildId: Snowflake
    
    /// Permissions for the command in the guild, max of 100.
    public let permissions: [ApplicationCommandPermissions]
    
    init(guildAppCommandPermData: JSON) {
        id = Conversions.snowflakeToUInt(guildAppCommandPermData["id"])
        applicationId = Conversions.snowflakeToUInt(guildAppCommandPermData["application_id"])
        guildId = Conversions.snowflakeToUInt(guildAppCommandPermData["guild_id"])
        
        var perms = [ApplicationCommandPermissions]()
        let permissionsObjs = guildAppCommandPermData["permissions"] as! [JSON]
        for permissionsObj in permissionsObjs { perms.append(.init(appCommandPermsData: permissionsObj, guildId: guildId)) }
        permissions = perms
    }
}

/// Represents the permissions for an application command.
public struct ApplicationCommandPermissions {
    
    /// ID of the role, user, or channel.
    public let id: Snowflake
    
    /// The permission type for an application command.
    public let type: ApplicationCommandPermissionType
    
    /// Whether the permission is allowed.
    public let allowed: Bool
    
    init(appCommandPermsData: JSON, guildId: Snowflake) {
        id = Conversions.snowflakeToUInt(appCommandPermsData["id"])
        type = .getType(id: id, guildId: guildId, value: appCommandPermsData["type"] as! Snowflake)
        allowed = appCommandPermsData["permission"] as! Bool
    }
}

/// Represents the permission type for an application command.
public enum ApplicationCommandPermissionType : Int {
    case role = 1
    case user = 2
    case channel = 3
    
    // These cases don't exist in the real types, they're a way
    // to represent application command permission constants.
    case everyone = -100
    case allChannels = -99
    
    static func getType(id: Snowflake, guildId: Snowflake, value: Snowflake) -> ApplicationCommandPermissionType {
        if id == guildId { return .everyone }
        else if id == (guildId - 1) { return .allChannels }
        else {
            return .init(rawValue: Int(value))!
        }
    }
}

/// Represents a permission.
public enum Permission : Int, CaseIterable {
    case createInstantInvite = 1                            // 1 << 0
    case kickMembers = 2                                    // 1 << 1
    case banMembers = 4                                     // 1 << 2
    case administrator = 8                                  // 1 << 3
    case manageChannels = 16                                // 1 << 4
    case manageGuild = 32                                   // 1 << 5
    case addReactions = 64                                  // 1 << 6
    case viewAuditLog = 128                                 // 1 << 7
    case prioritySpeaker = 256                              // 1 << 8
    case stream = 512                                       // 1 << 9
    case viewChannel = 1024                                 // 1 << 10
    case sendMessages = 2048                                // 1 << 11
    case sendTtsMessages = 4096                             // 1 << 12
    case manageMessages = 8192                              // 1 << 13
    case embedLinks = 16384                                 // 1 << 14
    case attachFiles = 32768                                // 1 << 15
    case readMessageHistory = 65536                         // 1 << 16
    case mentionEveryone = 131072                           // 1 << 17
    case useExternalEmojis = 262144                         // 1 << 18
    case viewGuildInsights = 524288                         // 1 << 19
    case connect = 1048576                                  // 1 << 20
    case speak = 2097152                                    // 1 << 21
    case muteMembers = 4194304                              // 1 << 22
    case deafenMembers = 8388608                            // 1 << 23
    case moveMembers = 16777216                             // 1 << 24
    case useVoiceActivityDetection = 33554432               // 1 << 25
    case changeNickname = 67108864                          // 1 << 26
    case manageNicknames = 134217728                        // 1 << 27
    case manageRoles = 268435456                            // 1 << 28
    case manageWebhooks = 536870912                         // 1 << 29
    case manageEmojisAndStickers = 1073741824               // 1 << 30
    case useApplicationCommands = 2147483648                // 1 << 31
    case requestToSpeak = 4294967296                        // 1 << 32
    case manageEvents = 8589934592                          // 1 << 33
    case manageThreads = 17179869184                        // 1 << 34
    case createPublicThreads = 34359738368                  // 1 << 35
    case createPrivateThreads = 68719476736                 // 1 << 36
    case useExternalStickers = 137438953472                 // 1 << 37
    case sendMessagesInThreads = 274877906944               // 1 << 38
    case useActivities = 549755813888                       // 1 << 39
    case moderateMembers = 1099511627776                    // 1 << 40
    case viewCreatorMonetizationAnalytics = 2199023255552   // 1 << 41
    case useSoundboard = 4398046511104                      // 1 << 42
}

/// Represents the permissions for a channel, user, or guild.
public class Permissions {
    
    /// The bitset value for the permissions that are enabled/disabled.
    public let value: Int
    
    /// The permissions that are enabled.
    public internal(set) var enabled = [Permission]()
    
    /// The permissions that are disabled.
    public internal(set) var disabled = [Permission]()
    
    /**
     Returns a permissions object with the default Discord UI permissions:
     
     The following permissions are enabled:
     * `viewChannel`
     * `createInvite`
     * `changeNickname`
     * `sendMessages`
     * `sendMessagesInThreads`
     * `embedLinks`
     * `attachFiles`
     * `addReactions`
     * `useExternalEmojis`
     * `useExternalStickers`
     * `readMessageHistory`
     * `useApplicationCommands`
     * `connect`
     * `speak`
     * `video`
     * `useActivities`
     * `requestToSpeak`
     */
    public static let `default` = Permissions(permsValue: 968585760321)
    
    /// Returns a permissions object with all permissions disabled.
    public static let none = Permissions(permsValue: 0)
    
    init(permsValue: Int) {
        value = permsValue
        for p in Permission.allCases {
            if (permsValue & p.rawValue) == p.rawValue { enabled.append(p) }
            else { disabled.append(p) }
        }
    }
    
    /// Initializes new permissions. Unlike ``init(enable:)``, each permission is either enabled or disabled.
    /// - Parameter permissions: The permissions to enable/disable.
    public convenience init(_ permissions: [Permission: Bool]) {
        var bitValue = 0
        for (perm, isEnabled) in permissions {
            if isEnabled { bitValue |= perm.rawValue }
            else { bitValue &= ~perm.rawValue }
        }
        self.init(permsValue: bitValue)
    }
    
    /// Initializes new permissions. Unlike ``init(_:)``, all permissions are enabled.
    /// - Parameter enable: The permissions to enable.
    public convenience init(enable: Set<Permission>) {
        var bitValue = 0
        for perm in enable {
            bitValue |= perm.rawValue
        }
        self.init(permsValue: bitValue)
    }
}

/// Represents the permission overwrites for a channel.
public struct PermissionOverwrites {
    
    /// The ``Member`` or ``Role`` to set overwrites for.
    public internal(set) var target: Object
    
    /// The permissions that will be enabled.
    public internal(set) var enabled = Set<Permission>()
    
    /// The permissions that will be disabled.
    public internal(set) var disabled = Set<Permission>()
    
    private var allowedBitSet = 0
    private var deniedBitSet = 0
    
    init(guild: Guild, overwriteData: JSON) {
        let snowflake = Conversions.snowflakeToUInt(overwriteData["id"])
        let typeValue = overwriteData["type"] as! Int
        target = typeValue == 0 ? guild.getRole(snowflake)! : guild.getMember(snowflake)!
        
        let allowedValue = Int(overwriteData["allow"] as! String) ?? 0
        let deniedValue = Int(overwriteData["deny"] as! String) ?? 0
        let permResults = PermissionOverwrites.decodePermissionsOverwritesPayload(allowedValue: allowedValue, deniedValue: deniedValue)
        
        enabled = permResults.allowed
        disabled = permResults.denied
    }
    
    /// Set permissions to be enabled or disabled.
    /// - Parameters:
    ///   - target: The target to set overwrites for. Must be a ``Member`` or ``Role`` object.
    ///   - enable: The permissions that will be enabled.
    ///   - disable: The permissions that will be disabled.
    /// - Note: This initializer is failable and will fail if parameter `for` is not a ``Member`` or ``Role`` object.
    public init?(for target: Object, enable: Set<Permission>, disable: Set<Permission>) {
        if target is Member == false && target is Role == false { return nil }
        
        self.target = target
        enabled = enable
        disabled = disable
        
        for perm in enable { allowedBitSet |= perm.rawValue }
        for perm in disable { deniedBitSet |= perm.rawValue }
    }
    
    func convert() -> JSON {
        return [
            "id": target.id,
            "type": target is Member ? 1 : 0,
            "allow": String(allowedBitSet),
            "deny": String(deniedBitSet)
        ]
    }

    private static func decodePermissionsOverwritesPayload(allowedValue: Int, deniedValue: Int) -> (allowed: Set<Permission>, denied: Set<Permission>) {
        var permsAllowed = Set<Permission>()
        var permsDenied = Set<Permission>()
        
        // Admin perms overrides all perms
        if (allowedValue & Permission.administrator.rawValue) == Permission.administrator.rawValue {
            return (Set<Permission>().union(Permission.allCases), [])
        } else {
            for perm in Permission.allCases {
                if (allowedValue & perm.rawValue) == perm.rawValue {
                    permsAllowed.update(with: perm)
                }
                if (deniedValue & perm.rawValue) == perm.rawValue {
                    permsDenied.update(with: perm)
                }
            }
            return (permsAllowed, permsDenied)
        }
    }
}

extension PermissionOverwrites {
    
    /// Represents the permission overwrite type.
    public enum OverwriteType : Int {
        case role
        case user
    }
}
