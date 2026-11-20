## 2.0.0

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
