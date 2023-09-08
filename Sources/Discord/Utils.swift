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

/// Discord's Unix timestamp, the first second of 2015.
public let discordEpoch: Snowflake = 1420070400000

/// Represents a Discord ID.
public typealias Snowflake = UInt

/// Represents a base Discord object.
public protocol Object {
    
    /// The ID of the object.
    var id: Snowflake { get }
}

/// Constructs a channel link.
/// - Parameters:
///   - guildId: Guild ID of the channel.
///   - channelId: The channel ID.
/// - Returns: A URL for the channel.
public func channelLink(guildId: Snowflake, channelId: Snowflake) -> String {
    "https://discord.com/channels/\(guildId)/\(channelId)"
}

/**
 Get the value for a variable in your environment. This is typically used to retrieve your Discord bot token, but can be used for anything.
 
 ```swift
 let bot = Bot(token: getVariable("TOKEN")!, intents: Intents.default)
 ```
 - Parameter variable: The environment variable.
 - Returns: The value associated with the variable, or `nil` if not found.
 */
public func getVariable(_ variable: String) -> String? {
    ProcessInfo.processInfo.environment[variable]
}

/// Constructs a message link.
/// - Parameters:
///   - guildId: Guild ID of the message.
///   - channelId: Channel ID of the message.
///   - messageId: The message ID.
/// - Returns: A URL for the message.
public func messageLink(guildId: Snowflake, channelId: Snowflake, messageId: Snowflake) -> String {
    "https://discord.com/channels/\(guildId)/\(channelId)/\(messageId)"
}

/// Contains all methods related to Discords markdown capabilites.
public struct Markdown {
    
    /// Converts the text to a formatted block quote.
    /// - Parameters:
    ///   - text: The text to block quote.
    ///   - multiline: Whether the text should be wrapped entirely in a block quote. If `false`, only the first line will be in a block quote.
    /// - Returns: The formatted block quote.
    public static func blockQuote(_ text: String, multiline: Bool = true) -> String { multiline ? ">>> \(text)" : "> \(text)" }
    
    /// Bolds the given text.
    /// - Parameter text: The text to bold.
    /// - Returns: The bolded text.
    public static func bold(_ text: String) -> String { "**\(text)**" }
        
    /// Converts the code into a formatted code block for the desired language.
    /// - Parameters:
    ///   - language: The language the text should be converted into.
    ///   - code: The code itself.
    /// - Returns: A formatted code block.
    public static func codeBlock(language: String? = nil, _ code: String) -> String { "```\(language ?? .empty)\n\(code)\n```" }
    
    /// Converts the parameters to a custom guild emoji.
    /// - Parameters:
    ///   - name: Name of the custom emoji.
    ///   - id: ID of the custom emoji.
    ///   - animated: Whether the custom emoji is animated.
    /// - Returns: The custom emoji.
    public static func customEmoji(name: String, id: Snowflake, animated: Bool) -> String { "<\(animated ? "a" : .empty):\(name):\(id)>" }
    
    /// Escapes all markdowns and returns the raw text.
    ///
    /// Various mardowns will be escaped. Here are just a few examples:
    /// - A channel mention (`#general`), will be converted to <#1234567891234567>.
    /// - The word **bolded** will be converted to \*\*bolded\*\*
    /// - An `@everyone` ping will be converted to raw @everyone and will not ping everyone.
    /// - A guild emoji (😂) will be converted to <:laughing:1234567891234567>.
    ///
    /// - Parameters:
    ///   - text: The text to escape.
    ///   - ignoreUrls: Whether to prevent URLs from being escaped.
    ///   - style: Various styles of escaping the text.
    ///     - 1: The normal escape style.
    ///     - 2: Wrap the entire text in a codeblock.
    /// - Returns: The escaped text.
    public static func escape(_ text: String, ignoreUrls: Bool = true, style: Int = 1) -> String {
        // - bullet points
        // # headers
        // * bold|italics|bullet points
        // ~ strikethrough
        // > quote/quote block/guild emojis/(user|role|channel|slash cmd) mentions
        // ` inline code/code block
        // | spoiler tags
        // _ underline
        // : normal emojis
        // @everyone|here mentions
        
        func addZeroSpace(_ txt: String) -> String {
            let zeroWidthSpace = "\u{200b}"
            return "@\(zeroWidthSpace)" + (txt.contains("everyone") ? "everyone" : "here")
        }
        
        if style == 1 {
            if ignoreUrls {
                let ignoreRegex = #/(?:https?://\S+|w{3}\.\S+)|@(everyone|here)|[:*~>`|_\-#]/#
                return text.replacing(ignoreRegex, with: { match -> String in
                    let v = match.output.0
                    if v.starts(with: "http") { return v.description }
                    else if v.contains("@") { return addZeroSpace(v.description) }
                    else { return "\\\(v)" }
                })
                
            } else {
                let regex = #/[:*~>`|_\-#]|@(everyone|here)/#
                return text.replacing(regex, with: { match -> String in
                    let v = match.output.0
                    if v.contains("@") { return addZeroSpace(v.description) }
                    else { return "\\\(v)" }
                })
            }
        }
        else if style == 2 {
            return codeBlock(text)
        }
        else {
            return text
        }
    }
    
    /// Converts the text to a formatted header.
    /// - Parameters:
    ///   - size: Size of the header (1-3). 1 = big, 2 = medium, 3 = small.
    ///   - text: The text to format.
    /// - Returns: The formatted text.
    public static func header(size: Int, _ text: String) -> String {
        let size = size < 1 ? 1 : min(size, 3)
        let headers = String(repeating: "#", count: size)
        return "\(headers) \(text)"
    }
    
    /// Converts the code into a formatted inline code.
    /// - Parameter code: The code itself.
    /// - Returns: The formatted inline code.
    public static func inlineCode(_ code: String) -> String { "`\(code)`" }
    
    /// Italicizes the given text.
    /// - Parameter text: The text to italicize.
    /// - Returns: The italicized text.
    public static func italic(_ text: String) -> String { "*\(text)*" }
    
    /// Converts the given items into a formatted bullet point list. This does not support bullet point indentation for inner bullet points.
    /// - Parameter items: The items in the list.
    /// - Returns: A bullet point list.
    public static func list(_ items: any Sequence<String>) -> String { items.map({ "- \($0)" }).joined(separator: "\n") }
    
    /// Masks the given link.
    /// - Parameters:
    ///   - title: Title of the masked link. This is what is displayed in Discord.
    ///   - url: The URL of the link.
    ///   - suppressEmbed: Whether to suppress the link embed.
    /// - Returns: The masked link.
    public static func maskedLink(title: String, url: String, suppressEmbed: Bool = true) -> String {
        "[\(title)](\(suppressEmbed ? suppressLinkEmbed(url: url) : url))"
    }
    
    /// Mentions the channel.
    /// - Parameter id: ID of the channel.
    /// - Returns: The channel in a mentioned format.
    public static func mentionChannel(id: Snowflake) -> String { "<#\(id)>" }
    
    /// Mentions the role.
    /// - Parameter id: ID of the role.
    /// - Returns: The role in a mentioned format.
    public static func mentionRole(id: Snowflake) -> String { "<@&\(id)>" }
    
    /**
     Mentions the slash command.
     
     Subcommands and subcommand groups can also be mentioned by using names respectively:
     ```swift
     // This is the command: /tag get <name>
     let mention = Markdown.mentionSlashCommand("tag get", id: 1234567890123456789)
     ```
     - Parameters:
        - name: Name of the slash command.
        - id: ID of the slash command.
     - Returns: The slash command in a mentioned format.
     */
    public static func mentionSlashCommand(name: String, id: Snowflake) -> String { "</\(name):\(id)>" }
    
    /// Mentions the user.
    /// - Parameter id: ID of the user.
    /// - Returns: The user in a mentioned format.
    public static func mentionUser(id: Snowflake) -> String { "<@\(id)>" }
    
    /// Wraps the given text in spoiler tags.
    /// - Parameter text: The text to wrap.
    /// - Returns: The wrapped text.
    public static func spoiler(_ text: String) -> String { "||\(text)||" }
    
    /// Prevents the website embed from being displayed when a URL is posted.
    /// - Parameter url: The URL.
    /// - Returns: The suppressed URL.
    public static func suppressLinkEmbed(url: String) -> String { "<\(url)>" }
    
    /// Converts the text into a formatted strikethrough.
    /// - Parameter text: The text to strikethrough.
    /// - Returns: The formatted text.
    public static func strikethrough(_ text: String) -> String { "~~\(text)~~" }
    
    /// Format a date to a Discord timestamp that will display the given timestamp in the user's timezone and locale.
    /// - Parameters:
    ///   - date: Date to format.
    ///   - style: The `date` style.
    /// - Returns: The formatted timestamp.
    public static func timestamp(date: Date, style: TimestampStyle = .f) -> String {
        "<t:\(Int(date.timeIntervalSince1970)):\(style.rawValue)>"
    }
    
    /// Underlines the given text.
    /// - Parameter text: The text to underline.
    /// - Returns: The underlined text.
    public static func underline(_ text: String) -> String { "__\(text)__" }
}

extension Markdown {
    
    /// Represents a Discord timestamp. Timestamps will display the given timestamp in the user's timezone and locale.
    public enum TimestampStyle : String {
        
        /// Short Time (16:20)
        case t = "t"
        
        /// Long Time (16:20:30)
        case T = "T"
        
        /// Short Date (20/04/2021)
        case d = "d"
        
        /// Long Date (20 April 2021)
        case D = "D"
        
        /// Short Date/Time (20 April 2021 16:20)
        case f = "f"
        
        /// Long Date/Time (Tuesday, 20 April 2021 16:20)
        case F = "F"
        
        /// Relative Time (2 months ago)
        case R = "R"
    }
}

/// Suspend execution for the provided amount of time.
/// - Parameter milliseconds: The amount of milliseconds to suspend execution.
public func sleep(_ milliseconds: Int) async {
    try? await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
}

// MARK: Public global extensions

extension Array {
    
    /**
     Retrieve an arrays elements into n sized groups.
     
     ```swift
     let numbers = [1, 2, 3, 4, 5, 6]
     for chunk in numbers.chunked(into: 2) {
         print(chunk)
     
         // 1st iteration - Prints [1, 2]
         // 2nd iteration - Prints [3, 4]
         // 3rd iteration - Prints [5, 6]
     }
     ```
     */
    public func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

// MARK: Private global extensions

extension Date {
    
    var asISO8601: String { ISO8601DateFormatter().string(from: self) }

    /// Converts the date to a Discord snowflake.
    public var asSnowflake: Snowflake {
        let timestamp = Snowflake(Snowflake(self.timeIntervalSince1970) * 1000 - discordEpoch)
        return (timestamp << 22) + Snowflake(pow(2.0, 22.0))
    }
}

// MARK: Conversions

struct Conversions {
    
    static func bitfield(_ seq: any Sequence<Int>) -> Int {
        var value = 0
        seq.forEach({ i in
            value |= i
        })
        return value
    }
    
    static func strArraySnowflakeToSnowflake(_ arrayIds: [String]) -> [Snowflake] {
        var ids = [Snowflake]()
        for id in ids { ids.append(Conversions.snowflakeToUInt(id)) }
        return ids
    }
    
    static func optionalBooltoBool(_ optionalAny: Any?) -> Bool {
        return optionalAny == nil ? false : optionalAny as! Bool
    }

    static func snowflakeToUInt(_ value: Any?) -> UInt {
        if let n = value as? String {
            return UInt(n)!
        } else {
            return value as! UInt
        }
    }

    static func snowflakeToOptionalUInt(_ optionalAny: Any?) -> UInt? {
        guard let str = optionalAny as? String else {
            return nil
        }
        return UInt(str)
    }

    static func defaultUserAvatar(discriminator: String, userId: Snowflake) -> String {
        var value: String
        if User.migrated(discriminator) {
            value = ((userId >> 22) % 6).description
        } else {
            value = (Int(discriminator)! % 5).description
        }
        return value + ".png"
    }
    
    static func stringDateToDate(iso8601: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        
        // Certain member `joined_at` dates come in different formats
        // (1) 2020-09-18T05:17:55.815000+00:00
        //               or
        // (2) 2020-09-18T05:17:55+00:00
        // When the date from discord comes in as (1), using ISO8601DateFormatter(), it works fine.
        // But when the date comes in as (2), it's missing the the extra parameters that .withFractionalSeconds expects.
        // So this basically adds the extra zero's to match .withFractionalSeconds
        
        // A cleaner way to do this would be with a RegEx, but...this works too
        if iso8601.count == "2022-05-11T20:08:47.860000+00:00".count {
            return formatter.date(from: iso8601)
        }
        else {
            let range = iso8601.range(of: "+00:00")!
            var iso = iso8601
            iso.replaceSubrange(range, with: ".000000+00:00")
            return formatter.date(from: iso)
        }
    }
}

// MARK: Log
struct Log {
    static private var enabled: Bool { ProcessInfo.processInfo.environment["d.swift-internal-logging"] != nil ? true : false }
    
    static func message(_ message: Any, withTimestamp: Bool = true) {
        if enabled {
            let now = Date().description.replacingOccurrences(of: " +0000", with: String.empty)
            print("[LOG]" + (withTimestamp ? " [\(now)] " : " ") + String(describing: message))
        }
    }
    
    static func fatal(_ message: String) -> Never {
        fatalError(message)
    }
}

// MARK: Other

extension String {
    static var empty: String { "" }
}

typealias JSON = [String: Any]

protocol Updateable {
    func update(_ data: JSON)
}
