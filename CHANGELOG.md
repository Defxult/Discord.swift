## 0.0.3-alpha
Pending release

#### New Features
- Method `Discord.waitUntilReady()`.
- Method `File.download()`. 

#### Fixed
- Event listener `onReady()` not being dispatched when certain intents were missing.
- The possibility that `VoiceChannel.State` (`Guild.voiceStates`) wouldn't' be fully updated.

### Updated
- **(Breaking Change)** Method `Guild.bans()` parameters `before` and `after` are now of type `Date`.
- **(Breaking Change)** Method `Guild.bans()` return type is now `Guild.AsyncBans`.



## [0.0.2-alpha](https://github.com/Defxult/Discord.swift/tree/v0.0.2-alpha)
Released on May 27, 2023.

#### New Features
- Function `getVariable()`.
- Function `oauth2Url()`.
- Method `Array.chunked()`.
- Property `Guild.safetyAlertsChannelId`.
- Property `Discord.emojis`.
- Case `Guild.Feature.raidAlertsDisabled`.
- Enum `OAuth2Scopes` (see updated).

#### Fixed
- `Embed.clear()` not removing the timestamp.
- `PartialInvite.inviter` error when missing inviter.

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
