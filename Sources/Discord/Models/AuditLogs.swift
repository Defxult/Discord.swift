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

/// Represents a guilds audit log.
public struct AuditLog {

    /// Audit log entries, sorted from most to least recent.
    public private(set) var entries = [Entry]()
    
    init(auditLogData: JSON) {
        for entryObj in auditLogData["audit_log_entries"] as! [JSON] {
            entries.append(Entry(entryData: entryObj))
        }
    }
    
    // Unlike `init(auditLogData:)`, this contains a single entry
    init(auditLogDataFromGateway: JSON) {
        entries.append(Entry(entryData: auditLogDataFromGateway))
    }
}

extension AuditLog {

    /// Represents a single administrative action.
    public struct Entry : Object {
        
        /// ID of the affected entity (webhook, user, role, etc.)
        public let targetId: Snowflake?
        
        /// Changes made to the `targetId`.
        public private(set) var changes = [Change]()
        
        /// User or app that made the changes.
        public let userId: Snowflake?
        
        /// ID of the entry.
        public let id: Snowflake
        
        /// Type of action that occurred.
        public let actionType: Action?
        
        /// Reason for the change.
        public let reason: String?

        init(entryData: JSON) {
            targetId = Conversions.snowflakeToOptionalUInt(entryData["target_id"])
            userId = Conversions.snowflakeToOptionalUInt(entryData["user_id"])
            id = Conversions.snowflakeToUInt(entryData["id"])
            actionType = Action(rawValue: entryData["action_type"] as! Int)
            reason = entryData["reason"] as? String
            
            let changesContainer = (entryData["changes"] as? [JSON]) ?? []
            for changesDict in changesContainer {
                changes.append(Change(changeData: changesDict))
            }
        }
    }

    /// Represents the values that were changed according to the audit logs entry.
    public struct Change {
        
        /// Old value of the key. If this is `nil`, that indicates that the property was not set.
        public let before: Any?
        
        /// New value of the key. If this is `nil` but `before` contains a value, that indicates that the property has been reset.
        public let after: Any?
        
        /// Name of the changed entity.
        public let key: String

        init(changeData: JSON) {
            before = changeData["old_value"]
            after = changeData["new_value"]
            key = changeData["key"] as! String
        }
    }

    /// Represents an action taken in the guild.
    public enum Action : Int, CaseIterable {
        
        /// Guild settings were updated.
        case guildUpdate = 1
        
        /// Channel was created.
        case channelCreate = 10
        
        /// Channel settings were updated.
        case channelUpdate = 11
        
        /// Channel was deleted.
        case channelDelete = 12
        
        /// Permission overwrite was added to a channel.
        case channelOverwriteCreate = 13
        
        /// Permission overwrite was updated for a channel.
        case channelOverwriteUpdate = 14
        
        /// Permission overwrite was deleted from a channel.
        case channelOverwriteDelete = 15
        
        /// Member was removed from the guild.
        case memberKick = 20
        
        /// Members were pruned from the guild
        case memberPrune = 21
        
        /// Member was banned from the guild.
        case memberBanAdd = 22
        
        /// Guild ban was lifted for a member.
        case memberBanRemove = 23
        
        /// Member was updated in guild.
        case memberUpdate = 24
        
        /// Member was added or removed from a role.
        case memberRoleUpdate = 25
        
        /// Member was moved to a different voice channel.
        case memberMove = 26
        
        /// Member was disconnected from a voice channel.
        case memberDisconnect = 27
        
        /// Bot user was added to guild.
        case botAdd = 28
        
        /// Role was created.
        case roleCreate = 30
        
        /// Role was edited.
        case roleUpdate = 31
        
        /// Role was deleted.
        case roleDelete = 32
        
        /// Guild invite was created.
        case inviteCreate = 40
        
        /// Guild invite was updated.
        case inviteUpdate = 41
        
        /// Guild invite was deleted.
        case inviteDelete = 42
        
        /// Webhook was created.
        case webhookCreate = 50
        
        /// Webhook properties or channel were updated.
        case webhookUpdate = 51
        
        /// Webhook was deleted.
        case webhookDelete = 52
        
        /// Emoji was created.
        case emojiCreate = 60
        
        /// Emoji name was updated.
        case emojiUpdate = 61
        
        /// Emoji was deleted.
        case emojiDelete = 62
        
        /// Single message was deleted.
        case messageDelete = 72
        
        /// Multiple messages were deleted.
        case messageBulkDelete = 73
        
        /// Message was pinned to a channel.
        case messagePin = 74
        
        /// Message was unpinned from a channel.
        case messageUnpin = 75
        
        /// App was added to guild.
        case integrationCreate = 80
        
        /// App was updated (as an example, its scopes were updated).
        case integrationUpdate = 81
        
        /// App was removed from guild.
        case integrationDelete = 82
        
        /// Stage instance was created (stage channel becomes live).
        case stageInstanceCreate = 83
        
        /// Stage instance details were updated.
        case stageInstanceUpdate = 84
        
        /// Stage instance was deleted (stage channel no longer live).
        case stageInstanceDelete = 85
        
        /// Sticker was created.
        case stickerCreate = 90
        
        /// Sticker details were updated.
        case stickerUpdate = 91
        
        /// Sticker was deleted.
        case stickerDelete = 92
        
        /// Event was created.
        case guildScheduledEventCreate = 100
        
        /// Event was updated.
        case guildScheduledEventUpdate = 101
        
        /// Event was cancelled.
        case guildScheduledEventDelete = 102
        
        /// Thread was created in a channel.
        case threadCreate = 110
        
        /// Thread was updated.
        case threadUpdate = 111
        
        /// Thread was deleted.
        case threadDelete = 112
        
        /// Permissions were updated for a command.
        case applicationCommandPermissionUpdate = 121
        
        /// Auto Moderation rule was created.
        case autoModerationRuleCreate = 140
        
        /// Auto Moderation rule was updated.
        case autoModerationRuleUpdate = 141
        
        /// Auto Moderation rule was deleted.
        case autoModerationRuleDelete = 142
        
        /// Message was blocked by Auto Moderation (according to a rule).
        case autoModerationBlockMessage = 143
        
        /// Message was flagged by Auto Moderation.
        case autoModerationFlagToChannel = 144
        
        /// Member was timed out by Auto Moderation.
        case autoModerationUserCommunicationDisabled = 145
    }
}
