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
    
    /// An array of RPC origin URLs, if RPC is enabled
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
    public private(set) var flags: [Flag]?

    /// Up to 5 tags describing the content and functionality of the application.
    public private(set) var tags: [String]?

    /// Settings for the application's default in-app authorization link, if enabled.
    public private(set) var installParams: InstallParams?

    /// The application's default custom authorization link, if enabled.
    public private(set) var customInstallUrl: String?
    
    /// The application's role connection verification entry point, which when configured will render
    /// the app as a verification method in the guild role verification configuration.
    public private(set) var roleConnectionsVerificationUrl: String?

    init(appData: JSON) {
        id = Conversions.snowflakeToUInt(appData["id"])
        name = appData["name"] as! String
        
        if let iconHash = appData["icon"] as? String {
            icon = Asset(hash: iconHash, fullURL: "/app-icons/\(id)/\(Asset.imageType(hash: iconHash))")
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
            coverImage = Asset(hash: coverHash, fullURL: "/app-icons/\(id)/\(Asset.imageType(hash: coverHash))")
        }

        if let flagsValue = appData["flags"] as? Int {
            flags = Application.Flag.get(flagsValue)
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
        
        if let rcvu = appData["role_connections_verification_url"] as? String {
            roleConnectionsVerificationUrl = rcvu
        }
    }
}

extension Application {

    /// Represents the bots flags.
    public enum Flag : Int, CaseIterable {
        
        /// Indicates if an app uses the Auto Moderation API.
        case applicationAutoModerationRuleCreateBadge = 64
        
        /// Intent required for bots in **100 or more guilds** to receive presence update events.
        case gatewayPresence = 4096
        
        /// Intent required for bots in under 100 guilds to receive presence update events, found in Bot Settings.
        case gatewayPresenceLimited = 8192
        
        /// Intent required for bots in **100 or more guilds** to receive member-related events like ``GatewayEvent/guildMemberJoin``.
        case gatewayGuildMembers = 16384
        
        /// Intent required for bots in under 100 guilds to receive member-related events like ``GatewayEvent/guildMemberJoin``, found in Bot Settings.
        case gatewayGuildMembersLimited = 32768
        
        /// Indicates unusual growth of an app that prevents verification.
        case verificationPendingGuildLimit = 65536
        
        /// Indicates if an app is embedded within the Discord client.
        case embedded = 131072
        
        /// Intent required for bots in **100 or more guilds** to receive [message content](https://support-dev.discord.com/hc/en-us/articles/4404772028055).
        case gatewayMessageContent = 262144
        
        /// Intent required for bots in under 100 guilds to receive [message content](https://support-dev.discord.com/hc/en-us/articles/4404772028055), found in Bot Settings.
        case gatewayMessageContentLimited = 524288
        
        /// Indicates if an app has registered global application commands.
        case applicationCommandBadge = 8388608

        static func get(_ appFlagValue: Int) -> [Application.Flag] {
            var flags = [Application.Flag]()
            for flag in Application.Flag.allCases {
                if (appFlagValue & flag.rawValue) == flag.rawValue {
                    flags.append(flag)
                }
            }
            return flags
        }
    }

    /// Represents a Discord Team.
    public struct Team {

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
            icon = iconHash != nil ? Asset(hash: iconHash!, fullURL: "/team-icons/\(id)/\(Asset.imageType(hash: iconHash!))") : nil

            let membersData = teamData["members"] as! [JSON]
            for teamMemberObj in membersData {
                members.append(Team.Member(teamMemberData: teamMemberObj))
            }

            name = teamData["name"] as! String
            ownerUserId = Conversions.snowflakeToUInt(teamData["owner_user_id"])
        }
        
        /// Represents a member on the team.
        public struct Member {
            
            /// Role of the team member.
            public let role: MemberRole?

            /// The user's membership state on the team.
            public let membershipState: MembershipState
            
            /// The ID of the parent team of which they are a member.
            public let teamId: Snowflake
            
            /// The user ID.
            public let userId: Snowflake
            
            /// The user's username.
            public let userName: String
            
            /// The user's 4-digit discord-tag.
            public let discriminator: String
            
            /// The user's avatar.
            public private(set) var avatar: Asset?

            init(teamMemberData: JSON) {
                role = MemberRole(rawValue: teamMemberData["role"] as! String)
                membershipState = MembershipState(rawValue: teamMemberData["membership_state"] as! Int)!
                teamId = Conversions.snowflakeToUInt(teamMemberData["team_id"])
                
                let userObj = teamMemberData["user"] as! JSON
                userId = Conversions.snowflakeToUInt(userObj["id"])
                userName = userObj["username"] as! String
                discriminator = userObj["discriminator"] as! String
                if let avatarHash = userObj["avatar"] as? String {
                    avatar = Asset(hash: avatarHash, fullURL: "/avatars/\(userId)/\(Asset.imageType(hash: avatarHash))")
                }
            }
        }
        
        /// Represents the role types that a team ``Application/Team-swift.struct/Member`` can be assigned.
        public enum MemberRole : String {
            
            /// Owners are the most permissiable role, and can take destructive, irreversible actions like deleting team-owned apps or the team itself.
            /// Teams are limited to 1 owner.
            case owner = "owner"
            
            /// Admins have similar access as owners, except they cannot take destructive actions on the team or team-owned apps.
            case admin = "admin"
            
            /// Developers can access information about team-owned apps, like the client secret or public key. They can also take limited actions on
            /// team-owned apps, like configuring interaction endpoints or resetting the bot token. Members with the Developer role *cannot* manage the team
            /// or its members, or take destructive actions on team-owned apps.
            case developer = "developer"
            
            /// Read-only members can access information about a team and any team-owned apps. Some examples include getting the IDs of applications and exporting payout records.
            case readOnly = "read_only"
        }
    }
    
    /// Represents a members state.
    public enum MembershipState : Int {
        case invited = 1
        case accepted
    }

    /// Represents the settings for the application's default in-app authorization link, if enabled.
    public struct InstallParams {

        /// The OAuth2 scopes to add the application to the server with.
        public let scopes: Set<OAuth2Scopes>

        /// The permissions to request for the bot role.
        public let permissions: Permissions

        init(installParamsData: JSON) {
            scopes = OAuth2Scopes.get(installParamsData["scopes"] as! [String])
            permissions = Permissions(permsValue: Int(installParamsData["permissions"] as! String)!)
        }
    }
}

/// Represents the OAuth2 scopes that Discord supports. Some scopes require approval from Discord to use. Requesting them from a user
/// without approval from Discord may cause errors or undocumented behavior in the OAuth2 flow.
public enum OAuth2Scopes : String, CaseIterable {
    
    /// Allows your app to fetch data from a user's "Now Playing/Recently Played" list — not currently available for apps
    case activitiesRead = "activities.read"
    
    /// Allows your app to update a user's activity - requires Discord approval (NOT REQUIRED FOR GAMESDK ACTIVITY MANAGER)
    case activitiesWrite = "activities.write"
    
    /// Allows your app to read build data for a user's applications.
    case applicationsBuildsRead = "applications.builds.read"
    
    /// Allows your app to upload/update builds for a user's applications - requires Discord approval.
    case applicationsBuildsUpload = "applications.builds.upload"
    
    /// Allows your app to use commands in a guild.
    case applicationsCommands = "applications.commands"
    
    /// Allows your app to update its commands using a Bearer token - client credentials grant only.
    case applicationsCommandsUpdate = "applications.commands.update"
    
    /// Allows your app to update permissions for its commands in a guild a user has permissions to.
    case applicationsCommandsPermissionsUpdate = "applications.commands.permissions.update"
    
    /// Allows your app to read entitlements for a user's applications.
    case applicationsEntitlements = "applications.entitlements"
    
    /// Allows your app to read and update store data (SKUs, store listings, achievements, etc.) for a user's applications.
    case applicationsStoreUpdate = "applications.store.update"
    
    /// For oauth2 bots, this puts the bot in the user's selected guild by default.
    case bot = "bot"
    
    /// Allows /users/@me/connections to return linked third-party accounts.
    case connections = "connections"
    
    /// Allows your app to see information about the user's DMs and group DMs - requires Discord approval.
    case dmChannelsRead = "dm_channels.read"
    
    /// Enables /users/@me to return an email.
    case email = "email"
    
    /// Allows your app to join users to a group dm.
    case gdmJoin = "gdm.join"
    
    /// Allows /users/@me/guilds to return basic information about all of a user's guilds.
    case guilds = "guilds"
    
    /// Allows /guilds/{guild.id}/members/{user.id} to be used for joining users to a guild.
    case guildsJoin = "guilds.join"
    
    /// Allows /users/@me/guilds/{guild.id}/member to return a user's member information in a guild.
    case guildsMembersRead = "guilds.members.read"
    
    /// Allows /users/@me without email.
    case identify = "identify"
    
    /// For local RPC server API access, this allows you to read messages from all client channels (otherwise restricted to channels/guilds your app creates).
    case messagesRead = "messages.read"
    
    /// Allows your app to know a user's friends and implicit relationships - requires Discord approval.
    case relationshipRead = "relationships.read"
    
    /// Allows your app to update a user's connection and metadata for the app.
    case roleConnectionsWrite = "role_connections.write"
    
    /// For local RPC server access, this allows you to control a user's local Discord client - requires Discord approval.
    case rpc = "rpc"
    
    /// For local RPC server access, this allows you to update a user's activity - requires Discord approval.
    case rpcActivitiesWrite = "rpc.activities.write"
    
    /// For local RPC server access, this allows you to receive notifications pushed out to the user - requires Discord approval.
    case rpcNotificationsRead = "rpc.notifications.read"
    
    /// For local RPC server access, this allows you to read a user's voice settings and listen for voice events - requires Discord approval.
    case rpcVoiceRead = "rpc.voice.read"
    
    /// For local RPC server access, this allows you to update a user's voice settings - requires Discord approval.
    case rpcVoiceWrite = "rpc.voice.write"
    
    /// Allows your app to connect to voice on user's behalf and see all the voice members - requires Discord approval.
    case voice = "voice"
    
    /// This generates a webhook that is returned in the oauth token response for authorization code grants.
    case webhookIncoming = "webhook.incoming"
    
    static func get(_ scopes: [String]) -> Set<OAuth2Scopes> {
        var oAuth2Scopes = Set<OAuth2Scopes>()
        for scope in scopes {
            if let s = OAuth2Scopes(rawValue: scope) {
                oAuth2Scopes.insert(s)
            }
        }
        return oAuth2Scopes
    }
}
