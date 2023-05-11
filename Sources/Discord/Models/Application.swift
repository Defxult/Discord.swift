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

/// Represents the application information for the bot.
public struct Application : Object {
    
    /// The ID of the app.
    public let id: Snowflake
    
    /// The name of the app.
    public let name: String
    
    /// The app's avatar.
    public private(set) var icon: Asset?
    
    /// The description of the app.
    public private(set) var description: String?
    
    /// An array of rpc origin URLs, if rpc is enabled
    public private(set) var rpcOrigins: [String]?
    
    /// When `false`, only the app owner can join the app's bot to guilds.
    public let botPublic: Bool
    
    /// When `true`, the app's bot will only join upon completion of the full oauth2 code grant flow.
    public let botRequireCodeGrant: Bool
    
    /// The URL of the app's terms of service
    public private(set) var termsOfServiceUrl: String?
    
    /// The URL of the app's privacy policy.
    public private(set) var privacyPolicyUrl: String?
    
    /// The ID of the application owner.
    public private(set) var ownerId: Snowflake?
    
    /// The hex encoded key for verification in interactions and the GameSDK's [GetTicket](https://discord.com/developers/docs/game-sdk/applications#getticket).
    public private(set) var verifyKey: String
    
    /// If the application belongs to a team, this will be contain an array of the members of that team.
    public private(set) var team: Team?
    
    /// If this application is a game sold on Discord, this field will be the guild to which it has been linked.
    public private(set) var guildId: Snowflake?
    
    /// If this application is a game sold on Discord, this field will be the ID of the "Game SKU" that is created, if it exists.
    public private(set) var primarySkuId: Snowflake?
    
    /// If this application is a game sold on Discord, this field will be the URL slug that links to the store page.
    public private(set) var slug: String?
    
    /// The application's default rich presence invite cover image.
    public private(set) var coverImage: Asset?
    
    /// The application's public flags.
    public private(set) var flags: [ApplicationFlag]?

    /// Up to 5 tags describing the content and functionality of the application.
    public private(set) var tags: [String]?

    /// Settings for the application's default in-app authorization link, if enabled.
    public private(set) var installParams: InstallParams?

    /// The application's default custom authorization link, if enabled.
    public private(set) var customInstallUrl: String?

    init(appData: JSON) {
        id = Conversions.snowflakeToUInt(appData["id"])
        name = appData["name"] as! String
        
        if let iconHash = appData["icon"] as? String {
            icon = Asset(hash: iconHash, fullURL: "/app-icons/\(id)/\(Asset.determineImageTypeURL(hash: iconHash))")
        }

        description = appData["description"] as? String
        rpcOrigins = appData["rpc_origins"] as? [String]
        botPublic = appData["bot_public"] as! Bool
        botRequireCodeGrant = appData["bot_require_code_grant"] as! Bool
        termsOfServiceUrl = appData["terms_of_service_url"] as? String
        privacyPolicyUrl = appData["privacy_policy_url"] as? String
        
        if let ownerObj = appData["owner"] as? JSON {
            ownerId = Conversions.snowflakeToUInt(ownerObj["id"])
        }
        
        verifyKey = appData["verify_key"] as! String

        if let teamObj = appData["team"] as? JSON {
            team = Team(teamData: teamObj)
        }

        guildId = Conversions.snowflakeToOptionalUInt(appData["guild_id"])
        primarySkuId = Conversions.snowflakeToOptionalUInt(appData["primary_sku_id"])
        slug = appData["slug"] as? String

        if let coverHash = appData["cover_image"] as? String {
            coverImage = Asset(hash: coverHash, fullURL: "/app-icons/\(id)/\(Asset.determineImageTypeURL(hash: coverHash))")
        }

        if let flagsValue = appData["flags"] as? Int {
            flags = ApplicationFlag.getApplicationFlags(appFlagValue: flagsValue)
        }

        if let tagValues = appData["tags"] as? [String] {
            tags = tagValues
        }

        if let appInstallsObj = appData["install_params"] as? JSON {
            installParams = InstallParams(installParamsData: appInstallsObj)
        }

        if let installUrl = appData["custom_install_url"] as? String {
            customInstallUrl = installUrl
        }
    }
}

extension Application {

    public enum ApplicationFlag : Int, CaseIterable {
        
        /// Intent required for bots in **100 or more guilds** to receive presence update events.
        case gatewayPresence = 4096
        
        /// Intent required for bots in under 100 guilds to receive presence update events, found in Bot Settings.
        case gatewayPresenceLimited = 8192
        
        /// Intent required for bots in **100 or more guilds** to receive member-related events like `DiscordEvent.guildMemberJoin`.
        case gatewayGuildMembers = 16384
        
        /// Intent required for bots in under 100 guilds to receive member-related events like `DiscordEvent.guildMemberJoin`, found in Bot Settings.
        case gatewayGuildMembersLimited = 32768
        
        /// Indicates unusual growth of an app that prevents verification.
        case verificationPendingGuildLimit = 65536
        
        /// Indicates if an app is embedded within the Discord client.
        case embedded = 131072
        
        /// Intent required for bots in **100 or more guilds** to receive [message content](https://support-dev.discord.com/hc/en-us/articles/4404772028055).
        case gatewayMessageContent = 262144
        
        /// Intent required for bots in under 100 guilds to receive [message content](https://support-dev.discord.com/hc/en-us/articles/4404772028055), found in Bot Settings.
        case gatewayMessageContentLimited = 524288

        static func getApplicationFlags(appFlagValue: Int) -> [ApplicationFlag] {
            var flags = [ApplicationFlag]()
            for flag in ApplicationFlag.allCases {
                if (appFlagValue & flag.rawValue) == flag.rawValue {
                    flags.append(flag)
                }
            }
            return flags
        }
    }

    /// Represents a Discord Team.
    public struct Team {
        
        /// Represents a member on the team.
        public struct Member {

            /// The user's membership state on the team.
            public let membershipState: MembershipState
            
            /// The ID of the parent team of which they are a member.
            public let teamId: Snowflake
            
            /// The user information.
            public let userId: Snowflake
            
            /// The user's username,.
            public let userName: String
            
            /// The user's 4-digit discord-tag.
            public let discriminator: String
            
            /// The user's avatar.
            public private(set) var avatar: Asset?

            init(teamMemberData: JSON) {
                membershipState = MembershipState(rawValue: teamMemberData["membership_state"] as! Int)!
                teamId = Conversions.snowflakeToUInt(teamMemberData["team_id"])
                
                let userObj = teamMemberData["user"] as! JSON
                userId = Conversions.snowflakeToUInt(userObj["id"])
                userName = userObj["username"] as! String
                discriminator = userObj["discriminator"] as! String
                if let avatarHash = userObj["avatar"] as? String {
                    avatar = Asset(hash: avatarHash, fullURL: "/avatars/\(userId)/\(Asset.determineImageTypeURL(hash: avatarHash))")
                }
            }
        }

        /// The teams profile image.
        public private(set) var icon: Asset?
        
        /// The unique ID of the team.
        public let id: Snowflake
        
        /// The members of the team.
        public private(set) var members = [Team.Member]()

        /// The name of the team.
        public let name: String

        /// The user ID of the current team owner.
        public let ownerUserId: Snowflake

        init(teamData: JSON) {
            id = Conversions.snowflakeToUInt(teamData["id"])

            let iconHash = teamData["icon"] as? String
            icon = iconHash != nil ? Asset(hash: iconHash!, fullURL: "/team-icons/\(id)/\(Asset.determineImageTypeURL(hash: iconHash!))") : nil

            let membersData = teamData["members"] as! [JSON]
            for teamMemberObj in membersData {
                members.append(Team.Member(teamMemberData: teamMemberObj))
            }

            name = teamData["name"] as! String
            ownerUserId = Conversions.snowflakeToUInt(teamData["owner_user_id"])
        }
    }

    public enum MembershipState : Int {
        case invited = 1
        case accepted
    }

    /// Represents the settings for the application's default in-app authorization link, if enabled.
    public struct InstallParams {

        /// The OAuth2 scopes to add the application to the server with.
        public let scopes: [String]

        /// The permissions to request for the bot role.
        public let permissions: Permissions

        init(installParamsData: JSON) {
            scopes = installParamsData["scopes"] as! [String]
            permissions = Permissions(permsValue: Int(installParamsData["permissions"] as! String)!)
        }
    }
}
