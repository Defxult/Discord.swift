## 0.0.4-alpha
Pending Release

#### New Features
- Added struct `Markdown`. This contains all methods related to markdowns. The following has been added:
  - `Markdown.blockQuote()`
  - `Markdown.bold()`
  - `Markdown.codeBlock()`
  - `Markdown.customEmoji()`
  - `Markdown.header()`
  - `Markdown.inlineCode()`
  - `Markdown.list()`
  - `Markdown.maskedLink()`
  - `Markdown.mentionChannel()`
  - `Markdown.mentionRole()`
  - `Markdown.mentionSlashCommand()`
  - `Markdown.mentionUser()`
  - `Markdown.spoiler()`
  - `Markdown.suppressLinkEmbed()`
  - `Markdown.strikethrough()`
  - `Markdown.underline()`

#### Bug Fixes
- Fixed property `Emoji.url` returning a .png URL even when the emoji was animated (.gif).

#### Updated
- With the addition of `Markdown`, the following has been changed:
  - **(Breaking Change)** Function `clean()` was renamed to `escape` and is now under `Markdown.escape()`.
  - **(Breaking Change)** Function `formatTimestamp()` was renamed to `timestamp` and is now under `Markdown.timestamp()`.
  - **(Breaking Change)** Enum `TimestampStyle` is now under `Markdown.TimestampStyle`.



## [0.0.3-alpha](https://github.com/Defxult/Discord.swift/tree/0.0.3-alpha)
Released on June 1, 2023.

#### New Features
- Added method `Discord.waitUntilReady()`.
- Added method `File.download()`. 

#### Bug Fixes
- Fixed event listener `onReady()` not being dispatched when certain intents were missing.
- Fixed the possibility that `VoiceChannel.State` (`Guild.voiceStates`) wouldn't' be fully updated.
- Fixed property `Guild.discoverySplash` returning `nil` even if a discovery splash was present.
- Fixed property `Guild.splash` not being updated.
- Fixed method `ScheduledEvent.users()` error when called.

#### Updated
- **(Breaking Change)** Method `Guild.bans()` parameters `before` and `after` are now of type `Date`.
- **(Breaking Change)** Method `Guild.bans()` return type is now `Guild.AsyncBans`.
- **(Breaking Change)** Method `ScheduledEvent.users()` parameters `before` and `after` are now of type `Date`.
- **(Breaking Change)** Method `ScheduledEvent.users()` return type is now `ScheduledEvent.AsyncUsers`.
- Various documentation improvements. Added documentation that was missing and corrected typos.



## [0.0.2-alpha](https://github.com/Defxult/Discord.swift/tree/v0.0.2-alpha)
Released on May 27, 2023.

#### New Features
- Added function `getVariable()`.
- Added function `oauth2Url()`.
- Added method `Array.chunked()`.
- Added property `Guild.safetyAlertsChannelId`.
- Added property `Discord.emojis`.
- Added case `Guild.Feature.raidAlertsDisabled`.
- Added enum `OAuth2Scopes` (see updated).

#### Bug Fixes
- Fixed `Embed.clear()` not removing the timestamp.
- Fixed `PartialInvite.inviter` error when missing inviter.

#### Updated
- Function `clean()` now escapes bullet points and headers.
- `AutoModerationRule`
  - **(Breaking Change)** Renamed `AutoModerationRule.TriggerData` to `Metadata`.
  - **(Breaking Change)** Renamed `AutoModerationRule.Edit.triggers` to `metadata`.
  - Added `AutoModerationRule.metadata`. This now houses data such as `keywordFilter`, `presets`, etc.
  - Added `AutoModerationRule.Metadata.mentionRaidProtectionEnabled`.
  - Added `AutoModerationRule.Metadata` documentation.
  - **(Breaking Change)** Removed `AutoModerationRule.keywordFilter`.
  - **(Breaking Change)** Removed `AutoModerationRule.presets`.
  - **(Breaking Change)** Removed parameter `mentionTotalLimit` from `AutoModerationRule.Metadata`.
- **(Breaking Change)** Parameter `triggerData` renamed to `metadata` in method `Guild.createAutoModerationRule()`.
- With the addition of `OAuth2Scopes`, the following has been updated:
  - **(Breaking Change)** Property `Application.InstallParams.scopes` is now of type `Set<OAuth2Scopes>`.
  - **(Breaking Change)** Property `Guild.Integration.scopes` is now of type `Set<OAuth2Scopes>`.



## [0.0.1-alpha](https://github.com/Defxult/Discord.swift/tree/v0.0.1-alpha)
Released on May 17, 2023.

Discord.swift initial release.
