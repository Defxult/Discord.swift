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

/// Represents Discords events that are dispatched.
public enum Intents : Int, CaseIterable {
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `guildCreate`
     - `guildUpdate`
     - `guildUnavailable`
     - `guildRoleCreate`
     - `guildRoleUpdate`
     - `guildRoleDelete`
     - `channelCreate`
     - `channelUpdate`
     - `channelDelete`
     - `channelPinsUpdate`
     - `threadCreate`
     - `threadUpdate`
     - `threadDelete`
     - `threadListSync`
     - `threadMemberAdd`
     - `threadMemberRemove`
     - `stageInstanceCreate`
     - `stageInstanceUpdate`
     - `stageInstanceDelete`
     */
    case guilds = 1
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `guildMemberJoin`
     - `guildMemberUpdate`
     - `guildMemberRemove`
     - `threadMemberAdd`
     - `threadMemberRemove`
     */
    case guildMembers = 2
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `guildAuditLogCreate`
     - `guildBan`
     - `guildUnban`
     */
    case guildModeration = 4
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `guildEmojisUpdate`
     - `guildStickersUpdate`
     */
    case guildEmojisAndStickers = 8
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `guildIntegrationsUpdate`
     - `integrationCreate`
     - `integrationUpdate`
     - `integrationDelete`
     */
    case guildIntegrations = 16
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `webhooksUpdate`
     */
    case guildWebhooks = 32

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `inviteCreate`
     - `inviteDelete`
     */
    case guildInvites = 64

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `voiceStateUpdate`
     */
    case guildVoiceStates = 128

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `presenceUpdate`
     */
    case guildPresences = 256

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `messageCreate`
     - `messageUpdate`
     - `messageDelete`
     - `messageDeleteBulk`
     */
    case guildMessages = 512

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `messageReactionAdd`
     - `messageReactionRemove`
     - `messageReactionRemoveAll`
     - `messageReactionRemoveEmoji`
     */
    case guildMessageReactions = 1024

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `typingStart`
     */
    case guildMessageTyping = 2048

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `messageCreate`
     - `messageUpdate`
     - `messageDelete`
     - `channelPinsUpdate`
     */
    case dmMessages = 4096

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `messageReactionAdd`
     - `messageReactionRemove`
     - `messageReactionRemoveAll`
     - `messageReactionRemoveEmoji`
     */
    case dmReactions = 8192

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `typingStart`
     */
    case dmTyping = 16384

    /**
     Enables the message content to be sent with a message.
     
     - Important: Enabling this intent in code will not suffice. You need to manually go into your [developer portal](https://discord.com/developers/applications) and enable the "Message Content Intent" button.
     */
    case messageContent = 32768

    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `guildScheduledEventCreate`
     - `guildScheduledEventUpdate`
     - `guildScheduledEventDelete`
     - `guildScheduledEventUserAdd`
     - `guildScheduledEventUserRemove`
     */
    case guildScheduledEvents = 65536
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `autoModerationRuleCreate`
     - `autoModerationRuleUpdate`
     - `autoModerationRuleDelete`
     */
    case autoModerationConfiguration = 1048576
    
    /**
     Enabling this intent allows the following events to be dispatched:
     
     **Events**
     - `autoModerationActionExecution`
     */
    case autoModerationExecution = 2097152
    
    /// Enables all intents.
    public static let all: Set<Intents> = Set<Intents>().union(Intents.allCases)
    
    /// All intents enabled except ``dmTyping``, & ``guildMessageTyping``.
    public static let `default`: Set<Intents> = Intents.all(except: [.dmTyping, .guildMessageTyping])
    
    /// Disables all intents.
    public static let none: Set<Intents> = []
    
    /// Enables all intents except the ones specified.
    /// - Parameter except: The intents to exclude.
    /// - Returns: All intents enabled excluding the ones in parameter `except`.
    public static func all(except: Set<Intents>) -> Set<Intents> {
        return Set<Intents>(Intents.allCases).filter({ !except.contains($0) })
    }

    static func convert(_ intents: Set<Intents>) -> Int {
        var value = 0
        for intent in intents {
            value |= intent.rawValue
        }
        return value
    }
}
