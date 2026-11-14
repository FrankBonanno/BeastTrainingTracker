# Beast Training Tracker

A hunter addon for WoW Forever that tracks your pet ability ranks, shows which beasts teach the ones you're missing, and keeps a collection list of rare, elite and quest-spawned pets.

## Features

- **Abilities:** every pet ability rank, what you've learned, and which beasts teach the rest. Beasts in your current zone are shown in green. Learned ranks sync automatically whenever you open Beast Training, and saved ranks are never overwritten.
- **Hunt Planner:** the zones where you can tame the most missing ranks at your level.
- **Special Pets:** rare, elite and quest-spawned pets, with attack speed, unique looks, and a tamed checklist that tracks renamed pets.
- **My Pet:** upgrades you can teach, and ranks coming up as your pet levels.
- **Map pins and alerts:** beast locations on the world map and minimap, a popup when a beast that teaches something you need is nearby, and a popup when you learn a new ability.
- **Zone tracker:** a small panel listing what you can tame in your current zone.
- **Backup:** export and import your learned ranks and tamed pets as text.
- **Minimap button:** works with minimap-button collector addons. Left-click opens the window, right-click shows or hides map pins, and middle-click toggles the tracker.

## Optional addons

None of these are required, but each one adds features:

- **QuestieDB:** beast spawn locations for map pins and waypoints.
- **TomTom:** waypoint arrows.
- **RareScanner:** live rare timers ("should be up", "back in ~30m", "seen 3h ago").

## Commands

`/btt` opens the window. `/btt help` lists the other commands.

## Credits

- Pet ability, rare, elite and attack speed data from [Petopia](https://www.wow-petopia.com/forever/).
- Uses LibStub, CallbackHandler-1.0, LibDataBroker-1.1 and LibDBIcon-1.0.

## Releasing

Pushing a tag (for example `v1.3.0`) runs the BigWigs packager through GitHub Actions and uploads the new version to CurseForge. A tag containing `alpha` or `beta` is uploaded as an alpha or beta release. This needs:

- the `CF_API_KEY` repository secret, and
- `## X-Curse-Project-ID` set in the TOC file.
