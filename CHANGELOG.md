# Changelog

All notable changes to Beast Training Tracker are listed here.
The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow [Semantic Versioning](https://semver.org/).

## [1.2.1] - 2026-11-14

### Fixed
- Beast Training sync now saves the correct rank of every ability. Before, every rank on WoW Forever could be saved as Rank 1.
- Taming a beast no longer counts its abilities as learned straight away. They're counted once your pet has taught them to you and the game's "You have learned" message appears.
- "You have learned" messages that show the ability as a spell link (for example "[Swipe]") are now detected, with the right rank.
- Resyncing (opening Beast Training after a reset, or importing a backup) no longer shows a "new pet abilities learned" popup for ranks you already had.
- The popup now resizes to fit its text, so long lines no longer spill past the bottom edge.

### Added
- `/btt dump` lists what the open Beast Training window reports for each ability, to help diagnose sync problems.

## [1.2.0] - 2026-11-14

First public release.

### Added
- **Abilities** tab: every pet ability rank, the pet level and training points each needs, and the beasts that teach it. Beasts in your current zone are highlighted in green.
- Automatic sync of learned ranks whenever you open Beast Training, plus detection from your pet's spellbook and "You have learned" messages. Saved ranks are never overwritten.
- **Hunt Planner** tab: the zones where you can tame missing ranks at your level, with each zone's level range, listed from lowest to highest level (or by most new ranks). The other faction's zones are hidden unless you turn them on.
- **Special Pets** tab: 140 rare, elite and quest-spawned pets, with attack speed, traits and a tamed checklist that keeps tracking renamed pets.
- **My Pet** tab: upgrades you can teach now, ranks coming up as your pet levels, and a Beast Training button.
- Map and minimap pins, waypoints and a movable zone tracker.
- Hunt routes: waypoints are ordered nearest-first and drawn as numbered stops joined by an evenly spaced dotted line on the world map, which opens on the first stop. The line color and opacity can be changed in Settings. Routes visit only one beast per ability and drop stops automatically once you learn what they teach or tame the pet. Clear routes from the window header or the world map.
- Alerts when a beast that teaches something you need is nearby, and a popup when you learn a new ability.
- Minimap button: left-click opens the window, right-click shows or hides pins, middle-click toggles the tracker.
- Export and import of learned ranks and tamed pets, an automatic account-wide backup, and a Reset button.
- The installed version is shown at the bottom of Settings, with a one-time chat note after updating.
- Works on its own. Optional support for Questie (spawn locations), TomTom (waypoint arrows) and RareScanner (live rare timers), with their status shown in the window.
