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

/// Represents the content moderation for a guild.
public struct AutoModerationRule : Object {

    /// The ID of this rule.
    public let id: Snowflake
    
    /// The guild which this rule belongs to.
    public let guild: Guild
    
    /// The rule name.
    public let name: String
    
    /// The user which first created this rule.
    public let creatorId: Snowflake
    
    /// The rule event type.
    public let eventType: EventType
    
    /// The rule trigger type.
    public let triggerType: TriggerType
    
    /// Additional data used to determine whether a rule should be triggered.
    public let metadata: Metadata
    
    /// The actions which will execute when the rule is triggered.
    public private(set) var actions = [AutoModerationRule.Action]()
    
    /// Whether the rule is enabled.
    public let enabled: Bool
    
    /// The roles that should not be affected by the rule.
    public private(set) var exemptRoles = [Role]()
    
    /// The channels that should not be affected by the rule.
    public private(set) var exemptChannels = [GuildChannel]()
    
    /// Your bot instance.
    public private(set) weak var bot: Discord?

    init(bot: Discord, autoModData: JSON) {
        self.bot = bot
        id = Conversions.snowflakeToUInt(autoModData["id"])
        
        let guildId = Conversions.snowflakeToUInt(autoModData["guild_id"])
        guild = bot.getGuild(guildId)!

        name = autoModData["name"] as! String
        creatorId = Conversions.snowflakeToUInt(autoModData["creator_id"])
        eventType = .init(rawValue: autoModData["event_type"] as! Int)!
        triggerType = .init(rawValue: autoModData["trigger_type"] as! Int)!
        metadata = .init(metadata: autoModData["trigger_metadata"] as! JSON)
        
        for actionObj in autoModData["actions"] as! [JSON] {
            actions.append(AutoModerationRule.Action(actionData: actionObj))
        }

        enabled = autoModData["enabled"] as! Bool

        for roleId in autoModData["exempt_roles"] as! [String] {
            exemptRoles.append(guild.getRole(Conversions.snowflakeToUInt(roleId))!)
        }
        
        for channelId in autoModData["exempt_channels"] as! [String] {
            exemptChannels.append(guild.getChannel(Conversions.snowflakeToUInt(channelId))!)
        }
    }
    
    /// Delete the auto-moderation rule.
    /// - Parameter reason: The reason for deleting the rule. This shows up in the guilds audit log.
    public func delete(reason: String? = nil) async throws {
        try await bot!.http.deleteAutoModerationRule(guildId: guild.id, ruleId: id, reason: reason)
    }
    
    /// Edit the auto-moderation rule.
    /// - Parameters:
    ///   - edits: The enum containing all values to be updated or removed for the auto-moderation rule.
    ///   - reason: The reason for editing the auto-moderation rule. This shows up in the guilds audit log.
    /// - Returns: The updated rule.
    @discardableResult
    public func edit(_ edits: AutoModerationRule.Edit..., reason: String? = nil) async throws -> AutoModerationRule {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }
        
        var payload: JSON = [:]
        for e in edits {
            switch e {
            case .name(let name):
                payload["name"] = name
            case .eventType(let eventType):
                payload["event_type"] = eventType.rawValue
            case .metadata(let metdata):
                payload["trigger_metadata"] = metdata.convert()
            case .actions(let actions):
                payload["actions"] = actions.map({ $0.convert() })
            case .enabled(let enabled):
                payload["enabled"] = enabled
            case .exemptRoles(let er):
                payload["exempt_roles"] = Role.toSnowflakes(er ?? [])
            case .exemptChannels(let ec):
                payload["exempt_roles"] = ec?.map({ $0.id }) ?? []
            }
        }
        
        return try await bot!.http.modifyAutoModerationRule(guildId: guild.id, ruleId: id, data: payload)
    }
}

extension AutoModerationRule {

    /// Represents the values that should be edited in a ``AutoModerationRule``.
    public enum Edit {
        
        /// The rule name.
        case name(String)
        
        /// The rule trigger type.
        case eventType(EventType)
        
        /// What triggers the rule.
        case metadata(Metadata)
        
        /// The actions which will execute when the rule is triggered.
        case actions([AutoModerationRule.Action])
        
        /// Whether the rule is enabled.
        case enabled(Bool)
        
        /// The roles that should not be affected by the rule. Can be set to `nil` to remove all roles from exemption.
        case exemptRoles([Role]?)
        
        /// The channels that should not be affected by the rule. Can be set to `nil` to remove all channels from exemption.
        case exemptChannels([GuildChannelMessageable]?)
    }

    /// Represents the words/phrases that can trigger an auto moderation rule.
    public struct Triggers {
        
        /// Words/phrases that can trigger the rule. This is simply a shortcut to show all words in properties `startsWith`, `endsWith`, `contains`, and `wholeWord`.
        public var words: [String] { startsWith + endsWith + contains + wholeWord }
        
        /// All `words` sorted into *starts with*.
        public private(set) var startsWith = [String]()
        
        /// All `words` sorted into *ends with*.
        public private(set) var endsWith = [String]()
        
        /// All `words` sorted into *contains*.
        public private(set) var contains = [String]()
        
        /// All `words` sorted into *whole word*.
        public private(set) var wholeWord = [String]()

        /**
         Initializes a trigger based on the keywords that you've set. All keywords are case insensitive. This initializer is failable and will fail if all parameters are `nil`. At least one parameter needs to be set.
         
         The following are some examples of what using each parameter matches against.
         
         - Starts With
             - `Triggers(startsWith: ["cat"])` Matches - **cat**ch, **Cat**apult, **CAt**tLE
             - `Triggers(startsWith: ["tra"])` Matches - **tra**in, **tra**de, **TRA**ditional
             - `Triggers(startsWith: ["the mat"])` Matches - **the mat**rix
         
         - Ends With
            - `Triggers(endsWith: ["cat"])` Matches - wild**cat**, copy**Cat**
            - `Triggers(endsWith: ["tra"])` Matches - ex**tra**, ul**tra**, orches**TRA**
            - `Triggers(endsWith: ["the mat"])` Matches - brea**the mat**

         - Contains
            - `Triggers(contains: ["cat"])` Matches - lo**cat**ion, edu**Cat**ion
            - `Triggers(contains: ["tra"])` Matches - abs**tra**cted, ou**tra**ge
            - `Triggers(contains: ["the mat"])` Matches - brea**the mat**ter
         
         - Whole Word
            - `Triggers(wholeWord: ["cat"])` Matches - **cat**
            - `Triggers(wholeWord: ["train"])` Matches - **train**
            - `Triggers(wholeWord: ["the mat"])` Matches - **the mat**
         
         - Parameters:
            - startsWith: Word must start with the keyword.
            - endsWith: Word must end with the keyword.
            - contains: Keyword can appear anywhere in the content.
            - wholeWord: Keyword is a full word or phrase and must be surrounded by whitespace at the beginning and end.
        */
        public init?(startsWith: [String]? = nil, endsWith: [String]? = nil, contains: [String]? = nil, wholeWord: [String]? = nil) {
            if [startsWith, endsWith, contains, wholeWord].allSatisfy({ $0 == nil }) { return nil }
            else {
                if let startsWith { for word in startsWith { self.startsWith.append("\(word)*") } }
                if let endsWith { for word in endsWith { self.endsWith.append("*\(word)") } }
                if let contains { for word in contains { self.contains.append("*\(word)*") } }
                if let wholeWord { for word in wholeWord { self.wholeWord.append(word) } }
            }
        }
        
        // This is used in the `AutoModerationRule` .init(_:)
        fileprivate init(keywordFilter: [String]) {
            for word in keywordFilter {
                // Contains (this needs to be first)
                if word.hasPrefix("*") && word.hasSuffix("*") { contains.append(word) }
                
                // Starts with
                else if word.hasSuffix("*") { startsWith.append(word) }
                
                // Ends with
                else if word.hasPrefix("*") { endsWith.append(word) }
                
                // Whole word
                else if !(word.hasPrefix("*") && word.hasSuffix("*")) { wholeWord.append(word) }
            }
        }
    }
    
    /// Represents an Auto Moderation trigger type.
    public enum TriggerType : Int {
        
        /// Check if content contains words from a user defined list of keywords (6 max per guild).
        case keyword = 1
        
        /// Check if content represents generic spam (1 max per guild).
        case spam = 3
        
        /// Check if content contains words from internal pre-defined wordsets (1 max per guild).
        case keywordPreset
        
        /// Check if content contains more unique mentions than allowed  (1 max per guild).
        case mentionSpam
    }
    
    /// Represents the additional data used to determine whether a ``AutoModerationRule`` should be triggered. Different fields are relevant based on the value of auto-moderation trigger type.
    public struct Metadata {
        
        /// Substrings which will be searched for in content (maximum of 1000). Only relevant for `TriggerType.keyword`. Each keyword must be 30 characters or less.
        public var keywordFilter: Triggers?
        
        /// Regular expression patterns which will be matched against content (maximum of 10). Only relevant for `TriggerType.keyword`. Each regex pattern must be 260 characters or less.
        public var regexPatterns: [String]?
        
        /// The wordsets defined by Discord which will be searched for in content. Only relevant for `TriggerType.keywordPreset`.
        public var presets: Set<KeywordPresetType>?
        
        /// Substrings which should **not** trigger the rule. Maximum of 100 for `TriggerType.keyword` or 1000 for `TriggerType.keywordPreset`. Each string also has a limit of 60 characters.
        public var allowList: Triggers?
        
        /// Total number of unique role and user mentions allowed per message (maximum of 50). Only relevant for `TriggerType.mentionSpam`.
        public var mentionTotalLimit: Int?
        
        /// Whether to automatically detect mention raids. Only relevant for `TriggerType.mentionSpam`.
        public var mentionRaidProtectionEnabled: Bool?
        
        /// The data that relates to the trigger type. This initializer is failable and will fail if all parameters are there "empty" equivalent.
        /// - Parameters:
        ///   - keywordFilter: Substrings which will be searched for in content (maximum of 1000). Only relevant for `TriggerType.keyword`.
        ///   - regexPatterns: Regular expression patterns which will be matched against content (maximum of 10). Only relevant for `TriggerType.keyword`. Each regex pattern must be 260 characters or less.
        ///   - presets: The wordsets defined by Discord which will be searched for in content. Only relevant for `TriggerType.keywordPreset`.
        ///   - allowList: Substrings which should **not** trigger the rule. Maximum of 100 for `TriggerType.keyword` or 1000 for `TriggerType.keywordPreset`. Each string also has a limit of 60 characters.
        public init?(
            keywordFilter: Triggers? = nil,
            regexPatterns: [String] = [],
            presets: Set<KeywordPresetType> = [],
            allowList: Triggers? = nil
        ) {
            guard !(
                keywordFilter == nil &&
                [regexPatterns.isEmpty, presets.isEmpty].allSatisfy({ $0 == true }) &&
                allowList == nil
            ) else { return nil }
            self.keywordFilter = keywordFilter
            self.regexPatterns = regexPatterns
            self.presets = presets
            self.allowList = allowList
        }
        
        init(metadata: JSON) {
            if let kwdFilter = metadata["keyword_filter"] as? [String] {
                keywordFilter = .init(keywordFilter: kwdFilter)
            }
            if let regex = metadata["regex_patterns"] as? [String] {
                regexPatterns = regex
            }
            if let presetValues = metadata["presets"] as? [Int] {
                presets = KeywordPresetType.getKeywordPresetType(presetValues)
            }
            if let alwdList = metadata["allow_list"] as? [String] {
                allowList = .init(keywordFilter: alwdList)
            }
            if let mtl = metadata["mention_total_limit"] as? Int {
                mentionTotalLimit = mtl
            }
            if let mrpe = metadata["mention_raid_protection_enabled"] as? Bool {
                mentionRaidProtectionEnabled = mrpe
            }
        }
        
        func convert() -> JSON {
            return [
                "keyword_filter": keywordFilter == nil ? [] : keywordFilter!.words,
                "regex_patterns": regexPatterns ?? [],
                "presets": presets?.map({ $0.rawValue }) ?? [],
                "allow_list": allowList?.words ?? [],
                "mention_total_limit": mentionTotalLimit ?? 0,
                "mention_raid_protection_enabled": mentionRaidProtectionEnabled ?? false
            ]
        }
    }

    /// Represents a keyword preset for an Auto Moderation rule
    public enum KeywordPresetType : Int, CaseIterable {
        
        /// Words that may be considered forms of swearing or cursing.
        case profanity = 1
        
        /// Words that refer to sexually explicit behavior or activity.
        case sexualContent
        
        /// Personal insults or words that may be considered hate speech.
        case slurs
        
        static func getKeywordPresetType(_ values: [Int]) -> Set<KeywordPresetType> {
            var presets = Set<KeywordPresetType>()
            for v in values {
                if let pre = KeywordPresetType(rawValue: v) { presets.insert(pre) }
            }
            return presets
        }
    }

    /// Indicates in what event context a rule should be checked.
    public enum EventType : Int {
        
        /// When a member sends or edits a message in the guild.
        case messageSend = 1
    }

    /// Represents an action which will execute whenever a rule is triggered.
    public struct Action {
        
        /// The type of action.
        public let type: ActionType
                
        // ---------- This information is under `metadata` -----------------------
        
        /// Additional explanation that will be shown to members whenever their message is blocked.
        public let customMessage: String?
        
        /// The ID of the channel to which user content will be logged.
        public let channelId: Snowflake?
        
        /// Timeout duration in seconds.
        public let duration: Int?
        
        // -----------------------------------------------------------------------
        
        private init(type: ActionType, customMessage: String? = nil, channelId: Snowflake? = nil, duration: Int? = nil) {
            self.type = type
            self.customMessage = customMessage
            self.channelId = channelId
            self.duration = duration
        }
        
        init(actionData: JSON) {
            type = ActionType(rawValue: actionData["type"] as! Int)!
            
            let metadata = actionData["metadata"] as! JSON
            customMessage = metadata["custom_message"] as? String
            channelId = Conversions.snowflakeToOptionalUInt(metadata["channel_id"])
            duration = metadata["duration_seconds"] as? Int
        }
        
        /// Blocks the message from being sent.
        /// - Parameter customMessage: Additional explanation that will be shown to members whenever their message is blocked.
        public static func blockMessage(customMessage: String? = nil) -> AutoModerationRule.Action {
            return .init(type: .blockMessage, customMessage: customMessage)
        }
        
        /// Send an alert message.
        /// - Parameter to: The ID of an existing channel to which user content should be logged.
        public static func sendAlertMessage(to channelId: Snowflake) -> AutoModerationRule.Action {
            return .init(type: .sendAlertMessage, channelId: channelId)
        }
        
        /// Timeout the user.
        /// - Parameter duration: The amount of time in seconds (max 2419200 aka 4 weeks) to timeout the user.
        public static func timeout(duration: Int) -> AutoModerationRule.Action {
            return .init(type: .timeout, duration: duration)
        }

        func convert() -> JSON {
            var payload: JSON = ["type": type.rawValue]
            let md = "metadata"
            
            switch type {
            case .blockMessage:
                if let customMessage { payload[md] = ["custom_message": customMessage] }
            case .sendAlertMessage:
                payload[md] = ["channel_id": channelId!]
            case .timeout:
                payload[md] = ["duration_seconds": duration!]
            }
                
            return payload
        }
    }
    
    /// Represents a triggered Auto Moderation rule and an action that was executed.
    public struct ActionExecution {
        
        /// Guild in which action was executed.
        public let guild: Guild
        
        /// Action which was executed.
        public let action: AutoModerationRule.Action
        
        /// ID of the rule which action belongs to.
        public let ruleId: Snowflake
        
        /// Trigger type of rule which was triggered.
        public let ruleTriggerType: TriggerType
        
        /// ID of the user which generated the content which triggered the rule.
        public let userId: Snowflake
        
        /// ID of the channel in which user content was posted.
        public let channel: GuildChannelMessageable
        
        /// ID of any user message which content belongs to. Will be `nil` if the message was blocked by Auto Moderation or content was not part of any message
        public let messageId: Snowflake?
        
        /// ID of any system auto moderation messages posted as a result of this action. Will be `nil` if this event does not correspond to ``AutoModerationRule/ActionType/sendAlertMessage``.
        public let alertMessageId: Snowflake?
        
        /// User-generated text content.
        public let content: String
        
        /// Word or phrase configured in the rule that triggered the rule.
        public let matchedKeyword: String?
        
        /// Substring in content that triggered the rule.
        public let matchedContent: String?
        
        init(bot: Discord, actionExecutionData: JSON) {
            guild = bot.getGuild(Conversions.snowflakeToUInt(actionExecutionData["guild_id"]))!
            action = .init(actionData: actionExecutionData["action"] as! JSON)
            ruleId = Conversions.snowflakeToUInt(actionExecutionData["rule_id"])
            ruleTriggerType = .init(rawValue: actionExecutionData["rule_trigger_type"] as! Int)!
            userId = Conversions.snowflakeToUInt(actionExecutionData["user_id"])
            
            let channelId = Conversions.snowflakeToUInt(actionExecutionData["channel_id"])
            channel = guild.getChannel(channelId) as! GuildChannelMessageable
            
            messageId = Conversions.snowflakeToOptionalUInt(actionExecutionData["message_id"])
            alertMessageId = Conversions.snowflakeToOptionalUInt(actionExecutionData["alert_system_message_id"])
            content = actionExecutionData["content"] as! String
            matchedKeyword = actionExecutionData["matched_keyword"] as? String
            matchedContent = actionExecutionData["matched_content"] as? String
        }
    }

    /// Represents an `AutoModerationRule` action type.
    public enum ActionType : Int {
        
        /// Blocks a member's message and prevents it from being posted.
        case blockMessage = 1
        
        /// Logs user content to a specified channel.
        case sendAlertMessage
        
        /// Timeout the user for a specified duration (in seconds). Maximum of 2,419,200 seconds (4 weeks).
        case timeout
    }
}
