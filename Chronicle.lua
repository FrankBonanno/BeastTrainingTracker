local _, ns = ...

-- Companion chronicle: a diary for every pet that's walked at your side.
-- Time together by day and zone, levels, ranks learned, loyalty, falls,
-- moods and notable kills. Shown on the My Pet tab (BookChronicle.lua).

local C = {}
ns.Chronicle = C

local TICK = 15
local MAX_ENTRIES = 500
local MAX_TRAIL = 800  -- path points per day
local TRAIL_STEP = 6   -- thousandths of the map moved before a new point
local TRAIL_DAYS = 60
local KILL_MARKS = { 10, 50, 100, 250, 500, 1000, 2500, 5000 }

local function Readable(...)
  if not issecretvalue then return true end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return false end
  end
  return true
end

local function DB() return ns.db and ns.db.chronicle end

ns.OnInit(function(db)
  local c = db.chronicle or {}
  db.chronicle = c
  c.pets = c.pets or {}     -- id -> record
  c.byGuid = c.byGuid or {} -- pet GUID -> id
  c.byName = c.byName or {} -- "Name|Family" -> id (survives a GUID change)
  c.nextId = c.nextId or 1
  c.gates = c.gates or {}   -- moment -> when it last happened (Moments.lua repeat limits)
end)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function SpellIcon(id, fallback)
  local t = GetSpellTexture and GetSpellTexture(id)
  if not t and C_Spell and C_Spell.GetSpellTexture then t = C_Spell.GetSpellTexture(id) end
  return t or fallback
end

-- icons come from the spells themselves, so they always exist on this client
local ICON_SPELL = { start = 883, level = 635, fall = 982, hungry = 6991, fed = 6991, loyalty = 1515, campfire = 818 }
-- moments without a fitting spell use plain icon files
local ICON_PATH = {
  city = "INV_Misc_Map_01", zone = "INV_Misc_Map02", flight = "Ability_Mount_Wyvern_01",
  inn = "Spell_Nature_Sleep", dungeon = "INV_Misc_Key_03",
  death = "INV_Misc_Bone_HumanSkull_01", sleep = "INV_Misc_Bag_08",
  pvpkill = "INV_Sword_04", battleground = "INV_Sword_04",
}
function C.Icon(kind)
  local id = ICON_SPELL[kind]
  if id then return SpellIcon(id, "Interface\\Icons\\Ability_Hunter_BeastCall") end
  if ICON_PATH[kind] then return "Interface\\Icons\\" .. ICON_PATH[kind] end
  return "Interface\\Icons\\Ability_Hunter_BeastCall"
end

function C.Duration(s)
  s = math.floor(s or 0)
  if s < 60 then return "a moment" end
  local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
  if h > 0 then return m > 0 and ("%d h %d min"):format(h, m) or ("%d h"):format(h) end
  return ("%d min"):format(m)
end

local function Zone()
  local z = ns.CurrentZone()
  return z ~= "" and z or "parts unknown"
end

-- Where you are on the map: uiMapID and x, y in thousandths (nil indoors,
-- in instances, or when the client hides the position)
local function ReadPos()
  if not (C_Map and C_Map.GetBestMapForUnit and C_Map.GetPlayerMapPosition) then return end
  local m = C_Map.GetBestMapForUnit("player")
  if not Readable(m) or not m then return end
  local p = C_Map.GetPlayerMapPosition(m, "player")
  if not p or not Readable(p) then return end
  local x, y = p:GetXY()
  if not Readable(x, y) or not x or not y or (x == 0 and y == 0) then return end
  return m, math.floor(x * 1000 + 0.5), math.floor(y * 1000 + 0.5)
end

local function Pos()
  local ok, m, x, y = pcall(ReadPos)
  if ok then return m, x, y end
end

local function Add(rec, kind, text, sub, icon)
  local e = { t = time(), k = kind, text = text, sub = sub, icon = icon, zone = ns.CurrentZone() }
  if e.zone == "" then e.zone = nil end
  e.m, e.x, e.y = Pos()
  rec.entries[#rec.entries + 1] = e
  if #rec.entries > MAX_ENTRIES then table.remove(rec.entries, 1) end
  return e
end

-- trails are the bulk of the saved data, so only the last TRAIL_DAYS keep theirs
local function PruneTrails(rec)
  local cutoff = date("%Y-%m-%d", time() - TRAIL_DAYS * 86400)
  for k, day in pairs(rec.days) do
    if k < cutoff then day.trail = nil end
  end
end

local function Day(rec)
  local d = date("%Y-%m-%d")
  if not rec.days[d] then
    rec.days[d] = { zones = {}, kills = 0, falls = 0, seconds = 0 }
    PruneTrails(rec)
  end
  return rec.days[d]
end

-- one point of the day's path, if you've moved since the last one
local function AddTrail(d)
  local m, x, y = Pos()
  if not m then return end
  d.trail = d.trail or {}
  local last = d.trail[#d.trail]
  if last and last[1] == m and math.abs(last[2] - x) + math.abs(last[3] - y) < TRAIL_STEP then return end
  if #d.trail < MAX_TRAIL then d.trail[#d.trail + 1] = { m, x, y } end
end

------------------------------------------------------------------------
-- Which pet is out
------------------------------------------------------------------------
local function Identify()
  if not UnitExists("pet") then return end
  local guid, name, fam = UnitGUID("pet"), UnitName("pet"), UnitCreatureFamily("pet")
  if not Readable(guid, name, fam) or not name or name == "" or name == UNKNOWNOBJECT then return end
  return guid, name, fam or "?"
end

-- The record for the pet that's out; `create` starts a new diary for a newcomer
local function Find(create)
  local c = DB()
  if not c then return end
  local guid, name, fam = Identify()
  if not name then return end
  local key = name .. "|" .. fam
  local id = (guid and c.byGuid[guid]) or c.byName[key]
  local rec = id and c.pets[id]
  if not rec then
    if not create then return end
    id = "p" .. c.nextId
    c.nextId = c.nextId + 1
    local lvl = UnitLevel("pet") or 0
    rec = {
      id = id, name = name, family = fam, first = time(), firstLevel = lvl, firstZone = Zone(),
      level = lvl, seconds = 0, kills = 0, falls = 0,
      prey = {}, zones = {}, days = {}, entries = {}, ranks = {},
    }
    c.pets[id] = rec
    Add(rec, "start", ("%s joins your journal at level %d, in %s."):format(name, lvl, rec.firstZone), nil, C.Icon("start"))
    if ns.Journal and C_Timer then C_Timer.After(1, ns.Journal.CheckSeals) end
  elseif rec.name ~= name then
    Add(rec, "rename", ("Renamed from %s to %s."):format(rec.name, name), nil, "Interface\\Icons\\INV_Misc_Note_01")
    rec.name = name
  end
  if guid then c.byGuid[guid] = id end
  c.byName[key] = id
  rec.last = time()
  return rec
end

------------------------------------------------------------------------
-- What changed since the last look
------------------------------------------------------------------------
local function CheckLevel(rec)
  local lvl = UnitLevel("pet")
  if not Readable(lvl) or not lvl or lvl <= 0 then return end
  local up = lvl > rec.level
  if up then
    Add(rec, "level", ("Reached level %d in %s."):format(lvl, Zone()), nil, C.Icon("level"))
  end
  rec.level = lvl
  if up and ns.Journal then ns.Journal.CheckSeals() end
end

-- Ranks only count once the pet's spellbook has been read at least once,
-- so the first look doesn't report everything it already knew as new.
local function CheckRanks(rec)
  if not ns.ScanPet then return end
  ns.ScanPet()
  local any = false
  for name, r in pairs(ns.petRank) do
    any = true
    if r > (rec.ranks[name] or 0) then
      if rec.ranksSeen then
        local ab = ns.byName and ns.byName[name]
        Add(rec, "learned", ("Learned %s %d."):format(name, r), nil, ab and ab.icon)
      end
      rec.ranks[name] = r
    end
  end
  if any then rec.ranksSeen = true end
end

local function CheckLoyalty(rec)
  if not GetPetLoyalty then return end
  local text = GetPetLoyalty()
  if not Readable(text) or type(text) ~= "string" or text == "" then return end
  if rec.loyalty and rec.loyalty ~= text then
    Add(rec, "loyalty", ("Loyalty grew: %s."):format(text), nil, C.Icon("loyalty"))
  end
  rec.loyalty = text
end

local function CheckRare(rec)
  local rare = ns.RS and ns.RS.RareFromPet and ns.RS.RareFromPet()
  if rare and rec.rare ~= rare then rec.rare = rare end
end

local function CheckMood(rec)
  if not GetPetHappiness then return end
  local h = GetPetHappiness()
  if not Readable(h) or not h then return end
  if h == 1 and rec.happy and rec.happy ~= 1 then
    Add(rec, "hungry", ("Grew unhappy in %s."):format(Zone()), "Feed it to bring its damage back up.", C.Icon("hungry"))
  elseif rec.happy == 1 and h > 1 then
    Add(rec, "fed", "Happy again after a good meal.", nil, C.Icon("fed"))
  end
  rec.happy = h
end

local function CheckFall(rec)
  local dead = UnitIsDead("pet")
  if not Readable(dead) then return end
  if dead and not rec.down then
    rec.down = true
    rec.falls = rec.falls + 1
    local d = Day(rec)
    d.falls = d.falls + 1
    Add(rec, "fall", ("Fell in battle in %s."):format(Zone()), nil, C.Icon("fall"))
  elseif not dead then
    rec.down = false
  end
end

------------------------------------------------------------------------
-- Time together
------------------------------------------------------------------------
local lastTick, lastRec
local ticks = 0

-- In combat the client hides the pet's GUID and name, so Find can't tell
-- which pet is out. A pet can't be swapped for another mid-fight, so while
-- one is still out it's the one we last saw.
local function PetStillOut()
  local ok, out = pcall(UnitExists, "pet")
  return ok and Readable(out) and out and lastRec or nil
end

local function Out(create)
  return Find(create) or PetStillOut()
end

local function Tick()
  ticks = ticks + 1
  -- time-together milestones move slowly; check them every few minutes
  if ticks % 20 == 0 and ns.Journal then ns.Journal.CheckSeals() end
  local rec = Out(true)
  if not rec then
    lastTick, lastRec = nil, nil
    return
  end
  local now = GetTime()
  local dt = (lastTick and lastRec == rec) and math.min(now - lastTick, TICK * 2) or 0
  lastTick, lastRec = now, rec
  if dt > 0 then
    rec.seconds = rec.seconds + dt
    local d, z = Day(rec), Zone()
    d.seconds = d.seconds + dt
    d.zones[z] = (d.zones[z] or 0) + dt
    rec.zones[z] = (rec.zones[z] or 0) + dt
    AddTrail(d)
  end
  CheckLevel(rec)
  CheckRanks(rec)
  CheckLoyalty(rec)
  CheckRare(rec)
end

------------------------------------------------------------------------
-- Kills (called by Journal.lua when a beast you or your pet slew dies)
------------------------------------------------------------------------
function C.OnKill(family, name)
  local rec = Out(false)
  if not rec then return end
  rec.kills = rec.kills + 1
  rec.prey[family] = (rec.prey[family] or 0) + 1
  local d = Day(rec)
  d.kills = d.kills + 1
  if name and ns.rarePetByName and ns.rarePetByName[name] then
    local icon = ns.RS and ns.RS.FamilyIcon(family)
    Add(rec, "trophy", ("Brought down %s together in %s."):format(name, Zone()), nil, icon)
  end
  for _, m in ipairs(KILL_MARKS) do
    if rec.kills == m then
      Add(rec, "milestone", ("Your %dth beast slain together."):format(m), nil, ns.RS and ns.RS.FamilyIcon(family))
    end
  end
end

------------------------------------------------------------------------
-- Skinning (called by Journal.lua): got = { itemID = count }, firsts = item IDs
-- you've never skinned before
------------------------------------------------------------------------
local function ItemName(id)
  local name = (C_Item and C_Item.GetItemNameByID and C_Item.GetItemNameByID(id))
    or (GetItemInfo and GetItemInfo(id))
  return name or ("item #" .. id)
end

local function ItemIcon(id)
  return (C_Item and C_Item.GetItemIconByID and C_Item.GetItemIconByID(id))
    or (GetItemIcon and GetItemIcon(id)) or "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"
end

function C.OnSkin(got, firsts)
  local rec = Out(false)
  if not rec then return end
  local d = Day(rec)
  d.skins = (d.skins or 0) + 1
  d.haul = d.haul or {}
  for id, n in pairs(got) do d.haul[id] = (d.haul[id] or 0) + n end
  rec.skins = (rec.skins or 0) + 1
  for _, id in ipairs(firsts) do
    Add(rec, "skin", ("First %s skinned, in %s."):format(ItemName(id), Zone()), nil, ItemIcon(id))
  end
end

-- a finished skinning session (Journal.lua), written into the current pet's diary
function C.OnSessionEnd(s)
  local rec = Out(false)
  if not rec then return end
  local J = ns.Journal
  local haul = J.Haul(s.items)
  local top = {}
  for i = 1, math.min(3, #haul) do top[i] = ("%d %s"):format(haul[i].count, J.ItemName(haul[i].itemID)) end
  Add(rec, "session", ("Skinning in %s: %d skin%s over %s, worth about %s."):format(J.SessionZone(s), s.skins,
    s.skins == 1 and "" or "s", C.Duration((s.finish or s.last) - s.start), J.Money(s.worth or 0)),
    #top > 0 and table.concat(top, ", ") or nil, haul[1] and J.ItemIcon(haul[1].itemID))
end

-- /btt mapcheck: why a day does or doesn't get a map
function C.MapCheck()
  local P = function(...) print("|cffabd473BTT map|r", ...) end
  local ok, m, x, y = pcall(ReadPos)
  P("position:", ok and (m and ("map " .. m .. " at " .. x .. ", " .. y) or "none read") or ("error " .. tostring(m)))
  P("C_Map.GetMapArtLayers:", C_Map and C_Map.GetMapArtLayers and "yes" or "MISSING",
    " GetMapArtLayerTextures:", C_Map and C_Map.GetMapArtLayerTextures and "yes" or "MISSING",
    " explored overlays:", C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures and "yes" or "MISSING")
  if m and C_Map and C_Map.GetMapArtLayers then
    local layers = C_Map.GetMapArtLayers(m)
    local layer = layers and layers[1]
    local files = C_Map.GetMapArtLayerTextures and C_Map.GetMapArtLayerTextures(m, 1)
    P("art for map " .. m .. ":", layer and ("%dx%d, tiles %dx%d"):format(layer.layerWidth or 0, layer.layerHeight or 0,
      layer.tileWidth or 0, layer.tileHeight or 0) or "no layer", "files:", files and #files or 0)
  end
  if ns.Moments then P(ns.Moments.CapitalCheck()) end
  local rec = Out(false)
  if not rec then return P("no pet out (the trail records while your pet is out)") end
  local d = rec.days[date("%Y-%m-%d")]
  P(("%s today: %d trail points"):format(rec.name, d and d.trail and #d.trail or 0))
end

------------------------------------------------------------------------
-- Reading the diaries
------------------------------------------------------------------------
function C.Current() return Out(false) end

-- The pet that's out, or the one last at your side within `window` seconds:
-- pets are put away when you die, fly or zone, and a moment then is still theirs.
function C.Recent(window)
  local rec = Out(false)
  if rec then return rec end
  local c, best = DB(), nil
  for _, r in pairs(c and c.pets or {}) do
    if r.last and time() - r.last <= window and (not best or r.last > best.last) then best = r end
  end
  return best
end

-- A moment (Moments.lua) for the pet that's out, or for `rec`. `extra` adds
-- fields to the entry (a tag; m, x, y for a place other than here).
-- Returns the entry, or false if there's no pet.
function C.Note(kind, text, sub, icon, rec, extra)
  rec = rec or Out(false)
  if not rec then return false end
  local e = Add(rec, kind, text, sub, icon or C.Icon(kind))
  for k, v in pairs(extra or {}) do e[k] = v end
  if ns.Refresh then ns.Refresh() end
  return e
end

-- where you are: { m =, x =, y = } (thousandths), or nil indoors / in instances
function C.Position()
  local m, x, y = Pos()
  if m then return { m = m, x = x, y = y } end
end

function C.Get(id)
  local c = DB()
  return c and c.pets[id]
end

-- every companion, most recently at your side first
function C.Pets()
  local out, c = {}, DB()
  for _, rec in pairs(c and c.pets or {}) do out[#out + 1] = rec end
  table.sort(out, function(a, b) return (a.last or a.first) > (b.last or b.first) end)
  return out
end

-- "zone, seconds" with the most time first
function C.TopZones(zones)
  local out = {}
  for z, s in pairs(zones or {}) do out[#out + 1] = { zone = z, seconds = s } end
  table.sort(out, function(a, b) return a.seconds > b.seconds end)
  return out
end

------------------------------------------------------------------------
-- Events (wrapped: unit events can arrive tainted on this client)
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local function OnEvent(_, e)
  if not ns.db or ns.isHunter == false then return end
  if e == "UNIT_PET" or e == "PLAYER_ENTERING_WORLD" or e == "UNIT_LEVEL" then
    Tick()
  else
    local rec = Out(false)
    if not rec then return end
    if e == "UNIT_HAPPINESS" then
      CheckMood(rec)
    elseif e == "UNIT_HEALTH" then
      CheckFall(rec)
    end
  end
end

for _, e in ipairs({ "UNIT_PET", "PLAYER_ENTERING_WORLD", "UNIT_HAPPINESS" }) do
  pcall(ev.RegisterEvent, ev, e)
end
if ev.RegisterUnitEvent then
  pcall(ev.RegisterUnitEvent, ev, "UNIT_HEALTH", "pet")
  pcall(ev.RegisterUnitEvent, ev, "UNIT_LEVEL", "pet")
end
ev:SetScript("OnEvent", function(...) pcall(OnEvent, ...) end)

if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(TICK, function() if ns.db and ns.isHunter ~= false then pcall(Tick) end end)
end
