## 0.0.2-alpha
Pending release

#### Added
- Function `getVariable(_:)`.
- Property `Guild.safetyAlertsChannelId`.
- Case `Guild.Feature.raidAlertsDisabled`.

#### Fixed
- `Embed.clear()` not removing the timestamp.
- `PartialInvite.inviter` error when missing inviter.

#### Updated
- `AutoModerationRule`
  - Renamed `AutoModerationRule.TriggerData` to `Metadata`.
  - Renamed `AutoModerationRule.Edit.triggers` to `metadata`.
  - Added `AutoModerationRule.metadata`. This now houses data such as `keywordFilter`, `presets`, etc.
  - Added `AutoModerationRule.Metadata.mentionRaidProtectionEnabled `.
  - Added `AutoModerationRule.Metadata` documentation.
  - Removed `AutoModerationRule.keywordFilter`.
  - Removed `AutoModerationRule.presets`.
  - Removed parameter `mentionTotalLimit` from `AutoModerationRule.Metadata`.
- Parameter `triggerData` renamed to `metadata` in method `Guild.createAutoModerationRule()`.

## 0.0.1-alpha
Released on May 17, 2023.

Discord.swift initial release.
