local _, ns = ...

-- Chronicle moments: what happened to you and your pet - deaths, PvP kills,
-- dungeon runs, campfires, cities, new zones, flights and inns - written into
-- the diary of the pet that's out. The Chronicle page shows them as small
-- map cards under each day's map (BookChronicle.lua).

local M = {}
ns.Moments = M

-- entry kinds that get a map card (the rest stay one-line notes)
M.KINDS = {
  death = true, pvpkill = true, dungeon = true, level = true, trophy = true, milestone = true,
  campfire = true, sleep = true, city = true, zone = true, flight = true, inn = true,
}
-- when a day has more moments than cards, these get theirs first
M.IMPORTANT = { death = true, pvpkill = true, dungeon = true, level = true, trophy = true, milestone = true }
M.MAX_PER_DAY = 8

local CAMPFIRE_AURA = 7353 -- Cozy Fire
local SLEEPING_BAG_AURA = 429959 -- Well-Rested, from the Cozy Sleeping Bag (item 211527)
local CAPITAL_IDS = { [1453] = true, [1454] = true, [1455] = true, [1456] = true, [1457] = true, [1458] = true }
local CAPITAL_NAMES = {
  ["Stormwind City"] = true, ["Orgrimmar"] = true, ["Ironforge"] = true,
  ["Thunder Bluff"] = true, ["Darnassus"] = true, ["Undercity"] = true,
}

------------------------------------------------------------------------
-- Helpers (pure; tested in tests/run.lua)
------------------------------------------------------------------------
local MINUTES = { "Five", "Ten", "Fifteen", "Twenty", "Twenty-five", "Thirty", "Thirty-five", "Forty",
  "Forty-five", "Fifty", "Fifty-five" }
local HOURS = { [2] = "Two", [3] = "Three", [4] = "Four", [5] = "Five" }

local function Since(gap)
  if gap < 120 then return "Moments later" end
  if gap < 3600 then
    local five = math.min(11, math.max(1, math.floor(gap / 300 + 0.5)))
    return MINUTES[five] .. " minutes later"
  end
  if gap < 5400 then return "An hour later" end
  if gap < 6 * 3600 then
    local h = math.min(5, math.max(2, math.floor(gap / 3600 + 0.5)))
    return HOURS[h] .. " hours later"
  end
  return "Later that day"
end

-- "Feralas, today" for the day's first moment; "Ten minutes later, in Durotar" after that
function M.Caption(prev, e, dayLabel)
  if not prev then
    local label = dayLabel or ""
    if e.zone then return e.zone .. ", " .. label end
    return (label:gsub("^%l", string.upper))
  end
  local s = Since((e.t or 0) - (prev.t or 0))
  if e.zone then s = s .. ", in " .. e.zone end
  return s
end

-- true (and remembered) unless `key` happened less than `window` seconds ago
function M.Gate(gates, key, now, window)
  local last = gates[key]
  if last and now - last < window then return false end
  gates[key] = now
  return true
end

function M.IsCapital(mapID, zone)
  return (mapID and CAPITAL_IDS[mapID]) or (zone and CAPITAL_NAMES[zone]) or false
end

-- One day's entries -> the moments that get a card (oldest first) and every
-- other entry (newest first, as the list shows them). Past MAX_PER_DAY the
-- important kinds win their cards over the rest.
function M.Select(entries, hasMap)
  local sorted = {}
  for _, e in ipairs(entries or {}) do sorted[#sorted + 1] = e end
  table.sort(sorted, function(a, b) return a.t < b.t end)
  local candidates, chosen = {}, {}
  for _, e in ipairs(sorted) do
    if M.KINDS[e.k] and e.m and e.x and hasMap(e.m) then candidates[#candidates + 1] = e end
  end
  local n = 0
  for pass = 1, 2 do
    for _, e in ipairs(candidates) do
      if n < M.MAX_PER_DAY and not chosen[e] and (pass == 2 or M.IMPORTANT[e.k]) then
        chosen[e], n = true, n + 1
      end
    end
  end
  local moments, rest = {}, {}
  for _, e in ipairs(sorted) do
    if chosen[e] then moments[#moments + 1] = e else rest[#rest + 1] = e end
  end
  table.sort(rest, function(a, b) return a.t > b.t end)
  return moments, rest
end

local function Duration(s)
  s = math.floor(s or 0)
  if s < 60 then return "a moment" end
  local h, m = math.floor(s / 3600), math.floor(s % 3600 / 60)
  if h > 0 then return m > 0 and ("%d h %d min"):format(h, m) or ("%d h"):format(h) end
  return ("%d min"):format(m)
end

-- "a level 39 Dwarf Warrior", "a Dwarf Warrior", or a monster's own name
function M.Describe(info)
  if not info then return "something" end
  local what = (info.race and info.class) and (info.race .. " " .. info.class) or nil
  if not what then return info.name or "something" end
  if info.level and info.level > 0 then return ("a level %d %s"):format(info.level, what) end
  return "a " .. what
end

-- the tag on a death card; `times` = how often this one has killed you
function M.DeathTag(info, times)
  local t = { title = M.Describe(info), sub = (times or 1) > 1 and "killed you again" or "killed you" }
  t.line = t.title .. " " .. t.sub
  return t
end

-- the tag on a PvP kill card
function M.KillTag(info)
  local t = { title = info and info.name or "an enemy", sub = info and (info.race and M.Describe(info)) or nil }
  t.line = t.sub and (t.title .. ", " .. t.sub) or t.title
  return t
end

-- "Razorfen Kraul, 45 min, 1 death."
function M.RunText(name, seconds, deaths)
  local s = ("%s, %s"):format(name, Duration(seconds))
  if (deaths or 0) > 0 then s = s .. (deaths == 1 and ", 1 death" or (", %d deaths"):format(deaths)) end
  return s .. "."
end

-- the name in an honorable-kill chat line (COMBATLOG_HONORGAIN: "%s dies, honorable kill Rank: ...")
function M.HonorName(msg, fmt)
  fmt = fmt or COMBATLOG_HONORGAIN
  if type(msg) ~= "string" or type(fmt) ~= "string" then return end
  local pattern = "^" .. fmt:gsub("[%%%(%)%.%+%-%*%?%[%]%^%$]", "%%%0"):gsub("%%%%s", "(.-)"):gsub("%%%%d", "%%d+")
  local first = msg:match(pattern)
  return first
end

------------------------------------------------------------------------
-- Reading the game. Every read is checked for secret values and wrapped in pcall.
------------------------------------------------------------------------
local function Readable(...)
  if not issecretvalue then return true end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return false end
  end
  return true
end

local function Pack(...) return { n = select("#", ...), ... } end

-- fn's results, or nothing if it errors or any result is secret
local function Safe(fn, ...)
  if type(fn) ~= "function" then return end
  local r = Pack(pcall(fn, ...))
  if not r[1] then return end
  for i = 2, r.n do
    if not Readable(r[i]) then return end
  end
  return unpack(r, 2, r.n)
end

local function Chron()
  local c = ns.db and ns.db.chronicle
  if not c then return end
  c.gates = c.gates or {}
  c.killers = c.killers or {}
  return c
end

local function Allowed(key, window)
  local c = Chron()
  return c and M.Gate(c.gates, key, time(), window)
end

local function Current()
  local C = ns.Chronicle
  return C and C.Current and C.Current()
end

-- the pet out now, or the one at your side in the last few minutes (pets are
-- put away when you die, fly or zone, and the moment is still theirs)
local RECENT = 5 * 60
local function Recent()
  local C = ns.Chronicle
  if C and C.Recent then return C.Recent(RECENT) end
  return Current()
end

-- Find the pet first, then use up the repeat limit, then write: a moment
-- with no pet out mustn't spend the limit. `rec` writes to that pet instead
-- of the one out now; `extra` adds fields to the entry (a tag, a place).
local function Moment(kind, text, gateKey, window, rec, extra)
  rec = rec or Current()
  if not rec then return false end
  if gateKey and not Allowed(gateKey, window) then return false end
  local C = ns.Chronicle
  return C and C.Note and C.Note(kind, text, nil, nil, rec, extra)
end

local function Zone() return ns.CurrentZone and ns.CurrentZone() or "" end
local function MapID() return Safe(C_Map and C_Map.GetBestMapForUnit, "player") end
local function InCapital() return M.IsCapital(MapID(), Zone()) end
-- "party", "raid", "pvp", "arena"... or nil outside instances
local function InstanceKind()
  local inside, kind = Safe(IsInInstance)
  if inside then return kind or "other" end
end
local function InDungeon() return InstanceKind() == "party" end
local function Later(sec, fn)
  if C_Timer then C_Timer.After(sec, function() pcall(fn) end) else fn() end
end

-- where you last were outside an instance: a dungeon's card goes there
-- (its entrance), whichever way you come out
local outside -- { m, x, y, zone }
local function NoteOutside()
  if InstanceKind() then return end
  local C = ns.Chronicle
  local p = C and C.Position and C.Position()
  if p then outside = { m = p.m, x = p.x, y = p.y, zone = Zone() } end
end

------------------------------------------------------------------------
-- Players you've seen: level, race and class, so a killer or a kill can be
-- described ("a level 39 Dwarf Warrior")
------------------------------------------------------------------------
local seen, seenByName, seenCount = {}, {}, 0

local function SeePlayer(unit)
  if not Safe(UnitIsPlayer, unit) then return end
  local guid, name = Safe(UnitGUID, unit), Safe(UnitName, unit)
  if type(guid) ~= "string" or type(name) ~= "string" then return end
  if seenCount >= 300 then wipe(seen); wipe(seenByName); seenCount = 0 end
  local info = seen[guid] or {}
  if not seen[guid] then seenCount = seenCount + 1 end
  info.guid, info.name = guid, name
  local level = Safe(UnitLevel, unit)
  if type(level) == "number" and level > 0 then info.level = level end
  local race, class = Safe(UnitRace, unit), Safe(UnitClass, unit)
  if type(race) == "string" then info.race = race end
  if type(class) == "string" then info.class = class end
  seen[guid], seenByName[name] = info, info
end

-- what's known of a player: from sightings, else from their GUID
local function PlayerInfo(guid, name)
  local info = (guid and seen[guid]) or (name and seenByName[name])
  if info then return info end
  info = { guid = guid, name = name }
  if guid and GetPlayerInfoByGUID then
    local class, _, race, _, _, gname = Safe(GetPlayerInfoByGUID, guid)
    info.class, info.race = class, race
    info.name = info.name or gname
  end
  return info
end

------------------------------------------------------------------------
-- Deaths: who killed you comes from the death recap (the combat log is
-- closed to addons on this client). Feign Death counts as a death to the
-- game, so it's skipped. Your pet is often down or put away by the time you
-- fall, so the death goes to the pet that was with you a moment ago.
------------------------------------------------------------------------
local function Killer()
  if not (C_DeathRecap and C_DeathRecap.GetRecapEvents) then return end
  local events = Safe(C_DeathRecap.GetRecapEvents)
  if type(events) ~= "table" then return end
  -- newest first: the first blow with overkill killed you; failing that, the last to hit you
  local pick, last
  for _, ev in ipairs(events) do
    local ok, overkill, name, guid = pcall(function() return ev.overkill, ev.sourceName, ev.sourceGUID end)
    if ok and Readable(overkill, name, guid) and type(name) == "string" then
      last = last or { name = name, guid = guid }
      if not pick and type(overkill) == "number" and overkill > 0 then pick = { name = name, guid = guid } end
    end
  end
  local killer = pick or last
  if not killer then return end
  if type(killer.guid) == "string" and killer.guid:find("^Player%-") then
    local info = PlayerInfo(killer.guid, killer.name)
    info.player = true
    return info
  end
  return { name = killer.name, guid = killer.guid }
end

local function OnDeath()
  if Safe(UnitIsFeignDeath, "player") then return end
  local c = Chron()
  if c and c.run then c.run.deaths = (c.run.deaths or 0) + 1 end
  local rec = Recent()
  if not rec then return end
  local where = ns.Chronicle and ns.Chronicle.Position and ns.Chronicle.Position()
  local zone = Zone()
  -- the recap is ready a moment after the death
  Later(1, function()
    local killer = Killer()
    local extra = where and { m = where.m, x = where.x, y = where.y } or {}
    if killer then
      local times = 1
      if killer.guid and c then
        c.killers[killer.guid] = (c.killers[killer.guid] or 0) + 1
        times = c.killers[killer.guid]
      end
      extra.tag = M.DeathTag(killer, times)
    end
    Moment("death", zone ~= "" and ("Fell in %s."):format(zone) or "Fell.", nil, nil, rec, extra)
  end)
end

------------------------------------------------------------------------
-- PvP kills: an honorable-kill line names them, or an enemy player you
-- targeted while they stood lies dead in your target once combat ends. In
-- battlegrounds the kills add up into one moment for the match, and a day
-- holds at most PVP_PER_DAY of them, so PvP can't crowd out the diary.
------------------------------------------------------------------------
local PVP_WINDOW = 5 * 60
local PVP_PER_DAY = 10
local fought, foughtCount = {}, 0 -- enemy player GUID -> when you targeted them standing

local function OnPvPKill(info)
  if not (info and info.name) then return end
  local c = Chron()
  if not c then return end
  local day = date("%Y-%m-%d")
  if not c.pvpDay or c.pvpDay.day ~= day then c.pvpDay = { day = day, n = 0 } end
  if c.pvpDay.n >= PVP_PER_DAY then return end
  if Moment("pvpkill", ("Defeated %s."):format(info.name), "pvp:" .. info.name, PVP_WINDOW, nil,
    { tag = M.KillTag(info) }) then
    c.pvpDay.n = c.pvpDay.n + 1
  end
end

local function NoteFoe()
  if not Safe(UnitIsPlayer, "target") or not Safe(UnitCanAttack, "player", "target") then return end
  if Safe(UnitIsDead, "target") then return end
  local guid = Safe(UnitGUID, "target")
  if type(guid) ~= "string" then return end
  if foughtCount >= 100 then wipe(fought); foughtCount = 0 end
  if not fought[guid] then foughtCount = foughtCount + 1 end
  fought[guid] = time()
end

local function CheckDeadTarget()
  if not Safe(UnitIsPlayer, "target") or not Safe(UnitCanAttack, "player", "target") then return end
  if not Safe(UnitIsDead, "target") or Safe(UnitIsFeignDeath, "target") then return end
  local guid, name = Safe(UnitGUID, "target"), Safe(UnitName, "target")
  if type(guid) ~= "string" or not fought[guid] or time() - fought[guid] > PVP_WINDOW then return end
  SeePlayer("target")
  local info = PlayerInfo(guid, name)
  -- an enemy hunter feigning death gets back up: look again in a moment
  Later(3, function()
    if Safe(UnitGUID, "target") ~= guid or not Safe(UnitIsDead, "target") then return end
    fought[guid] = nil
    OnPvPKill(info)
  end)
end

local function OnHonor(name)
  local kind = InstanceKind()
  if kind == "pvp" or kind == "arena" then
    local c = Chron()
    if not c then return end
    if not c.bg then c.bg = { name = Safe(GetInstanceInfo), kills = 0 } end
    c.bg.kills = c.bg.kills + 1
    return
  end
  OnPvPKill(PlayerInfo(nil, name))
end

local function FinishBattleground()
  local c = Chron()
  local bg = c and c.bg
  if not bg then return end
  c.bg = nil
  if bg.kills > 0 then
    local where = type(bg.name) == "string" and bg.name or "A battleground"
    Moment("battleground", ("%s: %d honorable kill%s."):format(where, bg.kills, bg.kills == 1 and "" or "s"),
      nil, nil, Recent())
  end
end

------------------------------------------------------------------------
-- Dungeon runs: one card per run, on the map where you went in. A run goes
-- on through a release and corpse run, a /reload or a logout inside; it's
-- written once you've been out for RUN_GAP, or when you enter another.
------------------------------------------------------------------------
local RUN_GAP = 5 * 60    -- outside this long and the run is over
local RUN_STALE = 30 * 60 -- away (logged out) longer than this: it ended when you left

local function FinishRun(c)
  local run = c and c.run
  if not run then return end
  c.run = nil
  local C = ns.Chronicle
  local rec = (run.pet and C and C.Get and C.Get(run.pet)) or Recent()
  if not rec then return end
  local stop = run.left or run.last or time()
  local e = run.entrance
  -- no entrance known (you logged in inside): a line in the list, not a card somewhere wrong
  local extra = e and { m = e.m, x = e.x, y = e.y, zone = e.zone } or { m = false }
  Moment("dungeon", M.RunText(run.name, stop - run.start, run.deaths), nil, nil, rec, extra)
end

-- inside a party dungeon: on arriving, and every so often while there
local function InRun()
  local c = Chron()
  if not c then return end
  local name = Safe(GetInstanceInfo)
  if type(name) ~= "string" or name == "" then return end
  local run, now = c.run, time()
  if run and (run.name ~= name or now - (run.last or run.start) > RUN_STALE) then
    FinishRun(c)
    run = nil
  end
  if not run then
    run = { name = name, start = now, deaths = 0, entrance = outside }
    c.run = run
  end
  run.last, run.left = now, nil -- back inside after a corpse run, a /reload or a login
  if not run.pet then
    local rec = Current()
    run.pet = rec and rec.id
  end
end

-- outside with a run open: a ghost is on the way back; otherwise the run
-- waits RUN_GAP in case you go back in, then it's written
local function OutOfRun(now)
  local c = Chron()
  local run = c and c.run
  if not run or Safe(UnitIsDeadOrGhost, "player") then return end
  if not run.left then
    local last = run.last or run.start
    run.left = (now - last > RUN_STALE) and last or now
  end
  if now - run.left >= RUN_GAP then FinishRun(c) end
end

------------------------------------------------------------------------
-- Campfires, cities, new zones, inns and flights
------------------------------------------------------------------------
local function HasAura(spellID)
  if C_UnitAuras and C_UnitAuras.GetPlayerAuraBySpellID then
    return Safe(C_UnitAuras.GetPlayerAuraBySpellID, spellID) ~= nil
  end
  if UnitBuff then
    for i = 1, 40 do
      local name, _, _, _, _, _, _, _, _, id = Safe(UnitBuff, "player", i)
      if not name then break end
      if id == spellID then return true end
    end
  end
  return false
end

-- Camp buffs: a moment when each one appears
local CAMP = {
  { aura = CAMPFIRE_AURA, kind = "campfire", text = "Sat by a campfire in %s.", window = 30 * 60 },
  { aura = SLEEPING_BAG_AURA, kind = "sleep", text = "Slept in a sleeping bag in %s.", window = 2 * 3600 },
}
local had = {}

local function CheckCamp()
  local z = Zone()
  for _, c in ipairs(CAMP) do
    local on = HasAura(c.aura)
    if on and not had[c.kind] and z ~= "" then Moment(c.kind, c.text:format(z), c.kind, c.window) end
    had[c.kind] = on
  end
end

local function ResetCamp()
  for _, c in ipairs(CAMP) do had[c.kind] = HasAura(c.aura) end
end

-- resting because of a campfire or the sleeping bag, not an inn
local function CampRest()
  for _, c in ipairs(CAMP) do
    if HasAura(c.aura) then return true end
  end
  return false
end

-- The first time this pet sets foot in a zone. Any time already spent there
-- (rec.zones) means it isn't, however it got there.
local function CheckNewZone(z, rec)
  rec = rec or Current()
  if not rec then return end
  rec.zonesNoted = rec.zonesNoted or {}
  if rec.zonesNoted[z] or (rec.zones and rec.zones[z]) or rec.firstZone == z then
    rec.zonesNoted[z] = true
    return
  end
  rec.zonesNoted[z] = true
  Moment("zone", ("Into %s for the first time."):format(z), nil, nil, rec)
end

local function CheckZone(rec)
  local z = Zone()
  if z == "" or InstanceKind() then return end -- instances have moments of their own
  if InCapital() then
    Moment("city", ("Arrived in %s."):format(z), "city:" .. z, 2 * 3600, rec)
  else
    CheckNewZone(z, rec)
  end
end

-- Resting outside a capital is an inn, unless a camp buff explains it (the
-- sleeping bag sets you resting too). Its buff can land a moment after the
-- resting flag, so this looks again shortly after.
local function CheckInn()
  if not Safe(IsResting) or InCapital() then return end
  Later(2, function()
    CheckCamp()
    if not Safe(IsResting) or CampRest() then return end
    local z = Zone()
    if z ~= "" then Moment("inn", ("Rested at an inn in %s."):format(z), "inn:" .. z, 2 * 3600) end
  end)
end

-- Flights: the pet is put away for the trip, so the pet that was out when
-- control was lost is remembered at once; the taxi is confirmed a moment
-- later (the flag can lag), and on landing the flight and the arrival are
-- written for that pet.
local flight -- { from = zone, rec = pet record }
local function OnControlLost()
  if flight then return end -- already in the air
  local takeoff = { from = Zone(), rec = Current() }
  if not takeoff.rec then return end
  Later(1, function()
    if not flight and Safe(UnitOnTaxi, "player") then flight = takeoff end
  end)
end

local function CheckLanding()
  if not flight or Safe(UnitOnTaxi, "player") then return end
  local f, to = flight, Zone()
  flight = nil
  if f.from ~= "" and to ~= "" and f.from ~= to then
    Moment("flight", ("Flew from %s to %s."):format(f.from, to), nil, nil, f.rec)
  end
  CheckZone(f.rec)
end

-- arriving somewhere after a loading screen (not a login or /reload)
local function Arrived(loggingIn)
  local kind = InstanceKind()
  if kind == "party" then InRun() else OutOfRun(time()) end
  if kind ~= "pvp" and kind ~= "arena" then FinishBattleground() end
  NoteOutside()
  if not loggingIn then CheckZone() end
end

-- every so often (and from the tests, with a clock of their own)
function M.Tick(now)
  now = now or time()
  if InDungeon() then
    InRun()
  else
    NoteOutside()
    OutOfRun(now)
  end
end

------------------------------------------------------------------------
-- Events
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
local function OnEvent(_, e, a1, a2)
  if not (ns.db and ns.isHunter ~= false) then return end
  if e == "UNIT_AURA" then
    CheckCamp()
  elseif e == "PLAYER_ENTERING_WORLD" then
    ResetCamp()
    Arrived(a1 or a2)
  elseif e == "ZONE_CHANGED_NEW_AREA" then
    NoteOutside()
    CheckZone()
  elseif e == "PLAYER_LEAVING_WORLD" then
    NoteOutside()
  elseif e == "PLAYER_UPDATE_RESTING" then
    CheckInn()
  elseif e == "PLAYER_CONTROL_LOST" then
    OnControlLost()
  elseif e == "PLAYER_CONTROL_GAINED" then
    CheckLanding()
  elseif e == "PLAYER_DEAD" then
    OnDeath()
  elseif e == "CHAT_MSG_COMBAT_HONOR_GAIN" then
    local name = Readable(a1) and M.HonorName(a1)
    if name then OnHonor(name) end
  elseif e == "PLAYER_REGEN_ENABLED" then
    CheckDeadTarget()
  elseif e == "PLAYER_TARGET_CHANGED" then
    SeePlayer("target")
    NoteFoe()
  elseif e == "UPDATE_MOUSEOVER_UNIT" then
    SeePlayer("mouseover")
  elseif e == "NAME_PLATE_UNIT_ADDED" then
    if type(a1) == "string" then SeePlayer(a1) end
  end
end

for _, e in ipairs({ "PLAYER_ENTERING_WORLD", "ZONE_CHANGED_NEW_AREA", "PLAYER_UPDATE_RESTING",
  "PLAYER_CONTROL_LOST", "PLAYER_CONTROL_GAINED", "PLAYER_DEAD", "CHAT_MSG_COMBAT_HONOR_GAIN",
  "PLAYER_REGEN_ENABLED", "PLAYER_TARGET_CHANGED", "UPDATE_MOUSEOVER_UNIT", "NAME_PLATE_UNIT_ADDED",
  "PLAYER_LEAVING_WORLD" }) do
  pcall(ev.RegisterEvent, ev, e)
end
-- only your own auras (a campfire)
if ev.RegisterUnitEvent then
  pcall(ev.RegisterUnitEvent, ev, "UNIT_AURA", "player")
else
  pcall(ev.RegisterEvent, ev, "UNIT_AURA")
end
ev:SetScript("OnEvent", function(...) pcall(OnEvent, ...) end)

if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(30, function()
    if ns.db and ns.isHunter ~= false then pcall(M.Tick) end
  end)
end

-- /btt mapcheck line
function M.CapitalCheck()
  return ("capital: %s (map %s, zone %s)"):format(InCapital() and "yes" or "no", tostring(MapID()), Zone())
end
