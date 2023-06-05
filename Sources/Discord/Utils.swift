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

/**
 Get the value for a variable in your environment. This is typically used to retrieve your Discord bot token, but can be used for anything.
 
 ```swift
 let bot = Discord(token: getVariable("TOKEN")!, intents: Intents.default)
 ```
 - Parameter variable: The environment variable.
 - Returns: The value associated with the variable, or `nil` if not found.
 */
public func getVariable(_ variable: String) -> String? {
    return ProcessInfo.processInfo.environment[variable]
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
    ///   - language: The coding language the text should be converted into.
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
    /// Various mardowns will be escaped as follows:
    /// - A channel mention (`#general`), will be converted to <#1234567891234567>.
    /// - The word **bolded** will be converted to \*\*bolded\*\*
    /// - An `@everyone` ping will be converted to raw @everyone and will not ping everyone.
    /// - A guild emoji (😂) will be converted to <:laughing:1234567891234567> etc.
    ///
    /// - Parameter text: The text to escape.
    /// - Returns: The escaped text.
    public static func escape(_ text: String) -> String {
        // - bullet points
        // # headers
        // * bold|italics
        // ~ strikethrough
        // > quote, (user|role|channel) mentions
        // ` code
        // | spoiler
        // _ underline
        // : guild emoji, url
        // @ everyone|here mentions
        text.replacing(#/[@*~>`|_:\-\#]/#, with: { match -> String in
            if match.description == "@" {
                let zeroWidthSpace = "\u{200b}"
                return "@\(zeroWidthSpace)"
            } else {
                return "\\\(match.description)"
            }
        })
    }
    
    /// Converts to text to a formatted header.
    /// - Parameters:
    ///   - size: Size of the header (1-3). 1 = big, 2 = medium, 3 = small.
    ///   - text: The text to format.
    /// - Returns: The formatted text.
    public static func header(size: Int, _ text: String) -> String {
        let size = size < 1 ? 1 : min(size, 3)
        let headers = Array(repeating: "#", count: size).joined()
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
    /// - Returns: The masked link.
    public static func maskedLink(title: String, url: String) -> String { "[\(title)](<\(url)>)" }
    
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
    /// - Returns: A Discord formatted timestamp.
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

/// Get the OAuth2 URL for inviting the bot.
/// - Parameters:
///   - botId: The bot ID.
///   - permissions: Permissions you're requesting the bot to have.
///   - guildId: The guild to select on the authorization form.
///   - disableGuildSelect: Whether the user can change the guild shown in the dropdown.
///   - scopes: A set of scopes.
///   - redirectUri: The redirect URI.
///   - state: The unique state.
/// - Returns: The OAuth2 URL.
public func oauth2Url(
    botId: Snowflake,
    permissions: Permissions = .none,
    guildId: Snowflake? = nil,
    disableGuildSelect: Bool = false,
    scopes: Set<OAuth2Scopes> = [.bot, .applicationsCommands],
    redirectUri: String? = nil,
    state: String? = nil) -> String {
        var url = URL(string: "https://discord.com/oauth2/authorize?client_id=\(botId)")!
        url.append(queryItems: [
            .init(name: "disable_guild_select", value: disableGuildSelect.description),
            .init(name: "permissions", value: permissions.value.description),
            .init(name: "scope", value: scopes.map({ $0.rawValue }).joined(separator: "+"))
        ])
        
        if let guildId {
            url.append(queryItems: [.init(name: "guild_id", value: guildId.description)])
        }
        if let redirectUri {
            url.append(queryItems: [
                .init(name: "response_type", value: "code"),
                .init(name: "redirect_uri", value: redirectUri.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed))
            ])
        }
        if let state {
            url.append(queryItems: [.init(name: "state", value: state)])
        }
        
        return url.absoluteString
}

/// Suspend execution for the provided amount of time.
/// - Parameter milliseconds: The amount of milliseconds to suspend execution.
public func sleep(_ milliseconds: Int) async {
    try? await Task.sleep(nanoseconds: UInt64(milliseconds * 1_000_000))
}

/// Convert the snowflake to the date it represents.
/// - Parameter snowflake: The snowflake to convert.
/// - Returns: The snowflake converted into a `Date`.
public func snowflakeDate(_ snowflake: Snowflake) -> Date {
    let timestamp = ((snowflake >> 22) + discordEpoch) / 1000
    return Date(timeIntervalSince1970: Double(timestamp))
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

extension String {
    
    /// An empty string.
    static let empty = ""
}

extension Date {
    
    var asISO8601: String { ISO8601DateFormatter().string(from: self) }

    /// Converts the date to a Discord snowflake.
    public var asSnowflake: Snowflake {
        get {
            let timestamp = Snowflake(Snowflake(self.timeIntervalSince1970) * 1000 - discordEpoch)
            return (timestamp << 22) + Snowflake(pow(2.0, 22.0))
        }
    }
}

extension Sequence<EventListener> {
    func forEachAsync(_ operation: @escaping (Element) async -> Void) {
        for element in self {
            guard element.isEnabled else { continue }
            Task { await operation(element) }
        }
    }
}

// MARK: Conversions

struct Conversions {
    
    static func strArraySnowflakeToSnowflake(_ arrayIds: [String]) -> [Snowflake] {
        var ids = [Snowflake]()
        for id in ids { ids.append(Conversions.snowflakeToUInt(id)) }
        return ids
    }
    
    static func optionalBooltoBool(_ optionalAny: Any?) -> Bool {
        return optionalAny == nil ? false : optionalAny as! Bool
    }

    static func snowflakeToUInt(_ optionalAny: Any?) -> UInt {
        let str = optionalAny as! String
        return UInt(str)!
    }

    static func snowflakeToOptionalUInt(_ optionalAny: Any?) -> UInt? {
        guard let str = optionalAny as? String else {
            return nil
        }
        return UInt(str)
    }

    static func defaultUserAvatar(discriminator: String) -> String {
        return String(Int(discriminator)! % 5) + ".png"
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
    static private var enabled: Bool { ProcessInfo.processInfo.environment["D.SWIFT_INTERNAL_LOG"] != nil ? true : false }
    
    static func message(_ message: Any, withTimestamp: Bool = false) {
        if enabled {
            print("[LOG]" + (withTimestamp == true ? " <\(Date.now.formatted(date: .abbreviated, time: .standard))> " : " ") + String(describing: message))
        }
    }
    
    static func notification(_ message: String, level: AlertLevel) {
        print("[Discord.swift Notification] - \(level.rawValue) \(message)")
    }
    
    static func fatal(_ message: String) -> Never {
        fatalError(message)
    }
}

extension Log {
    enum AlertLevel : String {
        case normal = ""
        case attention = "🟡"
        case warning = "🔴"
    }
}
