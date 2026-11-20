local _, ns = ...

-- Book tab 2: Hunt Planner. Index = zones with ranks you can tame now;
-- clicking a zone opens its page: the ranks it teaches and the beasts to tame.

local Book = ns.Book
if not Book then return end
local Geo = ns.Geo

local INK, INK_DIM, INK_GOOD, INK_RED = Book.INK, Book.INK_DIM, Book.INK_GOOD, Book.INK_RED
local INK_WARM = { 0.62, 0.30, 0.02 } -- dark orange ink: above your level, rares
local Font, JournalFont = Book.Font, Book.JournalFont
local COLS, ROW_STEP = Book.COLS, Book.ROW_STEP
local PAGE_W = Book.COLS * Book.COL_W
local PAGE_H = 428
local ITEM_H = 56
local MAX_ROUTE = 15
local CHIP_COLS, CHIP_MAX = 4, 8
local CHIP_W, CHIP_H = math.floor(PAGE_W / CHIP_COLS), 34
local MORE_ICON = "Interface\\Icons\\Ability_Hunter_BeastTraining"

local hunt = { zone = nil, indexPage = 1 }
Book.state.hunt = hunt

local RenderHunt -- forward
local page = Book.RegisterTab(2, { search = true, render = function() RenderHunt() end })

-- leaving the tab (or closing the book) returns to the zone index next time
page:HookScript("OnHide", function() hunt.zone = nil end)

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function Plural(n, word) return ("%d %s%s"):format(n, word, n == 1 and "" or "s") end

local function RankText(e) return ("%s %d"):format(e.ab.name, e.rank.rank) end

local function LevelRange(z)
  if not z.minLevel or z.minLevel <= 0 then return nil end
  if z.minLevel == z.maxLevel then return tostring(z.minLevel) end
  return ("%d-%d"):format(z.minLevel, z.maxLevel)
end

-- grey = outlevelled, green = your level, orange = above you
local function LevelColor(z, lvl)
  if not z.minLevel or z.minLevel <= 0 then return INK end
  if z.maxLevel < lvl then return INK_DIM end
  if z.minLevel > lvl then return INK_WARM end
  return INK_GOOD
end

-- Waypoints to every beast in the zone (same cap as the old planner)
local function ZoneRoute(z)
  local list = {}
  for _, e in ipairs(z.entries) do
    for _, t in ipairs(e.teachers) do
      if #list >= MAX_ROUTE then return list end
      list[#list + 1] = { t = t, label = Geo.Label(e.ab, e.rank, t) }
    end
  end
  return list
end

local function EntryRoute(e)
  local list = {}
  for _, t in ipairs(e.teachers) do list[#list + 1] = { t = t, label = Geo.Label(e.ab, e.rank, t) } end
  return list
end

local function GetPlan()
  local o = ns.db.opts
  local plan = ns.HuntPlan(o.huntPetOnly, o.huntDungeons, o.huntSortCount and "count" or "level")
  if o.huntHereFirst then
    for i, z in ipairs(plan) do
      if z.here then
        table.remove(plan, i)
        table.insert(plan, 1, z)
        break
      end
    end
  end
  return plan
end

-- The zone's icon: the most advanced rank you can learn there
local function ZoneIcon(z)
  local best
  for _, e in ipairs(z.entries) do
    if not best or e.rank.level > best.rank.level then best = e end
  end
  return best and best.ab.icon or MORE_ICON
end

local function Has(text, s) return text and text:lower():find(s, 1, true) ~= nil end

local function ZoneMatches(z, s)
  if s == "" or Has(z.zone, s) then return true end
  for _, e in ipairs(z.entries) do
    if Has(e.ab.name, s) then return true end
    for _, t in ipairs(e.teachers) do
      if Has(t.name, s) or Has(t.family, s) then return true end
    end
  end
  return false
end

local function Divider(parent)
  local d = parent:CreateTexture(nil, "ARTWORK")
  d:SetAtlas("spellbook-divider")
  d:SetSize(420, 11)
  return d
end

------------------------------------------------------------------------
-- Filters (ink checkboxes), same semantics as the old window's Check()
------------------------------------------------------------------------
local checks = {}

local function Check(parent, label, key, tip, after)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  if after then
    cb:SetPoint("LEFT", after, "RIGHT", 12, 0)
  else
    cb:SetPoint("TOPLEFT", -3, 2)
  end
  local fs = cb.text or cb.Text
  if not fs then
    fs = cb:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontNormalSmall")
  fs:SetShadowOffset(0, 0)
  Book.Ink(fs, INK)
  fs:SetText(label)
  -- the label is clickable too
  cb:SetHitRectInsets(0, -(fs:GetStringWidth() + 4), 0, 0)
  cb:SetScript("OnClick", function(self)
    ns.db.opts[key] = self:GetChecked() and true or false
    ns.Refresh()
  end)
  cb:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(label, 1, 0.82, 0)
    GameTooltip:AddLine(tip, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  cb:SetScript("OnLeave", GameTooltip_Hide)
  cb.key = key
  checks[#checks + 1] = cb
  return fs
end

------------------------------------------------------------------------
-- Index widgets: filters, intro, Questie note, divider
------------------------------------------------------------------------
local indexView = CreateFrame("Frame", nil, page)
indexView:SetAllPoints()

do
  local a = Check(indexView, "My pet's family only", "huntPetOnly", "Only count abilities your current pet's family can use.")
  a = Check(indexView, "Include dungeons", "huntDungeons", "Also count beasts that live inside dungeons.", a)
  a = Check(indexView, "Most new ranks first", "huntSortCount",
    "Show the zones with the most new ranks first, instead of lowest level first.", a)
  a = Check(indexView, "Enemy faction zones", "huntBothFactions",
    "Also list zones that belong to the other faction (marked in red). Contested zones are always shown.", a)
  Check(indexView, "My zone first", "huntHereFirst", "If the zone you're in has something to tame, list it at the top.", a)
end

local intro = Font(indexView, "GameFontNormalSmall")
intro:SetPoint("TOPLEFT", 0, -28)
intro:SetWidth(PAGE_W)
intro:SetWordWrap(true)

local questieNote = Font(indexView, "GameFontNormalSmall", INK_RED)
questieNote:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -3)
questieNote:SetWidth(PAGE_W)

local indexDivider = Divider(indexView)
indexDivider:SetPoint("TOPLEFT", -16, -74)

local indexEmpty = Font(indexView, "SystemFont_Med1")
indexEmpty:SetPoint("TOPLEFT", 0, -96)
indexEmpty:SetWidth(PAGE_W)

local INDEX_TOP = 90

------------------------------------------------------------------------
-- Zone page widgets: rank chips, Route all, beasts heading
------------------------------------------------------------------------
local zoneView = CreateFrame("Frame", nil, page)
zoneView:SetAllPoints()
zoneView:Hide()

local currentZone -- plan entry shown on the zone page

local ranksHeading = JournalFont(zoneView, 18, "SystemFont_Med3")
ranksHeading:SetPoint("TOPLEFT", 0, 0)
ranksHeading:SetText("Ranks you can learn here")

local routeBtn = CreateFrame("Button", nil, zoneView, "UIPanelButtonTemplate")
routeBtn:SetSize(130, 22)
routeBtn:SetPoint("TOPRIGHT", 0, 3)
routeBtn:SetText("Route all beasts")
routeBtn:SetScript("OnClick", function()
  if currentZone then Geo.WaypointMany(ZoneRoute(currentZone)) end
end)
routeBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("Route all beasts", 1, 0.82, 0)
  GameTooltip:AddLine(("Waypoints to every beast here that teaches a new rank, nearest first (up to %d stops; TomTom arrows if installed)."):format(MAX_ROUTE), 1, 1, 1, true)
  GameTooltip:Show()
end)
routeBtn:SetScript("OnLeave", GameTooltip_Hide)

local zoneDivider = Divider(zoneView)

local beastsHeading = JournalFont(zoneView, 18, "SystemFont_Med3")
beastsHeading:SetText("Beasts to tame")

local beastsHint = Font(zoneView, "GameFontNormalSmall", INK_DIM)
beastsHint:SetPoint("LEFT", beastsHeading, "RIGHT", 12, 0)
beastsHint:SetText("Click: waypoint  ·  Shift-click: route to every beast here")

local zoneEmpty = Font(zoneView, "SystemFont_Med1")
zoneEmpty:SetWidth(PAGE_W)

-- A rank "chip": small framed icon + "Bite 6" + pet level
local chips = {}

local function GetChip(i)
  if chips[i] then return chips[i] end
  local c = CreateFrame("Button", nil, zoneView)
  c:SetSize(CHIP_W - 8, CHIP_H)

  c.icon = c:CreateTexture(nil, "ARTWORK")
  c.icon:SetSize(26, 26)
  c.icon:SetPoint("LEFT", 8, 0)
  c.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  c.border = c:CreateTexture(nil, "OVERLAY")
  c.border:SetAtlas("spellbook-item-iconframe")
  c.border:SetSize(34, 31)
  c.border:SetPoint("TOPLEFT", c.icon, "TOPLEFT", -7, 1)

  c.glow = c:CreateTexture(nil, "OVERLAY", nil, 1)
  c.glow:SetAtlas("spellbook-item-iconframe-hover")
  c.glow:SetAllPoints(c.icon)
  c.glow:SetBlendMode("ADD")
  c.glow:SetAlpha(0.5)
  c.glow:Hide()

  c.name = Font(c, "SystemFont_Med1")
  c.name:SetPoint("TOPLEFT", c.icon, "TOPRIGHT", 8, 1)
  c.name:SetWidth(CHIP_W - 56)
  c.name:SetWordWrap(false)

  c.sub = Font(c, "GameFontNormalSmall", INK_DIM)
  c.sub:SetPoint("TOPLEFT", c.name, "BOTTOMLEFT", 0, -2)
  c.sub:SetWidth(CHIP_W - 56)
  c.sub:SetWordWrap(false)

  c:SetScript("OnEnter", function(self)
    self.glow:Show()
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      self.tip(GameTooltip)
      GameTooltip:Show()
    end
  end)
  c:SetScript("OnLeave", function(self)
    self.glow:Hide()
    GameTooltip_Hide()
  end)
  c:SetScript("OnClick", function(self)
    if self.onClick then self.onClick() end
  end)
  chips[i] = c
  return c
end

local function TeachersTip(tt, e)
  for _, t in ipairs(e.teachers) do
    tt:AddDoubleLine(t.name .. Geo.Tag(t.name), ("%s %s"):format(t.family, t.level), 1, 1, 1, 0.7, 0.7, 0.7)
  end
end

local function FillRankChip(c, e)
  c.icon:SetTexture(e.ab.icon)
  c.name:SetText(RankText(e))
  c.sub:SetText(("pet lvl %d  ·  %s"):format(e.rank.level, Plural(#e.teachers, "beast")))
  c.onClick = function() Geo.WaypointMany(EntryRoute(e)) end
  c.tip = function(tt)
    tt:AddLine(("%s (Rank %d)"):format(e.ab.name, e.rank.rank), 1, 0.82, 0)
    tt:AddLine(e.rank.effect, 1, 1, 1, true)
    tt:AddLine(("Pet level %d  -  %d TP"):format(e.rank.level, e.rank.tp), 0.8, 0.8, 0.8)
    tt:AddLine(" ")
    TeachersTip(tt, e)
    tt:AddLine(" ")
    tt:AddLine("Click: waypoints to these beasts", 0.5, 0.5, 0.5)
  end
end

local function FillMoreChip(c, z, from)
  local rest = #z.entries - from + 1
  c.icon:SetTexture(MORE_ICON)
  c.name:SetText(("+%d more"):format(rest))
  c.sub:SetText("hover for the list")
  c.onClick = function() Geo.WaypointMany(ZoneRoute(z)) end
  c.tip = function(tt)
    tt:AddLine("Also learnable here", 1, 0.82, 0)
    for i = from, #z.entries do
      local e = z.entries[i]
      local who = e.teachers[1].name .. (#e.teachers > 1 and (" +" .. (#e.teachers - 1)) or "")
      tt:AddDoubleLine(RankText(e), who, 1, 1, 1, 0.7, 0.7, 0.7)
    end
    tt:AddLine(" ")
    tt:AddLine("Click: waypoints to every beast here", 0.5, 0.5, 0.5)
  end
end

------------------------------------------------------------------------
-- Index page: a grid of zones
------------------------------------------------------------------------
local function ZoneTip(z, hostile)
  return function(tt)
    tt:AddLine(z.zone, 1, 0.82, 0)
    local range = LevelRange(z)
    if range then tt:AddLine("Recommended level " .. range, 0.8, 0.8, 0.8) end
    if hostile then tt:AddLine(("%s territory"):format(ns.ZoneFaction(z.zone) or "Enemy"), 1, 0.25, 0.25) end
    if z.here then tt:AddLine("You're here", 0.25, 1, 0.25) end
    tt:AddLine(" ")
    for _, e in ipairs(z.entries) do
      local who = e.teachers[1].name .. (#e.teachers > 1 and (" +" .. (#e.teachers - 1)) or "")
      tt:AddDoubleLine(RankText(e), who, 1, 1, 1, 0.7, 0.7, 0.7)
    end
    tt:AddLine(" ")
    tt:AddLine("Click: open this zone's page", 0.5, 0.5, 0.5)
    tt:AddLine("Shift- or right-click: waypoints to these beasts (TomTom arrows if installed)", 0.5, 0.5, 0.5, true)
  end
end

local function OpenZone(z)
  hunt.zone, hunt.indexPage = z.zone, Book.state.page
  Book.state.page = 1
  Book.Render()
end

-- Most new ranks among friendly zones that fit your level
local function BestZone(plan, lvl)
  local best, any
  for _, z in ipairs(plan) do
    if not ns.ZoneHostile(z.zone) then
      if not any or #z.entries > #any.entries then any = z end
      local fits = z.minLevel > 0 and z.minLevel <= lvl + 2 and z.maxLevel >= lvl - 3
      if fits and (not best or #z.entries > #best.entries
        or (#z.entries == #best.entries and z.levelSum > best.levelSum)) then
        best = z
      end
    end
  end
  return best, any
end

local function RenderIndex()
  indexView:Show()
  zoneView:Hide()
  currentZone = nil
  local o = ns.db.opts
  for _, cb in ipairs(checks) do cb:SetChecked(o[cb.key] and true or false) end

  local lvl = ns.PlayerLevel()
  intro:SetText(("Zones where you can tame ranks you're missing at your level (%d), %s. " ..
    "Only the highest missing rank of each ability is counted - it covers the lower ones."):format(lvl,
    o.huntSortCount and "most new ranks first" or "lowest level first"))
  questieNote:SetText(Geo.HasQuestie() and ""
    or "Questie not installed: routes only include beasts you've spotted yourself.")

  local plan = GetPlan()
  local s = Book.state.search or ""
  local list, seen, nRanks = {}, {}, 0
  for _, z in ipairs(plan) do
    for _, e in ipairs(z.entries) do
      local k = e.ab.name .. "#" .. e.rank.rank
      if not seen[k] then
        seen[k] = true
        nRanks = nRanks + 1
      end
    end
    if ZoneMatches(z, s) then
      local n = #z.entries
      local hostile = ns.ZoneHostile(z.zone)
      local range = LevelRange(z)
      local tail = hostile and (ns.ZoneFaction(z.zone) or "Enemy") or Plural(n, "new rank")
      list[#list + 1] = {
        icon = ZoneIcon(z),
        name = z.zone,
        sub = range and ("Lv %s  ·  %s"):format(range, tail) or tail,
        nameColor = hostile and INK_RED or INK,
        subColor = hostile and INK_RED or LevelColor(z, lvl),
        dim = hostile or z.minLevel > lvl,
        here = z.here,
        badge = tostring(n),
        tip = ZoneTip(z, hostile),
        onClick = function()
          if IsShiftKeyDown() then Geo.WaypointMany(ZoneRoute(z)) else OpenZone(z) end
        end,
        onRightClick = function() Geo.WaypointMany(ZoneRoute(z)) end,
      }
    end
  end

  Book.SetStats({
    { "Zones", tostring(#plan) },
    { "New ranks", tostring(nRanks) },
    { "Your level", tostring(lvl) },
  })

  if #plan == 0 then
    indexEmpty:SetText("Nothing left to tame at your level - nice!")
  elseif #list == 0 then
    indexEmpty:SetText("No zone matches your search.")
  else
    indexEmpty:SetText("")
  end

  local best, any = BestZone(plan, lvl)
  if best and best.here then
    Book.SetFieldNote(("You're standing in the best hunting ground for your level: %s, %s."):format(
      best.zone, Plural(#best.entries, "new rank")))
  elseif best then
    Book.SetFieldNote(("Best hunting for your level: %s, %s (level %s)."):format(
      best.zone, Plural(#best.entries, "new rank"), LevelRange(best)))
  elseif any then
    Book.SetFieldNote(("Most to learn: %s, %s."):format(any.zone, Plural(#any.entries, "new rank")))
  else
    Book.SetFieldNote("Every rank within reach is learned. Come back when you've levelled up.")
  end

  Book.ShowPage(list, COLS * 5, INDEX_TOP)
end

------------------------------------------------------------------------
-- Zone page: the ranks it teaches, then the beasts to tame
------------------------------------------------------------------------
local function BeastMatches(b, s)
  if s == "" or Has(b.t.name, s) or Has(b.t.family, s) then return true end
  for _, e in ipairs(b.teaches) do
    if Has(e.ab.name, s) then return true end
  end
  return false
end

local function RenderZone(z)
  indexView:Hide()
  zoneView:Show()
  currentZone = z
  Book.SetBack(function()
    hunt.zone = nil
    Book.state.page = hunt.indexPage or 1
    Book.Render()
  end)

  local hostile = ns.ZoneHostile(z.zone)
  Book.SetTitle("Beast Training Tracker - " .. z.zone)
  Book.SetHeader((z.zone:gsub("%s*%(Dungeon%)%s*$", "")))
  -- first stat column left empty so long zone names have room
  Book.SetStats({
    { "", "" },
    { "Levels", LevelRange(z) or "?" },
    { "New ranks", tostring(#z.entries) },
  })

  -- rank chips, at most two rows; the last slot becomes "+N more"
  local n = #z.entries
  local slots = n > CHIP_MAX and CHIP_MAX - 1 or n
  for i = 1, slots do FillRankChip(GetChip(i), z.entries[i]) end
  local used = slots
  if n > CHIP_MAX then
    used = CHIP_MAX
    FillMoreChip(GetChip(used), z, slots + 1)
  end
  for i = 1, used do
    local c = chips[i]
    c:ClearAllPoints()
    c:SetPoint("TOPLEFT", zoneView, "TOPLEFT", ((i - 1) % CHIP_COLS) * CHIP_W, -24 - math.floor((i - 1) / CHIP_COLS) * (CHIP_H + 4))
    c:Show()
  end
  for i = used + 1, #chips do chips[i]:Hide() end

  local rows = math.max(1, math.ceil(used / CHIP_COLS))
  local divY = -24 - rows * (CHIP_H + 4) - 4
  zoneDivider:ClearAllPoints()
  zoneDivider:SetPoint("TOPLEFT", zoneView, "TOPLEFT", -16, divY)
  beastsHeading:ClearAllPoints()
  beastsHeading:SetPoint("TOPLEFT", zoneView, "TOPLEFT", 0, divY - 16)
  local top = -divY + 40
  local perPage = COLS * math.max(1, math.floor((PAGE_H - top - ITEM_H) / ROW_STEP) + 1)

  -- one item per beast, with every new rank it teaches
  local byName, beasts = {}, {}
  for _, e in ipairs(z.entries) do
    for _, t in ipairs(e.teachers) do
      local b = byName[t.name]
      if not b then
        b = { t = t, teaches = {} }
        byName[t.name] = b
        beasts[#beasts + 1] = b
      end
      b.teaches[#b.teaches + 1] = e
    end
  end
  table.sort(beasts, function(a, b)
    if a.t.minLevel ~= b.t.minLevel then return a.t.minLevel < b.t.minLevel end
    return a.t.name < b.t.name
  end)

  local s = Book.state.search or ""
  local list = {}
  for _, b in ipairs(beasts) do
    if BeastMatches(b, s) then
      local t = b.t
      local parts = {}
      for _, e in ipairs(b.teaches) do parts[#parts + 1] = RankText(e) end
      local teachText = table.concat(parts, ", ")
      local label = #b.teaches == 1 and Geo.Label(b.teaches[1].ab, b.teaches[1].rank, t)
        or ("%s - %s"):format(t.name, teachText)
      local special = Geo.IsRare(t.name) or Geo.IsElite(t.name)
      list[#list + 1] = {
        icon = (ns.RS and ns.RS.FamilyIcon(t.family)) or b.teaches[1].ab.icon,
        name = t.name,
        sub = teachText,
        nameColor = special and INK_WARM or INK,
        here = z.here,
        badge = tostring(t.minLevel),
        onClick = function()
          if IsShiftKeyDown() then Geo.WaypointMany(ZoneRoute(z)) else Geo.Waypoint(t, label) end
        end,
        tip = function(tt)
          tt:AddLine(t.name .. Geo.Tag(t.name), 1, 0.82, 0)
          tt:AddLine(("Level %s %s"):format(t.level, t.family), 1, 1, 1)
          if z.here then tt:AddLine(z.zone, 0.25, 1, 0.25) else tt:AddLine(z.zone, 0.8, 0.8, 0.8) end
          tt:AddLine(" ")
          for _, e in ipairs(b.teaches) do
            tt:AddDoubleLine(RankText(e), ("pet lvl %d"):format(e.rank.level), 1, 1, 1, 0.7, 0.7, 0.7)
            tt:AddLine(e.rank.effect, 0.8, 0.8, 0.8, true)
          end
          local info = Geo.Lookup(t.name)
          if not (info and #info.spawns > 0) then
            tt:AddLine(" ")
            tt:AddLine("No location known yet - spot it once (target or mouse over it) and it's remembered" ..
              (Geo.HasQuestie() and "." or ", or install Questie for every spawn."), 1, 0.56, 0.25, true)
          end
          tt:AddLine(" ")
          tt:AddLine("Click: waypoint  ·  Shift-click: route to every beast here", 0.5, 0.5, 0.5)
        end,
      }
    end
  end

  zoneEmpty:ClearAllPoints()
  zoneEmpty:SetPoint("TOPLEFT", zoneView, "TOPLEFT", 0, -top)
  zoneEmpty:SetText(#list == 0 and "No beast here matches your search." or "")

  if hostile then
    Book.SetFieldNote(("%s territory - keep your guard up while you hunt."):format(ns.ZoneFaction(z.zone) or "Enemy"))
  elseif z.here then
    Book.SetFieldNote("You're here. The number on each beast is the level you can tame it at.")
  elseif not Geo.HasQuestie() then
    Book.SetFieldNote("Without Questie, only beasts you've spotted yourself can be routed.")
  else
    Book.SetFieldNote("The number on each beast is its level. Shift-click any of them to route the whole zone.")
  end

  Book.ShowPage(list, perPage, top)
end

------------------------------------------------------------------------
RenderHunt = function()
  if hunt.zone then
    for _, z in ipairs(GetPlan()) do
      if z.zone == hunt.zone then
        RenderZone(z)
        return
      end
    end
    -- nothing left to learn there (or the filters hide it): back to the index
    hunt.zone = nil
    Book.state.page = hunt.indexPage or 1
  end
  RenderIndex()
end
