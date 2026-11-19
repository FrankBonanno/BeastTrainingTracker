## Unreleased

### Added
- **Minimap button alert toggle**: Shift+Right-click the minimap button to quickly toggle all alerts on/off
  - When alerts are toggled back on, they restore to their previous state (remembers individual alert settings)
  - Chat feedback confirms whether alerts were enabled or disabled

### Fixed
- **Questie v12.11.0+ detection**: Updated addon detection to work with the latest Questie versions
  - Now checks for both old `NpcDB` API and new `QuestieDB` v12+ API
  - Automatically falls back to new Questie API if old API is not available
- **Taint error on ability learning**: Fixed crash when parsing tainted chat messages about learned abilities
  - Wrapped message parsing in pcall to safely handle WoW's secure message restrictions
