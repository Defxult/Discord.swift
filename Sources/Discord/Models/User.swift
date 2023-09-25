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

/// Represents a Discord user.
public class User : Object, Updateable, Hashable {
    
    /// The user's ID.
    public let id: Snowflake
    
    /// The user's username.
    public private(set) var name: String
    
    /// The user's display name, if it is set. For bots, this is the application name.
    public private(set) var displayName: String?
    
    /// The user's 4-digit discord-tag.
    public private(set) var discriminator: String
    
    /// The URL for the user's default avatar.
    public private(set) var defaultAvatarUrl: String
    
    /// The user's avatar.
    public private(set) var avatar: Asset?
    
    /// Whether the user is a bot.
    public let isBot: Bool
    
    /// Whether the user is an Official Discord System user (part of the urgent message system).
    public let isSystem: Bool
    
    /// The user's banner.
    public private(set) var banner: Asset?
    
    /// The public flags on a user's account.
    public private(set) var flags: [User.Flag]
    
    // ----- Presence related -----
    
    /// The user's status.
    public private(set) var status: User.Status?
    
    /// The user's current activities.
    public private(set) var activities = [User.Activity]()
    
    /// Platform(s) the user is currently on and their status.
    public private(set) var platform: User.Platform?
    
    // ----------------------------
    
    // Hashable
    public static func == (lhs: User, rhs: User) -> Bool { lhs.id == rhs.id }
    public func hash(into hasher: inout Hasher) { hasher.combine(id) }

    // ---------- API Separated ----------
    
    /// Whether the user is actively on mobile.
    public var isOnMobile: Bool {
        if let platform {
            return platform.mobile != nil
        }
        return false
    }

    /// Mention the user.
    public let mention: String
    
    /// The user's name. If their discriminator is still available it will be included.
    public var description: String { User.migrated(discriminator) ? name : name + "#" + discriminator }

    // -----------------------------------

    init(userData: JSON) {
        id = Conversions.snowflakeToUInt(userData["id"])
        name = userData["username"] as! String
        displayName = userData["global_name"] as? String
        discriminator = userData["discriminator"] as! String
        defaultAvatarUrl = HTTPClient.buildEndpoint(.cdn, endpoint: "/embed/avatars/\(Conversions.defaultUserAvatar(discriminator: discriminator, userId: id))")
        
        let avatarHash = userData["avatar"] as? String
        avatar = avatarHash != nil ? Asset(hash: avatarHash!, fullURL: "/avatars/\(id)/\(Asset.imageType(hash: avatarHash!))") : nil

        isBot = userData["bot"] as? Bool == nil ? false : true
        isSystem = userData["system"] as? Bool == nil ? false : true
        
        let bannerHash = userData["banner"] as? String
        banner = bannerHash != nil ? Asset(hash: bannerHash!, fullURL: "/banners/\(id)/\(Asset.imageType(hash: bannerHash!))") : nil
        
        let flagValue = userData["public_flags"] as? Int
        flags = flagValue != nil ? User.Flag.get(flagValue!) : []
        
        // Note: If `Intents.guildPresences` is enabled, properties `.status` and `.activites`
        // are added/updated via `.update()`. See `if fromGateway { }` in `Guild.init()` for reference
        
        mention = Markdown.mentionUser(id: id)
    }
    
    /// Whether the user was mentioned in the message. See ``Member/mentionedIn(_:)`` for the ``Member`` variant.
    /// - Parameter message: The message to check if the user was mentioned.
    public func mentionedIn(_ message: Message) -> Bool {
        return message.mentionedUsers.contains(self)
    }
    
    /// Updates the properties of the user when received via `GuildEvent.userUpdate` and `GuildEvent.presenceUpdate`.
    func update(_ data: JSON) {
        for (k, v) in data {
            switch k {
            case "name":
                name = v as! String
            case "discriminator":
                discriminator = v as! String
            case "avatar":
                if let avatarHash = v as? String {
                    avatar = Asset(hash: avatarHash, fullURL: "/avatars/\(id)/\(Asset.imageType(hash: avatarHash))")
                }
            case "banner":
                if let bannerHash = v as? String {
                    banner = Asset(hash: bannerHash, fullURL: "/banners/\(id)/\(Asset.imageType(hash: bannerHash))")
                }
            case "public_flags":
                if let flagValue = v as? Int {
                    flags = User.Flag.get(flagValue)
                }
            case "global_name":
                displayName = v as? String
            
            // ----- Presence related -----
                
            case "status":
                status = Status(rawValue: v as! String)
                
            case "activities":
                activities.removeAll()
                for actObj in v as! [JSON] {
                    activities.append(Activity(activityData: actObj))
                }
                
            case "client_status":
                platform = Platform(clientStatusData: v as! JSON)
                
            // ----------------------------
            default:
                break
            }
        }
    }
    
    /// Whether the user has migrated to the new naming system.
    static func migrated(_ discriminator: String) -> Bool {
        discriminator == "0"
    }
}

extension User {
    
    /// Represents the current status of a user.
    public enum Status : String {
        case idle = "idle"
        case dnd = "dnd"
        case online = "online"
        case offline = "offline"
    }
    
    /// Represents which platform the user is currently on and their status.
    public struct Platform {
        
        /// Active desktop session (Windows, Linux, Mac).
        public private(set) var desktop: Status?
        
        /// Active mobile session (iOS, Android).
        public private(set) var mobile: Status?
        
        /// Active web sesison (browser, bot user).
        public private(set) var web: Status?
        
        init(clientStatusData: JSON) {
            if let d = clientStatusData["desktop"] { desktop = Status(rawValue: d as! String) }
            if let m = clientStatusData["mobile"] { mobile = Status(rawValue: m as! String) }
            if let w = clientStatusData["web"] { web = Status(rawValue: w as! String) }
        }
    }
    
    /// Represents a user's activity.
    public struct Activity {
        
        /// Activity's name.
        public let name: String
        
        /// Activity type.
        public let type: ActivityType
        
        /// Stream URL.
        public let url: String?
        
        /// When the activity was added to the user's session.
        public let createdAt: Date
        
        /// The start and/or end of the game.
        public private(set) var timestamps: ActivityTimestamp?
        
        /// Application ID for the game.
        public let applicationId: Snowflake?
        
        /// What the player is currently doing.
        public let details: String?
        
        /// User's current party status, or text used for a custom status.
        public let state: String?
        
        /// Emoji used for a custom status.
        public private(set) var emoji: PartialEmoji?
        
        /// Information for the current party of the player.
        public private(set) var party: ActivityParty?
        
        /// Images for the presence and their hover texts.
        public private(set) var assets: ActivityAssets?
        
        /// Flags for the activity.
        public let flags: [ActivityFlag]
        
        /// Custom buttons shown in the Rich Presence (max 2).
        public private(set) var buttons: [ActivityButton]?
        
        init(activityData: JSON) {
            name = activityData["name"] as! String
            url = activityData["url"] as? String
            state = activityData["state"] as? String
            if let emojiObj = activityData["emoji"] as? JSON {
                emoji = PartialEmoji(partialEmojiData: emojiObj)
            }
            
            let actType = activityData["type"] as! Int
            switch actType {
            case 0:
                type = .game(name)
            case 1:
                type = .streaming(name, url: url!)
            case 2:
                type = .listening(name)
            case 3:
                type = .watching(name)
            case 4:
                var status = String.empty
                if let e = emoji?.description {
                    status.append(e)
                    status.append(" ")
                }
                status.append(state ?? .empty)
                
                // If the user only has an emoji as their custom status, remove the
                // excess white space from the above `.append()`
                status.trimSuffix(while: \.isWhitespace)
                
                type = .custom(status)
            case 5:
                type = .competing(name)
            default:
                // Default to `.game` so in the future if more are added this can
                // simply be updated to the correct type
                type = .game(name)
            }
            
            createdAt = Date(timeIntervalSince1970: (activityData["created_at"] as! TimeInterval) / 1000)
            
            if let timestampsObj = activityData["timestamps"] as? JSON {
                timestamps = .init(activityTimestampData: timestampsObj)
            }
            
            applicationId = Conversions.snowflakeToOptionalUInt(activityData["application_id"])
            details = activityData["details"] as? String
            
            if let partyObj = activityData["party"] as? JSON {
                party = ActivityParty(activityPartyData: partyObj)
            }
            
            if let assetsObj = activityData["assets"] as? JSON {
                assets = ActivityAssets(activityAssetsData: assetsObj, applicationId: applicationId)
            }
            
            flags = ActivityFlag.get((activityData["flags"] as? Int) ?? 0)
            
            if let buttonsArrayObjs = activityData["buttons"] as? [JSON] {
                buttons = []
                for buttonObj in buttonsArrayObjs {
                    buttons!.append(ActivityButton(activityButtonData: buttonObj))
                }
            }
        }
    }
    
    /// Represents an activity flag.
    public enum ActivityFlag : Int, CaseIterable {
        case instance = 1
        case join = 2
        case spectate = 4
        case joinRequest = 8
        case sync = 16
        case play = 32
        case partyPrivacyFriends = 64
        case partyPrivacyVoiceChannel = 128
        case embedded = 256
        
        static func get(_ actFlagValue: Int) -> [ActivityFlag] {
            var flags = [ActivityFlag]()
            for flag in ActivityFlag.allCases {
                if (actFlagValue & flag.rawValue) == flag.rawValue {
                    flags.append(flag)
                }
            }
            return flags
        }
    }
    
    /// Represents an activity button.
    public struct ActivityButton {
        
        /// Text shown on the button (1-32 characters).
        public let label: String
        
        /// URL opened when clicking the button (1-512 characters).
        public let url: String
        
        init(activityButtonData: JSON) {
            label = activityButtonData["label"] as! String
            url = activityButtonData["url"] as! String
        }
    }
    
    /// Represents an activity asset.
    public struct ActivityAssets {
        
        /// The assets image in a large format.
        public private(set) var largeImage: (id: String, url: String)?
        
        /// The assets image in a small format.
        public private(set) var smallImage: (id: String, url: String)?
        
        /// Text displayed when hovering over the large image of the activity.
        public let largeText: String?
        
        /// Text displayed when hovering over the small image of the activity.
        public let smallText: String?
        
        init(activityAssetsData: JSON, applicationId: Snowflake?) {
            if let largeImgId = Conversions.snowflakeToOptionalUInt(activityAssetsData["large_image"]), let applicationId {
                largeImage = (String(largeImgId), "\(APIRoute.cdn.rawValue)" + "app-assets/\(applicationId)/\(largeImgId).png)")
            }
            if let smallImgId = Conversions.snowflakeToOptionalUInt(activityAssetsData["small_image"]), let applicationId {
                smallImage = (String(smallImgId), "\(APIRoute.cdn.rawValue)" + "app-assets/\(applicationId)/\(smallImgId).png)")
            }
            largeText = activityAssetsData["large_text"] as? String
            smallText = activityAssetsData["small_text"] as? String
        }
    }
    
    /// Represents an activity party.
    public struct ActivityParty {
        
        /// ID of the party.
        public let id: String?
        
        /// The party's current and maximum size.
        public private(set) var size: (current: Int, max: Int)?
        
        init(activityPartyData: JSON) {
            id = activityPartyData["id"] as? String
            if let sizeData = activityPartyData["size"] as? [Int] { size = (sizeData[0], sizeData[1]) }
        }
    }
    
    /// Represents a user's activity type.
    public enum ActivityType {
        
        /// "Playing {name}"
        case game(String)
        
        /// "Streaming {name}". This supports Twitch and YouTube. Only https://twitch.tv/ and  https://youtube.com/ URLs will work.
        case streaming(String, url: String)
        
        /// "Listening to {name}"
        case listening(String)
        
        /// "Watching {name}".
        case watching(String)
        
        /// "🙂 I am cool"
        case custom(String)
        
        /// "Competing in {name}"
        case competing(String)
        
        func convert() -> [JSON] {
            var payload: JSON
            switch self {
            case .game(let name):
                payload = ["name": name, "type": 0]
            case .streaming(let name, url: let url):
                payload = ["name": name, "type": 1, "url": url]
            case .listening(let name):
                payload = ["name": name, "type": 2]
            case .watching(let name):
                payload = ["name": name, "type": 3]
            case .custom(let name):
                payload = ["name": name, "type": 4]
            case .competing(let name):
                payload = ["name": name, "type": 5]
            }
            return [payload]
        }
    }
    
    /// Represents the start and/or end of the game.
    public struct ActivityTimestamp {
        
        /// When the activity started.
        public private(set) var start: Date?
        
        /// When the activity ends.
        public private(set) var end: Date?
        
        init(activityTimestampData: JSON) {
            if let startUnix = activityTimestampData["start"] as? TimeInterval { start = Date(timeIntervalSince1970: startUnix / 1000) }
            if let endUnix = activityTimestampData["end"] as? TimeInterval { end = Date(timeIntervalSince1970: endUnix / 1000) }
        }
    }

    /// Represents the public flags on a user's account.
    public enum Flag : Int, CaseIterable {
        
        /// Discord Employee.
        case staff = 1
        
        /// Partnered Server Owner.
        case partner = 2
        
        /// HypeSquad Events Member.
        case hypeSquad = 4
        
        /// Bug Hunter Level 1.
        case bugHunterLevel1 = 8
        
        /// House Bravery Member.
        case hypeSquadOnlineHouse1 = 64
        
        /// House Brilliance Member.
        case hypeSquadOnlineHouse2 = 128
        
        /// House Balance Member.
        case hypeSquadOnlineHouse3 = 256
        
        /// Early Nitro Supporter.
        case premiumEarlySupporter = 512
        
        /// User is a [team](https://discord.com/developers/docs/topics/teams).
        case teamPseudoUser = 1024
        
        /// Bug Hunter Level 2.
        case bugHunterLevel2 = 16384
        
        /// Verified Bot.
        case verifiedBot = 65536
        
        /// Early Verified Bot Developer.
        case verifiedDeveloper = 131072
        
        /// Discord Certified Moderator.
        case certifiedModerator = 262144
        
        /// Bot uses only [HTTP interactions](https://discord.com/developers/docs/interactions/receiving-and-responding#receiving-an-interaction) and is shown in the online member list.
        case botHttpInteractions = 524288
        
        /// User is an active developer.
        case activeDeveloper = 4194304

        static func get(_ userFlagValue: Int) -> [User.Flag] {
            var flags = [User.Flag]()
            for flag in User.Flag.allCases {
                if (userFlagValue & flag.rawValue) == flag.rawValue {
                    flags.append(flag)
                }
            }
            return flags
        }
    }
}

/// Represents the bots user information.
public class ClientUser : User {
    
    /// Whether the user has two factor enabled on their account.
    public let mfaEnabled: Bool
    
    /// The user's chosen language option.
    public let locale: Locale?
    
    /// Whether the email on this account has been verified.
    public let verified: Bool
    
    /// Your bot instance.
    public weak private(set) var bot: Bot?

    init(bot: Bot, clientUserData: JSON) {
        self.bot = bot
        mfaEnabled = clientUserData["mfa_enabled"] as! Bool
        
        let loc = clientUserData["locale"] as? String
        locale = loc == nil ? nil : Locale(rawValue: loc!)
        
        verified = clientUserData["verified"] as! Bool
        super.init(userData: clientUserData)
    }
}

/// Represents a Discord locale.
public enum Locale : String, CaseIterable {
    
    /// Native name: Bahasa Indonesia
    case indonesian = "id"
    
    /// Native name: Dansk
    case danish = "da"
    
    /// Native name: Deutsch
    case german = "de"
    
    /// Native name: English, UK
    case englishUK = "en-GB"
    
    /// Native name: English, US
    case englishUS = "en-US"
    
    /// Native name: Español
    case spanish = "es-ES"
    
    /// Native name: Français
    case french = "fr"
    
    /// Native name: Hrvatski
    case croatian = "hr"
    
    /// Native name: Italiano
    case italian = "it"
    
    /// Native name: Lietuviškai
    case lithuanian = "lt"
    
    /// Native name: Magyar
    case hungarian = "hu"
    
    /// Native name: Nederlands
    case dutch = "nl"
    
    /// Native name: Norsk
    case norwegian = "no"
    
    /// Native name: Polski
    case polish = "pl"
    
    /// Native name: Português do Brasil
    case portuguese = "pt-BR"
    
    /// Native name: Română
    case romanian = "ro"
    
    /// Native name: Suomi
    case finnish = "fi"
    
    /// Native name: Svenska
    case swedish = "sv-SE"
    
    /// Native name: Tiếng Việt
    case vietnamese = "vi"
    
    /// Native name: Türkçe
    case turkish = "tr"
    
    /// Native name: Čeština
    case czech = "cs"
    
    /// Native name: Ελληνικά
    case greek = "el"
    
    /// Native name: български
    case bulgarian = "bg"
    
    /// Native name: Pусский
    case russian = "ru"
    
    /// Native name: Українська
    case ukrainian = "uk"
    
    /// Native name: हिन्दी
    case hindi = "hi"
    
    /// Native name: ไทย
    case thai = "th"
    
    /// Native name: 中文
    case chineseChina = "zh-CN"
    
    /// Native name: 日本語
    case japanese = "ja"
    
    /// Native name: 繁體中文
    case chineseTaiwan = "zh-TW"
    
    /// Native name: 한국어
    case korean = "ko"
}
