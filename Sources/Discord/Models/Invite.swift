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

/// Represents the partial invite information received when requesting an invite.
public class PartialInvite {
    
    /// The invite code.
    public let code: String
    
    /// The guild this invite is for.
    public private(set) var guild: PartialInviteGuild?
    
    /// The channel this invite is for.
    public private(set) var channel: PartialInviteChannel?
    
    /// The user who created the invite.
    public private(set) var inviter: User?

    /// The type of target for a voice channel invite.
    public private(set) var targetType: Invite.Target?

    /// The user whose stream to display for a voice channel stream invite.
    public private(set) var targetUser: User?
    
    /// The expiration date of the invite.
    public private(set) var expiresAt: Date?

    /// Approximate count of online members. This will always be `nil` unless called via ``Bot/requestInvite(code:)``.
    public let approximatePresenceCount: Int?

    /// Approximate count of total members. This will always be `nil` unless called via ``Bot/requestInvite(code:)``.
    public let approximateMemberCount: Int?
    
    // ------------------------------ API Separated -----------------------------------
    
    /// The invite URL for the invite. (*https://discord.gg/exAmpLE*)
    public let url: String
    
    // --------------------------------------------------------------------------------

    init(partialInviteData: JSON) {
        code = partialInviteData["code"] as! String

        if let partialGuildObj = partialInviteData["guild"] as? JSON {
            guild = PartialInviteGuild(partialGuildData: partialGuildObj)
        }
        
        if let partialChannelObj = partialInviteData["channel"] as? JSON {
            channel = PartialInviteChannel(partialInviteChannelData: partialChannelObj)
        }
        
        if let inviterObj = partialInviteData["inviter"] as? JSON {
            inviter = User(userData: inviterObj)
        }

        if let targetTypeValue = partialInviteData["target_type"] as? Int {
            targetType = Invite.Target(rawValue: targetTypeValue)
        }

        if let targetUserObj = partialInviteData["target_user"] as? JSON {
            targetUser = User(userData: targetUserObj)
        }

        if let expirationStr = partialInviteData["expires_at"] as? String {
            expiresAt = Conversions.stringDateToDate(iso8601: expirationStr)
        }

        approximatePresenceCount = partialInviteData["approximate_presence_count"] as? Int
        approximateMemberCount = partialInviteData["approximate_member_count"] as? Int
        url =  "https://discord.gg/\(code)"
    }
}

/// Represents the partial guild information received when requesting an invite.
public struct PartialInviteGuild : Object {

    /// Guild ID.
    public let id: Snowflake
    
    /// Guild name.
    public let name: String
    
    /// Guild splash.
    public private(set) var splash: Asset?

    /// The guild banner.
    public private(set) var banner: Asset?

    /// The description of a guild.
    public let description: String?

    /// Guild avatar.
    public private(set) var icon: Asset?
    
    /// Enabled guild features.
    public private(set) var features = [Guild.Feature]()

    /// Verification level required for the guild.
    public let verificationLevel: Guild.VerificationLevel
    
    /// The vanity URL code for the guild.
    public let vanityUrlCode: String?
    
    /// The number of boosts this guild currently has.
    public let premiumSubscriptionCount: Int?
    
    /// Guild NSFW level.
    public let nsfwLevel: Guild.NSFWLevel

    /// The welcome screen of a Community guild.
    public private(set) var welcomeScreen: Guild.WelcomeScreen?

    init(partialGuildData: JSON) {
        id = Conversions.snowflakeToUInt(partialGuildData["id"])
        name = partialGuildData["name"] as! String
        
        if let splashHash = partialGuildData["splash"] as? String {
            splash = Asset(hash: splashHash, fullURL: "/splash/\(id)/\(Asset.imageType(hash: splashHash))")
        }
        
        if let bannerHash = partialGuildData["banner"] as? String {
            banner = Asset(hash: bannerHash, fullURL: "/banners/\(id)/\(Asset.imageType(hash: bannerHash))")
        }
        
        description = partialGuildData["description"] as? String
        
        if let iconHash = partialGuildData["icon"] as? String {
            icon = Asset(hash: iconHash, fullURL: "/icons/\(id)/\(Asset.imageType(hash: iconHash))")
        }

        features = Guild.Feature.get(partialGuildData["features"] as! [String])
        verificationLevel = Guild.VerificationLevel(rawValue: partialGuildData["verification_level"] as! Int)!
        vanityUrlCode = partialGuildData["vanity_url_code"] as? String
        premiumSubscriptionCount = partialGuildData["premium_subscription_count"] as? Int
        nsfwLevel = Guild.NSFWLevel(rawValue: partialGuildData["nsfw_level"] as! Int)!

        if let welcomeScreenData = partialGuildData["welcome_screen"] as? JSON {
            welcomeScreen = Guild.WelcomeScreen(welcomeScreenData: welcomeScreenData)
        }
    }
}

/// Represents the partial channel information received when requesting an invite.
public struct PartialInviteChannel : Object {
    
    /// The channels ID.
    public let id: Snowflake
    
    /// The channels name.
    public let name: String
    
    /// The channel type.
    public let type: ChannelType

    init(partialInviteChannelData: JSON) {
        id = Conversions.snowflakeToUInt(partialInviteChannelData["id"])
        name = partialInviteChannelData["name"] as! String
        type = ChannelType(rawValue: partialInviteChannelData["type"] as! Int)!
    }
}

/// Represents a Discord invite.
public class Invite : PartialInvite {

    /// Number of times this invite has been used.
    public let uses: Int

    /// Max number of times this invite can be used.
    public let maxUses: Int

    /// Duration (in seconds) after which the invite expires.
    public let maxAge: Int

    /// Whether this invite only grants temporary membership.
    public let isTemporary: Bool

    /// When this invite was created.
    public let createdAt: Date
    
    /// The scheduled event related to the invite.
    public private(set) var guildScheduledEvent: Guild.ScheduledEvent?

    /// Your bot instance.
    public weak private(set) var bot: Bot?

    // ------------------------------ API Separated -----------------------------------
    
    /// When creating an invite, this value represents when the invite expires.
    public static let infinite = 0
    
    /// When creating an invite, this value represents when the invite expires.
    public static let twentyFourHours = 86400
    
    /// When creating an invite, this value represents when the invite expires.
    public static let threeDays = 259200
    
    /// When creating an invite, this value represents when the invite expires.
    public static let sevenDays = 604800

    // --------------------------------------------------------------------------------

    init(bot: Bot, inviteData: JSON) {
        self.bot = bot
        
        // Invite metadata
        uses = inviteData["uses"] as! Int
        maxAge = inviteData["max_age"] as! Int
        maxUses = inviteData["max_uses"] as! Int
        isTemporary = inviteData["temporary"] as! Bool
        createdAt = Conversions.stringDateToDate(iso8601: inviteData["created_at"] as! String)!
        
        if let scheduledEventObj = inviteData["guild_scheduled_event"] as? JSON {
            guildScheduledEvent = .init(bot: bot, eventData: scheduledEventObj)
        }
        
        super.init(partialInviteData: inviteData)
    }
    
    /// Delete the guild invite.
    /// - Parameter reason: The reason for deleting the invite. This shows up in the guilds audit log.
    public func delete(reason: String? = nil) async throws {
        try await bot!.http.deleteInvite(code: code, reason: reason)
    }
}

extension Invite {

    /// Represents the type of target for a voice channel invite.
    public enum Target : Int {
        case stream = 1
        case embeddedApplication
    }
}
