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

func convertFromLocalizations(_ locals: [Locale: String]) -> JSON {
    var payload: JSON = [:]
    for (local, nameOrDesc) in locals {
        payload[local.rawValue] = nameOrDesc
    }
    return payload
}

func convertToLocalizations(_ json: [String: String]) -> [Locale: String] {
    var newLocals: [Locale: String] = [:]
    for (local, nameOrDesc) in json {
        newLocals[Locale(rawValue: local)!] = nameOrDesc
    }
    return newLocals
}

/// Represents an application command.
public struct ApplicationCommand {
    
    /// Unique ID of command.
    public let id: Snowflake
    
    /// Type of command.
    public let type: ApplicationCommandType
    
    /// ID of the parent application.
    public let applicationId: Snowflake
    
    /// Guild of the command, if not global.
    public var guild: Guild? {
        get {
            if let guildId { return bot!.getGuild(guildId) }
            else { return nil }
        }
    }
    
    /// Guild ID of the command, if not global.
    public let guildId: Snowflake?
    
    /// Name of the command.
    public let name: String
    
    /// Name localizations for the command.
    public private(set) var nameLocalizations: [Locale: String]?
    
    /// Description for ``ApplicationCommandType/slashCommand`` commands, 1-100 characters.
    /// Empty string for ``ApplicationCommandType/user`` and ``ApplicationCommandType/message`` commands.
    public let description: String
    
    /// Description localizations for the command.
    public private(set) var descriptionLocalizations: [Locale: String]?
    
    /// Parameters for the command if it's type is ``ApplicationCommandType/slashCommand``, max of 25.
    public private(set) var options: [ApplicationCommandOption]?
    
    /// Default permissions for members.
    public private(set) var defaultMemberPermissions: Permissions?
    
    /// Indicates whether the command is available in DMs with the app, only for globally-scoped commands.
    public let dmPermission: Bool?
    
    /// Indicates whether the command is age-restricted.
    public let isNsfw: Bool
    
    // ---------- API Separated ----------
    
    /// Whether the application command is global.
    public var isGlobal: Bool { guildId == nil }
    
    // -----------------------------------
    
    /// Your bot instance.
    public private(set) weak var bot: Discord?
    
    init(bot: Discord, applicationCommandData: JSON) {
        self.bot = bot
        id = Conversions.snowflakeToUInt(applicationCommandData["id"])
        type = ApplicationCommandType(rawValue: applicationCommandData["type"] as! Int)!
        applicationId = Conversions.snowflakeToUInt(applicationCommandData["application_id"])
        guildId = Conversions.snowflakeToOptionalUInt(applicationCommandData["guild_id"])
        name = applicationCommandData["name"] as! String
        
        if let nameLocals = applicationCommandData["name_localizations"] as? [String: String] {
            nameLocalizations = [:]
            for (local, name) in nameLocals {
                nameLocalizations![Locale(rawValue: local)!] = name
            }
        }
        
        description = applicationCommandData["description"] as! String
        
        if let descLocals = applicationCommandData["description_localizations"] as? [String: String] {
            descriptionLocalizations = [:]
            for (local, name) in descLocals {
                descriptionLocalizations![Locale(rawValue: local)!] = name
            }
        }
        
        if let optionObjs = applicationCommandData["options"] as? [JSON] {
            options = []
            for optionObj in optionObjs {
                options!.append(ApplicationCommandOption(appCommandOptionData: optionObj))
            }
        }
        
        if let permissionsBitSet = applicationCommandData["default_member_permissions"] as? String {
            defaultMemberPermissions = Permissions(permsValue: Int(permissionsBitSet)!)
        }
        
        dmPermission = applicationCommandData.keys.contains("dm_permission") ? (applicationCommandData["dm_permission"] as! Bool) : nil
        isNsfw = applicationCommandData["nsfw"] as! Bool
    }
    
    /// Edit the application command.
    /// - Parameter edits: Values that should be changed.
    /// - Returns: The updated application command.
    @discardableResult
    public func edit(_ edits: Edit...) async throws -> ApplicationCommand {
        // Don't perform an HTTP request when nothing was changed
        guard !(edits.count == 0) else { return self }

        var payload: JSON = [:]
        
        for edit in edits {
            switch edit {
            case .name(let name):
                payload["name"] = ApplicationCommand.verifyName(name)
            case .nameLocalizations(let nameLocals):
                if let nameLocals {
                    payload["name_localizations"] = convertFromLocalizations(nameLocals)
                } else {
                    payload["name_localizations"] = NIL
                }
            case .description(let desc):
                if type == .slashCommand {
                    payload["description"] = desc
                }
            case .descriptionLocalizations(let descLocals):
                if let descLocals {
                    payload["description_localizations"] = convertFromLocalizations(descLocals)
                } else {
                    payload["description_localizations"] = NIL
                }
            case .options(let options):
                payload["options"] = options.map({ $0.convert() })
            case .defaultMemberPermissions(let perms):
                if let perms {
                    payload["default_member_permissions"] = String(perms.value)
                } else {
                    payload["default_member_permissions"] = NIL
                }
            case .nsfw(let nsfw):
                payload["nsfw"] = nsfw
            case .dmPermission(let dmPerm):
                if isGlobal {
                    payload["dm_permission"] = dmPerm
                }
            }
        }
        
        let updatedCmd = try await bot!.http.editApplicationCommand(botId: bot!.user!.id, appCommandId: id, guildId: guildId, json: payload)
        
        if let pendingCmd = bot!.pendingApplicationCommands.first(where: { $0.name == self.name && $0.guildId == self.guildId && $0.type == self.type }) {
            pendingCmd.update(payload)
        }
        
        return updatedCmd
    }
    
    /// Deletes the application command.
    public func delete() async throws {
        try await bot!.http.deleteApplicationCommand(botId: try await bot!.getClientID(), commandId: id, guildId: guildId)
        bot!.pendingApplicationCommands.removeAll(where: { $0.name == name && $0.guildId == guildId && $0.type == type })
    }
    
    // Verifies the basic requirements for an application command name/command option name
    static func verifyName(_ name: String) -> String {
        var name = name.lowercased()
        name = name.trimmingCharacters(in: [" "])
        name.replace(" ", with: "-")
        return name
    }
}

extension ApplicationCommand {
    
    /// Represents the values that should be edited in a ``ApplicationCommand``.
    public enum Edit {
        
        /// Name of the command.
        case name(String)
        
        /// Name localizations for the command.
        case nameLocalizations([Locale: String]?)
        
        /// Description for ``ApplicationCommandType/slashCommand`` commands, 1-100 characters.
        case description(String)
        
        /// Description localizations for the command.
        case descriptionLocalizations([Locale: String]?)
        
        /// Parameters for the command if it's type is ``ApplicationCommandType/slashCommand``, max of 25.
        case options([ApplicationCommandOption])
        
        /// The default member permissions.
        case defaultMemberPermissions(Permissions?)
        
        /// Indicates whether the command is age-restricted.
        case nsfw(Bool)
        
        /// Indicates whether the command is available in DMs with the app, only for globally-scoped commands. By default, commands are visible.
        case dmPermission(Bool)
    }
}

class PendingAppCommand {
    var type: ApplicationCommandType
    var name: String
    var guildId: Snowflake?
    var onInteraction: (Interaction) async -> Void
    var defaultMemberPermissions: Permissions?
    var nameLocalizations: [Locale: String]?
    var descriptionLocalizations: [Locale: String]?
    var nsfw: Bool
    var dmPermission: Bool
    var description: String?
    var options: [ApplicationCommandOption]?
    
    init(type: ApplicationCommandType, name: String, guildId: Snowflake? = nil, onInteraction: @escaping (Interaction) async -> Void, defaultMemberPermissions: Permissions? = nil, nameLocalizations: [Locale : String]? = nil, descriptionLocalizations: [Locale : String]? = nil, nsfw: Bool, dmPermission: Bool, description: String? = nil, options: [ApplicationCommandOption]? = nil) {
        self.type = type
        self.name = name
        self.guildId = guildId
        self.onInteraction = onInteraction
        self.defaultMemberPermissions = defaultMemberPermissions
        self.nameLocalizations = nameLocalizations
        self.descriptionLocalizations = descriptionLocalizations
        self.nsfw = nsfw
        self.dmPermission = dmPermission
        self.description = description
        self.options = options
    }
    
    fileprivate func update(_ data: JSON) {
        for (k, v) in data {
            switch k {
            case "name":
                name = v as! String
            case "name_localizations":
                nameLocalizations = convertToLocalizations(v as! [String: String])
            case "description":
                description = v as? String
            case "description_localizations":
                descriptionLocalizations = convertToLocalizations(v as! [String: String])
            case "options":
                var new = [ApplicationCommandOption]()
                for obj in v as! [JSON] {
                    new.append(.init(appCommandOptionData: obj))
                }
                options = new
            case "default_member_permissions":
                defaultMemberPermissions = .init(permsValue: v as! Int)
            case "nsfw":
                nsfw = v as! Bool
            case "dm_permission":
                dmPermission = v as! Bool
            default:
                break
            }
        }
    }
}

/// Represents the application command type.
public enum ApplicationCommandType : Int {
    
    /// Slash commands; a text-based command that shows up when a user types `/`.
    case slashCommand = 1
    
    /// A UI-based command that shows up when you right click or tap on a user.
    case user
    
    /// A UI-based command that shows up when you right click or tap on a message.
    case message
}

/// Represents an application command option.
public struct ApplicationCommandOption {
    
    /// Type of option.
    public let type: ApplicationCommandOptionType
    
    /// 1-32 character name.
    public let name: String
    
    /// 1-100 character description.
    public let description: String
    
    /// If the parameter is required. If `true`, this option must be before all other options that are not required.
    public let required: Bool
    
    /// Name localizations for the option.
    public private(set) var nameLocalizations: [Locale: String]?
    
    /// Description localizations for the option.
    public private(set) var descriptionLocalizations: [Locale: String]?
    
    /// The choices available for the user to pick from. If you specify choices, they are the **only** valid values for a user to pick.
    public private(set) var choices: [ApplicationCommandOptionChoice]?
    
    /// If the option is a subcommand or subcommand group type, these nested options will be the parameters.
    public private(set) var options: [ApplicationCommandOption]?
    
    /// If the option is a channel type, the channels shown will be restricted to these types.
    public private(set) var channelTypes: [ChannelType]?
    
    /// The minimum value permitted if the `type` is ``ApplicationCommandOptionType/integer`` or ``ApplicationCommandOptionType/double``.
    public private(set) var minValue: Double?
    
    /// The maximum value permitted if the `type` is ``ApplicationCommandOptionType/integer`` or ``ApplicationCommandOptionType/double``.
    public private(set) var maxValue: Double?
    
    /// The minimum allowed length if the `type` is ``ApplicationCommandOptionType/string``. Minimum of 1, maximum of 6000.
    public private(set) var minLength: Int?
    
    /// The maximum allowed length if the `type` is ``ApplicationCommandOptionType/string``. Minimum of 1, maximum of 6000.
    public private(set) var maxLength: Int?
    
    /// If autocomplete interactions are enabled for this ``ApplicationCommandOptionType/string``, ``ApplicationCommandOptionType/integer``, or ``ApplicationCommandOptionType/double`` type option.
    public private(set) var autocomplete: Bool
    
    // ---------- API Separated ----------
    
    /// The autocomplete suggestions that will show up for the option if `autocomplete` is enabled.
    public private(set) var suggestions: [ApplicationCommandOptionChoice]?
    
    // -----------------------------------
    
    /// Initializes a application command option.
    /// - Parameters:
    ///   - type: Type of option.
    ///   - name: 1-32 character name.
    ///   - description: 1-100 character description.
    ///   - required: If the parameter is required. If `true`, this option must be before all other options that are not required. This is not utilized if the `type` is ``ApplicationCommandOptionType/subCommand`` or ``ApplicationCommandOptionType/subCommandGroup``.
    ///   - choices: The choices available for the user to pick from. If you specify choices, they are the **only** valid values for a user to pick.
    ///   - channelTypes: If the option is a channel type, the channels shown will be restricted to these types.
    ///   - options: If the option is a subcommand or subcommand group type, these nested options will be the parameters.
    ///   - nameLocalizations: Name localizations for the option.
    ///   - descriptionLocalizations: Description localizations for the option.
    ///   - minValue: The minimum value permitted if the `type` is ``ApplicationCommandOptionType/integer`` or ``ApplicationCommandOptionType/double``.
    ///   - maxValue: The maximum value permitted if the `type` is ``ApplicationCommandOptionType/integer`` or ``ApplicationCommandOptionType/double``.
    ///   - minLength: The minimum allowed length if the `type` is ``ApplicationCommandOptionType/string``. Minimum of 1, maximum of 6000.
    ///   - maxLength: The maximum allowed length if the `type` is ``ApplicationCommandOptionType/string``. Minimum of 1, maximum of 6000.
    ///   - autocomplete: If autocomplete interactions are enabled for this ``ApplicationCommandOptionType/string``, ``ApplicationCommandOptionType/integer``, or ``ApplicationCommandOptionType/double`` type option.
    ///   - suggestions: The autocomplete suggestions that will show up for the option if ``autocomplete`` is enabled.
    public init(
        _ type: ApplicationCommandOptionType,
        name: String,
        description: String,
        required: Bool,
        choices: [ApplicationCommandOptionChoice]? = nil,
        channelTypes: [ChannelType]? = nil,
        options: [ApplicationCommandOption]? = nil,
        nameLocalizations: [Locale: String]? = nil,
        descriptionLocalizations: [Locale: String]? = nil,
        minValue: Double? = nil,
        maxValue: Double? = nil,
        minLength: Int? = nil,
        maxLength: Int? = nil,
        autocomplete: Bool = false,
        suggestions: [ApplicationCommandOptionChoice]? = nil) {
            self.type = type
            self.name = ApplicationCommand.verifyName(name)
            self.description = description
            // self.required is set below
            self.choices = choices
            self.channelTypes = channelTypes
            self.options = options
            self.nameLocalizations = nameLocalizations
            self.descriptionLocalizations = descriptionLocalizations
            self.minValue = minValue
            self.maxValue = maxValue
            self.minLength = minLength
            self.maxLength = maxLength
            self.autocomplete = autocomplete
            self.suggestions = suggestions
            
            // HTTPError.badRequest("Invalid form body") if `required` is set to `true` when
            // the `type` is `.subCommand` or `.subCommandGroup`. Required isn't utilized in subcommands
            // and subcommand groups (as noted in the init documentation now), but just in case (and to make it less of a headache)
            // just set `required` to `false`.
            let subs = [ApplicationCommandOptionType.subCommand, ApplicationCommandOptionType.subCommandGroup]
            if subs.contains(type) { self.required = false }
            else { self.required = required }
            
            // Discord: "autocomplete may not be set to true if choices are present."
            if let _ = choices { self.autocomplete = false }
            
            // If autocomplete is set to true, suggestions must be present. If they aren't, set autocomplete to false
            // and suggestions to nil
            if autocomplete {
                if suggestions == nil || suggestions?.count == 0 {
                    self.autocomplete = false
                    self.suggestions = nil
                }
            }
    }
    
    init(appCommandOptionData: JSON) {
        type = ApplicationCommandOptionType(rawValue: appCommandOptionData["type"] as! Int)!
        name = appCommandOptionData["name"] as! String
        
        if let nameLocals = appCommandOptionData["name_localizations"] as? [String: String] {
            nameLocalizations = convertToLocalizations(nameLocals)
        }
        
        description = appCommandOptionData["description"] as! String
        
        if let descLocals = appCommandOptionData["description_localizations"] as? [String: String] {
            descriptionLocalizations = convertToLocalizations(descLocals)
        }
        
        required = Conversions.optionalBooltoBool(appCommandOptionData["required"])
        
        if let choicesObjs = appCommandOptionData["choices"] as? [JSON] {
            choices = []
            for choiceObj in choicesObjs {
                choices!.append(ApplicationCommandOptionChoice(appCommandOptionChoiceData: choiceObj))
            }
        }
        
        if let optionObjs = appCommandOptionData["options"] as? [JSON] {
            options = []
            for optionObj in optionObjs {
                options!.append(ApplicationCommandOption(appCommandOptionData: optionObj))
            }
        }
        
        if let channelTypes = appCommandOptionData["channel_types"] as? [Int] {
            self.channelTypes = []
            for channelType in channelTypes {
                self.channelTypes!.append(ChannelType(rawValue: channelType)!)
            }
        }
        
        minValue = appCommandOptionData["min_value"] as? Double
        maxValue = appCommandOptionData["max_value"] as? Double
        minLength = appCommandOptionData["min_length"] as? Int
        maxLength = appCommandOptionData["max_length"] as? Int
        autocomplete = Conversions.optionalBooltoBool(appCommandOptionData["autocomplete"])
    }
    
    func convert() -> JSON {
        var payload: JSON = [
            "type": type.rawValue,
            "name": name,
            "description": description,
            "required": required
        ]
        
        if let choices { payload["choices"] = choices.map({ $0.convert() }) }
        if let channelTypes { payload["channel_types"] = channelTypes.map({ $0.rawValue }) }
        if let options { payload["options"] = options.map({ $0.convert() }) }
        if let nameLocalizations { payload["name_localizations"] = convertFromLocalizations(nameLocalizations) }
        if let descriptionLocalizations { payload["description_localizations"] = convertFromLocalizations(descriptionLocalizations) }
        
        // With minValue and maxValue, the API accepts the the value based on the `type`, so just do the conversion here
        if let minValue {
            if type == .integer { payload["min_value"] = Int(minValue) }
            else if type == .double { payload["min_value"] = minValue }
        }
        if let maxValue {
            if type == .integer { payload["max_value"] = Int(maxValue) }
            else if type == .double { payload["max_value"] = maxValue }
        }
        
        if let minLength {
            if type == .string { payload["min_length"] = minLength }
        }
        if let maxLength {
            if type == .string { payload["max_length"] = maxLength }
        }
        
        if [ApplicationCommandOptionType.string, ApplicationCommandOptionType.integer, ApplicationCommandOptionType.double].contains(type) {
            payload["autocomplete"] = autocomplete
        }
        
        return payload
    }
}

/// Represents an application command option type.
public enum ApplicationCommandOptionType : Int {
    case subCommand = 1
    case subCommandGroup
    case string
    case integer
    case boolean
    case user
    case channel
    case role
    case mentionable
    case double
    case attachment
}

/// Represents an application command option choice.
public struct ApplicationCommandOptionChoice {
    
    /// 1-100 character choice name.
    public let name: String
    
    /// Name localizations for the option choice.
    public private(set) var nameLocalizations: [Locale: String]?
    
    /// Value for the choice. Either string, integer, or double. Up to 100 characters if string.
    public let value: Any
    
    /// Initializes an application command option choice.
    /// - Parameters:
    ///   - name: 1-100 character choice name.
    ///   - value: Value for the choice. Up to 100 characters.
    ///   - nameLocalizations: Name localizations for the option choice.
    public init(name: String, value: String, nameLocalizations: [Locale: String]? = nil) {
        self.name = name
        self.value = value
        self.nameLocalizations = nameLocalizations
    }
    
    /// Initializes an application command option choice.
    /// - Parameters:
    ///   - name: 1-100 character choice name.
    ///   - value: Value for the choice.
    ///   - nameLocalizations: Name localizations for the option choice.
    public init(name: String, value: Int, nameLocalizations: [Locale: String]? = nil) {
        self.name = name
        self.value = value
        self.nameLocalizations = nameLocalizations
    }
    
    /// Initializes an application command option choice.
    /// - Parameters:
    ///   - name: 1-100 character choice name.
    ///   - value: Value for the choice.
    ///   - nameLocalizations: Name localizations for the option choice.
    public init(name: String, value: Double, nameLocalizations: [Locale: String]? = nil) {
        self.name = name
        self.value = value
        self.nameLocalizations = nameLocalizations
    }
    
    init(appCommandOptionChoiceData: JSON) {
        name = appCommandOptionChoiceData["name"] as! String
        value = appCommandOptionChoiceData["value"]!
        
        if let nameLocals = appCommandOptionChoiceData["name_localizations"] as? [String: String] {
            nameLocalizations = convertToLocalizations(nameLocals)
        }
    }
    
    func convert() -> JSON {
        var payload: JSON = ["name": name, "value": value]
        
        if let nameLocalizations {
            var nameLocalsDict: [String: String] = [:]
            for (local, name) in nameLocalizations {
                nameLocalsDict[local.rawValue] = name
            }
            payload["name_localizations"] = nameLocalsDict
        }
        
        return payload
    }
}

/// Represents the data specific to an interaction.
public protocol InteractionData {}

/// Represents a discord interaction.
public class Interaction {
    
    /// ID of the interaction.
    public let id: Snowflake
    
    /// ID of the application this interaction is for.
    public let applicationId: Snowflake
    
    /// Type of interaction.
    public let type: InteractionType
    
    /// The interaction data.
    public private(set) var data: InteractionData?
    
    /// Guild that the interaction was sent from.
    public var guild: Guild? {
        get {
            if let guildId { return bot!.getGuild(guildId) }
            else { return nil }
        }
    }
    
    /// Guild ID that the interaction was sent from.
    public let guildId: Snowflake?
    
    /// Channel that the interaction was sent from.
    public var channel: Channel? {
        get {
            if let channelId { return bot!.getChannel(channelId) }
            else { return nil }
        }
    }
    
    /// Channel ID that the interaction was sent from.
    public let channelId: Snowflake?
    
    /// Guild ``Member`` object for the invoking user, including permissions. Will be a ``User`` object if invoked in a DM.
    public let user: Object
    
    /// Continuation token for responding to the interaction.
    public let token: String
    
    /// For components, the message they were attached to.
    public private(set) var message: Message?
    
    /// Set of permissions the app or bot has within the channel the interaction was sent from.
    public let appPermissions: Permissions? = nil
    
    // ----------------------- API Separated -----------------------
    
    /// Whether the interaction has been responded to.
    public private(set) var isFinished = false
    
    /// The message ID for the followup message.
    public private(set) var followupMessageId: Snowflake? = nil
    
    // -------------------------------------------------------------
    
    /// Your bot instance.
    public private(set) weak var bot: Discord?
    
    init(bot: Discord, interactionData: JSON) {
        self.bot = bot
        id = Conversions.snowflakeToUInt(interactionData["id"])
        applicationId = Conversions.snowflakeToUInt(interactionData["application_id"])
        type = InteractionType(rawValue: interactionData["type"] as! Int)!
        
        let dataSubset = interactionData["data"] as! JSON
        
        switch type {
        case .ping:
            break
            
        case .applicationCommand, .applicationCommandAutocomplete:
            data = ApplicationCommandData(bot: bot, appCommandData: dataSubset)
            
        case .messageComponent:
            data = MessageComponentData(dataSubset)
            
        case .modalSubmit:
            data = ModalSubmitData(dataSubset)
        }
        
        guildId = Conversions.snowflakeToOptionalUInt(interactionData["guild_id"])
        channelId = Conversions.snowflakeToOptionalUInt(interactionData["channel_id"])
        
        if let obj = interactionData["member"] as? JSON { user = Member(bot: bot, memberData: obj, guildId: guildId!) }
        else { user = User(userData: interactionData["user"] as! JSON) }
        
        token = interactionData["token"] as! String
        
        if let msgObj = interactionData["message"] as? JSON { message = Message(bot: bot, messageData: msgObj) }
    }
    
    /// Send a followup message. This is used when the interaction has already been responded to.
    /// - Parameters:
    ///   - content: The message contents.
    ///   - embeds: Embeds attached to the message (10 max).
    ///   - tts: Whether this message should be sent as a TTS message.
    ///   - allowedMentions: Controls the mentions allowed when this message is sent.
    ///   - ui: The UI for the message. Contains things such as a ``Button`` or ``SelectMenu``.
    ///   - files: Files to attach to the message.
    /// - Returns: The followup message.
    @discardableResult
    public func followupWithMessage(
        _ content: String? = nil,
        embeds: [Embed]? = nil,
        tts: Bool = false,
        allowedMentions: AllowedMentions = Discord.allowedMentions,
        ui: UI? = nil,
        files: [File]? = nil
    ) async throws -> Message {
        var payload: JSON = ["tts": tts, "allowed_mentions": allowedMentions.convert()]

        if let content { payload["content"] = content }
        if let embeds { payload["embeds"] = Embed.convert(embeds) }
        if let ui { payload["components"] = try ui.convert() }

        let followup = try await bot!.http.createFollowupMessage(botId: bot!.user!.id, interactionToken: token, json: payload, files: files)
        followupMessageId = followup.id
        UI.setUI(message: followup, ui: ui)
        return followup
    }

    /// Retrieve the message that was used as a followup.
    /// - Returns: The followup message. Can be `nil` if a followup message was never sent.
    public func getFollowupMessage() async throws -> Message? {
        if let followupMessageId {
            // If the followup message is still in the cache, just retrieve it from there instead of
            // requesting it through the API.
            if let cachedFollowupMessage = bot!.getMessage(followupMessageId) {
                return cachedFollowupMessage
            }
            else {
                let followup = try await bot!.http.getFollowupMessage(botId: bot!.user!.id, interactionToken: token, messageId: followupMessageId)
                bot!.cacheMessage(followup)
                return followup
            }
        }
        return nil
    }
    
    /// Edit the followup message.
    /// - Parameters:
    ///   - content: The message contents.
    ///   - embeds: Embeds attached to the message (10 max).
    ///   - allowedMentions: Controls the mentions allowed when this message is sent.
    ///   - ui: The UI for the message. Contains things such as a ``Button`` or ``SelectMenu``.
    ///   - files: Files to attach to the message.
    /// - Returns: The updated message.
    @discardableResult
    public func editFollowupMessage(
        _ content: String? = nil,
        embeds: [Embed]? = nil,
        allowedMentions: AllowedMentions = Discord.allowedMentions,
        ui: UI? = nil,
        files: [File]? = nil
    ) async throws -> Message? {
        if let followupMessageId {
            var payload: JSON = ["allowed_mentions": allowedMentions.convert()]
            
            var threadId: Snowflake? = nil
            if let thread = channel as? ThreadChannel { threadId = thread.id }

            if let content { payload["content"] = content }
            if let embeds { payload["embeds"] = Embed.convert(embeds) }
            if let ui { payload["components"] = try ui.convert() }

            let editedMessage = try await bot!.http.editFollowupMessage(botId: bot!.user!.id, interactionToken: token, messageId: followupMessageId, json: payload, files: files, threadId: threadId)
            UI.setInteraction(message: editedMessage, ui: ui)
            return editedMessage
        }
        return nil
    }

    /// Delete the followup message.
    public func deleteFollowupMessage() async throws {
        if let followupMessageId {
            try await bot!.http.deleteFollowupMessage(botId: bot!.user!.id, interactionToken: token, messageId: followupMessageId)
        }
    }

    /// Retrieve the message that was originally used for the interaction.
    /// - Returns: The original message.
    public func originalResponse() async throws -> Message {
        var threadId: Snowflake? = nil
        if let thread = channel as? ThreadChannel {
            threadId = thread.id
        }
        let originalResponse = try await bot!.http.getOriginalInteractionResponse(botId: bot!.user!.id, interactionToken: token, threadId: threadId)
        if let cachedOriginalResponse = bot!.getMessage(originalResponse.id) {
            UI.setUI(message: originalResponse, ui: cachedOriginalResponse.ui)
            UI.setInteraction(message: originalResponse, ui: cachedOriginalResponse.ui)
            return cachedOriginalResponse
        } else {
            return originalResponse
        }
    }
    
    /// Edit the original response message.
    /// - Parameters:
    ///   - content: The message contents.
    ///   - embeds: Embeds attached to the message (10 max).
    ///   - allowedMentions: Controls the mentions allowed when this message is sent.
    ///   - ui: The UI for the message. Contains things such as a ``Button`` or ``SelectMenu``.
    ///   - files: Files to attach to the message.
    /// - Returns: The updated response.
    @discardableResult
    public func editOriginalResponse(
        _ content: String? = nil,
        embeds: [Embed]? = nil,
        allowedMentions: AllowedMentions = Discord.allowedMentions,
        ui: UI? = nil,
        files: [File]? = nil
    ) async throws -> Message {
        guard isFinished else {
            throw UIError.noResponse("Cannot edit the original response of a \(type) when the interaction was never responded to.")
        }

        var payload: JSON = ["allowed_mentions": allowedMentions.convert()]

        var threadId: Snowflake? = nil
        if let thread = channel as? ThreadChannel { threadId = thread.id }

        if let content { payload["content"] = content }
        if let embeds { payload["embeds"] = Embed.convert(embeds) }
        if let ui { payload["components"] = try ui.convert() }

        let editedMessage = try await bot!.http.editOriginalInteractionResponse(botId: bot!.user!.id, interactionToken: token, json: payload, files: files, threadId: threadId)
        UI.setUI(message: editedMessage, ui: ui)
        return editedMessage
    }

    /// Deletes the original response.
    public func deleteOriginalResponse() async throws {
        try await bot!.http.deleteOriginalInteractionResponse(botId: bot!.user!.id, interactionToken: token)
    }
    
    /// Respond to a discord ping interaction. This is only used if you're recieving webhook-based interactions.
    public func respondWithPong() async throws {
        try await bot!.http.createInteractionResponse(
            interactionId: id,
            interactionToken: token,
            json: ["type": InteractionCallbackType.pong.rawValue],
            files: nil
        )
    }

    /// Respond to a **message component** interaction. A defer simply acknowledges the interaction so you can edit/followup with the message later.
    public func respondWithDefer() async throws {
        guard type == .messageComponent else { return }

        try await bot!.http.createInteractionResponse(
            interactionId: id,
            interactionToken: token,
            json: ["type": InteractionCallbackType.deferredUpdateMessage.rawValue],
            files: nil
        )
        isFinished = true
    }

    /// Respond to the interaction with a pop-up modal.
    /// - Parameter modal: The modal that will be presented to the user.
    public func respondWithModal(_ modal: Modal) async throws {
        // With modals, the components setup is a little different. With other components like buttons, the inner "components"
        // array would house all the buttons. But with modals, it basically an array of an action row with a single component
        // in the inner "components" array.
        var componentsPayload: [JSON] = []
        for txtInput in modal.inputs {
            componentsPayload.append([
                "type": 1,
                "components": [txtInput.convert()]
            ])
        }

        let payload: JSON = [
            "type": InteractionCallbackType.modal.rawValue,
            "data": [
                "title": modal.title,
                "custom_id": modal.customId,
                "components": componentsPayload
            ] as [String: Any]
        ]

        try await bot!.http.createInteractionResponse(interactionId: id, interactionToken: token, json: payload, files: nil)
        isFinished = true

        // Set the modal key and closure
        if bot!.pendingModals.first(where: { $0.key == modal.customId }) == nil {
            bot!.pendingModals[modal.customId] = modal.onSubmit
        }
    }

    /// Respond to an interaction with a message that says "`{bot.name}` is thinking". This is typically used for application commands where your UI ``UI/onInteraction``
    /// takes longer periods of time and you'd like the end user to know that the interaction is being processed. If an interaction is not followed up, it will remain in a "thinking" state.
    /// - Parameter ephemeral: Indicates if the followup message will be ephemeral.
    public func respondWithThinking(ephemeral: Bool = false) async throws {
        var payload: JSON = ["type": InteractionCallbackType.deferredChannelMessageWithSource.rawValue]
        if ephemeral { payload["data"] = ["flags": Message.Flags.ephemeral.rawValue] }

        try await bot!.http.createInteractionResponse(interactionId: id, interactionToken: token, json: payload, files: nil)
        isFinished = true
    }
    
    /// Respond to an interaction with a message.
    /// - Parameters:
    ///   - content: The message contents.
    ///   - embeds: Embeds attached to the message (10 max).
    ///   - tts: Whether this message should be sent as a TTS message.
    ///   - allowedMentions: Controls the mentions allowed when this message is sent.
    ///   - ephemeral: Whether the message is ephemeral.
    ///   - ui: The UI for the message. Contains things such as a ``Button`` or ``SelectMenu``.
    ///   - files: Files to attach to the message.
    /// - Returns: The message that was sent.
    @discardableResult
    public func respondWithMessage(
        _ content: String? = nil,
        embeds: [Embed]? = nil,
        tts: Bool = false,
        allowedMentions: AllowedMentions = Discord.allowedMentions,
        ephemeral: Bool = false,
        ui: UI? = nil,
        files: [File]? = nil
    ) async throws -> Message {
        var payload: JSON = ["type": InteractionCallbackType.channelMessageWithSource.rawValue]

        // [MESSAGE] https://discord.com/developers/docs/interactions/receiving-and-responding#interaction-response-object-messages
        // NOTE: Stickers aren't supported
        var callbackData: JSON = ["tts": tts, "allowed_mentions": allowedMentions.convert()]

        if let content { callbackData["content"] = content }
        if let embeds { callbackData["embeds"] = Embed.convert(embeds) }
        if ephemeral { callbackData["flags"] = Message.Flags.ephemeral.rawValue }
        if let ui { callbackData["components"] = try ui.convert() }
        payload["data"] = callbackData

        try await bot!.http.createInteractionResponse(interactionId: id, interactionToken: token, json: payload, files: files)
        let response = try await originalResponse()
        UI.setUI(message: response, ui: ui)
        isFinished = true
        return response
    }
    
    // Respond with the autocomplete suggestions the user created.
    func respondWithAutocomplete(choices: [ApplicationCommandOptionChoice]) async throws {
        let payload: JSON = [
            "type": InteractionCallbackType.applicationCommandAutocompleteResult.rawValue,
            "data": ["choices": choices.map({ $0.convert() })]
        ]
        try await bot!.http.createInteractionResponse(
            interactionId: id,
            interactionToken: token,
            json: payload,
            files: nil
        )
    }
}

/// Represents the interaction type.
public enum InteractionType : Int {
    case ping = 1
    case applicationCommand
    case messageComponent
    case applicationCommandAutocomplete
    case modalSubmit
}

/// Represents the interaction callback type.
public enum InteractionCallbackType : Int {
    
    /// ACK a Ping.
    case pong = 1
    
    /// Respond to an interaction with a message.
    case channelMessageWithSource = 4
    
    /// ACK an interaction and edit a response later, the user sees a loading state.
    case deferredChannelMessageWithSource
    
    /// For components, ACK an interaction and edit the original message later; the user does not see a loading state,
    case deferredUpdateMessage
    
    /// For components, edit the message the component was attached to.
    case updateMessage
    
    /// Respond to an autocomplete interaction with suggested choices.
    case applicationCommandAutocompleteResult
    
    /// Respond to an interaction with a popup modal.
    case modal
}

/// Represents the data from an application command or autocomplete.
public struct ApplicationCommandData : InteractionData {
    
    /// The ID of the invoked command.
    public let id: Snowflake
    
    /// The name of the invoked command.
    public let name: String
    
    /// The type of the invoked command.
    public let type: ApplicationCommandType
    
    /// Options for the interaction data.
    public private(set) var options: [ApplicationCommandInteractionDataOption]?
    
    /// The ID of the guild the command is registered to.
    public let guildId: Snowflake?
    
    /// ID of the user or message targeted by a user or message command.
    public let targetId: Snowflake?
    
    /// The message the message application command was used on.
    public private(set) var message: Message?
    
    /// The values resulting from the end users choices.
    public let results: Resolved
    
    init(bot: Discord, appCommandData: JSON) {
        id = Conversions.snowflakeToUInt(appCommandData["id"])
        name = appCommandData["name"] as! String
        type = ApplicationCommandType(rawValue: appCommandData["type"] as! Int)!
        
        if let optionObjs = appCommandData["options"] as? [JSON] {
            options = []
            for optionObj in optionObjs {
                options!.append(ApplicationCommandInteractionDataOption(optionObj))
            }
        }
        
        guildId = Conversions.snowflakeToOptionalUInt(appCommandData["guild_id"])
        targetId = Conversions.snowflakeToOptionalUInt(appCommandData["target_id"])
        
        let resolvedObj = appCommandData["resolved"] as? JSON
        results = Resolved(resolvedData: resolvedObj ?? [:])
        
        if type == .message {
            var messagesData = resolvedObj!["messages"] as! JSON
            let messageObj = messagesData.popFirst()!.value as! JSON
            message = Message(bot: bot, messageData: messageObj)
        }
    }
}

/// Represents the the parameters and values from the user.
public class ApplicationCommandInteractionDataOption {
    
    /// Name of the parameter.
    public let name: String
    
    /// The application command option type.
    public let type: ApplicationCommandOptionType
    
    /// Value of the option resulting from user input. Either string, integer, double, or boolean.
    public let value: Any?
    
    /// Present if this option is a command group or subcommand.
    public private(set) var options: [ApplicationCommandInteractionDataOption]?
    
    /// If this is `true`, this option is the currently focused option for autocomplete
    public let focused: Bool?
    
    init(_ appCommandInteractionDataOption: JSON) {
        name = appCommandInteractionDataOption["name"] as! String
        type = ApplicationCommandOptionType(rawValue: appCommandInteractionDataOption["type"] as! Int)!
        value = appCommandInteractionDataOption["value"]
        
        if let optionObjs = appCommandInteractionDataOption["options"] as? [JSON] {
            options = []
            for optionObj in optionObjs {
                options!.append(ApplicationCommandInteractionDataOption(optionObj))
            }
        }
        
        focused = Conversions.optionalBooltoBool(appCommandInteractionDataOption["focused"])
    }
}

/// Represents the values/results from the end users choices.
public struct Resolved {
    
    /// The IDs of the users that were selected in the application command/message component.
    public private(set) var users = [Snowflake]()
    
    /// The IDs of the roles that were selected in the application command/message component.
    public private(set) var roles = [Snowflake]()
    
    /// The IDs of the channels that were selected in the application command/message component.
    public private(set) var channels = [Snowflake]()
    
    /// The attachments that were uploaded in the application command/message component.
    public private(set) var attachments = [Message.Attachment]()
    
    // ---------- API Separated ----------
    
    /// The choices that were selected. This is typically used if a select menu is of type ``SelectMenu/MenuType-swift.enum/text``.
    public internal(set) var texts = [String]()
    
    // -----------------------------------
    
    init(resolvedData: JSON) {
        if !resolvedData.isEmpty {
            if let userObjs = resolvedData["users"] as? JSON {
                users = userObjs.keys.map({ Conversions.snowflakeToUInt($0) })
            }
            if let roleObjs = resolvedData["roles"] as? JSON {
                roles = roleObjs.keys.map({ Conversions.snowflakeToUInt($0) })
            }
            if let channelObjs = resolvedData["channels"] as? JSON {
                channels = channelObjs.keys.map({ Conversions.snowflakeToUInt($0) })
            }
            if let attachmentObjs = resolvedData["attachments"] as? JSON {
                attachments = attachmentObjs.values.map({ Message.Attachment(attachmentData: $0 as! JSON) })
            }
        }
    }
}

/// Represents the values from a message component.
public struct MessageComponentData : InteractionData {
    
    /// The custom ID of the component.
    public let customId: String
    
    /// The type of the component.
    public let componentType: ComponentType
    
    /// The values resulting from the end users choices.
    public private(set) var results: Resolved
    
    init(_ messageComponentData: JSON) {
        customId = messageComponentData["custom_id"] as! String
        componentType = ComponentType(rawValue: messageComponentData["component_type"] as! Int)!
        results = Resolved(resolvedData: (messageComponentData["resolved"] as? JSON) ?? [:])
        
        // Easier access for `.text` types
        if let rawValue = messageComponentData["values"] as? [String] {
            results.texts.append(contentsOf: rawValue.map({ $0 }))
        }
    }
}

/// Represents the results from a submitted modal.
public struct ModalSubmitData : InteractionData {
    
    /// Custom ID for the modal.
    public let customId: String
    
    /// The values entered on the modal.
    public private(set) var results: [(inputId: String, value: String)] = []
    
    init(_ modalSubmitData: JSON) {
        customId = modalSubmitData["custom_id"] as! String
        let components = modalSubmitData["components"] as! [JSON]
        
        for outerComp in components {
            let resultsPayload = (outerComp["components"] as! [JSON])[0]
            results.append((resultsPayload["custom_id"] as! String, resultsPayload["value"] as! String))
        }
    }
}
