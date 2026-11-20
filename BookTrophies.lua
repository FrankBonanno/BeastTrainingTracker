local _, ns = ...

-- Book tab 6: Trophy Room. Bookmarks switch between the trophy wall (tamed
-- special pets as 3D models), milestone seals and the hunting log.
-- Skinning has its own tab (BookSkinning.lua).

local Book = ns.Book
if not Book then return end
local J = ns.Journal

local INK, INK_DIM, INK_GOOD = Book.INK, Book.INK_DIM, Book.INK_GOOD
local Font, JournalFont, Ink = Book.Font, Book.JournalFont, Book.Ink
local COLS, COL_W = Book.COLS, Book.COL_W

local TOP = 34                       -- content below the bookmarks
local PLAQUE_W, BOX_H, PLAQUE_H = COL_W - 14, 132, 184
local PER_WALL = COLS * 2

local Render -- forward
local page = Book.RegisterTab(6, { render = function() Render() end })

local function When(t)
  return type(t) == "number" and date("%b %d, %Y", t) or nil
end

local function FamilyIcon(f)
  return ns.RS and ns.RS.FamilyIcon(f ~= "Beast" and f or nil) or "Interface\\Icons\\Ability_Hunter_BeastTaming"
end

-- NPC id: our rare list first, then Questie
local function NpcId(name)
  if ns.rareIds and ns.rareIds[name] then return ns.rareIds[name] end
  local db = _G.NpcDB
  if ns.Geo.HasQuestie() and db and db.IdsByName then
    local ok, ids = pcall(db.IdsByName, name)
    if ok and type(ids) == "table" and ids[1] then return ids[1] end
  end
end

------------------------------------------------------------------------
-- Bookmarks
------------------------------------------------------------------------
local VIEWS = {
  { key = "trophies", label = "Trophies" },
  { key = "seals", label = "Milestones" },
  { key = "log", label = "Hunting Log" },
}

local function CurrentView()
  local v = Book.state.trophyView or "trophies"
  if v ~= "seals" and v ~= "log" then v = "trophies" end
  return v
end

local marks = {}
for i, v in ipairs(VIEWS) do
  local b = CreateFrame("Button", nil, page)
  b:SetHeight(22)
  b.text = JournalFont(b, 17, "SystemFont_Med3")
  b.text:SetPoint("LEFT", 0, 0)
  b.text:SetText(v.label)
  b:SetWidth(b.text:GetStringWidth() + 6)
  b.line = b:CreateTexture(nil, "ARTWORK")
  b.line:SetColorTexture(INK[1], INK[2], INK[3], 0.8)
  b.line:SetHeight(1)
  b.line:SetPoint("BOTTOMLEFT", 0, 1)
  b.line:SetPoint("BOTTOMRIGHT", -6, 1)
  b:SetScript("OnClick", function()
    Book.state.trophyView, Book.state.page = v.key, 1
    Book.Render()
  end)
  b:SetScript("OnEnter", function(self) if CurrentView() ~= v.key then Ink(self.text, INK) end end)
  b:SetScript("OnLeave", function(self) if CurrentView() ~= v.key then Ink(self.text, INK_DIM) end end)
  b.view = v
  marks[i] = b
end

local function LayoutMarks(view)
  local x = 0
  for _, b in ipairs(marks) do
    b:ClearAllPoints()
    b:SetPoint("TOPLEFT", page, "TOPLEFT", x, 0)
    x = x + b:GetWidth() + 22
    local on = b.view.key == view
    Ink(b.text, on and INK or INK_DIM)
    b.line:SetShown(on)
  end
end

local empty = Font(page, "SystemFont_Med1")
empty:SetPoint("TOPLEFT", 0, -(TOP + 6))
empty:SetWidth(COL_W * COLS)
empty:SetWordWrap(true)

------------------------------------------------------------------------
-- Trophy wall: a plaque per tamed special pet, with its 3D model
------------------------------------------------------------------------
local wall = CreateFrame("Frame", nil, page)
wall:SetAllPoints()

local plaques = {}

local function SetPlaqueModel(p, name)
  if p.modelName == name then return end
  p.modelName, p.facing, p.spin = name, 0.4, true
  p.model:ClearModel()
  local id = NpcId(name)
  if not id or not p.model.SetCreature then
    p.model:Hide()
    p.sketch:Show()
    return
  end
  p.sketch:Hide()
  p.model:Show()
  p.model:SetCreature(id)
  p.model:SetFacing(p.facing)
  -- the creature may not be in your game cache yet; try again shortly
  if C_Timer then
    C_Timer.After(0.5, function()
      if p.modelName == name and p.model:IsVisible() then
        p.model:SetCreature(id)
        p.model:SetFacing(p.facing)
      end
    end)
  end
end

local function PlaqueTip(p)
  local r = p.info
  if not r then return end
  local sp = r.t
  GameTooltip:SetOwner(p.box, "ANCHOR_RIGHT")
  GameTooltip:AddLine(r.name, 1, 0.82, 0)
  GameTooltip:AddLine(("%s, level %s  -  %s"):format(sp.family, sp.level, ns.RS.TypeText(sp)), 1, 1, 1)
  GameTooltip:AddLine(sp.zone, 0.8, 0.8, 0.8)
  if r.speed then GameTooltip:AddLine(("Attack speed %.1f"):format(r.speed), 0.8, 0.8, 0.8) end
  local nick = ns.db.tamedNicks and ns.db.tamedNicks[r.name]
  if nick then GameTooltip:AddLine("You call it " .. nick, 0.25, 1, 0.25) end
  local when = When(ns.db.tamedRares[r.name])
  GameTooltip:AddLine(when and ("Tamed " .. when) or "Tamed", 0.25, 1, 0.25)
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Drag to turn it", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end

local function MakePlaque(i)
  local p = CreateFrame("Frame", nil, wall)
  p:SetSize(PLAQUE_W, PLAQUE_H)
  p:SetPoint("TOPLEFT", ((i - 1) % COLS) * COL_W, -(TOP + math.floor((i - 1) / COLS) * (PLAQUE_H + 8)))

  p.box = CreateFrame("Frame", nil, p)
  p.box:SetPoint("TOPLEFT")
  p.box:SetSize(PLAQUE_W, BOX_H)
  local wash = p.box:CreateTexture(nil, "BACKGROUND")
  wash:SetAllPoints()
  wash:SetColorTexture(INK[1], INK[2], INK[3], 0.10)
  for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
    { "TOPLEFT", "BOTTOMLEFT", "w" }, { "TOPRIGHT", "BOTTOMRIGHT", "w" } }) do
    local t = p.box:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0.60, 0.48, 0.28, 0.9)
    t:SetPoint(side[1])
    t:SetPoint(side[2])
    if side[3] == "w" then t:SetWidth(1) else t:SetHeight(1) end
  end

  p.sketch = p.box:CreateTexture(nil, "ARTWORK")
  p.sketch:SetSize(56, 56)
  p.sketch:SetPoint("CENTER")
  p.sketch:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  p.sketch:SetDesaturated(true)
  p.sketch:SetAlpha(0.55)

  p.model = CreateFrame("PlayerModel", nil, p.box)
  p.model:SetPoint("TOPLEFT", 2, -2)
  p.model:SetPoint("BOTTOMRIGHT", -2, 2)
  p.model:EnableMouse(true)
  p.model:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then p.dragX, p.spin = GetCursorPosition(), false end
  end)
  p.model:SetScript("OnMouseUp", function() p.dragX = nil end)
  p.model:SetScript("OnUpdate", function(self, elapsed)
    if p.dragX then
      local x = GetCursorPosition()
      p.facing = p.facing + (x - p.dragX) * 0.02
      p.dragX = x
      self:SetFacing(p.facing)
    elseif p.spin then
      p.facing = p.facing + elapsed * 0.4
      self:SetFacing(p.facing)
    end
  end)
  p.model:SetScript("OnEnter", function() PlaqueTip(p) end)
  p.model:SetScript("OnLeave", GameTooltip_Hide)
  p.box:EnableMouse(true)
  p.box:SetScript("OnEnter", function() PlaqueTip(p) end)
  p.box:SetScript("OnLeave", GameTooltip_Hide)

  p.name = JournalFont(p, 16, "SystemFont_Med3")
  p.name:SetPoint("TOP", p.box, "BOTTOM", 0, -6)
  p.name:SetWidth(PLAQUE_W)
  p.name:SetJustifyH("CENTER")
  p.name:SetWordWrap(false)

  p.sub = Font(p, "GameFontNormalSmall", INK_DIM)
  p.sub:SetPoint("TOP", p.name, "BOTTOM", 0, -3)
  p.sub:SetWidth(PLAQUE_W)
  p.sub:SetJustifyH("CENTER")
  p.sub:SetWordWrap(false)

  plaques[i] = p
  return p
end
for i = 1, PER_WALL do MakePlaque(i) end

local function Trophies()
  local list = {}
  for name, v in pairs(ns.db.tamedRares or {}) do
    local r = v and ns.RS.Info(name)
    if r then list[#list + 1] = { info = r, when = type(v) == "number" and v or 0 } end
  end
  table.sort(list, function(a, b)
    if a.when ~= b.when then return a.when > b.when end
    return a.info.name < b.info.name
  end)
  return list
end

local function RenderWall()
  wall:Show()
  local list = Trophies()
  local n = Book.SetPager(math.max(1, math.ceil(#list / PER_WALL)))
  local first = (n - 1) * PER_WALL
  for i, p in ipairs(plaques) do
    local e = list[first + i]
    p.info = e and e.info
    if e then
      local r = e.info
      p.sketch:SetTexture(r.icon)
      SetPlaqueModel(p, r.name)
      p.name:SetText(r.name)
      local nick = ns.db.tamedNicks and ns.db.tamedNicks[r.name]
      local bits = {}
      if nick and nick ~= r.name then bits[#bits + 1] = ('"%s"'):format(nick) end
      bits[#bits + 1] = When(e.when > 0 and e.when or nil) or (r.t.family .. ", level " .. r.t.level)
      p.sub:SetText(table.concat(bits, "  ·  "))
      p:Show()
    else
      p:Hide()
    end
  end
  empty:SetText(#list == 0 and "The walls are bare. Tame a special pet - see the Special Pets pages - "
    .. "and it will be mounted here." or "")
  local total = #(ns.rarePets or {})
  local seals, earned = J.Seals(), 0
  for _, e in ipairs(seals) do
    if e.done then earned = earned + 1 end
  end
  Book.SetStats({
    { "Trophies", ("%d / %d"):format(#list, total) },
    { "Seals", ("%d / %d"):format(earned, #seals) },
    { "Beasts slain", tostring(J.Kills()) },
  })
  Book.SetFieldNote(#list > 0 and ("Your latest trophy: %s."):format(list[1].info.name)
    or "Every rare, elite and quest beast you tame earns a place on this wall.")
end

------------------------------------------------------------------------
-- Milestones, hunting log, skinning: spellbook-style grids
------------------------------------------------------------------------
local function SealProgress(e)
  local s = e.seal
  if s.money then return ("%s / %s"):format(J.Money(e.have), J.Money(s.goal)) end
  if s.id:find("^rank") then return ("%d%% / %d%%"):format(math.min(e.have, s.goal), s.goal) end
  return ("%d / %d"):format(math.min(e.have, s.goal), s.goal)
end

-- Hunter rank banner above the seals: emblem, name, progress, the ladder of ranks
local BANNER_H = 66
local banner = CreateFrame("Frame", nil, page)
banner:SetPoint("TOPLEFT", 0, -TOP)
banner:SetSize(COLS * COL_W, BANNER_H)
banner:Hide()
do
  local wash = banner:CreateTexture(nil, "BACKGROUND")
  wash:SetAllPoints()
  wash:SetColorTexture(INK[1], INK[2], INK[3], 0.08)
  for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
    { "TOPLEFT", "BOTTOMLEFT", "w" }, { "TOPRIGHT", "BOTTOMRIGHT", "w" } }) do
    local t = banner:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0.60, 0.48, 0.28, 0.9)
    t:SetPoint(side[1])
    t:SetPoint(side[2])
    if side[3] == "w" then t:SetWidth(1) else t:SetHeight(1) end
  end
end
banner.icon = banner:CreateTexture(nil, "ARTWORK")
banner.icon:SetSize(42, 42)
banner.icon:SetPoint("LEFT", 16, 0)
banner.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
banner.frame = banner:CreateTexture(nil, "OVERLAY")
banner.frame:SetAtlas("spellbook-item-iconframe")
banner.frame:SetSize(55, 50)
banner.frame:SetPoint("TOPLEFT", banner.icon, "TOPLEFT", -12, 1)
banner.label = Font(banner, "GameFontNormalSmall", INK_DIM)
banner.label:SetPoint("TOPLEFT", banner.icon, "TOPRIGHT", 14, 1)
banner.name = JournalFont(banner, 20, "SystemFont_Huge2")
banner.name:SetPoint("TOPLEFT", banner.label, "BOTTOMLEFT", 0, -1)
banner.bar = CreateFrame("StatusBar", nil, banner)
banner.bar:SetSize(196, 6)
banner.bar:SetPoint("TOPLEFT", banner.name, "BOTTOMLEFT", 1, -5)
banner.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
banner.bar:SetStatusBarColor(0.85, 0.62, 0.15)
banner.bar.edge = banner.bar:CreateTexture(nil, "BACKGROUND", nil, 1)
banner.bar.edge:SetPoint("TOPLEFT", -1, 1)
banner.bar.edge:SetPoint("BOTTOMRIGHT", 1, -1)
banner.bar.edge:SetColorTexture(0.60, 0.48, 0.28, 0.9)
banner.bar.bg = banner.bar:CreateTexture(nil, "BACKGROUND", nil, 2)
banner.bar.bg:SetAllPoints()
banner.bar.bg:SetColorTexture(0.16, 0.11, 0.07, 1)
banner.next = Font(banner, "GameFontNormalSmall", INK_DIM)
banner.next:SetPoint("LEFT", banner.bar, "RIGHT", 10, 0)

-- every rank as a small icon: reached ones in color, the rest faded
banner.ladder = {}
for i, r in ipairs(J.RANKS) do
  local b = CreateFrame("Frame", nil, banner)
  b:SetSize(20, 20)
  b:SetPoint("RIGHT", banner, "RIGHT", -12 - (#J.RANKS - i) * 24, 0)
  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetAllPoints()
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b:EnableMouse(true)
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(("Rank %d: %s"):format(i, r.name), 1, 0.82, 0)
    GameTooltip:AddLine(("%d hunter points"):format(J.Ranks()[i].points), 1, 1, 1)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  banner.ladder[i] = b
end

local function UpdateBanner()
  local i, r, pts, nextRank = J.Rank()
  banner.icon:SetTexture(J.RankIcon(i))
  banner.label:SetText(("HUNTER RANK %d OF %d  ·  %d POINTS"):format(i, #J.RANKS, pts))
  banner.name:SetText(r.name)
  if nextRank then
    banner.bar:SetMinMaxValues(r.points, nextRank.points)
    banner.bar:SetValue(pts)
    banner.next:SetText(("%d to %s"):format(nextRank.points - pts, nextRank.name))
  else
    banner.bar:SetMinMaxValues(0, 1)
    banner.bar:SetValue(1)
    banner.next:SetText("The highest rank")
  end
  for k, b in ipairs(banner.ladder) do
    b.icon:SetTexture(J.RankIcon(k))
    b.icon:SetDesaturated(k > i)
    b.icon:SetAlpha(k > i and 0.45 or 1)
  end
end

local function RenderSeals()
  banner:Show()
  UpdateBanner()
  local list, done = {}, 0
  for _, e in ipairs(J.Seals()) do
    if e.done then done = done + 1 end
    local s = e.seal
    local when = When(e.when)
    list[#list + 1] = {
      icon = s.icon, name = s.name, dim = not e.done, mastered = e.done,
      sub = e.done and ((when and ("Earned " .. when) or "Earned") .. ("  ·  +%d"):format(s.points))
        or ("%s  ·  %d pts"):format(SealProgress(e), s.points),
      subColor = e.done and INK_GOOD or INK,
      tip = function(tt)
        tt:AddLine(s.name, 1, 0.82, 0)
        tt:AddLine(s.desc, 1, 1, 1, true)
        tt:AddLine(SealProgress(e), 0.8, 0.8, 0.8)
        tt:AddLine(("Worth %d hunter points"):format(s.points), 1, 0.82, 0.3)
        if e.done then tt:AddLine(when and ("Earned " .. when) or "Earned", 0.25, 1, 0.25) end
      end,
    }
  end
  local _, _, pts = J.Rank()
  Book.SetStats({
    { "Seals", ("%d / %d"):format(done, #list) },
    { "Hunter points", ("%d / %d"):format(pts, J.MaxPoints()) },
  })
  Book.SetFieldNote(done == #list and "Every seal is yours. A legend among hunters."
    or "Each seal adds hunter points; points raise your hunter rank.")
  Book.ShowPage(list, COLS * 4, TOP + BANNER_H + 10)
end

local function RenderLog()
  local counts, killed = {}, 0
  for _, e in ipairs(J.FamilyKills()) do counts[e.family] = e.count end
  local list = {}
  local function Add(f, n)
    if n > 0 then killed = killed + 1 end
    list[#list + 1] = {
      icon = FamilyIcon(f), name = f == "Beast" and "Other beasts" or f, dim = n == 0,
      sub = n > 0 and (n == 1 and "1 slain" or ("%d slain"):format(n)) or "None yet",
      subColor = n > 0 and INK or INK_DIM,
      badge = n > 0 and tostring(n) or nil,
      tip = function(tt)
        tt:AddLine(f == "Beast" and "Other beasts" or f, 1, 0.82, 0)
        tt:AddLine(n > 0 and ("%d slain by you or your pet"):format(n) or "You haven't hunted one yet", 1, 1, 1)
      end,
    }
  end
  local families = J.Families()
  table.sort(families, function(a, b)
    local ca, cb = counts[a] or 0, counts[b] or 0
    if ca ~= cb then return ca > cb end
    return a < b
  end)
  for _, f in ipairs(families) do Add(f, counts[f] or 0) end
  if (counts.Beast or 0) > 0 then Add("Beast", counts.Beast) end

  local j = ns.db.journal
  Book.SetStats({
    { "Beasts slain", tostring(J.Kills()) },
    { "Families", ("%d / %d"):format(killed - ((counts.Beast or 0) > 0 and 1 or 0), #families) },
  })
  Book.SetFieldNote(("Kills by you or your pet since %s. Faded families are still waiting for you."):format(
    When(j and j.since) or "today"))
  Book.ShowPage(list, COLS * 5, TOP)
end

------------------------------------------------------------------------
Render = function()
  local view = CurrentView()
  LayoutMarks(view)
  empty:SetText("")
  wall:SetShown(view == "trophies")
  banner:Hide()
  if view == "trophies" then
    RenderWall()
  elseif view == "seals" then
    RenderSeals()
  else
    RenderLog()
  end
end
