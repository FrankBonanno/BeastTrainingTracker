local _, ns = ...

-- The hunter's journal records: beasts slain (by family), skinning hauls with
-- their auction value, and the milestones (wax seals) built on them.
-- Shown by the Trophy Room tab (BookTrophies.lua).

local J = {}
ns.Journal = J

local MAX_TRACKED = 400  -- GUIDs remembered at once (families seen, mobs you hit)
local SKIN_WINDOW = 4    -- seconds between a Skinning cast and its loot window
local CALLER = "BeastTrainingTracker"

local BEAST = (C_CreatureInfo and C_CreatureInfo.GetCreatureTypeInfo
  and (C_CreatureInfo.GetCreatureTypeInfo(1) or {}).name) or "Beast"
local function SpellName(id)
  if C_Spell and C_Spell.GetSpellName then
    local name = C_Spell.GetSpellName(id)
    if name then return name end
  end
  if GetSpellInfo then return (GetSpellInfo(id)) end
end

-- Skinning's ranks (Apprentice .. Artisan): any of them known means a skinner
local SKIN_IDS = { [8613] = true, [8617] = true, [8618] = true, [10768] = true }
local SKINNING = SpellName(8613) or "Skinning"

local function DB() return ns.db and ns.db.journal end

ns.OnInit(function(db)
  local j = db.journal or {}
  db.journal = j
  j.kills = j.kills or 0
  j.byFamily = j.byFamily or {}
  j.skins = j.skins or 0
  j.skinned = j.skinned or {}  -- itemID -> count
  j.seals = j.seals or {}      -- seal id -> time earned
  j.since = j.since or time()
  j.sessions = j.sessions or {} -- finished skinning sessions, oldest first
  j.npcFamily = j.npcFamily or {} -- creature ID -> family, for every beast kind you've seen
end)

------------------------------------------------------------------------
-- Which family a mob belongs to: from units you've looked at, else by name.
-- This client hides some values from addons in combat ("secret" values):
-- anything secret is skipped rather than read.
------------------------------------------------------------------------
local familyOf, familyCount = {}, 0
local counted, countedCount = {}, 0

local function Readable(...)
  if not issecretvalue then return true end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return false end
  end
  return true
end

-- the creature ID inside a GUID (Creature-0-server-instance-zone-npcID-spawn)
local function NpcOf(guid)
  if type(guid) ~= "string" then return end
  local kind, _, _, _, _, npc = strsplit("-", guid)
  if kind == "Creature" or kind == "Vehicle" then return tonumber(npc) end
end

-- Families are remembered per creature kind and saved, so seeing one
-- Riverglades Panther once is enough for every one you kill after it
-- (in combat their GUIDs are hidden, so a mob pulled mid-fight can't be read).
local function Remember(unit)
  if not UnitExists(unit) or UnitIsPlayer(unit) or UnitPlayerControlled(unit) then return end
  local guid = UnitGUID(unit)
  if not Readable(guid) or type(guid) ~= "string" or familyOf[guid] ~= nil then return end
  local fam, kind = UnitCreatureFamily(unit), UnitCreatureType(unit)
  if not Readable(fam, kind) or kind ~= BEAST then return end
  if familyCount >= MAX_TRACKED then wipe(familyOf); familyCount = 0 end
  familyOf[guid] = fam or BEAST
  familyCount = familyCount + 1
  local npc, j = NpcOf(guid), DB()
  if npc and j then j.npcFamily[npc] = fam or BEAST end
end

local function FamilyByName(name)
  if not name then return end
  local rare = ns.rarePetByName and ns.rarePetByName[name]
  if rare then return rare.family end
  local list = ns.teacherIndex and ns.teacherIndex[name]
  if list and list[1] then return list[1].t.family end
end

local function FamilyOf(guid, name)
  local fam = familyOf[guid]
  if fam ~= nil then return fam end
  local npc, j = NpcOf(guid), DB()
  if npc and j and j.npcFamily[npc] then return j.npcFamily[npc] end
  return FamilyByName(name)
end

-- /btt killcheck: says in chat why each corpse you loot does or doesn't count
local killCheck = false
function J.ToggleKillCheck()
  killCheck = not killCheck
  ns.Say("kill check " .. (killCheck and "on - loot a few corpses and watch chat. /btt killcheck again to stop."
    or "off."))
end
local function Check(...)
  if killCheck then print("|cffabd473BTT kills|r", ...) end
end

------------------------------------------------------------------------
-- Milestones
------------------------------------------------------------------------
local seals -- built on first use

local function Families()
  local set, list = {}, {}
  for _, ab in ipairs(ns.abilities) do
    if not ab.isAll then
      for _, f in ipairs(ab.fam) do
        if not set[f] then set[f], list[#list + 1] = true, f end
      end
    end
  end
  table.sort(list)
  return list
end
J.Families = Families

local function KilledFamilies()
  local j, n = DB(), 0
  for _, f in ipairs(Families()) do
    if j and (j.byFamily[f] or 0) > 0 then n = n + 1 end
  end
  return n
end

local function TamedCount()
  local n = 0
  for _ in pairs(ns.db and ns.db.tamedRares or {}) do n = n + 1 end
  return n
end

local function MasteredCount()
  local n = 0
  for _, ab in ipairs(ns.abilities) do
    local all = #ab.parsed > 0
    for _, r in ipairs(ab.parsed) do
      if not ns.Status(ab, r.rank) then all = false break end
    end
    if all then n = n + 1 end
  end
  return n
end

local function RankPercent()
  local known, total = ns.Counts()
  return total > 0 and math.floor(known / total * 100) or 0
end

-- Companion-based progress, read from the Chronicle (loaded after this file)
local function Pets() return ns.Chronicle and ns.Chronicle.Pets() or {} end

local function MaxPetLevel()
  local m = 0
  for _, r in ipairs(Pets()) do m = math.max(m, r.level or 0) end
  return m
end

local function CompanionFamilies()
  local set, n = {}, 0
  for _, r in ipairs(Pets()) do
    if r.family and r.family ~= "?" and not set[r.family] then set[r.family], n = true, n + 1 end
  end
  return n
end

local function HoursTogether()
  local s = 0
  for _, r in ipairs(Pets()) do s = s + (r.seconds or 0) end
  return math.floor(s / 3600)
end

local function BestPetKills()
  local m = 0
  for _, r in ipairs(Pets()) do m = math.max(m, r.kills or 0) end
  return m
end

local function ZonesHunted()
  local set, n = {}, 0
  for _, r in ipairs(Pets()) do
    for z in pairs(r.zones or {}) do
      if not set[z] then set[z], n = true, n + 1 end
    end
  end
  return n
end

local function SessionsDone()
  local j = DB()
  return j and #j.sessions or 0
end

local function BestHaul()
  local m, j = 0, DB()
  for _, s in ipairs(j and j.sessions or {}) do m = math.max(m, s.worth or 0) end
  return m
end

-- opts: skinner = only for skinners, money = goal/progress in copper
local function Seal(id, group, name, desc, icon, goal, points, value, opts)
  opts = opts or {}
  return { id = id, group = group, name = name, desc = desc, icon = icon, goal = goal, points = points,
    value = value, skinner = opts.skinner, money = opts.money }
end

local function BuildSeals()
  local fam = ns.RS and ns.RS.FamilyIcon or function() return "Interface\\Icons\\Ability_Hunter_BeastTaming" end
  local kills = function() local j = DB() return j and j.kills or 0 end
  local skins = function() local j = DB() return j and j.skins or 0 end
  local companions = function() return #Pets() end
  local value = function() return J.SkinValue() end
  local nFam, nAb = #Families(), #ns.abilities
  local TRAIN, CALL = "Interface\\Icons\\Ability_Hunter_BeastTraining", "Interface\\Icons\\Ability_Hunter_BeastCall"
  local PELT, COIN = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01", "Interface\\Icons\\INV_Misc_Coin_01"
  local MAP = "Interface\\Icons\\INV_Misc_Map_01"
  local SKIN, GOLD = { skinner = true }, { skinner = true, money = true }
  return {
    Seal("slay10", "Slayer", "Novice Trapper", "Slay 10 beasts", fam("Boar"), 10, 10, kills),
    Seal("slay100", "Slayer", "Seasoned Hunter", "Slay 100 beasts", fam("Wolf"), 100, 25, kills),
    Seal("slay500", "Slayer", "Beastbane", "Slay 500 beasts", fam("Raptor"), 500, 50, kills),
    Seal("slay1000", "Slayer", "Scourge of the Wilds", "Slay 1,000 beasts", fam("Gorilla"), 1000, 75, kills),
    Seal("slay5000", "Slayer", "Apex Predator", "Slay 5,000 beasts", fam("Cat"), 5000, 150, kills),
    Seal("fam5", "Prey", "Know Thy Prey", "Slay beasts of 5 families", fam("Spider"), 5, 25, KilledFamilies),
    Seal("fam10", "Prey", "Student of the Wild", "Slay beasts of 10 families", fam("Crocolisk"), 10, 50, KilledFamilies),
    Seal("famAll", "Prey", "Every Fang and Claw", ("Slay beasts of all %d families"):format(nFam), fam("Wind Serpent"), nFam, 100, KilledFamilies),
    Seal("pet20", "Companion", "Growing Bond", "Raise a companion to level 20", CALL, 20, 15, MaxPetLevel),
    Seal("pet40", "Companion", "Seasoned Companion", "Raise a companion to level 40", CALL, 40, 40, MaxPetLevel),
    Seal("pet60", "Companion", "Partner in Legend", "Raise a companion to level 60", CALL, 60, 100, MaxPetLevel),
    Seal("comp3", "Companion", "Small Pack", "Keep a journal for 3 companions", fam("Wolf"), 3, 20, companions),
    Seal("comp6", "Companion", "Full Stable", "Keep a journal for 6 companions", fam("Boar"), 6, 40, companions),
    Seal("comp10", "Companion", "Friend to Beasts", "Keep a journal for 10 companions", fam("Bear"), 10, 75, companions),
    Seal("compFam3", "Companion", "Mixed Company", "Companions of 3 different families", fam("Cat"), 3, 25, CompanionFamilies),
    Seal("compFam6", "Companion", "Menagerie of Friends", "Companions of 6 different families", fam("Raptor"), 6, 60, CompanionFamilies),
    Seal("hours10", "Companion", "Side by Side", "Spend 10 hours with your companions", CALL, 10, 20, HoursTogether),
    Seal("hours50", "Companion", "Old Friends", "Spend 50 hours with your companions", CALL, 50, 50, HoursTogether),
    Seal("hours200", "Companion", "Inseparable", "Spend 200 hours with your companions", CALL, 200, 120, HoursTogether),
    Seal("petKills100", "Companion", "Hunting Partner", "Slay 100 beasts with one companion", fam("Wolf"), 100, 25, BestPetKills),
    Seal("petKills1000", "Companion", "Pack Hunter", "Slay 1,000 beasts with one companion", fam("Hyena"), 1000, 75, BestPetKills),
    Seal("zones10", "Explorer", "Wanderer", "Hunt with a companion in 10 zones", MAP, 10, 25, ZonesHunted),
    Seal("zones25", "Explorer", "Far Ranger", "Hunt with a companion in 25 zones", MAP, 25, 60, ZonesHunted),
    Seal("tame1", "Collector", "First Trophy", "Tame a special pet", fam("Bird of Prey"), 1, 25, TamedCount),
    Seal("tame5", "Collector", "Trophy Hunter", "Tame 5 special pets", fam("Bear"), 5, 50, TamedCount),
    Seal("tame10", "Collector", "Menagerie", "Tame 10 special pets", fam("Tallstrider"), 10, 75, TamedCount),
    Seal("tame25", "Collector", "Keeper of Legends", "Tame 25 special pets", fam("Turtle"), 25, 150, TamedCount),
    Seal("rank25", "Trainer", "Apprentice Trainer", "Learn 25% of all ranks", TRAIN, 25, 25, RankPercent),
    Seal("rank50", "Trainer", "Journeyman Trainer", "Learn 50% of all ranks", TRAIN, 50, 50, RankPercent),
    Seal("rank75", "Trainer", "Expert Trainer", "Learn 75% of all ranks", TRAIN, 75, 75, RankPercent),
    Seal("rank100", "Trainer", "Master Trainer", "Learn every rank", TRAIN, 100, 150, RankPercent),
    Seal("master1", "Trainer", "Perfected", "Learn every rank of an ability", CALL, 1, 25, MasteredCount),
    Seal("master10", "Trainer", "Ten Perfected", "Learn every rank of 10 abilities", CALL, 10, 75, MasteredCount),
    Seal("masterAll", "Trainer", "Beastmaster", ("Learn every rank of all %d abilities"):format(nAb), CALL, nAb, 200, MasteredCount),
    Seal("skin50", "Skinner", "Steady Knife", "Skin 50 beasts", PELT, 50, 15, skins, SKIN),
    Seal("skin500", "Skinner", "Tanner's Friend", "Skin 500 beasts", PELT, 500, 40, skins, SKIN),
    Seal("skin2000", "Skinner", "Master Flayer", "Skin 2,000 beasts", PELT, 2000, 100, skins, SKIN),
    Seal("session5", "Skinner", "Regular Rounds", "Finish 5 skinning sessions", PELT, 5, 20, SessionsDone, SKIN),
    Seal("session25", "Skinner", "Seasoned Skinner", "Finish 25 skinning sessions", PELT, 25, 60, SessionsDone, SKIN),
    Seal("haul1g", "Skinner", "Good Day's Work", "Skin 1 gold worth in one session", COIN, 10000, 20, BestHaul, GOLD),
    Seal("haul10g", "Skinner", "Mother Lode", "Skin 10 gold worth in one session", COIN, 100000, 60, BestHaul, GOLD),
    Seal("gold10", "Skinner", "Pocket Money", "Skin 10 gold worth of goods", COIN, 100000, 25, value, GOLD),
    Seal("gold100", "Skinner", "Hide Merchant", "Skin 100 gold worth of goods", COIN, 1000000, 75, value, GOLD),
  }
end

------------------------------------------------------------------------
-- Hunter rank: earned seals give points; points climb the ranks
------------------------------------------------------------------------
local function SpellIcon(id)
  local t = C_Spell and C_Spell.GetSpellTexture and C_Spell.GetSpellTexture(id)
  if not t and GetSpellTexture then t = GetSpellTexture(id) end
  return t or "Interface\\Icons\\Ability_Hunter_BeastTraining"
end

-- Each rank needs a share of the points this character can earn: skinners
-- have more seals than non-skinners, so the scale follows what's open to you.
-- The top rank asks for 88%, so no one has to earn every last seal.
-- Icons are hunter spells, so they exist on every client.
J.RANKS = {
  { name = "Fledgling", share = 0, spell = 1494 },            -- Track Beasts
  { name = "Trapper", share = 0.02, spell = 1499 },           -- Freezing Trap
  { name = "Tracker", share = 0.05, spell = 1130 },           -- Hunter's Mark
  { name = "Stalker", share = 0.09, spell = 5118 },           -- Aspect of the Cheetah
  { name = "Pathfinder", share = 0.15, spell = 6197 },        -- Eagle Eye
  { name = "Huntsman", share = 0.23, spell = 13165 },         -- Aspect of the Hawk
  { name = "Beastwarden", share = 0.33, spell = 3045 },       -- Rapid Fire
  { name = "Wildmaster", share = 0.45, spell = 13159 },       -- Aspect of the Pack
  { name = "Packleader", share = 0.58, spell = 1515 },        -- Tame Beast
  { name = "Beastlord", share = 0.72, spell = 20043 },        -- Aspect of the Wild
  { name = "Legend of the Wilds", share = 0.88, spell = 19574 }, -- Bestial Wrath
}

function J.RankIcon(i)
  local r = J.RANKS[i]
  return r and SpellIcon(r.spell)
end

-- seals that apply to this character (skinning ones only for skinners)
local function Applicable(s, skinner) return skinner or not s.skinner end

-- points from every applicable seal you've earned (once earned, a seal is yours to keep)
function J.Points()
  seals = seals or BuildSeals()
  local j, skinner, total = DB(), J.IsSkinner(), 0
  for _, s in ipairs(seals) do
    if j and j.seals[s.id] and Applicable(s, skinner) then total = total + s.points end
  end
  return total
end

-- every point this character could earn
function J.MaxPoints()
  seals = seals or BuildSeals()
  local skinner, total = J.IsSkinner(), 0
  for _, s in ipairs(seals) do
    if Applicable(s, skinner) then total = total + s.points end
  end
  return total
end

-- the ranks with the points each needs for this character
function J.Ranks()
  local max, out = J.MaxPoints(), {}
  for i, r in ipairs(J.RANKS) do
    out[i] = { name = r.name, spell = r.spell, points = math.floor(r.share * max / 5 + 0.5) * 5 }
  end
  return out
end

-- index, rank, points, next rank (nil at the top)
function J.Rank()
  local ranks, pts, idx = J.Ranks(), J.Points(), 1
  for i, r in ipairs(ranks) do
    if pts >= r.points then idx = i end
  end
  return idx, ranks[idx], pts, ranks[idx + 1]
end

-- { seal, have, done, when } for every seal that applies to this character
function J.Seals()
  seals = seals or BuildSeals()
  local j, skinner, out = DB(), J.IsSkinner(), {}
  for _, s in ipairs(seals) do
    if skinner or not s.skinner then
      local ok, have = pcall(s.value)
      have = ok and have or 0
      out[#out + 1] = { seal = s, have = have, done = have >= s.goal, when = j and j.seals[s.id] }
    end
  end
  return out
end

-- Records newly earned seals; announces them (and rank-ups) except on the very first check
function J.CheckSeals()
  local j = DB()
  if not j then return end
  local announce = j.sealsChecked
  local before = J.Rank()
  for _, e in ipairs(J.Seals()) do
    if e.done and not j.seals[e.seal.id] then
      j.seals[e.seal.id] = time()
      if announce and ns.Toast then
        ns.Toast("Milestone reached!", { e.seal.name, e.seal.desc, ("+%d hunter points"):format(e.seal.points) },
          e.seal.icon)
      end
    end
  end
  j.sealsChecked = true
  local after, rank = J.Rank()
  if announce and after > before and ns.Toast then
    -- shown after the seal's toast, which it replaces
    C_Timer.After(4, function()
      ns.Toast("Hunter rank: " .. rank.name, { ("Rank %d of %d"):format(after, #J.RANKS) }, J.RankIcon(after))
    end)
  end
end

------------------------------------------------------------------------
-- Hunting log
------------------------------------------------------------------------
function J.Kills()
  local j = DB()
  return j and j.kills or 0
end

-- { family, count } most slain first
function J.FamilyKills()
  local out, j = {}, DB()
  for f, n in pairs(j and j.byFamily or {}) do out[#out + 1] = { family = f, count = n } end
  table.sort(out, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.family < b.family
  end)
  return out
end

local function CountKill(guid, name)
  if type(guid) ~= "string" or not guid:find("^Creature") then return end
  if counted[guid] then return Check("already counted", NpcOf(guid)) end
  local fam = FamilyOf(guid, name)
  if not fam then return Check(("not counted: creature %s isn't a beast I've seen yet"):format(tostring(NpcOf(guid)))) end
  Check(("counted: %s (creature %s)"):format(fam, tostring(NpcOf(guid))))
  if countedCount >= MAX_TRACKED then wipe(counted); countedCount = 0 end
  counted[guid], countedCount = true, countedCount + 1
  local j = DB()
  if not j then return end
  j.kills = j.kills + 1
  j.byFamily[fam] = (j.byFamily[fam] or 0) + 1
  familyOf[guid] = nil
  if ns.Chronicle then ns.Chronicle.OnKill(fam, name) end
  J.CheckSeals()
  if ns.Refresh then ns.Refresh() end
end

------------------------------------------------------------------------
-- Skinning
------------------------------------------------------------------------
-- rank, max (nil when the character doesn't have Skinning)
function J.SkinningRank()
  if GetNumSkillLines and GetSkillLineInfo then
    for i = 1, GetNumSkillLines() do
      local name, header, _, rank, _, _, max = GetSkillLineInfo(i)
      if not header and name == SKINNING then return rank, max end
    end
  end
end

local function KnowsSkinningSpell()
  for id in pairs(SKIN_IDS) do
    if IsPlayerSpell and IsPlayerSpell(id) then return true end
    if IsSpellKnown and IsSpellKnown(id) then return true end
    if C_SpellBook and C_SpellBook.IsSpellKnown and C_SpellBook.IsSpellKnown(id) then return true end
  end
  -- by name, which only finds spells in your spellbook
  if C_Spell and C_Spell.GetSpellInfo and C_Spell.GetSpellInfo(SKINNING) then return true end
end

-- Skill lines can be hidden under a collapsed header, so the spellbook and
-- any recorded skin count too
function J.IsSkinner()
  if J.SkinningRank() then return true end
  local ok, known = pcall(KnowsSkinningSpell)
  if ok and known then return true end
  local j = DB()
  return j and j.skins > 0 or false
end

-- copper per item, and where the price came from
function J.Price(itemID)
  local nf = _G.NaowhForever
  if nf and nf.AuctionPrice then
    local ok, p = pcall(nf.AuctionPrice, itemID)
    if ok and type(p) == "number" and p > 0 then return p, "Naowh Forever" end
  end
  local api = Auctionator and Auctionator.API and Auctionator.API.v1
  if api and api.GetAuctionPriceByItemID then
    local ok, p = pcall(api.GetAuctionPriceByItemID, CALLER, itemID)
    if ok and type(p) == "number" and p > 0 then return p, "Auctionator" end
  end
  if TSM_API and TSM_API.GetCustomPriceValue then
    local ok, p = pcall(TSM_API.GetCustomPriceValue, "dbmarket", "i:" .. itemID)
    if ok and type(p) == "number" and p > 0 then return p, "TSM" end
  end
  local sell = J.VendorPrice(itemID)
  if sell and sell > 0 then return sell, "vendor" end
end

------------------------------------------------------------------------
-- Item names, icons and vendor prices. An item the client hasn't loaded
-- yet returns nothing at first; we ask for it and the page redraws when
-- ITEM_DATA_LOAD_RESULT / GET_ITEM_INFO_RECEIVED arrives.
------------------------------------------------------------------------
local function GetInfo(id)
  if C_Item and C_Item.GetItemInfo then return C_Item.GetItemInfo(id) end
  if GetItemInfo then return GetItemInfo(id) end
end

local function RequestItem(id)
  if C_Item and C_Item.RequestLoadItemDataByID then pcall(C_Item.RequestLoadItemDataByID, id) end
end

function J.ItemName(id)
  local name = C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id)
  if not name then name = GetInfo(id) end
  if name then return name end
  RequestItem(id)
  return "Loading..."
end

function J.ItemIcon(id)
  local icon = C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id)
  return icon or (GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"
end

function J.VendorPrice(id)
  local sell = select(11, GetInfo(id))
  if type(sell) == "number" then return sell end
  RequestItem(id)
end

-- { itemID, count, price, value, source } most valuable first; items = { itemID = count }
function J.Haul(items)
  local out = {}
  for id, n in pairs(items or {}) do
    local price, source = J.Price(id)
    out[#out + 1] = { itemID = id, count = n, price = price, value = (price or 0) * n, source = source }
  end
  table.sort(out, function(a, b)
    if a.value ~= b.value then return a.value > b.value end
    return a.count > b.count
  end)
  return out
end

function J.SkinHaul()
  local j = DB()
  return J.Haul(j and j.skinned)
end

function J.SkinValue()
  local total = 0
  for _, e in ipairs(J.SkinHaul()) do total = total + e.value end
  return total
end

function J.Skins()
  local j = DB()
  return j and j.skins or 0
end

-- "12g 34s 5c" (no textures, so it reads on the parchment)
function J.Money(copper)
  copper = math.floor(copper or 0)
  local g, s, c = math.floor(copper / 10000), math.floor(copper / 100) % 100, copper % 100
  if g > 0 then return ("%dg %ds"):format(g, s) end
  if s > 0 then return ("%ds %dc"):format(s, c) end
  return ("%dc"):format(c)
end

------------------------------------------------------------------------
-- Skinning sessions: one starts with your first skin and ends when you're
-- back in a city or inn, after SESSION_IDLE without a skin, or by hand.
------------------------------------------------------------------------
local SESSION_IDLE = 30 * 60
local MAX_SESSIONS = 100

-- the zone with the most skins in a session
function J.SessionZone(s)
  local best, n = nil, 0
  for z, c in pairs(s.zones or {}) do
    if c > n then best, n = z, c end
  end
  return best or "the wilds"
end

function J.SessionValue(s)
  local total = 0
  for _, e in ipairs(J.Haul(s.items)) do total = total + e.value end
  return total
end

function J.Session()
  local j = DB()
  return j and j.session
end

-- finished sessions, newest first
function J.Sessions()
  local out, j = {}, DB()
  for i = #(j and j.sessions or {}), 1, -1 do out[#out + 1] = j.sessions[i] end
  return out
end

local function Resting() return IsResting and IsResting() or false end

-- starts a session by hand (one also starts on its own with your first skin)
function J.StartSession()
  local j = DB()
  if not j or j.session then return end
  local now = time()
  j.session = { start = now, last = now, skins = 0, items = {}, zones = {}, out = not Resting() }
  ns.Say("skinning session started. It ends when you're back in town, after 30 minutes without a skin, or by hand.")
  if ns.Refresh then ns.Refresh() end
end

function J.EndSession(reason)
  local j = DB()
  local s = j and j.session
  if not s then return end
  j.session = nil
  if s.skins == 0 then
    -- nothing skinned: no ledger worth keeping
    if reason == "manual" then ns.Say("skinning session ended - nothing skinned.") end
    if ns.Refresh then ns.Refresh() end
    return
  end
  s.finish = s.last or time()
  s.reason = reason
  s.worth = J.SessionValue(s)
  table.insert(j.sessions, s)
  if #j.sessions > MAX_SESSIONS then table.remove(j.sessions, 1) end
  ns.Say(("skinning session in %s done: %d skin%s, worth about %s."):format(J.SessionZone(s), s.skins,
    s.skins == 1 and "" or "s", J.Money(s.worth)))
  if ns.Chronicle and ns.Chronicle.OnSessionEnd then ns.Chronicle.OnSessionEnd(s) end
  J.CheckSeals()
  if ns.Refresh then ns.Refresh() end
end

local function SessionFor(now)
  local j = DB()
  if j.session and now - (j.session.last or j.session.start) > SESSION_IDLE then J.EndSession("idle") end
  if not j.session then
    j.session = { start = now, last = now, skins = 0, items = {}, zones = {}, out = not Resting() }
  end
  return j.session
end

-- "back in town" only counts once you've been out of town during the session,
-- so a session started in a city isn't closed straight away
local function CheckSessionEnd()
  local s = J.Session()
  if not s then return end
  if not Resting() then s.out = true end
  if time() - (s.last or s.start) > SESSION_IDLE then
    J.EndSession("idle")
  elseif s.out and Resting() then
    J.EndSession("town")
  end
end

------------------------------------------------------------------------
-- Events. Addons can't read the combat log on this client, so a kill is
-- seen the way the game shows it: your target dying while tapped by you,
-- or a corpse you loot. Everything is wrapped in pcall (unit events can
-- arrive tainted).
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local lastSkin = 0
local lootReadAt = 0
local watching -- GUID of the beast you're targeting, until it dies

local function SafeName(unit)
  local name = UnitName(unit)
  if Readable(name) then return name end
end

local function StopWatching()
  watching = nil
  ev:UnregisterEvent("UNIT_HEALTH")
end

local function TargetDied()
  local guid = UnitGUID("target")
  if not Readable(guid) or guid ~= watching then return end
  local dead = UnitIsDead("target")
  local denied = UnitIsTapDenied and UnitIsTapDenied("target")
  if not Readable(dead, denied) or not dead then return end
  if not denied then CountKill(guid, SafeName("target")) end
  StopWatching()
end

local function Retarget()
  StopWatching()
  Remember("target")
  local guid = UnitGUID("target")
  if not Readable(guid) or type(guid) ~= "string" or counted[guid] then return end
  local name = SafeName("target")
  if not FamilyOf(guid, name) then return end
  local dead = UnitIsDead("target")
  local denied = UnitIsTapDenied and UnitIsTapDenied("target")
  if not Readable(dead, denied) then return end
  if dead then
    if not denied then CountKill(guid, name) end
    return
  end
  watching = guid
  if ev.RegisterUnitEvent then
    ev:RegisterUnitEvent("UNIT_HEALTH", "target")
  else
    ev:RegisterEvent("UNIT_HEALTH")
  end
end

local function RecordSkinLoot()
  local j = DB()
  if not j then return end
  local got, firsts = {}, {}
  for slot = 1, GetNumLootItems() do
    local link = GetLootSlotLink(slot)
    local id = Readable(link) and type(link) == "string" and tonumber(link:match("item:(%d+)"))
    if id then
      local _, _, qty = GetLootSlotInfo(slot)
      if not Readable(qty) then qty = 1 end
      qty = math.max(1, qty or 1)
      if not j.skinned[id] then firsts[#firsts + 1] = id end
      j.skinned[id] = (j.skinned[id] or 0) + qty
      got[id] = (got[id] or 0) + qty
    end
  end
  if next(got) then
    j.skins = j.skins + 1
    local s = SessionFor(time())
    s.skins, s.last = s.skins + 1, time()
    local zone = ns.CurrentZone()
    if zone ~= "" then s.zones[zone] = (s.zones[zone] or 0) + 1 end
    for id, n in pairs(got) do s.items[id] = (s.items[id] or 0) + n end
    if ns.Chronicle then ns.Chronicle.OnSkin(got, firsts) end
    J.CheckSeals()
    if ns.Refresh then ns.Refresh() end
  end
end

-- A corpse you can loot is one you killed (GetLootSourceInfo: guid, quantity, guid, quantity...)
local function CountLootSources()
  if not GetLootSourceInfo then return end
  -- the corpse you clicked is usually under the mouse or targeted, and readable by now
  Remember("mouseover")
  Remember("target")
  for slot = 1, GetNumLootItems() do
    local src = { GetLootSourceInfo(slot) }
    for i = 1, #src, 2 do
      if Readable(src[i]) then CountKill(src[i]) else Check("not counted: the game hid this corpse's ID") end
    end
  end
end

local function OnEvent(_, e, a1, _, a3)
  if not ns.db then return end
  if e == "PLAYER_TARGET_CHANGED" then
    Retarget()
  elseif e == "UNIT_HEALTH" then
    if a1 == "target" then TargetDied() end
  elseif e == "UPDATE_MOUSEOVER_UNIT" then
    Remember("mouseover")
  elseif e == "NAME_PLATE_UNIT_ADDED" then
    Remember(a1)
  elseif e == "UNIT_SPELLCAST_SUCCEEDED" then
    if a1 == "player" and Readable(a3) and a3 and (SKIN_IDS[a3] or SpellName(a3) == SKINNING) then
      lastSkin = GetTime()
    end
  elseif e == "LOOT_READY" or e == "LOOT_OPENED" then
    -- LOOT_READY comes first (before auto loot empties the window); LOOT_OPENED follows
    -- within moments, so read each window once
    if GetTime() - lootReadAt < 1 then return end
    lootReadAt = GetTime()
    -- skinning someone else's kill isn't your kill, so skinning loot only counts as skins
    if GetTime() - lastSkin <= SKIN_WINDOW then
      lastSkin = 0
      RecordSkinLoot()
    else
      CountLootSources()
    end
  elseif e == "PLAYER_UPDATE_RESTING" or e == "ZONE_CHANGED_NEW_AREA" then
    CheckSessionEnd()
  elseif e == "PLAYER_ENTERING_WORLD" then
    J.CheckSeals()
    CheckSessionEnd()
  end
end

for _, e in ipairs({ "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
  "UNIT_SPELLCAST_SUCCEEDED", "LOOT_READY", "LOOT_OPENED", "PLAYER_ENTERING_WORLD",
  "PLAYER_UPDATE_RESTING", "ZONE_CHANGED_NEW_AREA" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(...) if ns.isHunter ~= false then pcall(OnEvent, ...) end end)

-- closes a session that's gone quiet, even while you stand still
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(60, function() if ns.db and ns.isHunter ~= false then pcall(CheckSessionEnd) end end)
end
