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

/// Represents a components type.
public enum ComponentType : Int {
    case actionRow = 1
    case button
    case selectMenu
    case textInput
    case userSelect
    case roleSelect
    case mentionableSelect
    case channelSelect
}

/// Represents a message component. Either a ``Button`` or ``SelectMenu``.
public protocol Component {
    var type: ComponentType { get }
    var customId: String { get }
}

protocol InternalComponent : Component {
    func convert() -> JSON
}

/// Represents the UI components on a message such as a ``Button`` or ``SelectMenu``.
public class UI {
    
    /// The components that make up the UI.
    public internal(set) var items = [Component]()
    
    /// The closure that is called when the UI receives an interaction.
    public internal(set) var onInteraction: ((Interaction) async -> Void) = { _ in }
    
    /// The closure that is called when the `timeout` is reached. By default, this disables all items.
    public internal(set) var onTimeout: (Message?) async -> Void = { msg async in
        if let msg, let ui = msg.ui {
            ui.disableAllItems()
            _ = try? await msg.edit(.ui(ui))
        }
    }
    
    /// The amount of time in seconds for when the UI times out and the `onTimeout` closure is called.
    public let timeout: TimeInterval
    
    /// The message the UI is attached to.
    public internal(set) var attachedMessage: Message? = nil
    
    var timer: Timer? = nil
    
    /// Initializes a UI.
    /// - Parameter timeout: The amount of time in seconds for when the UI times out and the `onTimeout` closure is called.
    public init(timeout: TimeInterval = 120) {
        self.timeout = timeout < 0 ? 120 : timeout
    }
    
    /// Add an item to the UI.
    /// - Returns: The UI instance.
    @discardableResult
    public func addItem(_ item: Component) -> Self {
        // Although text inputs are considered components, they aren't used for
        // message UI's, only for Modals.
        if item.type != .textInput {
            items.append(item)
        }
        return self
    }
    
    /// Remove an item from the UI.
    /// - Parameter identity: The `customId` of the item. If the item you want to remove is a link-styled ``Button``, you must use its URL.
    @discardableResult
    public func removeItem(_ identity: String) -> Self {
        let len = items.count
        items.removeAll(where: { $0.customId == identity })
        
        // if this executes, an item wasn't removed so it's probably a link button
        if items.count == len {
            for btn in items.filter({ $0.type == .button }) {
                if (btn as! Button).url == identity {
                    items.removeAll(where: { ($0 as! Button).url == identity })
                    break
                }
            }
        }
        return self
    }
    
    /// Enable all items on the UI.
    /// - Note: This simply changes all item `disabled` properties on the UI to `false`. In order for the components on the message to be updated,
    ///         you must edit the message with the updated UI.
    public func enableAllItems() {
        for item in items {
            if item.type == .button { (item as! Button).disabled = false }
            if item.type == .selectMenu { (item as! SelectMenu).disabled = false }
        }
    }
    
    /// Disables all items on the UI.
    /// - Note: This simply changes all item `disabled` properties on the UI to `true`. In order for the components on the message to be updated,
    ///         you must edit the message with the updated UI.
    public func disableAllItems() {
        for item in items {
            if item.type == .button { (item as! Button).disabled = true }
            if item.type == .selectMenu { (item as! SelectMenu).disabled = true }
        }
    }
    
    /// Removes all items on the UI.
    /// - Note: This simply removes the components in `items`. In order for the components on the message to be removed,
    ///         you must edit the message with the updated UI.
    public func removeAllItems() {
        items.removeAll()
    }
    
    /// Set the closure that's called when the UI receives an interaction.
    /// - Parameter callback: The closure that's called when the UI receives an interaction.
    /// - Returns: The UI instance.
    public func onInteraction(_ callback: @escaping (Interaction) async -> Void) -> Self {
        onInteraction = callback
        return self
    }
    
    /// Set the closure that's called when the UI times out.
    /// - Parameter callback: The closure that's called when the UI times out.
    /// - Returns: The UI instance.
    public func onTimeout(_ callback: @escaping (Message?) async -> Void) -> Self {
        onTimeout = callback
        return self
    }
    
    func startOnTimeoutTimer() {
        timer?.invalidate()
        DispatchQueue.main.async {
            self.timer = .scheduledTimer(withTimeInterval: self.timeout, repeats: false, block: { _ in
                Task {
                    await self.onTimeout(self.attachedMessage)
                }
            })
        }
    }
    
    func convert() throws -> [JSON] {
        if !items.isEmpty {
            var actionRows = [ActionRow]()
            let grouped = Dictionary(grouping: items, by: { $0.type })
            let btnsFiltered = grouped.filter({ $0.key == .button })
            let menusFiltered = grouped.filter({ $0.key == .selectMenu })
            
            // add all buttons
            for (_, buttons) in btnsFiltered {
                for btnChunk in buttons.chunked(into: 5) {
                    actionRows.append(ActionRow(btnChunk))
                }
            }
            
            // add all select menus
            for (_, menus) in menusFiltered {
                for menu in menus {
                    actionRows.append(ActionRow([menu]))
                }
            }
            
            if actionRows.count > 5 {
                throw UIError.invalidUI("Too many components were attempted to be attached to the message.")
            }
            return ActionRow.convert(actionRows)
        }
        return []
    }
    
    static func setUI(message: Message, ui: UI?) {
        if let ui, let cachedMessage = message.bot!.getMessage(message.id) {
            cachedMessage.ui = ui
            ui.attachedMessage = cachedMessage
            ui.startOnTimeoutTimer()
        }
    }
    
    static func setInteraction(message: Message, ui: UI?) {
        if let ui, let cachedMsg = message.bot!.getMessage(message.id) {
            cachedMsg.ui?.onInteraction = ui.onInteraction
            ui.attachedMessage = cachedMsg
        }
    }
    
    static func convertFromPayload(_ data: [JSON]) -> UI? {
        if !data.isEmpty {
            let ui = UI()
            for actionRow in data {
                for itemObj in actionRow["components"] as! [JSON] {
                    let itemType = ComponentType(rawValue: itemObj["type"] as! Int)!
                    switch itemType {
                    case .button:
                        ui.addItem(Button(itemObj))
                    case .selectMenu:
                        ui.addItem(SelectMenu(itemObj))
                    default:
                        break
                    }
                }
            }
            return ui
        }
        return nil
    }
}

class ActionRow {
    
    var components: [Component]
    
    init(_ components: [Component]) {
        self.components = components
    }
    
    private func convertComponents() -> [JSON] {
        var componentsPayload = [JSON]()
        for component in components as! [InternalComponent] {
            componentsPayload.append(component.convert())
        }
        return componentsPayload
    }
    
    static func convert(_ actionRows: [ActionRow]) -> [JSON] {
        var rowData = [JSON]()
        for ar in actionRows {
            rowData.append(["type": ComponentType.actionRow.rawValue, "components": ar.convertComponents()])
        }
        return rowData
    }
}

/// Represents a message component button.
public class Button : Component, InternalComponent {
    
    /// The components type.
    public let type = ComponentType.button
    
    /// A button style.
    public var style: Style
    
    /// Text that appears on the button; max 80 characters.
    public var label: String?
    
    /// The emoji of the button.
    public var emoji: String?
    
    /// The ID of the button.
    public var customId: String
    
    /// URL for link-style buttons.
    public var url: String?
    
    /// Whether the button is disabled.
    public var disabled: Bool
    
    /**
     Initializes a message component button.
     
     Buttons come in a variety of styles to convey different types of actions. These styles also define what fields are valid for a button.
     - Non-link buttons must have a `customId`, and cannot have a `url`.
     - Link buttons must have a `url`, and cannot have a `customId`.
     - Link buttons do not send an interaction to your app when clicked.
     
     Below are examples on how to create buttons:
     ```swift
     let platforms = UI()
         .addItem(Button(style: .primary, label: "PlayStation", customId: "ps"))
         .addItem(Button(style: .primary, label: "Xbox", customId: "xb"))
         .onInteraction({ interaction async in
             // Convert the data to the proper type
             let data = interaction.data as! MessageComponentData
     
             // Check which button was clicked based on the customId
             if data.customId == "ps" {
                 try! await interaction.respondWithMessage("You chose PlayStation!")
             }
             // ...
         })
     
     try await channel.send("What platform do you play on?", ui: platforms)
     ```
     - Parameters:
        - style: A button style.
        - label: Text that appears on the button; max 80 characters.
        - emoji: The emoji of the button.
        - customId: The ID of the button. This must be unique across **all** components on the message.
        - url: URL for link-style buttons.
        - disabled: Whether the button is disabled.
     */
    public init(style: Style, label: String? = nil, emoji: String? = nil, customId: String? = nil, url: String? = nil, disabled: Bool = false) {
        self.style = style
        self.label = label
        self.emoji = emoji
        
        if style == .link { self.customId = String.empty }
        else { self.customId = customId ?? arc4random().description }
        
        self.url = url
        self.disabled = disabled
    }
    
    init(_ buttonData: JSON) {
        style = Style(rawValue: buttonData["style"] as! Int)!
        label = buttonData["label"] as? String
        
        if let partialEmojiObj = buttonData["emoji"] as? JSON {
            let partial = PartialEmoji(partialEmojiData: partialEmojiObj)
            emoji = partial.description!
        }
        
        customId = (buttonData["custom_id"] as? String) ?? String.empty
        url = buttonData["url"] as? String
        disabled = Conversions.optionalBooltoBool(buttonData["disabled"])
    }
    
    func convert() -> JSON {
        var payload: JSON = ["type": type.rawValue, "style": style.rawValue, "disabled": disabled]
        
        if let label { payload["label"] = label }
        if let emoji { payload["emoji"] = PartialEmoji.fromString(emoji).convert() }
        
        // The lib itself identifies all buttons by their custom ID, but the API itself does not
        // accept link style buttons with a custom ID, so only include the custom ID if it's not
        // a link-styled button. This also applies to the URL.
        if style != .link { payload["custom_id"] = customId }
        if let url, style == .link { payload["url"] = url }
        
        return payload
    }
}

extension Button {
    
    /// Represents a buttons style.
    public enum Style : Int {
        
        /// A button with the color blurple.
        case primary = 1
        
        /// A button with the color grey.
        case secondary
        
        /// A button with the color green.
        case success
        
        /// A button with the color red.
        case danger
        
        /// A button that utilizes a URL (grey in color).
        case link
    }
}

/// Represents a message component select menu.
public class SelectMenu : Component, InternalComponent {
    
    /// The components type.
    public let type = ComponentType.selectMenu
    
    /// Type of select menu.
    public var menuType: MenuType
    
    /// ID for the select menu; max 100 characters.
    public var customId: String

    /// Specified choices in a select menu (only required and available when the `type` is ``MenuType-swift.enum/text``); max 25.
    public var options: [Option]?

    /// Array of channel types to include in the channel select component when the `type` is ``MenuType-swift.enum/channels``.
    public var channelTypes: [ChannelType]?

    /// Placeholder text if nothing is selected; max 150 characters.
    public var placeholder: String?

    /// Minimum number of items that must be chosen; min 0, max 25.
    public var minValues: Int

    /// Maximum number of items that can be chosen; max 25.
    public var maxValues: Int

    /// Whether select menu is disabled.
    public var disabled: Bool
    
    /// Initializes a select menu.
    /// - Parameters:
    ///   - menuType: Type of select menu.
    ///   - customId: ID for the select menu; max 100 characters.
    ///   - options: Specified choices in a select menu (only required and available when the `type` is ``MenuType-swift.enum/text``); max 25.
    ///   - channelTypes: Channel types to include in the channel select component when the `type` is ``MenuType-swift.enum/channels``.
    ///   - placeholder: Placeholder text if nothing is selected; max 150 characters.
    ///   - minValues: Minimum number of items that must be chosen; min 0, max 25.
    ///   - maxValues: Maximum number of items that can be chosen; max 25.
    ///   - disabled: Whether the select menu is disabled.
    public init(
        menuType: MenuType,
        customId: String,
        options: [Option]? = nil,
        channelTypes: [ChannelType]? = nil,
        placeholder: String? = nil,
        minValues: Int = 1,
        maxValues: Int = 1,
        disabled: Bool = false) {
            self.menuType = menuType
            self.customId = customId
            self.options = options
            self.channelTypes = channelTypes
            self.placeholder = placeholder
            self.minValues = minValues
            self.maxValues = maxValues
            self.disabled = disabled
    }
    
    init(_ selectMenuData: JSON) {
        menuType = MenuType(rawValue: selectMenuData["type"] as! Int)!
        customId = selectMenuData["custom_id"] as! String
        
        if let optionsObjs = selectMenuData["options"] as? [JSON] {
            options = []
            for optionsObj in optionsObjs {
                options!.append(Option(optionData: optionsObj))
            }
        }
        
        if let channelTypesNumbers = selectMenuData["channel_types"] as? [Int] {
            var channelTypes = [ChannelType]()
            for number in channelTypesNumbers {
                channelTypes.append(ChannelType(rawValue: number)!)
            }
            self.channelTypes = channelTypes
        }
        
        placeholder = selectMenuData["placeholder"] as? String
        minValues = (selectMenuData["min_values"] as? Int) ?? 1
        maxValues = (selectMenuData["max_values"] as? Int) ?? 1
        disabled = Conversions.optionalBooltoBool(selectMenuData["disabled"])
    }
    
    func convert() -> JSON {
        var payload: JSON = [
            "type": menuType.rawValue,
            "custom_id": customId,
            "min_values": minValues,
            "max_values": maxValues,
            "disabled": disabled
        ]

        if let channelTypes {
            if menuType == .channels {
                payload["channel_types"] = channelTypes.map({ $0.rawValue })
            }
        }
        if let placeholder {
            payload["placeholder"] = placeholder
        }
        if let options {
            if menuType == .text {
                payload["options"] = options.map({ $0.convert() })
            }
        }
        
        return payload
    }
}

extension SelectMenu {
    
    /// Represents a select menus option.
    public class Option {
        
        /// User-facing name of the option; max 100 characters.
        public var label: String
        
        /// Value of the option. This is not shown to the user. Max 100 characters.
        public var value: String
        
        /// Additional description of the option; max 100 characters.
        public var description: String?
        
        /// Emoji for the option. Only used when the ``SelectMenu/menuType-swift.property`` is ``SelectMenu/MenuType-swift.enum/text``.
        public var emoji: PartialEmoji?
        
        /// Whether this option will show as selected by default.
        public var `default`: Bool
        
        /// Initializes an option for a select menu.
        /// - Parameters:
        ///   - label: User-facing name of the option; max 100 characters.
        ///   - value: Value of the option. This is not shown to the user. Max 100 characters. If `nil`, it's set to whatever `label` is set to.
        ///   - description: Additional description of the option; max 100 characters.
        ///   - emoji: Emoji for the emoji.
        ///   - default: Whether this option will show as selected by default.
        public init(label: String, value: String? = nil, description: String? = nil, emoji: PartialEmoji? = nil, `default`: Bool = false) {
            self.label = label
            self.value = value ?? label
            self.description = description
            self.emoji = emoji
            self.default = `default`
        }
        
        init(optionData: JSON) {
            label = optionData["label"] as! String
            value = optionData["value"] as! String
            description = optionData["description"] as? String
            
            if let emojiObj = optionData["emoji"] as? JSON { emoji = PartialEmoji(partialEmojiData: emojiObj) }
            
            if optionData.contains(where: { $0.key == "default" }) {
                self.default = optionData["default"] as! Bool
            } else {
                self.default = false
            }
        }
        
        func convert() -> JSON {
            var payload: JSON = ["label": label, "value": value, "default": self.default]
            
            if let description { payload["description"] = description }
            if let emoji { payload["emoji"] = emoji.convert() }
            
            return payload
        }
    }
    
    /// Represents a select menus type.
    public enum MenuType : Int {
        case text = 3
        case user = 5
        case role = 6
        case mentionable = 7
        case channels = 8
    }
}

/// Represents a modal text input.
public class TextInput : Component, InternalComponent {
    
    /// The components type.
    public let type = ComponentType.textInput
    
    /// ID of the text input; max 100 characters.
    public var customId: String
    
    /// The text input style.
    public var style: Style
    
    /// Label for this component; max 45 characters.
    public var label: String
    
    /// Minimum input length for a text input; min 0, max 4000.
    public var minLength: Int
    
    /// Maximum input length for a text input; min 1, max 4000.
    public var maxLength: Int
    
    /// Whether this component is required to be filled.
    public var required: Bool
    
    /// Pre-filled value for this component; max 4000 characters.
    public var value: String?
    
    /// Custom placeholder text if the input is empty; max 100 characters.
    public var placeholder: String?
    
    /// Always `nil` for this component type.
    public let onInteraction: ((Interaction) async -> Void)? = nil
    
    /// Initializes a text input.
    /// - Parameters:
    ///   - label: Label for this component; max 45 characters.
    ///   - style: The text input style.
    ///   - customId: ID of the text input; max 100 characters.
    ///   - minLength: Minimum input length for a text input; min 0, max 4000.
    ///   - maxLength: Maximum input length for a text input; min 1, max 4000.
    ///   - required: Whether this component is required to be filled.
    ///   - value: Pre-filled value for this component; max 4000 characters.
    ///   - placeholder: Custom placeholder text if the input is empty; max 100 characters.
    public init(label: String, style: Style, customId: String, minLength: Int = 0, maxLength: Int = 4000, required: Bool = true, value: String? = nil, placeholder: String? = nil) {
        self.style = style
        self.label = label
        self.customId = customId
        self.minLength = minLength
        self.maxLength = maxLength
        self.required = required
        self.value = value
        self.placeholder = placeholder
    }
    
    func convert() -> JSON {
        var payload: JSON = [
            "type": type.rawValue,
            "custom_id": customId,
            "style": style.rawValue,
            "label": label,
            "required": required,
            "min_length": minLength,
            "max_length": maxLength
        ]
        
        if let value { payload["value"] = value }
        if let placeholder { payload["placeholder"] = placeholder }
        
        return payload
    }
}

extension TextInput {
    
    /// Represents a text input style.
    public enum Style : Int {
        
        /// Single-line input.
        case short = 1
        
        /// Multi-line input.
        case paragraph
    }
}

/// Represents a pop-up modal.
public struct Modal {
    
    /// Title of the modal; max 45 characters.
    public var title: String
    
    /// ID of the modal.
    public var customId: String
    
    /// Inputs on the modal; max 5.
    public var inputs: [TextInput]
    
    /// The closure that is called when the modal is submitted.
    public var onSubmit: (Interaction) async -> Void
    
    /// Initializes a pop-up modal.
    /// - Parameters:
    ///   - title: Title of the modal; max 45 characters.
    ///   - customId: ID of the modal.
    ///   - inputs: Inputs on the modal; max 5.
    ///   - onSubmit: The closure that is called when the modal is submitted.
    public init(title: String, customId: String, inputs: [TextInput], onSubmit: @escaping (Interaction) async -> Void) {
        self.title = title
        self.customId = customId
        self.inputs = inputs
        self.onSubmit = onSubmit
    }
    
    func convert() -> JSON {
        // The modal "components" field acts like an action row
        let falseRow = ActionRow(inputs)
        let payload: JSON = [
            "title": title,
            "custom_id": customId,
            "components": ActionRow.convert([falseRow])
        ]
        return payload
    }
}
