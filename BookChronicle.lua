local _, ns = ...

-- Book tab 5: the Companion Chronicle. A diary page per pet, day by day,
-- and a gallery of every companion you've had; bookmarks switch between them.

local Book, C = ns.Book, ns.Chronicle
if not (Book and C) then return end

local INK, INK_DIM, INK_RED = Book.INK, Book.INK_DIM, Book.INK_RED
local Font, JournalFont, Ink = Book.Font, Book.JournalFont, Book.Ink
local COLS = Book.COLS
local state = Book.state

local TOP = 32 -- content below the bookmarks
local PAGE_W, PAGE_H = Book.COLS * Book.COL_W, 428
local NOTES_H = TOP + 64
local DAY_H, SUM_H, ENTRY_H, SUB_H = 28, 18, 20, 13
local NOTE_W, NOTE_STEP = 166, 180

local Render -- forward
local page = Book.RegisterTab(5, { render = function() Render() end })

local function FamilyIcon(f) return ns.RS and ns.RS.FamilyIcon(f) or "Interface\\Icons\\Ability_Hunter_BeastTaming" end

------------------------------------------------------------------------
-- Bookmarks: Chronicle · Companions
------------------------------------------------------------------------
local LINKS = { { key = "chronicle", label = "Chronicle" }, { key = "companions", label = "Companions" } }
local links = {}
local x = 0
for _, l in ipairs(LINKS) do
  local b = CreateFrame("Button", nil, page)
  b:SetHeight(22)
  b.text = JournalFont(b, 17, "SystemFont_Med3")
  b.text:SetPoint("LEFT")
  b.text:SetText(l.label)
  b:SetWidth(b.text:GetStringWidth() + 6)
  b:SetPoint("TOPLEFT", page, "TOPLEFT", x, 0)
  x = x + b:GetWidth() + 22
  b.line = b:CreateTexture(nil, "ARTWORK")
  b.line:SetColorTexture(INK[1], INK[2], INK[3], 0.8)
  b.line:SetHeight(1)
  b.line:SetPoint("BOTTOMLEFT", 0, 0)
  b.line:SetPoint("BOTTOMRIGHT", -4, 0)
  b.key = l.key
  b:SetScript("OnClick", function()
    state.chronView, state.page = l.key, 1
    if l.key == "chronicle" then state.chronPet = nil end
    Book.Render()
  end)
  links[#links + 1] = b
end

local function UpdateLinks(view)
  for _, b in ipairs(links) do
    local on = b.key == view
    Ink(b.text, on and INK or INK_DIM)
    b.line:SetShown(on)
  end
end

local empty = Font(page, "SystemFont_Med1")
empty:SetPoint("TOPLEFT", 0, -(TOP + 6))
empty:SetWidth(PAGE_W)
empty:SetWordWrap(true)

------------------------------------------------------------------------
-- Chronicle view: sticky notes, then the days
------------------------------------------------------------------------
local chron = CreateFrame("Frame", nil, page)
chron:SetAllPoints()
chron:Hide()

-- a note taped onto the page
local notes = {}
for i = 1, 4 do
  local n = CreateFrame("Frame", nil, chron)
  n:SetSize(NOTE_W, 48)
  n:SetPoint("TOPLEFT", (i - 1) * NOTE_STEP, -(TOP + 6))
  local shadow = n:CreateTexture(nil, "BACKGROUND", nil, 1)
  shadow:SetPoint("TOPLEFT", 2, -2)
  shadow:SetPoint("BOTTOMRIGHT", 2, -2)
  shadow:SetColorTexture(0, 0, 0, 0.18)
  local card = n:CreateTexture(nil, "BACKGROUND", nil, 2)
  card:SetAllPoints()
  card:SetColorTexture(0.98, 0.94, 0.82, 1)
  local tape = n:CreateTexture(nil, "ARTWORK")
  tape:SetSize(44, 12)
  tape:SetPoint("CENTER", n, "TOPLEFT", 26, 0)
  tape:SetColorTexture(0.86, 0.78, 0.52, 0.8)
  if tape.SetRotation then tape:SetRotation(math.rad(i % 2 == 0 and 8 or -10)) end
  n.title = JournalFont(n, 14, "SystemFont_Med1")
  n.title:SetPoint("TOPLEFT", 9, -11)
  n.title:SetWidth(NOTE_W - 16)
  n.title:SetWordWrap(false)
  n.sub = Font(n, "GameFontNormalSmall", INK_DIM)
  n.sub:SetPoint("TOPLEFT", n.title, "BOTTOMLEFT", 0, -3)
  n.sub:SetWidth(NOTE_W - 16)
  n.sub:SetWordWrap(false)
  notes[i] = n
end

-- pooled timeline rows
local dayRows, sumRows, entryRows = {}, {}, {}

local function DayRow(i)
  if dayRows[i] then return dayRows[i] end
  local r = {}
  r.mark = chron:CreateTexture(nil, "ARTWORK")
  r.mark:SetSize(7, 7)
  r.mark:SetColorTexture(INK_RED[1], INK_RED[2], INK_RED[3], 1)
  if r.mark.SetRotation then r.mark:SetRotation(math.rad(45)) end
  r.label = JournalFont(chron, 17, "SystemFont_Med3", INK_RED)
  r.label:SetPoint("LEFT", r.mark, "RIGHT", 8, 1)
  r.line = chron:CreateTexture(nil, "ARTWORK")
  r.line:SetHeight(1)
  r.line:SetColorTexture(INK_RED[1], INK_RED[2], INK_RED[3], 0.35)
  r.line:SetPoint("LEFT", r.label, "RIGHT", 10, -1)
  r.line:SetPoint("RIGHT", chron, "RIGHT", -4, 0)
  dayRows[i] = r
  return r
end

local function SumRow(i)
  if sumRows[i] then return sumRows[i] end
  local fs = Font(chron, "GameFontNormalSmall", INK_DIM)
  fs:SetWidth(PAGE_W - 20)
  fs:SetWordWrap(false)
  sumRows[i] = fs
  return fs
end

local function EntryRow(i)
  if entryRows[i] then return entryRows[i] end
  local r = {}
  r.time = Font(chron, "GameFontNormalSmall", INK_DIM)
  r.icon = chron:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(15, 15)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.icon:SetPoint("LEFT", r.time, "LEFT", 42, 0)
  r.text = Font(chron, "SystemFont_Med1")
  r.text:SetPoint("LEFT", r.icon, "RIGHT", 7, 0)
  r.text:SetWidth(PAGE_W - 80)
  r.text:SetWordWrap(false)
  r.sub = Font(chron, "GameFontNormalSmall", INK_DIM)
  r.sub:SetPoint("TOPLEFT", r.text, "BOTTOMLEFT", 0, -1)
  r.sub:SetWidth(PAGE_W - 80)
  r.sub:SetWordWrap(false)
  entryRows[i] = r
  return r
end

local function DayKey(t) return date("%Y-%m-%d", t) end

local function DayLabel(key)
  if key == DayKey(time()) then return "Today" end
  if key == DayKey(time() - 86400) then return "Yesterday" end
  local y, m, d = key:match("^(%d+)-(%d+)-(%d+)$")
  if not y then return key end
  local t = time({ year = tonumber(y), month = tonumber(m), day = tonumber(d), hour = 12 })
  return (date("%A, %d %B", t):gsub(" 0", " "))
end

local function Times(n) return n == 1 and "once" or (n == 2 and "twice" or (n .. " times")) end

local function DaySummary(day)
  if not day then return nil end
  local parts = {}
  if day.seconds and day.seconds >= 60 then
    local zones, names = C.TopZones(day.zones), {}
    for i = 1, math.min(3, #zones) do
      names[i] = ("%s (%s)"):format(zones[i].zone, C.Duration(zones[i].seconds))
    end
    local where = table.concat(names, ", ")
    if #zones > 3 then where = where .. (" and %d more"):format(#zones - 3) end
    parts[#parts + 1] = ("Out together %s: %s"):format(C.Duration(day.seconds), where)
  end
  if day.kills > 0 then parts[#parts + 1] = day.kills == 1 and "1 beast slain" or (day.kills .. " beasts slain") end
  if (day.skins or 0) > 0 then
    local worth = 0
    for id, n in pairs(day.haul or {}) do worth = worth + (ns.Journal.Price(id) or 0) * n end
    local s = day.skins == 1 and "1 skinned" or (day.skins .. " skinned")
    if worth > 0 then s = s .. (" (~%s)"):format(ns.Journal.Money(worth)) end
    parts[#parts + 1] = s
  end
  if day.falls > 0 then parts[#parts + 1] = "fell " .. Times(day.falls) end
  if #parts == 0 then return nil end
  return table.concat(parts, "  ·  ")
end

------------------------------------------------------------------------
-- Map snippets: the day's path on a cut-out of the zone map, taped into
-- the diary. Click one for a bigger view with every event marked.
------------------------------------------------------------------------
local BookMap = ns.BookMap
local MAP_H, SNIP_W, SNIP_H = 142, 230, 124

local function Where(name, key)
  local label = DayLabel(key)
  if label == "Today" or label == "Yesterday" then label = label:lower() end
  return name and (name .. ", " .. label) or label
end

-- the day's main map, if there's a path on it and the client has its art
local function DayMap(rec, key)
  local day = rec.days[key]
  local trail = day and day.trail
  if not (BookMap and trail and #trail >= 2) then return end
  local mapID, name = BookMap.MainMap(trail)
  if not (mapID and BookMap.HasArt(mapID)) then return end
  return mapID, name, trail
end

-- the day's entries that happened on that map; `tips` makes them hoverable
local function DayMarks(rec, key, mapID, tips)
  local marks = {}
  for _, e in ipairs(rec.entries) do
    if e.m == mapID and e.x and DayKey(e.t) == key then
      marks[#marks + 1] = { x = e.x, y = e.y, icon = e.icon or C.Icon(e.k), tip = tips and function(tt)
        tt:AddLine(date("%H:%M", e.t), 1, 0.82, 0)
        tt:AddLine(e.text, 1, 1, 1, true)
        if e.sub then tt:AddLine(e.sub, 0.8, 0.8, 0.8, true) end
      end or nil }
    end
  end
  return marks
end

-- a cream card with a soft shadow and two strips of tape across its corners
local function TapedCard(parent, w, h)
  local c = CreateFrame("Frame", nil, parent)
  c:SetSize(w, h)
  local shadow = c:CreateTexture(nil, "BACKGROUND", nil, 1)
  shadow:SetPoint("TOPLEFT", 3, -3)
  shadow:SetPoint("BOTTOMRIGHT", 3, -3)
  shadow:SetColorTexture(0, 0, 0, 0.22)
  local card = c:CreateTexture(nil, "BACKGROUND", nil, 2)
  card:SetAllPoints()
  card:SetColorTexture(0.98, 0.94, 0.82, 1)
  for _, corner in ipairs({ { "TOPLEFT", 10, -4, -40 }, { "BOTTOMRIGHT", -10, 4, -40 } }) do
    local tape = c:CreateTexture(nil, "OVERLAY", nil, 6)
    tape:SetSize(38, 11)
    tape:SetPoint("CENTER", c, corner[1], corner[2], corner[3])
    tape:SetColorTexture(0.86, 0.78, 0.52, 0.85)
    if tape.SetRotation then tape:SetRotation(math.rad(corner[4])) end
  end
  return c
end

local OpenZoom -- forward
local mapRows = {}

local function MapRow(i)
  if mapRows[i] then return mapRows[i] end
  local r = CreateFrame("Button", nil, chron)
  r:SetSize(PAGE_W - 20, MAP_H - 10)
  r.card = TapedCard(r, SNIP_W + 10, SNIP_H + 10)
  r.card:SetPoint("TOPLEFT", 16, -2)
  r.view = BookMap.New(r.card, SNIP_W, SNIP_H, 12)
  r.view.frame:SetPoint("CENTER")
  r.title = JournalFont(r, 15, "SystemFont_Med1")
  r.title:SetPoint("TOPLEFT", r.card, "TOPRIGHT", 20, -12)
  r.sub = Font(r, "SystemFont_Med1", INK_DIM)
  r.sub:SetPoint("TOPLEFT", r.title, "BOTTOMLEFT", 0, -4)
  r.sub:SetWidth(PAGE_W - SNIP_W - 80)
  r.sub:SetWordWrap(true)
  r.hint = Font(r, "GameFontNormalSmall", INK_DIM)
  r.hint:SetPoint("TOPLEFT", r.sub, "BOTTOMLEFT", 0, -8)
  r.hint:SetText("Click the map to look closer")
  r:SetScript("OnClick", function(self) OpenZoom(self.rec, self.key) end)
  mapRows[i] = r
  return r
end

-- the bigger view, over the whole page
local zoom = CreateFrame("Frame", nil, page)
zoom:SetAllPoints()
zoom:SetFrameLevel(page:GetFrameLevel() + 40)
zoom:EnableMouse(true)
zoom:Hide()
-- the card covers the page; the map fills it but for a thin band of text
-- above (where, and the day's summary) and below (the legend)
local ZOOM_W, ZOOM_H = PAGE_W - 4, PAGE_H - 2
local ZOOM_PAD, ZOOM_TOP, ZOOM_FOOT = 8, 40, 20
local card = TapedCard(zoom, ZOOM_W, ZOOM_H)
card:SetPoint("TOPLEFT", 0, 0)
-- text lives on the card itself, so the card can't cover it
zoom.title = JournalFont(card, 17, "SystemFont_Med3")
zoom.title:SetPoint("TOPLEFT", ZOOM_PAD + 4, -6)
zoom.sub = Font(card, "GameFontNormalSmall", INK_DIM)
zoom.sub:SetPoint("TOPLEFT", zoom.title, "BOTTOMLEFT", 0, -2)
zoom.sub:SetWidth(ZOOM_W - 60)
zoom.sub:SetWordWrap(false)
zoom.legend = Font(card, "GameFontNormalSmall", INK_DIM)
zoom.legend:SetPoint("BOTTOMLEFT", ZOOM_PAD + 4, 5)
zoom.legend:SetText("Red ink: the path you took that day.  Icons: what happened, and where - hover them.")
zoom.view = BookMap.New(zoom, ZOOM_W - ZOOM_PAD * 2, ZOOM_H - ZOOM_TOP - ZOOM_FOOT, 20)
zoom.view.frame:SetPoint("TOPLEFT", ZOOM_PAD, -ZOOM_TOP)
zoom.view.frame:SetFrameLevel(card:GetFrameLevel() + 2)
zoom.close = CreateFrame("Button", nil, zoom, "UIPanelCloseButton")
zoom.close:SetPoint("TOPRIGHT", -2, -2)
zoom.close:SetFrameLevel(card:GetFrameLevel() + 5)
zoom.close:SetScript("OnClick", function() zoom:Hide() end)
page:HookScript("OnHide", function() zoom:Hide() end)

local zoomKey

local function DrawZoom()
  local rec = zoomKey and C.Get(zoomKey.id)
  local mapID, name, trail
  if rec then mapID, name, trail = DayMap(rec, zoomKey.key) end
  if not mapID then
    zoom:Hide()
    return
  end
  zoom.title:SetText(Where(name, zoomKey.key))
  zoom.sub:SetText(DaySummary(rec.days[zoomKey.key]) or "")
  zoom.view:Draw(mapID, trail, DayMarks(rec, zoomKey.key, mapID, true), true)
end

OpenZoom = function(rec, key)
  if not rec then return end
  zoomKey = { id = rec.id, key = key }
  zoom:Show()
  DrawZoom()
end

-- the diary flowed into pages: { { op, ... }, ... }
local function Paginate(rec)
  local byDay = {}
  for _, e in ipairs(rec.entries) do
    local k = DayKey(e.t)
    byDay[k] = byDay[k] or {}
    table.insert(byDay[k], e)
  end
  local keys, seen = {}, {}
  for k in pairs(byDay) do keys[#keys + 1], seen[k] = k, true end
  for k, d in pairs(rec.days) do
    if not seen[k] and DaySummary(d) then keys[#keys + 1] = k end
  end
  table.sort(keys, function(a, b) return a > b end)

  local pages, y = { {} }, NOTES_H
  local function Put(op, h)
    if y + h > PAGE_H then
      pages[#pages + 1] = {}
      y = TOP
    end
    op.y = y
    table.insert(pages[#pages], op)
    y = y + h
  end
  for _, k in ipairs(keys) do
    Put({ kind = "day", label = DayLabel(k) }, DAY_H)
    local sum = DaySummary(rec.days[k])
    if sum then Put({ kind = "sum", text = sum }, SUM_H) end
    if DayMap(rec, k) then Put({ kind = "map", rec = rec, key = k }, MAP_H) end
    local list = byDay[k] or {}
    table.sort(list, function(a, b) return a.t > b.t end)
    for _, e in ipairs(list) do
      Put({ kind = "entry", e = e }, ENTRY_H + (e.sub and SUB_H or 0))
    end
    y = y + 6
  end
  return pages
end

local function DrawPage(ops)
  local nd, ns_, ne, nm = 0, 0, 0, 0
  for _, op in ipairs(ops or {}) do
    if op.kind == "map" then
      local mapID, name, trail = DayMap(op.rec, op.key)
      if mapID then
        nm = nm + 1
        local r = MapRow(nm)
        r.rec, r.key = op.rec, op.key
        r:ClearAllPoints()
        r:SetPoint("TOPLEFT", chron, "TOPLEFT", 0, -(op.y + 4))
        r.view:Draw(mapID, trail, DayMarks(op.rec, op.key, mapID, false))
        r.title:SetText(Where(name, op.key))
        local day = op.rec.days[op.key]
        local bits = {}
        if day and day.seconds >= 60 then bits[#bits + 1] = C.Duration(day.seconds) .. " out together" end
        if day and day.kills > 0 then bits[#bits + 1] = day.kills == 1 and "1 beast slain" or (day.kills .. " beasts slain") end
        r.sub:SetText(#bits > 0 and table.concat(bits, "  ·  ") or "In good company.")
        r:Show()
      end
    elseif op.kind == "day" then
      nd = nd + 1
      local r = DayRow(nd)
      r.mark:ClearAllPoints()
      r.mark:SetPoint("TOPLEFT", chron, "TOPLEFT", 2, -(op.y + 11))
      r.label:SetText(op.label)
      r.mark:Show(); r.label:Show(); r.line:Show()
    elseif op.kind == "sum" then
      ns_ = ns_ + 1
      local fs = SumRow(ns_)
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", chron, "TOPLEFT", 17, -(op.y + 2))
      fs:SetText(op.text)
      fs:Show()
    else
      ne = ne + 1
      local r, e = EntryRow(ne), op.e
      r.time:ClearAllPoints()
      r.time:SetPoint("TOPLEFT", chron, "TOPLEFT", 4, -(op.y + 4))
      r.time:SetText(date("%H:%M", e.t))
      r.icon:SetTexture(e.icon or C.Icon(e.k))
      r.text:SetText(e.text)
      r.sub:SetText(e.sub or "")
      r.time:Show(); r.icon:Show(); r.text:Show(); r.sub:SetShown(e.sub ~= nil)
    end
  end
  for i = nd + 1, #dayRows do dayRows[i].mark:Hide(); dayRows[i].label:Hide(); dayRows[i].line:Hide() end
  for i = ns_ + 1, #sumRows do sumRows[i]:Hide() end
  for i = ne + 1, #entryRows do
    local r = entryRows[i]
    r.time:Hide(); r.icon:Hide(); r.text:Hide(); r.sub:Hide()
  end
  for i = nm + 1, #mapRows do mapRows[i]:Hide() end
end

local function SetNote(i, title, sub)
  notes[i].title:SetText(title)
  notes[i].sub:SetText(sub or "")
  notes[i]:Show()
end

local function TopPrey(rec)
  local best, n = nil, 0
  for f, c in pairs(rec.prey or {}) do
    if c > n then best, n = f, c end
  end
  return best, n
end

local function RenderChronicle()
  local rec = (state.chronPet and C.Get(state.chronPet)) or C.Current() or C.Pets()[1]
  if not rec then
    chron:Hide()
    empty:SetText("No companion has joined your journal yet.\n\nSummon your pet and its story begins here: "
      .. "time together, the places you hunt, levels, new ranks, falls and the beasts you bring down.")
    Book.SetFieldNote("Every pet gets its own page.")
    return
  end
  chron:Show()
  local cur = C.Current()
  Book.SetTitle("Beast Training Tracker - Chronicle")
  Book.SetHeader(rec.name)
  Book.SetStats({
    { "Together", C.Duration(rec.seconds) },
    { "Beasts slain", tostring(rec.kills) },
    { "Level", ("%d %s"):format(rec.level, rec.family) },
  })
  if state.chronPet and not (cur and cur.id == rec.id) then
    Book.SetBack(function()
      state.chronView, state.chronPet, state.page = "companions", nil, 1
      Book.Render()
    end)
  end

  local pages = Paginate(rec)
  local n = Book.SetPager(#pages)
  for i = 1, 4 do notes[i]:SetShown(n == 1) end
  if n == 1 then
    SetNote(1, "First met " .. (date("%d %B", rec.first):gsub("^0", "")), ("at level %d, %s"):format(rec.firstLevel, rec.firstZone))
    local zones = C.TopZones(rec.zones)
    if zones[1] then
      SetNote(2, zones[1].zone, ("favourite haunt, %s"):format(C.Duration(zones[1].seconds)))
    else
      SetNote(2, "No haunt yet", "still exploring")
    end
    local prey, count = TopPrey(rec)
    if prey then
      SetNote(3, "Hunts " .. prey, ("%d slain together"):format(count))
    else
      SetNote(3, "No prey yet", "the hunt awaits")
    end
    if rec.rare then
      SetNote(4, rec.rare, "the special pet you tamed")
    elseif rec.loyalty then
      SetNote(4, rec.loyalty, rec.falls > 0 and ("fell " .. Times(rec.falls)) or "never fallen")
    else
      SetNote(4, rec.falls > 0 and ("Fell " .. Times(rec.falls)) or "Never fallen", "in battle")
    end
  end
  DrawPage(pages[n])

  if cur and cur.id == rec.id then
    Book.SetFieldNote(("%s has been at your side for %s. The journal keeps writing while it's out."):format(
      rec.name, C.Duration(rec.seconds)))
  else
    Book.SetFieldNote(("Last at your side on %s."):format((date("%d %B", rec.last or rec.first):gsub("^0", ""))))
  end
end

------------------------------------------------------------------------
-- Companions view: everyone who's had a page
------------------------------------------------------------------------
local function RenderCompanions()
  chron:Hide()
  Book.SetTitle("Beast Training Tracker - Companions")
  Book.SetHeader("Companions")
  local cur = C.Current()
  local list, total = {}, 0
  for _, rec in ipairs(C.Pets()) do
    total = total + rec.seconds
    local info = rec.rare and ns.RS and ns.RS.Info(rec.rare)
    list[#list + 1] = {
      icon = info and info.icon or FamilyIcon(rec.family),
      name = rec.name,
      sub = ("%s  ·  %s"):format(rec.family, C.Duration(rec.seconds)),
      badge = tostring(rec.level),
      here = cur and cur.id == rec.id,
      mastered = rec.rare ~= nil,
      onClick = function()
        state.chronView, state.chronPet, state.page = "chronicle", rec.id, 1
        Book.Render()
      end,
      tip = function(tt)
        tt:AddLine(rec.name, 1, 0.82, 0)
        tt:AddLine(("Level %d %s"):format(rec.level, rec.family), 1, 1, 1)
        if rec.rare then tt:AddLine("Tamed from " .. rec.rare, 0.25, 1, 0.25) end
        tt:AddLine(("First met %s at level %d"):format(date("%b %d, %Y", rec.first), rec.firstLevel), 0.8, 0.8, 0.8)
        tt:AddLine(("%s together  ·  %d beasts slain"):format(C.Duration(rec.seconds), rec.kills), 0.8, 0.8, 0.8)
        tt:AddLine(" ")
        tt:AddLine("Click to read its chronicle", 0.5, 0.5, 0.5)
      end,
    }
  end
  Book.SetStats({
    { "Companions", tostring(#list) },
    { "Together", C.Duration(total) },
  })
  if #list == 0 then
    empty:SetText("No companions in the journal yet. Summon your pet and its page begins.")
  end
  Book.SetFieldNote("Every pet that walks at your side gets a page. Click one to read it.")
  Book.ShowPage(list, COLS * 5, TOP + 2)
end

------------------------------------------------------------------------
Render = function()
  local view = state.chronView or "chronicle"
  UpdateLinks(view)
  empty:SetText("")
  if view == "companions" then
    zoom:Hide()
    RenderCompanions()
  else
    RenderChronicle()
    if zoom:IsShown() then DrawZoom() end
  end
end
