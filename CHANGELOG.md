## 0.0.2-alpha
Pending release

#### Added
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
  - Renamed `AutoModerationRule.TriggerData` to `Metadata`.
  - Renamed `AutoModerationRule.Edit.triggers` to `metadata`.
  - Added `AutoModerationRule.metadata`. This now houses data such as `keywordFilter`, `presets`, etc.
  - Added `AutoModerationRule.Metadata.mentionRaidProtectionEnabled`.
  - Added `AutoModerationRule.Metadata` documentation.
  - Removed `AutoModerationRule.keywordFilter`.
  - Removed `AutoModerationRule.presets`.
  - Removed parameter `mentionTotalLimit` from `AutoModerationRule.Metadata`.
- Parameter `triggerData` renamed to `metadata` in method `Guild.createAutoModerationRule()`.
- With the addition of `OAuth2Scopes`, the following has been updated:
  - Property `Application.InstallParams.scopes` is now of type `Set<OAuth2Scopes>` (was `Array<String>`).
  - Property `Guild.Integration.scopes` is now of type `Set<OAuth2Scopes>` (was `Array<String>`).


## 0.0.1-alpha
Released on May 17, 2023.

Discord.swift initial release.
