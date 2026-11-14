local ADDON, ns = ...

ns.TAG = "|cffabd473Beast Training Tracker:|r "
function ns.Say(msg) print(ns.TAG .. msg) end
local Say = ns.Say

------------------------------------------------------------------------
-- Data prep
------------------------------------------------------------------------
local abilities = ns.abilities
local byName = {}        -- "Bite" -> ability
local teacherIndex = {}  -- "Prairie Wolf" -> { {ab=, rank=, t=}, ... }
ns.byName, ns.teacherIndex = byName, teacherIndex

local ICONS = {
  ["Bite"] = "Ability_Racial_Cannibalize",
  ["Charge"] = "Ability_Hunter_Pet_Boar",
  ["Claw"] = "Ability_Druid_Rake",
  ["Cower"] = "Ability_Druid_Cower",
  ["Dash"] = "Ability_Druid_Dash",
  ["Demoralizing Screech"] = "Ability_Druid_DemoralizingRoar",
  ["Dismember"] = "Ability_Hunter_Pet_Crocolisk",
  ["Dive"] = "Spell_Shadow_BurningSpirit",
  ["Dust Cloud"] = "Ability_Hunter_Pet_TallStrider",
  ["Furious Howl"] = "Ability_Hunter_Pet_Wolf",
  ["Lava Breath"] = "Spell_Fire_Fire",
  ["Lightning Breath"] = "Spell_Nature_Lightning",
  ["Mine!"] = "INV_Misc_Coin_01",
  ["Pinch"] = "Ability_Hunter_Pet_Crab",
  ["Prowl"] = "Ability_Ambush",
  ["Savage Rend"] = "Ability_Hunter_Pet_Raptor",
  ["Scorpid Poison"] = "Ability_PoisonSting",
  ["Shell Shield"] = "Ability_Hunter_Pet_Turtle",
  ["Swipe"] = "INV_Misc_MonsterClaw_03",
  ["Tendon Rip"] = "Ability_Hunter_Pet_Hyena",
  ["Thunderstomp"] = "Ability_Hunter_Pet_Gorilla",
  ["Trickster's Dance"] = "Ability_Rogue_Feint",
  ["Web"] = "Ability_Ensnare",
  ["Growl"] = "Ability_Physical_Taunt",
  ["Great Stamina"] = "Spell_Nature_UnyeildingStamina",
  ["Natural Armor"] = "Spell_Nature_SpiritArmor",
  ["Arcane Resistance"] = "Spell_Nature_StarFall",
  ["Fire Resistance"] = "Spell_Fire_FireArmor",
  ["Frost Resistance"] = "Spell_Frost_FrostWard",
  ["Nature Resistance"] = "Spell_Nature_ResistNature",
  ["Shadow Resistance"] = "Spell_Shadow_AntiShadow",
}

for _, ab in ipairs(abilities) do
  byName[ab.name] = ab
  ab.isAll = ab.fam[1] == "All"
  ab.famText = table.concat(ab.fam, ", ")
  ab.icon = "Interface\\Icons\\" .. (ICONS[ab.name] or "INV_Misc_QuestionMark")
  ab.parsed = {}
  for _, r in ipairs(ab.ranks) do
    local pr = { rank = r[1], level = r[2], tp = r[3], effect = r[4], teachers = {} }
    for i = 5, #r do
      local n, fam, l, z = strsplit(";", r[i])
      local t = {
        name = n, family = fam, level = l, zone = z,
        minLevel = tonumber(l:match("^(%d+)")) or 0,
        dungeon = z:find("(Dungeon)", 1, true) ~= nil,
      }
      pr.teachers[#pr.teachers + 1] = t
      teacherIndex[n] = teacherIndex[n] or {}
      table.insert(teacherIndex[n], { ab = ab, rank = pr, t = t })
    end
    table.sort(pr.teachers, function(a, b) return a.minLevel < b.minLevel end)
    ab.parsed[#ab.parsed + 1] = pr
  end
end

------------------------------------------------------------------------
-- State / persistence
--
-- Learned ranks are stored by the addon and only ever ADDED by scans.
-- Whatever WoW's Beast Training window happens to show (filters, an empty
-- list, a different pet) can never erase what was already recorded.
-- Only the Reset button (or "/btt reset confirm") removes data.
-- A second copy is kept account-wide in BeastTrainingTrackerBackup.
------------------------------------------------------------------------
ns.petHas = {}   -- "Bite#3" -> true for the current pet
ns.petRank = {}  -- "Bite" -> highest rank the current pet has

local function Key(name, rank) return name .. "#" .. rank end
ns.Key = Key

local function Explicit(name, rank) return ns.db and ns.db.known[Key(name, rank)] and true or false end
ns.Explicit = Explicit

-- "known" = recorded; "implied" = a higher rank is recorded (lower ranks are never needed)
function ns.Status(ab, rank)
  if Explicit(ab.name, rank) then return "known" end
  for _, r in ipairs(ab.parsed) do
    if r.rank > rank and Explicit(ab.name, r.rank) then return "implied" end
  end
end
function ns.IsKnown(ab, rank) return ns.Status(ab, rank) ~= nil end

function ns.BestKnown(ab, maxLevel)
  local best = 0
  for _, r in ipairs(ab.parsed) do
    if Explicit(ab.name, r.rank) and (not maxLevel or r.level <= maxLevel) then best = math.max(best, r.rank) end
  end
  return best
end

local function RankFromSub(sub)
  return tonumber((sub or ""):match("(%d+)")) or 1
end

-- Handles "Bite" + "Rank 3" and "Bite (Rank 3)"
local function NameRank(name, sub)
  if not name then return end
  if byName[name] then return name, RankFromSub(sub) end
  local base, r = name:match("^(.-)%s*%(%D*(%d+)%)%s*$")
  if base and byName[base] then return base, tonumber(r) end
end

function ns.PlayerLevel() return UnitLevel("player") or 1 end
function ns.PetLevel()
  if UnitExists("pet") then return UnitLevel("pet") or ns.PlayerLevel() end
  return ns.PlayerLevel()
end
function ns.PetFamily()
  if not UnitExists("pet") then return nil end
  return UnitCreatureFamily("pet")
end
function ns.AbilityFitsPet(ab, fam)
  if ab.isAll or not fam then return true end
  for _, f in ipairs(ab.fam) do
    if f == fam then return true end
  end
  return false
end

function ns.CurrentZone() return GetRealZoneText() or "" end
function ns.InZone(t, zone)
  return zone ~= "" and t.zone:find(zone, 1, true) ~= nil
end
function ns.HasTeacherHere(r, zone)
  for _, t in ipairs(r.teachers) do
    if ns.InZone(t, zone) then return true end
  end
end
-- Hunters can tame beasts up to their own level
function ns.CanTame(t) return t.minLevel <= ns.PlayerLevel() end

-- Record a learned rank. Returns true if it was new. Never removes anything.
local function Mark(name, rank)
  local db = ns.db
  if not db or not byName[name] or not rank then return end
  local k = Key(name, rank)
  if db.known[k] then return end
  db.known[k] = true
  ns.learnedSerial = (ns.learnedSerial or 0) + 1
  if ns.OnLearned then ns.OnLearned(name, rank) end
  return true
end

local function Announce(added, from)
  if added > 0 then
    Say(("saved |cffffffff%d|r new learned rank%s (%s)."):format(added, added == 1 and "" or "s", from))
  end
end

------------------------------------------------------------------------
-- Refresh dispatch (UI modules register here)
------------------------------------------------------------------------
ns.refreshers = {}
function ns.OnRefresh(fn) ns.refreshers[#ns.refreshers + 1] = fn end

local ScanPet -- forward
function ns.RefreshNow()
  if not ns.db then return end
  local added = ScanPet()
  if added > 0 then Announce(added, "your pet's spellbook") end
  for _, fn in ipairs(ns.refreshers) do fn() end
end

-- Events like PET_BAR_UPDATE fire in bursts; batch them into one refresh
local refreshQueued
function ns.Refresh()
  if not ns.db or refreshQueued then return end
  refreshQueued = true
  C_Timer.After(0.1, function()
    refreshQueued = false
    ns.RefreshNow()
  end)
end

------------------------------------------------------------------------
-- Detection
------------------------------------------------------------------------
ns.lastScan = { what = "none yet" }

-- Classic-style craft API (in case Beast Training uses it)
local function ScanBeastTraining()
  if not (GetNumCrafts and GetCraftInfo) then return end
  local n, matched, added = GetNumCrafts() or 0, 0, 0
  for i = 1, n do
    local name, sub, ctype = GetCraftInfo(i)
    if ctype ~= "header" then
      local an, ar = NameRank(name, sub)
      if an then
        matched = matched + 1
        if Mark(an, ar) then added = added + 1 end
      end
    end
  end
  if matched > 0 then
    ns.db.lastSync = time()
    ns.lastScan = { what = "craft window", n = n, matched = matched, added = added }
  end
  Announce(added, "Beast Training")
  if added > 0 then ns.Refresh() end
end

local function TrainerTitle()
  for _, fs in ipairs({ _G.ClassTrainerNameText, _G.ClassTrainerFrameTitleText,
    ClassTrainerFrame and ClassTrainerFrame.TitleText, ClassTrainerFrame and ClassTrainerFrame.TitleContainer and ClassTrainerFrame.TitleContainer.TitleText }) do
    if fs and fs.GetText then
      local ok, t = pcall(fs.GetText, fs)
      if ok and t and t ~= "" then return t end
    end
  end
  return ""
end

-- Beast Training (no NPC) vs a real Pet Trainer NPC
local function IsBeastTraining()
  if not UnitExists("npc") then return true end
  if UnitIsUnit and UnitIsUnit("npc", "player") then return true end
  return TrainerTitle():lower():find("beast", 1, true) ~= nil
end

-- Reads whatever the trainer list currently shows. Never touches the
-- window's own filters (that used to break the "hide learned" checkbox).
local function ScanTrainer()
  if not (ns.db and GetNumTrainerServices and GetTrainerServiceInfo) then return end
  local beast = IsBeastTraining()
  local n, matched, added = GetNumTrainerServices() or 0, 0, 0
  for i = 1, n do
    local ok, name, sub, typ = pcall(GetTrainerServiceInfo, i)
    if ok and name and typ ~= "header" then
      local an, ar = NameRank(name, sub)
      if an then
        matched = matched + 1
        -- In Beast Training every listed ability is one you've learned.
        -- At a Pet Trainer NPC only "used" entries are already learned.
        if (beast or typ == "used") and Mark(an, ar) then added = added + 1 end
      end
    end
  end
  if matched > 0 then
    if beast then ns.db.lastSync = time() end
    ns.lastScan = { what = beast and "Beast Training" or "Pet Trainer", n = n, matched = matched, added = added }
  end
  Announce(added, beast and "Beast Training" or "Pet Trainer")
  if added > 0 then ns.Refresh() end
end

local function ScanTrainerSoon()
  ScanTrainer()
  if C_Timer then C_Timer.After(0.3, ScanTrainer) end
end

local function OnTrainerShown()
  if ns.debugOn then
    local n = GetNumTrainerServices and GetNumTrainerServices() or -1
    print("|cffabd473BTT|r trainer opened. services:", n, "npc:", tostring(UnitExists("npc")), "title:", TrainerTitle())
    for i = 1, math.min(8, n) do print("|cffabd473BTT|r  ", i, GetTrainerServiceInfo(i)) end
  end
  ScanTrainerSoon()
end

local hooked
local function HookTrainer()
  if hooked or not ClassTrainerFrame then return end
  ClassTrainerFrame:HookScript("OnShow", OnTrainerShown)
  hooked = true
end

-- Current pet's spellbook: anything the pet has, you've learned.
function ScanPet()
  wipe(ns.petHas)
  wipe(ns.petRank)
  if not UnitExists("pet") then return 0 end
  local added = 0
  local function take(name, sub)
    local an, ar = NameRank(name, sub)
    if an then
      ns.petHas[Key(an, ar)] = true
      ns.petRank[an] = math.max(ns.petRank[an] or 0, ar)
      if Mark(an, ar) then added = added + 1 end
    end
  end
  if C_SpellBook and C_SpellBook.HasPetSpells and C_SpellBook.GetSpellBookItemName and Enum and Enum.SpellBookSpellBank then
    local n = C_SpellBook.HasPetSpells() or 0
    for i = 1, n do take(C_SpellBook.GetSpellBookItemName(i, Enum.SpellBookSpellBank.Pet)) end
  elseif HasPetSpells and GetSpellBookItemName then
    local n = HasPetSpells() or 0
    for i = 1, n do take(GetSpellBookItemName(i, BOOKTYPE_PET or "pet")) end
  end
  return added
end
ns.ScanPet = ScanPet

-- "You have learned a new ability: Bite (Rank 3)."
local function ToPattern(fmt)
  local p = fmt:gsub("([%%%(%)%.%-%+%*%?%[%]%^%$])", "%%%1")
  p = p:gsub("%%%%s", "(.+)")
  return "^" .. p .. "$"
end

local learnPatterns = {}
for _, g in ipairs({ "ERR_LEARN_ABILITY_S", "ERR_LEARN_SPELL_S", "ERR_PET_LEARN_ABILITY_S", "ERR_PET_LEARN_SPELL_S" }) do
  if type(_G[g]) == "string" then learnPatterns[#learnPatterns + 1] = ToPattern(_G[g]) end
end

local function ParseLearned(msg)
  for _, p in ipairs(learnPatterns) do
    local cap = msg:match(p)
    if cap then
      local an, ar = NameRank(cap, nil)
      if an and Mark(an, ar) then
        Say(("learned %s %d"):format(an, ar))
        ns.Refresh()
      end
      return
    end
  end
end

------------------------------------------------------------------------
-- Planning logic
------------------------------------------------------------------------
function ns.Counts()
  local known, total = 0, 0
  for _, ab in ipairs(abilities) do
    for _, r in ipairs(ab.parsed) do
      total = total + 1
      if ns.IsKnown(ab, r.rank) then known = known + 1 end
    end
  end
  return known, total
end

-- Recommended level range per zone (Classic). Zones not listed (Forever's
-- own zones, dungeons) use the level range of the beasts that live there.
local ZONE_LEVELS = {
  ["Elwynn Forest"] = { 1, 10 }, ["Dun Morogh"] = { 1, 10 }, ["Tirisfal Glades"] = { 1, 10 },
  ["Durotar"] = { 1, 10 }, ["Mulgore"] = { 1, 10 }, ["Teldrassil"] = { 1, 10 },
  ["Westfall"] = { 10, 20 }, ["Loch Modan"] = { 10, 20 }, ["Silverpine Forest"] = { 10, 20 },
  ["Darkshore"] = { 10, 20 }, ["The Barrens"] = { 10, 25 }, ["Redridge Mountains"] = { 15, 25 },
  ["Stonetalon Mountains"] = { 15, 27 }, ["Ashenvale"] = { 18, 30 }, ["Duskwood"] = { 18, 30 },
  ["Hillsbrad Foothills"] = { 20, 30 }, ["Wetlands"] = { 20, 30 }, ["Thousand Needles"] = { 25, 35 },
  ["Alterac Mountains"] = { 30, 40 }, ["Arathi Highlands"] = { 30, 40 }, ["Desolace"] = { 30, 40 },
  ["Stranglethorn Vale"] = { 30, 45 }, ["Dustwallow Marsh"] = { 35, 45 }, ["Badlands"] = { 35, 45 },
  ["Swamp of Sorrows"] = { 35, 45 }, ["Feralas"] = { 40, 50 }, ["The Hinterlands"] = { 40, 50 },
  ["Tanaris"] = { 40, 50 }, ["Searing Gorge"] = { 43, 50 }, ["Azshara"] = { 45, 55 },
  ["Blasted Lands"] = { 45, 55 }, ["Un'Goro Crater"] = { 48, 55 }, ["Felwood"] = { 48, 55 },
  ["Burning Steppes"] = { 50, 58 }, ["Western Plaguelands"] = { 51, 58 }, ["Eastern Plaguelands"] = { 53, 60 },
  ["Winterspring"] = { 55, 60 }, ["Deadwind Pass"] = { 55, 60 }, ["Silithus"] = { 55, 60 },
}

local zoneCache = {}

-- "The Tundrid Hills, Dun Morogh" -> "Dun Morogh"; "Kraul (Dungeon)" -> "Kraul"
local function BaseZone(zone)
  local z = (zone or ""):match("([^,]+)$") or zone or ""
  return (z:gsub("%s*%b()", ""):match("^%s*(.-)%s*$"))
end

-- min, max recommended level for a zone name
function ns.ZoneLevels(zone)
  local c = zoneCache[zone]
  if c then return c[1], c[2] end
  local known = ZONE_LEVELS[BaseZone(zone)]
  local lo, hi
  if known then
    lo, hi = known[1], known[2]
  else
    -- from the beasts that live there
    for _, ab in ipairs(abilities) do
      for _, r in ipairs(ab.parsed) do
        for _, t in ipairs(r.teachers) do
          if BaseZone(t.zone) == BaseZone(zone) then
            local a = t.minLevel
            local b = tonumber(t.level:match("(%d+)%s*$")) or a
            lo = (not lo or a < lo) and a or lo
            hi = (not hi or b > hi) and b or hi
          end
        end
      end
    end
    for _, p in ipairs(ns.rarePets or {}) do
      if BaseZone(p.zone) == BaseZone(zone) then
        local b = tonumber(p.level:match("(%d+)%s*$")) or p.minLevel
        lo = (not lo or p.minLevel < lo) and p.minLevel or lo
        hi = (not hi or b > hi) and b or hi
      end
    end
  end
  zoneCache[zone] = { lo or 0, hi or lo or 0 }
  return zoneCache[zone][1], zoneCache[zone][2]
end

-- Faction territory. Zones not listed are contested or unknown (shown to everyone).
local ZONE_FACTION = {
  ["Elwynn Forest"] = "Alliance", ["Dun Morogh"] = "Alliance", ["Teldrassil"] = "Alliance",
  ["Westfall"] = "Alliance", ["Loch Modan"] = "Alliance", ["Darkshore"] = "Alliance",
  ["Redridge Mountains"] = "Alliance", ["Duskwood"] = "Alliance", ["Wetlands"] = "Alliance",
  ["Stormwind City"] = "Alliance", ["Ironforge"] = "Alliance", ["Darnassus"] = "Alliance",
  ["Durotar"] = "Horde", ["Mulgore"] = "Horde", ["Tirisfal Glades"] = "Horde",
  ["Silverpine Forest"] = "Horde", ["The Barrens"] = "Horde",
  ["Orgrimmar"] = "Horde", ["Thunder Bluff"] = "Horde", ["Undercity"] = "Horde",
}

-- "Alliance" / "Horde" / nil (contested or unknown)
function ns.ZoneFaction(zone) return ZONE_FACTION[BaseZone(zone)] end

-- true if the zone belongs to the other faction
function ns.ZoneHostile(zone)
  local f = ns.ZoneFaction(zone)
  local me = UnitFactionGroup and UnitFactionGroup("player")
  return f ~= nil and me ~= nil and f ~= me
end

-- Missing ranks you can tame right now, grouped by zone.
-- Only the highest missing rank per ability counts (it covers the lower ones).
-- Returns { {zone=, entries={ {ab=, rank=, teachers={...}} }, levelSum=, minLevel=, maxLevel=} }.
-- sortBy "count": most new ranks first; otherwise by zone level, lowest first.
-- The other faction's zones are left out unless allFactions is set or the
-- "Show enemy faction zones" option is on.
function ns.HuntPlan(petOnly, dungeons, sortBy, allFactions)
  local fam = ns.PetFamily()
  local hideHostile = not allFactions and not (ns.db and ns.db.opts.huntBothFactions)
  local zones = {}
  for _, ab in ipairs(abilities) do
    if ab.src == "beast" and (not petOnly or ns.AbilityFitsPet(ab, fam)) then
      for _, r in ipairs(ab.parsed) do
        if not ns.IsKnown(ab, r.rank) then
          for _, t in ipairs(r.teachers) do
            if ns.CanTame(t) and (dungeons or not t.dungeon) and not (hideHostile and ns.ZoneHostile(t.zone)) then
              local z = zones[t.zone]
              if not z then z = { zone = t.zone, by = {} }; zones[t.zone] = z end
              local cur = z.by[ab.name]
              if not cur or r.rank > cur.rank.rank then
                z.by[ab.name] = { ab = ab, rank = r, teachers = { t } }
              elseif cur.rank == r then
                cur.teachers[#cur.teachers + 1] = t
              end
            end
          end
        end
      end
    end
  end
  local here = ns.CurrentZone()
  local out = {}
  for _, z in pairs(zones) do
    z.entries, z.levelSum = {}, 0
    for _, e in pairs(z.by) do
      z.entries[#z.entries + 1] = e
      z.levelSum = z.levelSum + e.rank.level
    end
    table.sort(z.entries, function(a, b) return a.ab.name < b.ab.name end)
    z.here = here ~= "" and z.zone:find(here, 1, true) ~= nil
    z.minLevel, z.maxLevel = ns.ZoneLevels(z.zone)
    out[#out + 1] = z
  end
  if sortBy == "count" then
    table.sort(out, function(a, b)
      if #a.entries ~= #b.entries then return #a.entries > #b.entries end
      if a.levelSum ~= b.levelSum then return a.levelSum > b.levelSum end
      return a.zone < b.zone
    end)
  else
    table.sort(out, function(a, b)
      if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
      if a.maxLevel ~= b.maxLevel then return a.maxLevel < b.maxLevel end
      return a.zone < b.zone
    end)
  end
  return out
end

-- Highest missing rank per ability that's tameable in the zone you're in
function ns.NeededHere()
  local zone = ns.CurrentZone()
  for _, z in ipairs(ns.HuntPlan(false, true, nil, true)) do -- your current zone, whoever owns it
    if z.here then return z.entries, z.zone end
  end
  return {}, zone
end

-- Abilities your pet has where you know a better rank
function ns.Upgrades()
  local out = {}
  if not UnitExists("pet") then return out end
  local fam, plvl = ns.PetFamily(), ns.PetLevel()
  for _, ab in ipairs(abilities) do
    local has = ns.petRank[ab.name]
    if has and ns.AbilityFitsPet(ab, fam) then
      local teach, any = ns.BestKnown(ab, plvl), ns.BestKnown(ab)
      if teach > has then
        out[#out + 1] = { ab = ab, from = has, to = teach }
      elseif any > has then
        out[#out + 1] = { ab = ab, from = has, to = any, needLevel = ab.parsed[any] and ab.parsed[any].level }
      end
    end
  end
  return out
end

-- Ranks unlocking for your pet over the next `span` levels (abilities it already uses)
function ns.ComingUp(span)
  local out = {}
  if not UnitExists("pet") then return out end
  local plvl = ns.PetLevel()
  for _, ab in ipairs(abilities) do
    if ns.petRank[ab.name] then
      for _, r in ipairs(ab.parsed) do
        if r.rank > ns.petRank[ab.name] and r.level > plvl and r.level <= plvl + span then
          out[#out + 1] = { ab = ab, rank = r, known = ns.IsKnown(ab, r.rank) }
        end
      end
    end
  end
  table.sort(out, function(a, b)
    if a.rank.level ~= b.rank.level then return a.rank.level < b.rank.level end
    return a.ab.name < b.ab.name
  end)
  return out
end

-- "Hillsbrad Foothills, Arathi Highlands"
function ns.TeacherZones(ab, r, limit)
  if ab.src == "trainer" then return "any Pet Trainer" end
  local seen, list = {}, {}
  for _, t in ipairs(r.teachers) do
    local z = t.zone
    if not seen[z] then
      seen[z] = true
      list[#list + 1] = z
      if #list >= (limit or 2) then break end
    end
  end
  return #list > 0 and table.concat(list, ", ") or "unknown"
end

------------------------------------------------------------------------
-- Export / import / reset
------------------------------------------------------------------------
function ns.Export()
  local parts = {}
  for _, ab in ipairs(abilities) do
    local ranks = {}
    for _, r in ipairs(ab.parsed) do
      if Explicit(ab.name, r.rank) then ranks[#ranks + 1] = r.rank end
    end
    if #ranks > 0 then parts[#parts + 1] = ab.name .. "=" .. table.concat(ranks, ",") end
  end
  local s = "BTT1:" .. table.concat(parts, ";")

  -- tamed special pets: "#T:The Rake>Kittery,Vulgara the Insatiable"
  local tamed = {}
  for name in pairs(ns.db.tamedRares or {}) do
    local nick = ns.db.tamedNicks and ns.db.tamedNicks[name]
    tamed[#tamed + 1] = nick and (name .. ">" .. nick) or name
  end
  table.sort(tamed)
  if #tamed > 0 then s = s .. "#T:" .. table.concat(tamed, ",") end
  return s
end

-- Merges into existing data; never removes anything.
function ns.Import(text)
  text = (text or ""):gsub("[\r\n\t]", ""):match("^%s*(.-)%s*$")
  local body = text:match("^BTT1:(.*)$")
  if not body then return nil, "That doesn't look like a Beast Training Tracker export (it should start with BTT1:)." end
  local added, skipped, tamedAdded = 0, 0, 0

  -- "#T:" section: tamed special pets (merged, never removes)
  local tamedPart
  body, tamedPart = body:match("^([^#]*)#?T?:?(.*)$")
  if tamedPart and tamedPart ~= "" then
    local db = ns.db
    db.tamedRares = db.tamedRares or {}
    db.tamedNicks = db.tamedNicks or {}
    db.petLinks = db.petLinks or {}
    for entry in tamedPart:gmatch("[^,]+") do
      local name, nick = entry:match("^%s*(.-)%s*>%s*(.-)%s*$")
      name = name or entry:match("^%s*(.-)%s*$")
      local sp = ns.rarePetByName and ns.rarePetByName[name]
      if sp then
        if not db.tamedRares[name] then
          db.tamedRares[name] = time()
          tamedAdded = tamedAdded + 1
        end
        if nick and nick ~= "" then
          db.tamedNicks[name] = db.tamedNicks[name] or nick
          db.petLinks[nick .. "|" .. sp.family] = db.petLinks[nick .. "|" .. sp.family] or name
        end
      else
        skipped = skipped + 1
      end
    end
    ns.tamedSerial = (ns.tamedSerial or 0) + 1
  end

  for chunk in body:gmatch("[^;]+") do
    local name, list = chunk:match("^%s*(.-)%s*=%s*(.-)%s*$")
    local ab = name and byName[name]
    if ab then
      for n in list:gmatch("%d+") do
        local rk = tonumber(n)
        if ab.parsed[rk] then
          if Mark(name, rk) then added = added + 1 end
        else
          skipped = skipped + 1
        end
      end
    else
      skipped = skipped + 1
    end
  end
  ns.Refresh()
  return added, skipped, tamedAdded
end

function ns.ResetData()
  wipe(ns.db.known)
  ns.db.lastSync = nil
  ns.learnedSerial = (ns.learnedSerial or 0) + 1
  Say("cleared all learned ranks. Open Beast Training to resync.")
  ns.Refresh()
end

------------------------------------------------------------------------
-- Init / events
------------------------------------------------------------------------
ns.initers = {}
function ns.OnInit(fn) ns.initers[#ns.initers + 1] = fn end

local DEFAULTS = {
  -- ability list
  petOnly = false, hideKnown = false, hideTrainer = false, hideHigh = false, zoneOnly = false,
  -- hunt planner
  huntPetOnly = false, huntDungeons = false, huntSortCount = false, huntBothFactions = false,
  -- map & alerts
  mapPins = true, minimapPins = true, pinsOff = false, learnToast = true, routeOpenMap = true, routeLines = true,
  -- rare pets
  rareHideTamed = false, rareHideHigh = false, rarePins = true, rareSortSpeed = false,
  spShowRare = true, spShowElite = true, spShowSpawned = true, spShowDungeon = false,
  alertTarget = true, alertNameplate = true, alertSound = true, rsHandlesRares = true,
  tracker = true, trackerAutoHide = false,
  upgradeAlert = true, levelNudge = true,
}

local function CharKey()
  return (UnitName("player") or "?") .. "-" .. (GetRealmName() or "?")
end

local function InitDB()
  BeastTrainingTrackerDB = BeastTrainingTrackerDB or {}
  BeastTrainingTrackerBackup = BeastTrainingTrackerBackup or {}
  local db = BeastTrainingTrackerDB
  ns.db = db
  db.known = db.known or {}
  db.manualOff = nil
  db.collapsed = db.collapsed or {}
  db.minimap = db.minimap or {}
  db.rares = db.rares or {}
  db.opts = db.opts or {}
  for k, v in pairs(DEFAULTS) do
    if db.opts[k] == nil then db.opts[k] = v end
  end

  -- merge the account-wide backup back in, then keep it in sync
  -- (learned ranks + tamed special pets and their name links)
  db.tamedRares = db.tamedRares or {}
  db.tamedNicks = db.tamedNicks or {}
  db.petLinks = db.petLinks or {}
  local key = CharKey()
  local bk = BeastTrainingTrackerBackup[key]
  local restored, restoredPets = 0, 0
  if type(bk) == "table" then
    for k in pairs(type(bk.known) == "table" and bk.known or {}) do
      if not db.known[k] then db.known[k] = true; restored = restored + 1 end
    end
    for k, v in pairs(type(bk.tamedRares) == "table" and bk.tamedRares or {}) do
      if not db.tamedRares[k] then db.tamedRares[k] = v; restoredPets = restoredPets + 1 end
    end
    for _, field in ipairs({ "tamedNicks", "petLinks" }) do
      for k, v in pairs(type(bk[field]) == "table" and bk[field] or {}) do
        if db[field][k] == nil then db[field][k] = v end
      end
    end
  end
  local function SyncBackup()
    BeastTrainingTrackerBackup[key] = { known = db.known, tamedRares = db.tamedRares, tamedNicks = db.tamedNicks, petLinks = db.petLinks }
  end
  SyncBackup()
  ns.SyncBackup = SyncBackup
  if restored > 0 then Say(("restored %d learned ranks from backup."):format(restored)) end
  if restoredPets > 0 then Say(("restored %d tamed special pets from backup."):format(restoredPets)) end

  -- one-time note after updating to a new version
  local v = ns.Version()
  if v ~= "dev" then
    if db.lastVersion and db.lastVersion ~= v then
      Say(("updated to |cffffffff%s|r. See the changelog on CurseForge for what's new."):format(v))
    end
    db.lastVersion = v
  end

  for _, fn in ipairs(ns.initers) do fn(db) end
end

-- Installed version from the TOC. The packager replaces @project-version@
-- with the release tag; an unpackaged copy reports "dev".
function ns.Version()
  local get = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
  local ok, v = false, nil
  if get then ok, v = pcall(get, ADDON, "Version") end
  if not ok or type(v) ~= "string" or v == "" or v:find("@", 1, true) then return "dev" end
  return v
end

function ns.VersionText()
  local v = ns.Version()
  return v == "dev" and "development version (not a packaged release)" or v
end

local ev = CreateFrame("Frame")
local function Reg(e) pcall(ev.RegisterEvent, ev, e) end

for _, e in ipairs({
  "ADDON_LOADED", "PLAYER_LOGIN", "PLAYER_LOGOUT", "TRAINER_SHOW", "TRAINER_UPDATE", "CRAFT_SHOW", "CRAFT_UPDATE",
  "CHAT_MSG_SYSTEM", "UNIT_PET", "PET_BAR_UPDATE", "SPELLS_CHANGED", "PLAYER_LEVEL_UP", "ZONE_CHANGED_NEW_AREA", "UNIT_LEVEL",
}) do Reg(e) end

ns.loginHooks = {}
function ns.OnLogin(fn) ns.loginHooks[#ns.loginHooks + 1] = fn end

ev:SetScript("OnEvent", function(_, e, a1)
  if e == "ADDON_LOADED" then
    HookTrainer()
    if a1 == ADDON then InitDB() end
    return
  elseif not ns.db then
    return
  elseif e == "PLAYER_LOGIN" then
    for _, fn in ipairs(ns.loginHooks) do fn() end
    ns.Refresh()
  elseif e == "PLAYER_LOGOUT" then
    if ns.SyncBackup then ns.SyncBackup() end
  elseif e == "CRAFT_SHOW" or e == "CRAFT_UPDATE" then
    ScanBeastTraining()
  elseif e == "TRAINER_SHOW" or e == "TRAINER_UPDATE" then
    ScanTrainerSoon()
  elseif e == "CHAT_MSG_SYSTEM" then
    ParseLearned(a1 or "")
  elseif e == "UNIT_PET" or e == "UNIT_LEVEL" then
    if a1 == "player" or a1 == "pet" then ns.Refresh() end
  else
    ns.Refresh()
  end
end)

------------------------------------------------------------------------
-- Debug helpers
------------------------------------------------------------------------
local function P(...) print("|cffabd473BTT|r", ...) end

local dbgFrame = CreateFrame("Frame")
dbgFrame:SetScript("OnEvent", function(_, e, ...)
  if ns.logAll then
    if not (e:find("COOLDOWN") or e:find("^COMBAT_LOG") or e:find("^UNIT_") or e == "CURSOR_CHANGED" or e:find("^UPDATE_") or e:find("^NAME_PLATE")) then
      P("ev", e, ...)
    end
    return
  end
  if not ns.debugOn then return end
  if e:find("COOLDOWN") or e == "PET_BAR_UPDATE" or e == "PET_BAR_UPDATE_USABLE" then return end
  local u = e:upper()
  if u:find("PET") or u:find("TRAIN") or u:find("CRAFT") or u:find("BEAST") or u:find("LEARN") or u:find("SPELLS_CHANGED") then
    P("event", e, ...)
  end
end)

function ns.PrintStatus()
  print("|cffabd473BTT|r", "version: " .. ns.VersionText())
  local known, total = ns.Counts()
  local explicit = 0
  for _ in pairs(ns.db.known) do explicit = explicit + 1 end
  P(("learned %d/%d (%d saved, rest implied by higher ranks)"):format(known, total, explicit))
  local ls = ns.lastScan
  P("last scan:", ls.what, ls.n and ("services " .. ls.n .. ", matched " .. ls.matched .. ", new " .. ls.added) or "")
  P("last Beast Training sync:", ns.db.lastSync and date("%b %d %H:%M", ns.db.lastSync) or "never")
  if ns.Geo then P("coordinates:", ns.Geo.StatusText()) end
end

------------------------------------------------------------------------
-- Slash commands
------------------------------------------------------------------------
SLASH_BEASTTRAININGTRACKER1 = "/btt"
SLASH_BEASTTRAININGTRACKER2 = "/beasttraining"
SlashCmdList.BEASTTRAININGTRACKER = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "reset confirm" then
    ns.ResetData()
  elseif msg == "reset" then
    StaticPopup_Show("BTT_RESET_DATA")
  elseif msg == "status" then
    ns.PrintStatus()
  elseif msg == "minimap" then
    if ns.ToggleMinimapButton then ns.ToggleMinimapButton() end
  elseif msg == "tracker" then
    ns.db.opts.tracker = not ns.db.opts.tracker
    Say("zone tracker " .. (ns.db.opts.tracker and "shown" or "hidden"))
    ns.Refresh()
  elseif msg == "hunt" or msg == "pet" or msg == "map" or msg == "settings" or msg == "backup" or msg == "export"
    or msg == "import" or msg == "rarepets" or msg == "abilities" then
    local key = ({ export = "backup", import = "backup", rarepets = "rares", settings = "map" })[msg] or msg
    if ns.ShowTab and ns.TAB then ns.ShowTab(ns.TAB[key]) end
  elseif msg == "petinfo" then
    if ns.RS then ns.RS.PetInfo() end
  elseif msg == "pins" then
    if ns.Geo then ns.Geo.TogglePins() end
  elseif msg == "rares" then
    local list = ns.RS and ns.RS.NeededRares() or {}
    if #list == 0 then Say("no rare teachers left that you need at your level.") end
    for i, r in ipairs(list) do
      if i > 10 then break end
      local parts = {}
      for _, e in ipairs(r.teaches) do parts[#parts + 1] = ("%s %d"):format(e.ab.name, e.rank.rank) end
      Say(("|cffff8000%s|r (%s) - %s%s"):format(r.name, r.t.zone, table.concat(parts, ", "),
        r.status and ("  |cff9d9d9d" .. r.status.text .. "|r") or ""))
    end
  elseif msg == "clearwp" then
    if ns.Geo then ns.Geo.ClearWaypoints() end
  elseif msg == "debug" then
    ns.debugOn = true
    pcall(dbgFrame.RegisterAllEvents, dbgFrame)
    P("debug on - open Beast Training to see what it reports. /btt off to stop")
    ns.PrintStatus()
  elseif msg == "events" then
    ns.logAll = not ns.logAll
    if ns.logAll then pcall(dbgFrame.RegisterAllEvents, dbgFrame) else dbgFrame:UnregisterAllEvents() end
    P("logging all events:", ns.logAll and "ON" or "OFF")
  elseif msg == "off" or msg == "debug off" then
    ns.debugOn, ns.logAll = false, false
    dbgFrame:UnregisterAllEvents()
    P("debug off")
  elseif msg == "help" then
    Say("/btt - toggle window   /btt abilities | hunt | rarepets | pet | settings | backup - open a tab")
    Say("/btt pins - show/hide all beast pins on the map (same as minimap right-click)")
    Say("/btt tracker - show/hide the zone tracker   /btt minimap - show/hide minimap button")
    Say("/btt clearwp - remove waypoints this addon added   /btt status - saved data info")
    Say("/btt rares - rare teachers you still need, with RareScanner timers")
    Say("/btt reset - wipe saved data (asks first)")
  else
    if ns.ToggleMain then ns.ToggleMain() end
  end
end
