# Beast Training Tracker

A hunter addon for WoW Forever. It tracks your pet ability ranks, shows which beasts teach the ones you're missing, and keeps a collection list of rare, elite and quest-spawned pets.

**It works fully on its own.** Questie, TomTom and RareScanner each add extras if you have them installed.

## Features

- **Abilities:** every pet ability rank, what you've learned, and which beasts teach the rest. Beasts in your current zone are shown in green. Learned ranks sync automatically whenever you open Beast Training, and saved ranks are never overwritten.
- **Hunt Planner:** the zones where you can tame the most missing ranks at your level.
- **Special Pets:** rare, elite and quest-spawned pets, with attack speed, unique looks, and a tamed checklist that tracks renamed pets. Click one for a drawer with its 3D model, respawn time and full details. Respawn times come from the [CMaNGOS Classic database](https://github.com/cmangos/classic-db).
- **My Pet:** upgrades you can teach, and ranks coming up as your pet levels.
- **Map pins and waypoints:** beast locations on the world map and minimap. Click a pin for a waypoint.
- **Alerts:** a popup when a beast that teaches something you need is nearby, and a popup when you learn a new ability.
- **Zone tracker:** a small panel listing what you can tame in your current zone.
- **Pet XP bar:** a thin bar with your pet's experience, under your pet's frame. Mouse over it for the numbers, and drag it anywhere you like.
- **Backup:** export and import your learned ranks and tamed pets as text.
- **Minimap button:** works with minimap-button collector addons. Left-click opens the window, right-click shows or hides map pins, and middle-click toggles the tracker.

## Works on its own, better with friends

The window header shows which optional addons are detected: green if found, grey if not. Hover it for details; click it to open **Settings**.

| Addon | Without it | With it |
|---|---|---|
| **Questie** | Map pins show every beast you've spotted yourself (targeted, moused over or nameplate seen). These are remembered across all your characters. | Spawn locations for every beast, before you've seen them |
| **TomTom** | Waypoints use a built-in map pin and a minimap marker that points the way | TomTom's arrow |
| **RareScanner** | Rare pets are listed with their zone | Live rare timers ("should be up", "back in ~30m", "seen 3h ago") and waypoints to where a rare was last seen |

## Commands

`/btt` opens the window. `/btt help` lists the other commands.

## Credits

- Pet ability, rare, elite and attack speed data from [Petopia](https://www.wow-petopia.com/forever/).
- Uses LibStub, CallbackHandler-1.0, LibDataBroker-1.1, LibDBIcon-1.0 and HereBeDragons.

## Development

- Run the unit tests from the addon folder: `lua5.1 tests/run.lua`. They also run on GitHub on every push.
- **Releasing:** push a tag (for example `v1.3.0`). GitHub Actions then tests, packages and uploads the new version to CurseForge with the BigWigs packager. A tag containing `alpha` or `beta` is uploaded as an alpha or beta release.
- This needs the `CF_API_KEY` repository secret, and `## X-Curse-Project-ID` set in the TOC.
- **Changelog:** add player-facing notes to `CHANGELOG.md` ([Keep a Changelog](https://keepachangelog.com) format) before tagging. The packager uploads it as the CurseForge changelog.
- **Commit messages** follow [Conventional Commits](https://www.conventionalcommits.org): `feat:`, `fix:`, `docs:`, `test:`, `ci:`, `build:`, `refactor:`, `chore:`.
