local _, ns = ...

------------------------------------------------------------------------
-- Beast coordinates (from QuestieDB), TomTom waypoints, map pins
------------------------------------------------------------------------
local Geo = { ready = false, located = 0, status = "waiting for login" }
ns.Geo = Geo

local cache = {}       -- npc name -> info table | false
local areaToMap        -- Questie areaId -> uiMapID
local mapByName        -- "Duskwood" -> uiMapID

local function ToTable(v)
  if type(v) == "string" then
    local fn = loadstring and loadstring(v)
    if not fn then return nil end
    local ok, t = pcall(fn)
    return ok and type(t) == "table" and t or nil
  end
  return type(v) == "table" and v or nil
end

local function LoadAreaMap()
  areaToMap = {}
  local LQ = _G.LibQuestieDB
  local zdb = LQ and LQ.Support and LQ.Support.Get and LQ.Support.Get("ZoneDB")
  local p = zdb and zdb.private
  if p then
    for _, key in ipairs({ "areaIdToUiMapId", "areaIdToUiMapIdOverride" }) do
      local t = ToTable(p[key])
      if t then
        for area, m in pairs(t) do areaToMap[area] = (m and m > 0) and m or nil end
      end
    end
  end
end

local function QuestieZoneMap(area)
  if not (QuestieLoader and QuestieLoader.ImportModule) then return end
  local ok, z = pcall(QuestieLoader.ImportModule, QuestieLoader, "ZoneDB")
  if ok and z and z.GetUiMapIdByAreaId then
    local ok2, m = pcall(z.GetUiMapIdByAreaId, z, area)
    if ok2 and m and m > 0 then return m end
  end
end

local function MapFor(area)
  if not areaToMap then LoadAreaMap() end
  local m = areaToMap[area] or QuestieZoneMap(area)
  if m then areaToMap[area] = m end
  return m
end

function Geo.MapIdByName(zone)
  if not mapByName then
    mapByName = {}
    if C_Map and C_Map.GetMapInfo then
      for id = 1, 3000 do
        local info = C_Map.GetMapInfo(id)
        if info and info.name then
          local cur = mapByName[info.name]
          -- prefer real zone maps (type 3) over dungeons/micro maps
          if not cur or (info.mapType == 3 and cur.type ~= 3) then
            mapByName[info.name] = { id = id, type = info.mapType }
          end
        end
      end
    end
  end
  local z = (zone or ""):gsub("%s*%b()", "")
  local e = mapByName[z]
  return e and e.id
end

-- Returns { spawns = {{map=, x=, y=}...}, rare=bool, elite=bool } or nil
function Geo.Lookup(name)
  local c = cache[name]
  if c ~= nil then return c or nil end

  -- Rares: RareScanner's spawn point + patrol path beats Questie's data
  local rs = ns.rsRares and ns.rsRares[name]
  if rs then
    local res = { rare = true, rs = true, spawns = { { map = rs.map, x = rs.x, y = rs.y } } }
    for _, pt in ipairs(rs.path or {}) do
      res.spawns[#res.spawns + 1] = { map = rs.map, x = pt[1], y = pt[2] }
    end
    Geo.located = Geo.located + 1
    cache[name] = res
    return res
  end

  if not Geo.ready then return nil end
  local res = { spawns = {} }
  local ids = NpcDB.IdsByName(name)
  for _, id in ipairs(ids or {}) do
    local ok, rank = pcall(NpcDB.Get, id, "rank")
    if ok and rank then
      if rank == 2 or rank == 4 then res.rare = true end
      if rank == 1 or rank == 2 or rank == 3 then res.elite = true end
    end
    local ok2, sp = pcall(NpcDB.Get, id, "spawns")
    if ok2 and type(sp) == "table" then
      for area, pts in pairs(sp) do
        local m = MapFor(area)
        if m and type(pts) == "table" then
          for _, pt in ipairs(pts) do
            local x, y = pt[1], pt[2]
            if x and y and x >= 0 and y >= 0 then
              res.spawns[#res.spawns + 1] = { map = m, x = x / 100, y = y / 100 }
            end
          end
        end
      end
    end
  end
  if #res.spawns > 0 then Geo.located = Geo.located + 1 end
  cache[name] = (#res.spawns > 0 or res.rare) and res or false
  return cache[name] or nil
end

function Geo.IsRare(name)
  if ns.db and ns.db.rares[name] then return true end
  local sp = ns.rarePetByName and ns.rarePetByName[name]
  if sp and sp.rare then return true end
  local info = Geo.Lookup(name)
  return info and info.rare or false
end

function Geo.Tag(name)
  if Geo.IsRare(name) then
    local st = ns.RS and ns.RS.Status(name)
    return " |cffff8000[Rare]|r" .. (st and st.short and (" " .. st.short) or "")
  end
  local info = Geo.Lookup(name)
  if info and info.elite then return " |cffffd100[Elite]|r" end
  return ""
end

local function PlayerPos()
  if not (C_Map and C_Map.GetBestMapForUnit) then return end
  local m = C_Map.GetBestMapForUnit("player")
  if not m then return end
  local p = C_Map.GetPlayerMapPosition(m, "player")
  if p then
    local x, y = p:GetXY()
    return m, x, y
  end
  return m
end
Geo.PlayerPos = PlayerPos

-- Nearest spawn to you if you're on that map, else the middle of the pack
function Geo.BestSpawn(info, zoneName)
  local pm, px, py = PlayerPos()
  local best, bd
  if pm and px then
    for _, s in ipairs(info.spawns) do
      if s.map == pm then
        local d = (s.x - px) ^ 2 + (s.y - py) ^ 2
        if not bd or d < bd then best, bd = s, d end
      end
    end
    if best then return best end
  end
  local want = Geo.MapIdByName(zoneName)
  local pool = {}
  for _, s in ipairs(info.spawns) do
    if not want or s.map == want then pool[#pool + 1] = s end
  end
  if #pool == 0 then pool = info.spawns end
  local cx, cy = 0, 0
  for _, s in ipairs(pool) do cx, cy = cx + s.x, cy + s.y end
  cx, cy = cx / #pool, cy / #pool
  for _, s in ipairs(pool) do
    local d = (s.x - cx) ^ 2 + (s.y - cy) ^ 2
    if not bd or d < bd then best, bd = s, d end
  end
  return best
end

------------------------------------------------------------------------
-- TomTom
------------------------------------------------------------------------
Geo.uids = {}

function Geo.HasTomTom() return TomTom and TomTom.AddWaypoint and true or false end

function Geo.Waypoint(t, label, quiet)
  if not Geo.HasTomTom() then
    if not quiet then ns.Say("TomTom isn't loaded, so waypoints aren't available.") end
    return
  end
  local s
  -- a rare RareScanner saw in the last two days: go where it was actually seen
  local rs = ns.RS and ns.RS.Get(t.name)
  if rs then
    local seen = ns.RS.LastSeen(rs.id)
    local now = (GetServerTime and GetServerTime()) or time()
    if seen and seen.map and seen.x and seen.y and seen.time and now - seen.time < 2 * 86400 then
      s = { map = seen.map, x = seen.x, y = seen.y }
      label = (label or t.name) .. " (last seen)"
    end
  end
  if not s then
    local hasLocal = ns.rsRares and ns.rsRares[t.name]
    if not Geo.ready and not hasLocal then
      if not quiet then ns.Say("beast locations are still loading (or QuestieDB isn't installed).") end
      return
    end
    local info = Geo.Lookup(t.name)
    if not info or #info.spawns == 0 then
      if not quiet then ns.Say(("no coordinates known for %s (%s)."):format(t.name, t.zone)) end
      return
    end
    s = Geo.BestSpawn(info, t.zone)
  end
  local ok, uid = pcall(TomTom.AddWaypoint, TomTom, s.map, s.x, s.y, {
    title = label or t.name, persistent = false, minimap = true, world = true, from = "Beast Training Tracker",
  })
  if ok and uid then
    Geo.uids[#Geo.uids + 1] = uid
    if not quiet then ns.Say(("waypoint set: %s (%.0f, %.0f)"):format(label or t.name, s.x * 100, s.y * 100)) end
    return uid
  end
end

-- One waypoint per teacher in the list; returns how many were added
function Geo.WaypointMany(list)
  local n = 0
  for _, item in ipairs(list) do
    if Geo.Waypoint(item.t, item.label, true) then n = n + 1 end
  end
  if n > 0 then
    if TomTom.SetClosestWaypoint then pcall(TomTom.SetClosestWaypoint, TomTom) end
    ns.Say(("added %d TomTom waypoint%s."):format(n, n == 1 and "" or "s"))
  elseif Geo.HasTomTom() then
    ns.Say("couldn't find coordinates for any of those beasts.")
  else
    ns.Say("TomTom isn't loaded, so waypoints aren't available.")
  end
  return n
end

function Geo.ClearWaypoints()
  local n = 0
  if TomTom and TomTom.RemoveWaypoint then
    for _, uid in ipairs(Geo.uids) do
      if pcall(TomTom.RemoveWaypoint, TomTom, uid) then n = n + 1 end
    end
  end
  wipe(Geo.uids)
  ns.Say(("removed %d waypoint%s."):format(n, n == 1 and "" or "s"))
end

-- Label used for waypoints and pins
function Geo.Label(ab, r, t) return ("%s - %s %d"):format(t.name, ab.name, r.rank) end

------------------------------------------------------------------------
-- Map pins (HereBeDragons, shipped with TomTom)
------------------------------------------------------------------------
local HBDPins
local REF = "BeastTrainingTracker"
local worldPool, miniPool = {}, {}
local worldUsed, miniUsed = {}, {}
local MAX_WORLD, MAX_PER_TEACHER, MAX_MINI = 900, 25, 120

local function PinEnter(self)
  local tip = GameTooltip
  tip:SetOwner(self, "ANCHOR_RIGHT")
  local d = self.data
  tip:AddLine(d.t.name .. Geo.Tag(d.t.name), 1, 0.82, 0)
  tip:AddLine(("%s, level %s"):format(d.t.family or "?", d.t.level or "?"), 0.8, 0.8, 0.8)
  local st = ns.RS and ns.RS.Status(d.t.name)
  if st then tip:AddLine("RareScanner: " .. st.text, 1, 0.6, 0.25, true) end
  for _, e in ipairs(d.teaches) do
    tip:AddLine(("Teaches %s %d"):format(e.ab.name, e.rank.rank), 0.25, 1, 0.25)
  end
  if d.rareOnly then
    tip:AddLine("Untamed rare for your collection", 1, 0.5, 0)
    local info = ns.RS and ns.RS.Info(d.t.name)
    if info then
      tip:AddLine("Attack speed " .. ns.RS.SpeedText(info.speed), 0.8, 0.8, 0.8)
      for _, tr in ipairs(info.traits) do tip:AddLine(tr.short, 1, 1, 1) end
    end
  end
  tip:AddLine(" ")
  tip:AddLine("Click: TomTom waypoint", 0.5, 0.5, 0.5)
  tip:Show()
end

local function NewPin(pool, size)
  local p = table.remove(pool)
  if p then return p end
  p = CreateFrame("Button", nil, UIParent)
  p:SetSize(size, size)
  p.border = p:CreateTexture(nil, "BACKGROUND")
  p.border:SetPoint("TOPLEFT", -1, 1)
  p.border:SetPoint("BOTTOMRIGHT", 1, -1)
  p.border:SetColorTexture(0, 0, 0, 0.85)
  p.tex = p:CreateTexture(nil, "ARTWORK")
  p.tex:SetAllPoints()
  p.tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  p:RegisterForClicks("AnyUp")
  p:SetScript("OnEnter", PinEnter)
  p:SetScript("OnLeave", GameTooltip_Hide)
  p:SetScript("OnClick", function(self)
    local d = self.data
    local e = d.teaches[1]
    Geo.Waypoint(d.t, e and Geo.Label(e.ab, e.rank, d.t) or (d.t.name .. " (rare)"))
  end)
  return p
end

local function ClearPins()
  if not HBDPins then return end
  HBDPins:RemoveAllWorldMapIcons(REF)
  HBDPins:RemoveAllMinimapIcons(REF)
  for _, p in ipairs(worldUsed) do p:Hide(); worldPool[#worldPool + 1] = p end
  for _, p in ipairs(miniUsed) do p:Hide(); miniPool[#miniPool + 1] = p end
  wipe(worldUsed); wipe(miniUsed)
end

-- teacher name -> { t=, teaches={ {ab, rank} } } for every missing rank you can tame now
local function TeachersToPin()
  local o = ns.db.opts
  local out = {}
  for _, z in ipairs(ns.HuntPlan(o.huntPetOnly, o.huntDungeons)) do
    for _, e in ipairs(z.entries) do
      for _, t in ipairs(e.teachers) do
        local d = out[t.name]
        if not d then d = { t = t, teaches = {} }; out[t.name] = d end
        d.teaches[#d.teaches + 1] = e
      end
    end
  end
  -- untamed rares you can tame, even if they teach nothing you need
  if o.rarePins and ns.RS then
    for _, p in ipairs(ns.rarePets or {}) do
      if not out[p.name] and not ns.db.tamedRares[p.name] and ns.CanTame(p) and (p.rare or not p.dungeon) then
        out[p.name] = { t = p, teaches = {}, rareOnly = true }
      end
    end
  end
  return out
end

function Geo.UpdatePins()
  if not ns.db then return end
  HBDPins = HBDPins or (LibStub and LibStub("HereBeDragons-Pins-2.0", true))
  if not HBDPins then return end
  ClearPins()
  local o = ns.db.opts
  -- without QuestieDB only RareScanner's rares have coordinates, which still works
  if o.pinsOff or not (o.mapPins or o.minimapPins) then return end

  local pm, px, py = PlayerPos()
  local nearby = {}
  local worldCount = 0
  for name, d in pairs(TeachersToPin()) do
    local info = Geo.Lookup(name)
    if info and #info.spawns > 0 then
      local rare = Geo.IsRare(name)
      local icon = d.teaches[1] and d.teaches[1].ab.icon
        or (ns.RS and ns.RS.Info(name) and ns.RS.Info(name).icon) or "Interface\\Icons\\Ability_Hunter_BeastTaming"
      if o.mapPins and worldCount < MAX_WORLD then
        local step = math.max(1, math.floor(#info.spawns / MAX_PER_TEACHER))
        for i = 1, #info.spawns, step do
          local s = info.spawns[i]
          local p = NewPin(worldPool, rare and 16 or 12)
          p:SetSize(rare and 16 or 12, rare and 16 or 12)
          p.border:SetColorTexture(rare and 1 or 0, rare and 0.5 or 0, 0, 0.9)
          p.tex:SetTexture(icon)
          p.data = d
          HBDPins:AddWorldMapIconMap(REF, p, s.map, s.x, s.y, 0)
          worldUsed[#worldUsed + 1] = p
          worldCount = worldCount + 1
          if worldCount >= MAX_WORLD then break end
        end
      end
      if o.minimapPins and pm then
        for _, s in ipairs(info.spawns) do
          if s.map == pm then
            nearby[#nearby + 1] = { s = s, d = d, icon = icon, rare = rare,
              dist = px and ((s.x - px) ^ 2 + (s.y - py) ^ 2) or 0 }
          end
        end
      end
    end
  end

  table.sort(nearby, function(a, b) return a.dist < b.dist end)
  for i = 1, math.min(MAX_MINI, #nearby) do
    local n = nearby[i]
    local p = NewPin(miniPool, n.rare and 14 or 10)
    p:SetSize(n.rare and 14 or 10, n.rare and 14 or 10)
    p.border:SetColorTexture(n.rare and 1 or 0, n.rare and 0.5 or 0, 0, 0.9)
    p.tex:SetTexture(n.icon)
    p.data = n.d
    HBDPins:AddMinimapIconMap(REF, p, n.s.map, n.s.x, n.s.y, false, false)
    miniUsed[#miniUsed + 1] = p
  end
end

-- Rebuild pins only when something that affects them changed
local lastSig
local queued
function Geo.QueuePins(force)
  if not ns.db then return end
  local o = ns.db.opts
  local sig = table.concat({ ns.learnedSerial or 0, ns.PlayerLevel(), ns.CurrentZone(), tostring(o.mapPins),
    tostring(o.minimapPins), tostring(o.huntPetOnly), tostring(o.huntDungeons), tostring(Geo.ready), ns.PetFamily() or "",
    tostring(o.pinsOff), tostring(o.rarePins), tostring(ns.tamedSerial or 0) }, "|")
  if sig == lastSig and not force then return end
  lastSig = sig
  if queued then return end
  queued = true
  C_Timer.After(1, function() queued = false; Geo.UpdatePins() end)
end

ns.OnRefresh(function() Geo.QueuePins() end)

-- Master on/off for every beast pin (minimap button right-click)
function Geo.TogglePins()
  local o = ns.db.opts
  o.pinsOff = not o.pinsOff
  ns.Say("beast pins on the map " .. (o.pinsOff and "|cffff4040hidden|r" or "|cff40ff40shown|r"))
  Geo.QueuePins(true)
  ns.Refresh()
end

------------------------------------------------------------------------
-- Startup: build QuestieDB's name index spread over several frames
------------------------------------------------------------------------
function Geo.StatusText()
  local s = Geo.ready and ("QuestieDB ready, %d beasts located so far"):format(Geo.located) or Geo.status
  local rsCount = 0
  for _ in pairs(ns.rareIds or ns.rsRares or {}) do rsCount = rsCount + 1 end
  return s .. (Geo.HasTomTom() and "  |  TomTom loaded" or "  |  TomTom not loaded")
    .. ((ns.RS and ns.RS.Loaded()) and ("  |  RareScanner linked (%d rare teachers)"):format(rsCount) or "  |  RareScanner not loaded")
end

ns.OnLogin(function()
  if not (_G.NpcDB and NpcDB.IdsByName and NpcDB.Get) then
    Geo.status = "QuestieDB not found - map pins and waypoints need it"
    return
  end
  Geo.status = "loading beast locations..."
  local co = coroutine.create(function()
    if NpcDB.BuildNameIndexAsync then NpcDB.BuildNameIndexAsync(400) else NpcDB.BuildNameIndex() end
  end)
  local runner = CreateFrame("Frame")
  runner:SetScript("OnUpdate", function(self)
    local ok, err = coroutine.resume(co)
    if not ok then
      self:SetScript("OnUpdate", nil)
      Geo.status = "QuestieDB error: " .. tostring(err)
      return
    end
    if coroutine.status(co) == "dead" then
      self:SetScript("OnUpdate", nil)
      Geo.ready = true
      Geo.status = "ready"
      ns.Refresh()
    end
  end)
end)

local zev = CreateFrame("Frame")
zev:RegisterEvent("ZONE_CHANGED_NEW_AREA")
zev:RegisterEvent("PLAYER_ENTERING_WORLD")
zev:SetScript("OnEvent", function() if Geo.ready then Geo.QueuePins(true) end end)
