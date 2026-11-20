## 1.6.0

### Added

- **Search bar on rare pets tab**: Filter special pets by name, family, or zone
- **Ta'shkal rare pet**: New level 58 cat with Faster Attack VII (1.0 speed) found in Mount Hyjal via corrupted cat figurine

### Fixed

- **Questie v12.11.0+ detection**: Updated addon detection to work with the latest Questie versions
  - Now checks for both old `NpcDB` API and new `QuestieDB` v12+ API
  - Automatically falls back to new Questie API if old API is not available
- **Taint error on ability learning**: Fixed crash when parsing tainted chat messages about learned abilities
  - Wrapped message parsing in pcall to safely handle WoW's secure message restrictions
- **Forever server character data overlap**: Fixed characters with the same first name overwriting each other's data
  - CharKey now properly uses full character name (FirstName LastName) on Forever server since realm is unavailable
- **Pet Trainer ability wording**: Improved message clarity for abilities taught by Pet Trainers
  - Now says "Taught by any Pet Trainer" instead of "Teachers in any Pet Trainer"
- **Rare pets tab layout**: Fixed search bar overlapping column headers
