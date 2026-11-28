# Changelog

All notable changes to Beast Training Tracker, newest first.

## 2.1.3 - 2026-11-27

### Fixed

- Broodwidow was listed as teaching Dash 3. It teaches Web 1. Thanks to **user_agvjza376ndbx5iu** on CurseForge for spotting it!

### Changed

- Refreshed all pet ability and special pet data from Petopia's latest WoW Forever lists:
  - **Sonic Blast** (Bats) is now tracked, with all 5 ranks and the beasts that teach them.
  - Around 90 new teachers, including Riverglades, Mount Hyjal, Moonglade and Dustwallow Marsh beasts, and corrected ranks for others (for example, Winterspring Screecher teaches Mine! 5, not Dive 3).
  - New special pets: Kackle, Zopilote, Old Rusthowl, Ombassa, Krek the Noxious, Aku'mai Snapjaw, Chasm Crawler, Riding Wolf, Slavering Hound, Hungry Crocolisk and Gharrik.
  - Removed Olm the Wise and Broodmother Valraxx, which Petopia no longer lists.
  - Ghostfang's attack speed is now 2.0, and Araga, Humar the Pridelord, Carnage and Deviate Dreadfang are no longer marked as unique looks.

## 2.1.2 - 2026-11-22

### Added

- **Chronicle moments**: the Chronicle now notes what happens to you and your pet, each as a small map card on the page. The day's map and the cards zig-zag down the page, with a line like "Ten minutes later, in The Barrens":
  - **your deaths**, with a taped tag naming who killed you ("a level 39 Dwarf Warrior - killed you again")
  - **PvP kills**, with a tag naming who you defeated (only players you fought; at most ten a day). A battleground is one line for the match: "Warsong Gulch: 12 honorable kills."
  - **dungeon runs**, one card per run on the map where you went in ("Razorfen Kraul, 45 min, 1 death."). A run lasts through a release and corpse run or a /reload, and is written a few minutes after you come out, even if you hearth out.
  - level-ups, rare kills and kill milestones
  - sitting by a campfire, sleeping in the Cozy Sleeping Bag, arriving in a capital city, your pet's first time in a zone, flights ("Flew from Orgrimmar to Feralas") and resting at an inn

  A day shows up to eight cards; deaths, kills, dungeons and level-ups always get theirs first, and the rest go in the list below. Small moments repeat at most once in a while (a campfire once per half hour, a city or inn once per two hours). Feign Death doesn't count as a death. A death still counts if your pet fell first. A death with no map card, like one inside a dungeon, still says who killed you in the list. `/btt mapcheck` also says whether you're in a capital.

### Fixed

- **Beasts slain** missed most kills, so the Chronicle had little to write about: kill milestones, rare kills and the Slayer seals rarely came up. A beast only counted if you'd looked at that exact mob before the fight. Now, once you've seen one beast of a kind, every one of that kind you kill counts, and the corpse you loot is checked too. Kills from before this fix can't be recovered.
- **Time together** stopped counting during fights, because the game hides your pet's name and ID in combat. So did kills made with your pet mid-fight. Both now keep counting while the same pet is out. Time already missed can't be recovered.
- **Account-wide backup**: each character's backup now has a slot of its own. It used to be saved under first name and realm, so characters sharing a first name on one realm (Socks Gathers, Socks Hunts…) shared one slot. One character's backup could overwrite another's, or be restored onto the wrong character. Non-hunters no longer write to the backup at all. Nothing to do on your end: the next time each hunter logs in, its old backup moves to its own slot and the old one is removed. Empty old slots are removed too. An old slot holding another character's ranks waits until that character logs in. The Backup page shows each character's full name.
- On characters that aren't hunters, the addon still showed beast pins on the map and minimap, tracked kills and pet time, and could fill in ranks. Now it stays fully off on other classes: no pins, no minimap button, no tracking and no changes to your saved ranks. It says once in chat that it's for hunters only.
- Clicking a moment's little map now opens a bigger view of the map that moment happened on. It used to open the zone you spent most of that day in. Clicking the icon on the card opens it too.
- New `/btt killcheck`: says in chat whether each corpse you loot counted as a kill, and why not.

## 2.1.1 - 2026-11-20

### Added

- **Text size**: make the text bigger or smaller, from 90% to 140%, without changing the window's size. Headings keep their size so they still fit the page. It's in Settings in both windows, next to Window size, and the Default button on the journal's Window & Reading page resets it too.

### Fixed

- The changelog shows every version again, not only the newest one.

## 2.1.0 - 2026-11-20

### Added

- **Choose your window**: the classic window from 1.x is back. After updating, a popup asks once whether you want the **Hunter's Journal** or the **Classic** window. Your answer is remembered for every character on the account, so it never asks again.
  - Switch any time in Settings, or with `/btt classic` and `/btt journal`.
  - The classic window has the Abilities, Hunt Planner, Special Pets, My Pet, Settings and Backup tabs, with all their old filters. The Chronicle, Trophy Room and Skinning live in the journal, and keep recording whichever window you use.
- **Window and text size**: make the window bigger or smaller, text included, from 70% to 150%. It applies to both windows.
- **Reading options** for the journal, on the first page of Settings:
  - **Darker ink**: near-black text instead of the spellbook's brown ink, for screens where the text blends into the page.
  - **Page brightness**: dims the parchment. Helps on HDR and very bright screens.
  - A **Default** button puts these back.

### Changed

- The journal's Settings tab now starts on a new **Window & Reading** page. The map, addon, alert and tracker settings are on pages 2 and 3.

### Fixed

- The classic window now opens where you last dragged it, instead of always in the middle of the screen.

## 2.0.1 - 2026-11-20

### Added

- **Chronicle backup**: your pets' chronicles are now saved in the account-wide backup with your learned ranks and tamed pets. If a character's saved data is lost, the chronicle comes back on the next login. The daily map trails aren't backed up because they would double the size of the saved file, so restored days have no path drawn.

## 2.0.0 - 2026-11-20

The tracker is now a hunter's journal: a new window drawn with the same art as the Forever spellbook, with parchment pages, square tabs, framed icons and page arrows. Every old feature is still there. New in this version: a Chronicle for your pets with maps of where you went, a Trophy Room with milestones and a Hunter Rank, and a Skinning tab with sessions and auction values.

### Added

- **New journal window**: replaces the old window. `/btt` and the minimap button open it.
  - Spellbook art: metal frame, parchment page, swirl dividers, framed icons and "Page 1/2" arrows. Page headings use the quest-book font, and the mouse wheel turns pages.
  - Tabs: Abilities, Hunt Planner, Special Pets, My Pet, Chronicle, Trophy Room, Skinning (skinners only), Settings and Backup.
  - Your pet's portrait in the corner, and a pet card in the top strip on every tab: name, level and XP. Click it for My Pet.
  - Your Hunter Rank emblem on the portrait, on every tab. Hover it for your points; click it for Milestones.
  - A note at the bottom of each page with a useful tip, such as how many ranks you can tame in your zone.
- **Abilities**: every pet ability as a framed icon.
  - Small boxes under each name fill in for every rank learned. A check marks abilities with every rank. An icon glows when a beast in your zone teaches a rank you're missing.
  - Click an ability for its page: what each rank does, numbered rank buttons, and every beast that teaches the selected rank, with its level on the icon. Click a beast for a waypoint, shift-click for all of them.
  - A "My pet's family only" filter and a search box.
- **Hunt Planner**: zones as framed icons. Your current zone glows; enemy-faction zones are marked in red.
  - Click a zone for its page: the ranks you can learn there and the beasts to tame. "Route all beasts" sets waypoints to all of them.
  - The page notes the best hunting zone for your level.
- **Special Pets**: rares, elites and quest spawns as framed icons, with level badges, attack speed and respawn timers. A check marks the ones you've tamed; ones in your zone glow.
  - Click one for its page: a turning 3D model you can drag and zoom, plus attack speed, respawn, traits, what it teaches and Waypoint / Mark tamed buttons.
- **My Pet**: a page about your current pet.
  - 3D model, XP with how much is left to level, and its stats: attack speed, damage, health and armor.
  - Sections for upgrades to teach, abilities on your pet, ranks coming up and abilities you know that it doesn't have.
  - The Beast Training button now lives here.
- **Chronicle** (new tab): a diary for every pet that's walked at your side.
  - Notes at the top: when you first met, its favourite haunt, the family it hunts most, and the special pet it was tamed from.
  - Day by day ("Today", "Yesterday", then dates): time together and where, beasts slain, falls and skins with their value.
  - Timed entries: levels reached, new ranks learned, loyalty growth, going unhappy and being fed, falling in battle, special beasts brought down, kill milestones, first skins of each material and finished skinning sessions.
  - **Maps**: each day gets a cut-out of the zone map with the path you took in red ink and the day's events marked. Click it for a big view where you can hover each event.
  - **Companions**: every pet you've had, with time together. Click one to read its chronicle. Renaming a pet keeps its chronicle.
- **Trophy Room** (new tab):
  - **Trophies**: every special pet you've tamed, mounted as a turning 3D model with its nickname and tame date.
  - **Milestones**: 44 wax seals (35 for non-skinners) in eight groups:
    - beasts slain and families hunted
    - companions: pet levels, how many pets, their families, hours together and kills with one pet
    - zones explored
    - special pets tamed
    - ranks learned and abilities completed
    - skinning (skinners only)

    A popup announces each one you earn.

  - **Hunter Rank**: every seal is worth points, and points climb 11 ranks from Fledgling to Legend of the Wilds, each with a hunter spell as its emblem. The scale follows the seals open to your character, so non-skinners can reach the top rank too. A banner shows your rank, a progress bar and the ladder of ranks, and a popup marks each rank-up.
  - **Hunting Log**: beasts slain by you or your pet, by family. Families you haven't hunted yet are faded.

- **Skinning** (new tab, shown only to characters with Skinning):
  - **Sessions**: one starts with your first skin or the Start session button. It ends when you're back in a city or inn, after 30 minutes without a skin, or with End session. A chat line and a Chronicle entry report each finished session.
  - A session panel with a live clock, skins and value so far, skins and gold per hour, and the items you've got.
  - Records: your best haul, favourite skinning ground and average gold per hour.
  - Past sessions and an all-time ledger. Click one for its items, how long it lasted, its hours and its gold per hour.
  - Values come from vendor prices, with auction prices from Naowh Forever's auction data, Auctionator or TSM when one of them is installed. None of them is needed.
- **Settings**: two pages of journal sections. Every old setting is kept. The pet XP bar options have their own section.
- **Backup**: export and import side by side, plus your saved records (ranks, characters in the account-wide backup, last sync) and Reset.
- **New commands**: `/btt chronicle`, `/btt companions`, `/btt trophies`, `/btt milestones`, `/btt skinning`, and `/btt mapcheck` (shows whether the Chronicle can read your position and the zone's map art).

### Changed

- The old window is gone. `/btt hunt`, `/btt pet`, `/btt settings`, `/btt backup` and the rest open the matching tab of the journal.
- The Beast Training button is on the My Pet tab instead of the window's top corner.
- My Pet shows the stats Forever gives addons (attack speed, damage, health, armor) instead of happiness, loyalty, training points and diet, which it doesn't.
- Settings: the minimap checkbox now reads "Show the minimap button".

### Notes

- Kills, skins, sessions, pet chronicles and map paths start from this version.
- Kills are counted when a beast you're targeting dies after you tagged it, or when you loot its corpse. Forever doesn't let addons read the combat log, so a kill you never targeted or looted isn't counted.
- Map paths are only recorded while your pet is out, and not where the game hides your position (such as in dungeons). Paths older than 60 days are dropped to keep saved data small; the diary entries stay.

## 1.6.0 - 2026-11-19

### Added

- **Search bar on rare pets tab**: Filter special pets by name, family, or zone
- **Ta'shkal rare pet**: New level 58 cat with Faster Attack VII (1.0 speed) found in Mount Hyjal via corrupted cat figurine

### Fixed

- **Forever server character data overlap**: Fixed characters with the same first name overwriting each other's data
  - CharKey now properly uses full character name (FirstName LastName) on Forever server since realm is unavailable
- **Pet Trainer ability wording**: Improved message clarity for abilities taught by Pet Trainers
  - Now says "Taught by any Pet Trainer" instead of "Teachers in any Pet Trainer"
- **Rare pets tab layout**: Fixed search bar overlapping column headers

## 1.5.2 - 2026-11-19

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

## 1.5.1 - 2026-11-16

### Fixed
- Taint errors when entering dungeons with many nameplates ("attempted to index a table that cannot be indexed with secret keys"). Event handlers for nameplate alerts now wrapped in pcall to safely handle WoW's security restrictions.
- Missing RareData.lua file error on source installs. Added stub file to prevent load errors.

### Added
- Auto-disable on non-hunter characters. When logging in on a non-hunter, the addon will disable itself with a notification message, freeing up resources and preventing errors.

## 1.5.0 - 2026-11-16

### Added
- **Special Pets drawer:** click a pet to slide out a drawer beside the window with a rotating 3D model (drag to turn, mouse wheel to zoom) and everything about it: type, family, level, zone, attack speed, traits, respawn time, what its family can learn, what it teaches, tamed status and RareScanner timers, plus Waypoint and Mark tamed buttons. Shift-click a pet for a waypoint straight away.
- Respawn times for about 110 special pets, from the CMaNGOS Classic database. These are classic values, so WoW Forever may differ. RareScanner's live timers are shown too when it's installed.

## 1.4.0 - 2026-11-16

### Added
- **Pet XP bar:** a thin bar with your hunter pet's experience, under your pet's frame. It shows while your pet is out. Mouse over it for the exact numbers, drag it to move it, and Shift-right-click to snap it back under the pet frame. Turn it off in Settings.
- Pet XP bar options (right-click the bar, **Customize...** in Settings, or `/btt petxp`): bar color, height, width (or match the pet frame), always-on numbers, lock position, and which parts of the text to show (pet name, level, XP numbers, percent).

## 1.3.0 - 2026-11-14

### Changed
- The zone tracker now shows a beast it can put on the map for each ability, instead of always the first one listed. Beasts with no known location are only shown when nothing else teaches that rank in the zone, greyed out and marked with "?".

### Added
- Right-click a line in the zone tracker to switch to a different beast for that ability. Your choice is remembered. The tooltip marks the beast that's shown and the ones with no known location.

## 1.2.1 - 2026-11-14

### Fixed
- Beast Training sync now saves the correct rank of every ability. Before, every rank on WoW Forever could be saved as Rank 1.
- Taming a beast no longer counts its abilities as learned straight away. They're counted once your pet has taught them to you and the game's "You have learned" message appears.
- "You have learned" messages that show the ability as a spell link (for example "[Swipe]") are now detected, with the right rank.
- Resyncing (opening Beast Training after a reset, or importing a backup) no longer shows a "new pet abilities learned" popup for ranks you already had.
- The popup now resizes to fit its text, so long lines no longer spill past the bottom edge.

### Added
- `/btt dump` lists what the open Beast Training window reports for each ability, to help diagnose sync problems.

## 1.2.0 - 2026-11-14

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
