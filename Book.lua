local _, ns = ...

-- The v2 window, drawn with the same Blizzard art as the Forever spellbook
-- (atlas names, fonts and ink color recorded from PlayerSpellsFrame via /btt dumpbook).

local Geo = ns.Geo

local W, H = 820, 660
local INK = { 0.180, 0.106, 0.059 }
local INK_DIM = { 0.42, 0.31, 0.20 }
local INK_GOOD = { 0.08, 0.40, 0.06 }
local INK_RED = { 0.55, 0.10, 0.04 }
local COLS = 3
local MARGIN_L, MARGIN_R = 62, 50
local COL_W = math.floor((W - MARGIN_L - MARGIN_R) / COLS)
local ROW_STEP = 66
local ICON = 40

-- Spellbook page arrows (file IDs used by PagingControls in the spellbook)
local PREV_UP, PREV_DOWN, PREV_OFF = 130869, 130868, 130867
local NEXT_UP, NEXT_DOWN, NEXT_OFF = 130866, 130865, 130864
local ARROW_HL = 130757

local TABS = {
  { name = "Abilities", icon = "Interface\\Icons\\Ability_Hunter_BeastTraining" },
  { name = "Hunt Planner", icon = "Interface\\Icons\\INV_Misc_Map_01" },
  { name = "Special Pets", icon = "Interface\\Icons\\Ability_Hunter_Pet_Cat" },
  { name = "My Pet", icon = "Interface\\Icons\\Ability_Hunter_BeastCall" },
  { name = "Chronicle", icon = "Interface\\Icons\\INV_Scroll_03" },
  { name = "Trophy Room", icon = "Interface\\Icons\\INV_Misc_Head_Dragon_01" },
  { name = "Skinning", icon = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01",
    visible = function() return ns.Journal and ns.Journal.IsSkinner() end },
  { name = "Settings", icon = "Interface\\Icons\\INV_Misc_Gear_01" },
  { name = "Backup", icon = "Interface\\Icons\\INV_Misc_Book_09" },
}

local function Ink(fs, c) fs:SetTextColor(c[1], c[2], c[3]) return fs end

local function Font(parent, font, color, layer)
  local fs = parent:CreateFontString(nil, layer or "OVERLAY", font)
  fs:SetJustifyH("LEFT")
  fs:SetShadowOffset(0, 0)
  return Ink(fs, color or INK)
end

-- Morpheus (the quest-book font) for headings, so the book reads like a hunter's journal
local function JournalFont(parent, size, fallback, color)
  local fs = Font(parent, fallback, color)
  local ok = pcall(fs.SetFont, fs, "Fonts\\MORPHEUS.TTF", size, "")
  if not ok or not fs:GetFont() then fs:SetFontObject(fallback) end
  fs:SetShadowOffset(0, 0)
  return fs
end

------------------------------------------------------------------------
-- Window
------------------------------------------------------------------------
local f = CreateFrame("Frame", "BeastTrainingTrackerBook", UIParent, "PortraitFrameTemplate")
f:SetSize(W, H)
f:SetPoint("CENTER")
f:SetFrameStrata("HIGH")
f:SetToplevel(true)
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:Hide()
tinsert(UISpecialFrames, "BeastTrainingTrackerBook")

local function SetTitle(text)
  if f.SetTitle then
    f:SetTitle(text)
  elseif f.TitleText then
    f.TitleText:SetText(text)
  end
end

-- The portrait shows your current pet, or the Beast Training icon when none is out
local BOOK_ICON = "Interface\\Icons\\Ability_Hunter_BeastTraining"
local function UpdatePortrait()
  local portrait = (f.PortraitContainer and f.PortraitContainer.portrait) or f.portrait
  if UnitExists("pet") then
    if f.SetPortraitToUnit then f:SetPortraitToUnit("pet")
    elseif portrait then SetPortraitTexture(portrait, "pet") end
  elseif f.SetPortraitToAsset then
    f:SetPortraitToAsset(BOOK_ICON)
  elseif portrait then
    SetPortraitToTexture(portrait, BOOK_ICON)
  end
end

f:SetScript("OnDragStart", f.StartMoving)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  if ns.db then ns.db.bookPos = { p, rp, x, y } end
end)

-- The spellbook page art is drawn for a 574x702 page. Stretched to this
-- window its curled edges thicken, so it's cut into nine: corners at their
-- own size, edges stretched only along their length, the plain middle filling
-- the rest. PAGE_CUT is the edge band (in the art's pixels) kept unstretched.
local PAGE_ATLAS = "spellbook-Page-Right-C60"
local PAGE_CUT = { left = 46, right = 46, top = 118, bottom = 50 }

local function NineSlicePage()
  local info = C_Texture and C_Texture.GetAtlasInfo and C_Texture.GetAtlasInfo(PAGE_ATLAS)
  local file = info and (info.file or info.filename)
  if not (file and info.width and info.width > 0 and info.height and info.height > 0) then return false end
  local L, R, T, B = info.leftTexCoord, info.rightTexCoord, info.topTexCoord, info.bottomTexCoord
  local W, H = info.width, info.height
  local function U(px) return L + (R - L) * px / W end
  local function V(px) return T + (B - T) * px / H end
  local cl, cr, ct, cb = PAGE_CUT.left, PAGE_CUT.right, PAGE_CUT.top, PAGE_CUT.bottom
  local us = { U(0), U(cl), U(W - cr), U(W) }
  local vs = { V(0), V(ct), V(H - cb), V(H) }
  local area = CreateFrame("Frame", nil, f)
  area:SetPoint("TOPLEFT", 2, -18)
  area:SetPoint("BOTTOMRIGHT", -1, 2)
  area:SetFrameLevel(f:GetFrameLevel())
  for row = 1, 3 do
    for col = 1, 3 do
      local t = f:CreateTexture(nil, "BACKGROUND", nil, 2)
      t:SetTexture(file)
      t:SetTexCoord(us[col], us[col + 1], vs[row], vs[row + 1])
      local x1 = col == 1 and 0 or (col == 2 and cl or -cr)
      local y1 = row == 1 and 0 or (row == 2 and -ct or cb)
      -- the piece's top-left and bottom-right corners, each pinned to the edge it's measured from
      local fromX = col == 3 and "RIGHT" or "LEFT"
      local fromY = row == 3 and "BOTTOM" or "TOP"
      t:SetPoint("TOPLEFT", area, fromY .. fromX, x1, y1)
      local toX = col == 1 and "LEFT" or "RIGHT"
      local toY = row == 1 and "TOP" or "BOTTOM"
      local x2 = col == 1 and cl or (col == 2 and -cr or 0)
      local y2 = row == 1 and -ct or (row == 2 and cb or 0)
      t:SetPoint("BOTTOMRIGHT", area, toY .. toX, x2, y2)
    end
  end
  return true
end

if not NineSlicePage() then
  local page = f:CreateTexture(nil, "BACKGROUND", nil, 2)
  page:SetAtlas(PAGE_ATLAS)
  page:SetPoint("TOPLEFT", 2, -18)
  page:SetPoint("BOTTOMRIGHT", -1, 2)
end

------------------------------------------------------------------------
-- Category tabs (square spellbook tabs)
------------------------------------------------------------------------
local tabButtons = {}
local state = { tab = 1, page = 1, search = "" }
local Render, search, back, backFn -- forward

local function SelectTab(i)
  state.tab, state.ab, state.page = i, nil, 1
  if search and search:GetText() ~= "" then search:SetText("") end
  Render()
end

for i, t in ipairs(TABS) do
  local b = CreateFrame("Button", nil, f)
  b:SetSize(43, 38)
  b.icon = b:CreateTexture(nil, "ARTWORK", nil, 1)
  b.icon:SetSize(30, 30)
  b.icon:SetPoint("CENTER", 0, 1)
  b.icon:SetTexture(t.icon)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  b.frame = b:CreateTexture(nil, "ARTWORK", nil, 2)
  b.frame:SetAtlas("spellbook-Tab-Frame-C60")
  b.frame:SetAllPoints()
  b.glow = b:CreateTexture(nil, "OVERLAY")
  b.glow:SetAtlas("spellbook-Tab-Frame-Glow-C60")
  b.glow:SetAllPoints()
  b:SetHighlightAtlas("spellbook-Tab-Frame-glow-gradient-C60", "ADD")
  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(t.name, 1, 0.82, 0)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", function() SelectTab(i) end)
  tabButtons[i] = b
end

------------------------------------------------------------------------
-- Search + back
------------------------------------------------------------------------
search = CreateFrame("EditBox", nil, f, "SearchBoxTemplate")
search:SetSize(100, 20)
search:SetPoint("TOPRIGHT", -36, -54)
search:SetAutoFocus(false)
search:HookScript("OnTextChanged", function(self)
  state.search = (self:GetText() or ""):lower():match("^%s*(.-)%s*$")
  state.page = 1
  Render()
end)

back = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
back:SetSize(70, 22)
back:SetPoint("RIGHT", search, "LEFT", -8, 0)
back:SetText("Back")
back:SetScript("OnClick", function()
  if backFn then backFn() end
end)

------------------------------------------------------------------------
-- Pet card in the top strip: name, level, XP, happiness, free TP.
-- Hidden on the My Pet tab, which shows all of it in detail.
------------------------------------------------------------------------
local HAPPY = {
  [1] = { "Unhappy", 1, 0.35, 0.25 },
  [2] = { "Content", 1, 0.82, 0 },
  [3] = { "Happy", 0.4, 1, 0.3 },
}

local CARD_W = 128
local card = CreateFrame("Button", nil, f)
card:SetPoint("TOPLEFT", 462, -46)
card:SetSize(CARD_W, 36)

card.name = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
card.name:SetPoint("TOPLEFT", 0, 0)
card.name:SetWidth(CARD_W)
card.name:SetJustifyH("LEFT")
card.name:SetWordWrap(false)

card.bar = CreateFrame("StatusBar", nil, card)
card.bar:SetSize(CARD_W - 4, 4)
card.bar:SetPoint("TOPLEFT", 1, -17)
card.bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
card.bar:SetStatusBarColor(0.62, 0.42, 0.95)
card.bar.edge = card.bar:CreateTexture(nil, "BACKGROUND", nil, 1)
card.bar.edge:SetPoint("TOPLEFT", -1, 1)
card.bar.edge:SetPoint("BOTTOMRIGHT", 1, -1)
card.bar.edge:SetColorTexture(0.60, 0.48, 0.28, 0.9)
card.bar.bg = card.bar:CreateTexture(nil, "BACKGROUND", nil, 2)
card.bar.bg:SetAllPoints()
card.bar.bg:SetColorTexture(0.16, 0.11, 0.07, 1)

card.info = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
card.info:SetPoint("TOPLEFT", 0, -25)
card.info:SetWidth(CARD_W)
card.info:SetJustifyH("LEFT")
card.info:SetWordWrap(false)

local function PetStats()
  local s = {}
  if GetPetExperience then s.xp, s.xpMax = GetPetExperience() end
  if GetPetHappiness then s.happy, s.dmg = GetPetHappiness() end
  if GetPetTrainingPoints then
    local total, spent = GetPetTrainingPoints()
    if total then s.tp, s.tpTotal = (total or 0) - (spent or 0), total end
  end
  if GetPetLoyalty then s.loyalty = GetPetLoyalty() end
  return s
end

local function UpdateCard()
  if state.tab == 4 then card:Hide() return end
  card:Show()
  if not UnitExists("pet") then
    card.name:SetText("|cff9d9d9dNo pet out|r")
    card.bar:Hide()
    card.info:SetText("|cff9d9d9dSummon one to see its stats|r")
    return
  end
  local s = PetStats()
  card.name:SetText(("%s  |cffffffffLv %d %s|r"):format(UnitName("pet") or "Pet", UnitLevel("pet") or 0, ns.PetFamily() or ""))
  local parts = {}
  if s.xpMax and s.xpMax > 0 then
    card.bar:SetMinMaxValues(0, s.xpMax)
    card.bar:SetValue(s.xp or 0)
    card.bar:Show()
    parts[1] = ("|cffc8a8ff%d%% XP|r"):format(math.floor((s.xp or 0) / s.xpMax * 100))
  else
    card.bar:Hide()
  end
  local h = s.happy and HAPPY[s.happy]
  if h then parts[#parts + 1] = ("|cff%02x%02x%02x%s|r"):format(h[2] * 255, h[3] * 255, h[4] * 255, h[1]) end
  if s.tp then parts[#parts + 1] = ("%d TP"):format(s.tp) end
  card.info:SetText(table.concat(parts, "  ·  "))
end

card:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  if not UnitExists("pet") then
    GameTooltip:AddLine("No pet out", 0.6, 0.6, 0.6)
  else
    local s = PetStats()
    GameTooltip:AddLine(UnitName("pet") or "Pet", 1, 0.82, 0)
    GameTooltip:AddLine(("Level %d %s"):format(UnitLevel("pet") or 0, ns.PetFamily() or ""), 1, 1, 1)
    if s.xpMax and s.xpMax > 0 then
      GameTooltip:AddLine(("Experience: %d / %d (%d%%)"):format(s.xp or 0, s.xpMax, math.floor((s.xp or 0) / s.xpMax * 100)), 0.6, 0.75, 1)
    end
    local h = s.happy and HAPPY[s.happy]
    if h then
      GameTooltip:AddLine(("%s%s"):format(h[1], s.dmg and ("  -  %d%% damage"):format(s.dmg) or ""), h[2], h[3], h[4])
    end
    if s.loyalty then GameTooltip:AddLine(s.loyalty, 0.8, 0.8, 0.8) end
    if s.tp then GameTooltip:AddLine(("Training points: %d free of %d"):format(s.tp, s.tpTotal), 1, 1, 1) end
    if ns.Upgrades then
      local n = #ns.Upgrades()
      if n > 0 then GameTooltip:AddLine(("%d upgrade%s you can teach it"):format(n, n == 1 and "" or "s"), 0.25, 1, 0.25) end
    end
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click for My Pet", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end)
card:SetScript("OnLeave", GameTooltip_Hide)
card:SetScript("OnClick", function() SelectTab(4) end)

local petEvents = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_PET", "UNIT_PET_EXPERIENCE", "UNIT_HAPPINESS", "UNIT_LEVEL", "PET_UI_UPDATE",
  "UNIT_PET_TRAINING_POINTS" }) do
  pcall(petEvents.RegisterEvent, petEvents, e)
end
petEvents:SetScript("OnEvent", function()
  if f:IsShown() then
    UpdateCard()
    UpdatePortrait()
  end
end)

------------------------------------------------------------------------
-- Hunter rank emblem on the portrait, on every tab. Click for Milestones.
------------------------------------------------------------------------
local rankBadge = CreateFrame("Button", nil, f)
rankBadge:SetSize(26, 26)
rankBadge:SetPoint("CENTER", f, "TOPLEFT", 4, -46)
-- above the portrait and the frame's metal corner, which sit on their own child frames
do
  local level = f:GetFrameLevel()
  for _, child in ipairs({ f.PortraitContainer, f.NineSlice, f.TitleContainer }) do
    if child and child.GetFrameLevel then level = math.max(level, child:GetFrameLevel()) end
  end
  rankBadge:SetFrameLevel(level + 10)
end
rankBadge.icon = rankBadge:CreateTexture(nil, "ARTWORK")
rankBadge.icon:SetAllPoints()
rankBadge.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
rankBadge.border = rankBadge:CreateTexture(nil, "OVERLAY")
rankBadge.border:SetAtlas("spellbook-item-iconframe")
rankBadge.border:SetSize(34, 31)
rankBadge.border:SetPoint("TOPLEFT", rankBadge.icon, "TOPLEFT", -7, 1)
rankBadge.num = rankBadge:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
rankBadge.num:SetDrawLayer("OVERLAY", 3)
rankBadge.num:SetPoint("BOTTOMRIGHT", 3, -3)

rankBadge:SetScript("OnEnter", function(self)
  local J = ns.Journal
  if not J then return end
  local i, r, pts, nextRank = J.Rank()
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(("Hunter Rank %d: %s"):format(i, r.name), 1, 0.82, 0)
  GameTooltip:AddLine(("%d hunter points"):format(pts), 1, 1, 1)
  if nextRank then
    GameTooltip:AddLine(("%d more to %s"):format(nextRank.points - pts, nextRank.name), 0.8, 0.8, 0.8)
  else
    GameTooltip:AddLine("The highest rank there is.", 0.25, 1, 0.25)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Milestone seals give points. Click to see them.", 0.5, 0.5, 0.5, true)
  GameTooltip:Show()
end)
rankBadge:SetScript("OnLeave", GameTooltip_Hide)
rankBadge:SetScript("OnClick", function()
  state.trophyView = "seals"
  SelectTab(ns.TAB and ns.TAB.trophies or 6)
end)

local function UpdateRank()
  local J = ns.Journal
  if not J then return rankBadge:Hide() end
  local i = J.Rank()
  rankBadge.icon:SetTexture(J.RankIcon(i))
  rankBadge.num:SetText(i)
  rankBadge:Show()
end

------------------------------------------------------------------------
-- Page header: big title, swirl divider, small stat columns
------------------------------------------------------------------------
local header = JournalFont(f, 30, "SystemFont_Huge2")
header:SetPoint("TOPLEFT", 78, -100)

-- One line of field notes at the bottom of each page
local fieldNote = JournalFont(f, 15, "SystemFont_Med3")
fieldNote:SetPoint("BOTTOMLEFT", 72, 42)
fieldNote:SetWidth(W - 72 - 230)
fieldNote:SetWordWrap(true)

local divider = f:CreateTexture(nil, "ARTWORK")
divider:SetAtlas("spellbook-divider")
divider:SetSize(420, 11)
divider:SetPoint("TOPLEFT", 46, -140)

local stats = {}
for i = 1, 3 do
  local label = Font(f, "GameFontNormalSmall", INK_DIM)
  label:SetPoint("TOPLEFT", 330 + (i - 1) * 120, -104)
  local value = Font(f, "SystemFont_Med1")
  value:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 0, -3)
  stats[i] = { label = label, value = value }
end

local function SetStats(list)
  for i, s in ipairs(stats) do
    local d = list and list[i]
    s.label:SetText(d and d[1]:upper() or "")
    s.value:SetText(d and d[2] or "")
  end
end

------------------------------------------------------------------------
-- Content area and spellbook-style item (framed icon + name + subtitle)
------------------------------------------------------------------------
local content = CreateFrame("Frame", nil, f)
content:SetPoint("TOPLEFT", MARGIN_L, -162)
content:SetPoint("BOTTOMRIGHT", -MARGIN_R, 70)

local items = {}

local function ItemTooltip(self)
  if not self.tip then return end
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  self.tip(GameTooltip)
  GameTooltip:Show()
end

local function GetItem(i)
  if items[i] then return items[i] end
  local b = CreateFrame("Button", nil, content)
  b:SetSize(COL_W - 6, 56)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  b.plate = b:CreateTexture(nil, "BACKGROUND")
  b.plate:SetAtlas("spellbook-item-backplate")
  b.plate:SetPoint("TOPLEFT", -4, 4)
  b.plate:SetPoint("BOTTOMRIGHT", 8, -8)
  b.plate:SetAlpha(0.25)

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(ICON, ICON)
  b.icon:SetPoint("TOPLEFT", 11, -6)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAtlas("spellbook-item-iconframe")
  b.border:SetSize(52, 48)
  b.border:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -11, 1)

  b.glow = b:CreateTexture(nil, "OVERLAY", nil, 1)
  b.glow:SetAtlas("spellbook-item-iconframe-hover")
  b.glow:SetAllPoints(b.icon)
  b.glow:SetBlendMode("ADD")
  b.glow:SetAlpha(0.5)
  b.glow:Hide()

  b.badge = b:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
  b.badge:SetDrawLayer("OVERLAY", 3)
  b.badge:SetPoint("BOTTOMRIGHT", b.icon, "BOTTOMRIGHT", -1, 2)

  b.seal = b:CreateTexture(nil, "OVERLAY", nil, 4)
  b.seal:SetTexture("Interface\\RaidFrame\\ReadyCheck-Ready")
  b.seal:SetSize(18, 18)
  b.seal:SetPoint("CENTER", b.icon, "BOTTOMRIGHT", -2, 2)
  b.seal:Hide()

  b.pips = {}

  b.name = Font(b, "SystemFont_Large")
  b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 9, 1)
  b.name:SetWidth(COL_W - 72)
  b.name:SetWordWrap(true)
  if b.name.SetMaxLines then b.name:SetMaxLines(2) end

  b.sub = Font(b, "SystemFont_Med1")
  b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
  b.sub:SetWidth(COL_W - 72)
  b.sub:SetWordWrap(false)

  b:SetScript("OnEnter", function(self)
    self.glow:Show()
    ItemTooltip(self)
  end)
  b:SetScript("OnLeave", function(self)
    self.glow:SetShown(self.here and true or false)
    GameTooltip_Hide()
  end)
  b:SetScript("OnClick", function(self, button)
    if button == "RightButton" then
      if self.onRightClick then self.onRightClick() end
    elseif self.onClick then
      self.onClick()
    end
  end)
  items[i] = b
  return b
end

local function PlaceItem(b, index, top)
  local col = (index - 1) % COLS
  local row = math.floor((index - 1) / COLS)
  b:ClearAllPoints()
  b:SetPoint("TOPLEFT", content, "TOPLEFT", col * COL_W, -(top + row * ROW_STEP))
  b:Show()
end

local function FillItem(b, d)
  b.icon:SetTexture(d.icon)
  b.icon:SetDesaturated(d.dim and true or false)
  b.icon:SetAlpha(d.dim and 0.75 or 1)
  b.name:SetText(d.name)
  Ink(b.name, d.nameColor or INK)
  b.sub:SetText(d.sub or "")
  Ink(b.sub, d.subColor or INK)
  b.tip, b.onClick, b.onRightClick = d.tip, d.onClick, d.onRightClick

  b.here = d.here
  b.glow:SetShown(d.here and true or false)
  b.seal:SetShown(d.mastered and true or false)
  b.badge:SetText(d.badge or "")
  local bc = d.badgeColor or { 1, 1, 1 }
  b.badge:SetTextColor(bc[1], bc[2], bc[3])

  -- rank pips: one small box per rank, filled when learned
  local pips = d.pips or {}
  for i, st in ipairs(pips) do
    local p = b.pips[i]
    if not p then
      p = { edge = b:CreateTexture(nil, "ARTWORK", nil, 1), fill = b:CreateTexture(nil, "ARTWORK", nil, 2) }
      p.edge:SetSize(8, 8)
      p.edge:SetColorTexture(INK[1], INK[2], INK[3], 0.85)
      p.fill:SetPoint("TOPLEFT", p.edge, "TOPLEFT", 1, -1)
      p.fill:SetPoint("BOTTOMRIGHT", p.edge, "BOTTOMRIGHT", -1, 1)
      b.pips[i] = p
    end
    p.edge:ClearAllPoints()
    p.edge:SetPoint("TOPLEFT", b.sub, "BOTTOMLEFT", (i - 1) * 10, -4)
    if st == "known" then
      p.fill:SetColorTexture(0.16, 0.48, 0.10, 1)
    elseif st == "implied" then
      p.fill:SetColorTexture(0.45, 0.66, 0.36, 1)
    else
      p.fill:SetColorTexture(0.90, 0.82, 0.64, 1)
    end
    p.edge:Show()
    p.fill:Show()
  end
  for i = #pips + 1, #b.pips do
    b.pips[i].edge:Hide()
    b.pips[i].fill:Hide()
  end
end

------------------------------------------------------------------------
-- Paging (Page X/Y + spellbook arrows)
------------------------------------------------------------------------
local function Arrow(up, down, off)
  local b = CreateFrame("Button", nil, f)
  b:SetSize(32, 32)
  b:SetNormalTexture(up)
  b:SetPushedTexture(down)
  b:SetDisabledTexture(off)
  b:SetHighlightTexture(ARROW_HL, "ADD")
  return b
end

local nextBtn = Arrow(NEXT_UP, NEXT_DOWN, NEXT_OFF)
nextBtn:SetPoint("BOTTOMRIGHT", -62, 34)
local prevBtn = Arrow(PREV_UP, PREV_DOWN, PREV_OFF)
prevBtn:SetPoint("RIGHT", nextBtn, "LEFT", -2, 0)
local pageText = Font(f, "SystemFont_Med3")
pageText:SetPoint("RIGHT", prevBtn, "LEFT", -8, 0)

local function Turn(delta)
  local n = state.pages or 1
  local p = math.max(1, math.min(n, (state.page or 1) + delta))
  if p ~= state.page then
    state.page = p
    Render()
  end
end
nextBtn:SetScript("OnClick", function() Turn(1) end)
prevBtn:SetScript("OnClick", function() Turn(-1) end)
f:EnableMouseWheel(true)
f:SetScript("OnMouseWheel", function(_, delta) Turn(delta > 0 and -1 or 1) end)

-- Shows `perPage` entries of `list` on the current page, starting `top` px into the content area
local function ShowPage(list, perPage, top)
  local pages = math.max(1, math.ceil(#list / perPage))
  state.pages = pages
  state.page = math.max(1, math.min(state.page or 1, pages))
  local first = (state.page - 1) * perPage
  local shown = 0
  for i = 1, perPage do
    local d = list[first + i]
    if not d then break end
    shown = i
    local b = GetItem(i)
    FillItem(b, d)
    PlaceItem(b, i, top)
  end
  for i = shown + 1, #items do items[i]:Hide() end
  pageText:SetText(("Page %d/%d"):format(state.page, pages))
  prevBtn:SetEnabled(state.page > 1)
  nextBtn:SetEnabled(state.page < pages)
  prevBtn:Show()
  nextBtn:Show()
  pageText:Show()
end

local note = Font(content, "SystemFont_Med1")
note:SetPoint("TOPLEFT", 0, 0)
note:SetWidth(W - MARGIN_L - MARGIN_R)

------------------------------------------------------------------------
-- Ability detail widgets (icon, effect text, rank selector)
------------------------------------------------------------------------
local detail = CreateFrame("Frame", nil, content)
detail:SetPoint("TOPLEFT")
detail:SetPoint("TOPRIGHT")
detail:SetHeight(112)

detail.icon = detail:CreateTexture(nil, "ARTWORK")
detail.icon:SetSize(32, 32)
detail.icon:SetPoint("TOPLEFT", 10, -2)
detail.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
detail.border = detail:CreateTexture(nil, "OVERLAY")
detail.border:SetAtlas("spellbook-item-iconframe")
detail.border:SetSize(42, 38)
detail.border:SetPoint("TOPLEFT", detail.icon, "TOPLEFT", -9, 1)

detail.effect = Font(detail, "GameFontNormal", INK_RED)
detail.effect:SetPoint("TOPLEFT", detail.icon, "TOPRIGHT", 12, -2)
detail.effect:SetPoint("RIGHT", -8, 0)
detail.fams = Font(detail, "GameFontNormalSmall")
detail.fams:SetPoint("TOPLEFT", detail.effect, "BOTTOMLEFT", 0, -4)
detail.fams:SetPoint("RIGHT", -8, 0)
detail.fams:SetWordWrap(true)

detail.rankLabel = Font(detail, "GameFontNormalSmall", INK_DIM)
detail.rankLabel:SetPoint("TOPLEFT", 10, -58)
detail.rankLabel:SetText("RANK")
detail.info = Font(detail, "GameFontNormalSmall")
detail.info:SetPoint("TOPLEFT", 10, -84)

detail.ranks = {}
local function RankButton(i)
  local b = detail.ranks[i]
  if b then return b end
  b = CreateFrame("Button", nil, detail)
  b:SetSize(20, 20)
  b:SetPoint("TOPLEFT", 52 + (i - 1) * 23, -54)
  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.edge = b:CreateTexture(nil, "BORDER")
  b.edge:SetPoint("TOPLEFT", -1, 1)
  b.edge:SetPoint("BOTTOMRIGHT", 1, -1)
  b.edge:SetColorTexture(0.30, 0.20, 0.10, 1)
  b.bg:SetDrawLayer("ARTWORK")
  b.text = b:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  b.text:SetPoint("CENTER", 0, 0)
  b:SetHighlightTexture("Interface\\Buttons\\ButtonHilight-Square", "ADD")
  b:SetScript("OnClick", function(self)
    state.rank, state.page = self.rank, 1
    Render()
  end)
  b:SetScript("OnEnter", function(self)
    local ab, r = state.ab, self.r
    if not (ab and r) then return end
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(("%s (Rank %d)"):format(ab.name, r.rank), 1, 0.82, 0)
    GameTooltip:AddLine(r.effect, 1, 1, 1, true)
    GameTooltip:AddLine(("Pet level %d  -  %d TP"):format(r.level, r.tp), 0.8, 0.8, 0.8)
    local st = ns.Status(ab, r.rank)
    if st == "known" then
      GameTooltip:AddLine("Learned", 0.25, 1, 0.25)
    elseif st == "implied" then
      GameTooltip:AddLine("Not needed - you know a higher rank", 0.25, 0.8, 0.25)
    end
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  detail.ranks[i] = b
  return b
end

------------------------------------------------------------------------
-- Abilities: index page
------------------------------------------------------------------------
local function AbilityMatches(ab, s)
  if s == "" then return true end
  if ab.name:lower():find(s, 1, true) then return true end
  for _, r in ipairs(ab.parsed) do
    for _, t in ipairs(r.teachers) do
      if t.name:lower():find(s, 1, true) or t.zone:lower():find(s, 1, true) or t.family:lower():find(s, 1, true) then
        return true
      end
    end
  end
end

-- "My pet's family" filter, in the free space right of the header swirl
local petOnly = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
petOnly:SetSize(22, 22)
petOnly:SetPoint("TOPLEFT", 520, -134)
do
  local fs = petOnly.text or petOnly.Text
  if not fs then
    fs = petOnly:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("LEFT", petOnly, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontNormalSmall")
  fs:SetShadowOffset(0, 0)
  Ink(fs, INK)
  fs:SetText("My pet's family only")
end
petOnly:SetScript("OnClick", function(self)
  ns.db.opts.petOnly = self:GetChecked() and true or false
  state.page = 1
  ns.Refresh()
end)
petOnly:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine("My pet's family only", 1, 0.82, 0)
  GameTooltip:AddLine("Only abilities your current pet's family can use.", 1, 1, 1, true)
  GameTooltip:Show()
end)
petOnly:SetScript("OnLeave", GameTooltip_Hide)
petOnly:Hide()

local function FirstMissingRank(ab)
  for _, r in ipairs(ab.parsed) do
    if not ns.Status(ab, r.rank) then return r.rank end
  end
  return ab.parsed[1] and ab.parsed[1].rank or 1
end

local function RenderAbilities()
  SetTitle("Beast Training Tracker - Abilities")
  header:SetText("Abilities")
  local known, total = ns.Counts()
  local zone, fam = ns.CurrentZone(), ns.PetFamily()
  petOnly:SetChecked(ns.db.opts.petOnly and true or false)
  petOnly:Show()
  local started, list, tameHere = 0, {}, 0
  for _, ab in ipairs(ns.abilities) do
    local have, pips, hereNew = 0, {}, false
    for i, r in ipairs(ab.parsed) do
      local st = ns.Status(ab, r.rank)
      pips[i] = st
      if st then
        have = have + 1
      elseif ab.src == "beast" then
        for _, t in ipairs(r.teachers) do
          if ns.InZone(t, zone) and ns.CanTame(t) then
            hereNew = true
            tameHere = tameHere + 1
            break
          end
        end
      end
    end
    if have > 0 then started = started + 1 end
    if AbilityMatches(ab, state.search) and not (ns.db.opts.petOnly and not ns.AbilityFitsPet(ab, fam)) then
      local n = #ab.parsed
      local sub
      if have == n then
        sub = n == 1 and "Learned" or ("All %d ranks"):format(n)
      elseif have > 0 then
        sub = ("Rank %d of %d"):format(ns.BestKnown(ab), n)
      elseif ab.src == "trainer" then
        sub = "Pet Trainer"
      else
        sub = "Not learned yet"
      end
      list[#list + 1] = {
        icon = ab.icon, name = ab.name, sub = sub, dim = have == 0,
        subColor = have == n and INK_GOOD or INK,
        pips = n > 1 and pips or nil, mastered = have == n, here = hereNew,
        onClick = function()
          state.ab, state.rank, state.abPage, state.page = ab, FirstMissingRank(ab), state.page, 1
          Render()
        end,
        tip = function(tt)
          tt:AddLine(ab.name, 1, 0.82, 0)
          tt:AddLine(ab.isAll and "All pet families" or ab.famText, 1, 1, 1, true)
          tt:AddLine(ab.src == "trainer" and "Bought from a Pet Trainer" or "Learned by taming a beast that has it", 0.6, 0.8, 1)
          tt:AddLine(("%d of %d ranks learned"):format(have, n), 0.8, 0.8, 0.8)
          if hereNew then tt:AddLine("A beast in this zone teaches a rank you're missing", 0.25, 1, 0.25, true) end
          tt:AddLine(" ")
          tt:AddLine("Click to see its ranks and which beasts teach them", 0.5, 0.5, 0.5)
        end,
      }
    end
  end
  SetStats({
    { "Ranks", ("%d%%  %d / %d"):format(total > 0 and math.floor(known / total * 100 + 0.5) or 0, known, total) },
    { "Abilities", ("%d / %d"):format(started, #ns.abilities) },
  })
  note:SetText(#list == 0 and "Nothing matches your search." or "")
  local where = zone ~= "" and zone or "this zone"
  if tameHere > 0 then
    fieldNote:SetText(("%s: %d rank%s you're missing can be tamed here. Look for the glowing icons."):format(
      where, tameHere, tameHere == 1 and "" or "s"))
  else
    fieldNote:SetText(("%s: nothing new to tame here."):format(where))
  end
  ShowPage(list, COLS * 6, 0)
end

------------------------------------------------------------------------
-- Abilities: one ability (ranks + the beasts that teach the chosen rank)
------------------------------------------------------------------------
local function RenderAbility()
  local ab = state.ab
  SetTitle("Beast Training Tracker - " .. ab.name)
  header:SetText(ab.name)
  backFn = function()
    state.ab, state.page = nil, state.abPage or 1
    Render()
  end
  local have = 0
  for _, r in ipairs(ab.parsed) do
    if ns.Status(ab, r.rank) then have = have + 1 end
  end
  SetStats({ { "Learned", ("%d / %d"):format(have, #ab.parsed) } })

  local r
  for _, pr in ipairs(ab.parsed) do
    if pr.rank == state.rank then r = pr end
  end
  r = r or ab.parsed[1]
  state.rank = r.rank

  detail:Show()
  detail.icon:SetTexture(ab.icon)
  detail.effect:SetText(r.effect)
  detail.fams:SetText("Learned by: " .. (ab.isAll and "all pet families" or ab.famText))

  for i, pr in ipairs(ab.parsed) do
    local b = RankButton(i)
    b.rank, b.r = pr.rank, pr
    b.text:SetText(pr.rank)
    local st = ns.Status(ab, pr.rank)
    if pr.rank == r.rank then
      b.bg:SetColorTexture(0.93, 0.74, 0.20, 1)
      b.text:SetTextColor(0.18, 0.10, 0.04)
    elseif st then
      b.bg:SetColorTexture(0.16, 0.36, 0.10, 1)
      b.text:SetTextColor(0.85, 1, 0.75)
    else
      b.bg:SetColorTexture(0.24, 0.16, 0.09, 1)
      b.text:SetTextColor(1, 0.88, 0.70)
    end
    b:Show()
  end
  for i = #ab.parsed + 1, #detail.ranks do detail.ranks[i]:Hide() end

  local zone = ns.CurrentZone()
  local st = ns.Status(ab, r.rank)
  local stText = st == "known" and "  ·  |cff146b0aLearned|r" or (st == "implied" and "  ·  |cff146b0aCovered by a higher rank|r" or "")

  if ab.src == "trainer" then
    detail.info:SetText(("Rank %d  ·  pet level %d  ·  %d TP%s"):format(r.rank, r.level, r.tp, stText))
    note:SetText("\n\n\n\n\n\n\n\nBought from any Pet Trainer in a major city.")
    fieldNote:SetText("Pet Trainers sell this one. No taming needed.")
    ShowPage({}, COLS * 4, 118)
    return
  end

  local teachers = {}
  for _, t in ipairs(r.teachers) do teachers[#teachers + 1] = t end
  table.sort(teachers, function(a, b)
    local ah, bh = ns.InZone(a, zone), ns.InZone(b, zone)
    if ah ~= bh then return ah end
    if a.minLevel ~= b.minLevel then return a.minLevel < b.minLevel end
    return a.name < b.name
  end)
  detail.info:SetText(("Rank %d  ·  pet level %d  ·  %d TP  ·  %d beast%s teach it%s"):format(
    r.rank, r.level, r.tp, #teachers, #teachers == 1 and "" or "s", stText))

  local list = {}
  for _, t in ipairs(teachers) do
    local here, tame = ns.InZone(t, zone), ns.CanTame(t)
    list[#list + 1] = {
      icon = ns.RS and ns.RS.FamilyIcon(t.family) or ab.icon,
      name = t.name,
      sub = t.zone,
      dim = not tame,
      here = here and tame,
      badge = tostring(t.minLevel),
      badgeColor = tame and { 1, 1, 1 } or { 1, 0.35, 0.25 },
      subColor = here and INK_GOOD or INK,
      onClick = function()
        if IsShiftKeyDown() then
          local many = {}
          for i2, t2 in ipairs(teachers) do
            if i2 > 12 then break end
            many[#many + 1] = { t = t2, label = Geo.Label(ab, r, t2) }
          end
          Geo.WaypointMany(many)
        else
          Geo.Waypoint(t, Geo.Label(ab, r, t))
        end
      end,
      tip = function(tt)
        tt:AddLine(t.name .. Geo.Tag(t.name), 1, 0.82, 0)
        tt:AddLine(("Level %s %s"):format(t.level, t.family), 1, 1, 1)
        tt:AddLine(t.zone, here and 0.25 or 0.8, here and 1 or 0.8, here and 0.25 or 0.8)
        if not tame then tt:AddLine(("You can tame it at level %d"):format(t.minLevel), 1, 0.56, 0.25) end
        tt:AddLine(" ")
        tt:AddLine("Click: waypoint  ·  Shift-click: waypoints to all", 0.5, 0.5, 0.5)
      end,
    }
  end
  note:SetText(#list == 0 and "\n\n\n\n\n\n\n\nNo known beast teaches this rank." or "")
  fieldNote:SetText("The number on each beast is its level. Glowing beasts live in your zone.")
  ShowPage(list, COLS * 4, 118)
end

------------------------------------------------------------------------
-- Tab registry: tabs 2-6 each live in their own file and register here
------------------------------------------------------------------------
local tabDefs = {}

local function ClearPage()
  for _, b in ipairs(items) do b:Hide() end
  prevBtn:Hide()
  nextBtn:Hide()
  pageText:Hide()
  note:SetText("")
  fieldNote:SetText("")
  SetStats(nil)
  detail:Hide()
  petOnly:Hide()
  backFn = nil
end

Render = function()
  if not (f:IsShown() and ns.db) then return end
  UpdatePortrait()
  UpdateRank()
  -- tabs that don't apply (Skinning for non-skinners) are hidden and the rest close up
  local x = 60
  for i, b in ipairs(tabButtons) do
    local t = TABS[i]
    local shown = not t.visible or t.visible()
    if not shown and state.tab == i then state.tab, state.page = 1, 1 end
    b:SetShown(shown)
    if shown then
      b:ClearAllPoints()
      b:SetPoint("TOPLEFT", x, -44)
      x = x + 44
    end
  end
  card:ClearAllPoints()
  card:SetPoint("TOPLEFT", x + 7, -46)
  UpdateCard()
  ClearPage()
  for i, b in ipairs(tabButtons) do b.glow:SetShown(i == state.tab) end
  for i, def in pairs(tabDefs) do def.page:SetShown(i == state.tab) end
  local def = tabDefs[state.tab]
  search:SetShown(state.tab == 1 or (def ~= nil and def.search == true))
  local t = TABS[state.tab]
  SetTitle("Beast Training Tracker - " .. t.name)
  header:SetText(t.name)
  if state.tab == 1 then
    if state.ab then RenderAbility() else RenderAbilities() end
  elseif def then
    -- a broken tab reports to BugSack instead of breaking the whole book
    xpcall(function() def.render(def.page) end, geterrorhandler())
  else
    note:SetText("This page hasn't moved into the new book yet.")
  end
  back:SetShown(backFn ~= nil)
end

------------------------------------------------------------------------
-- API for the tab files (BookHunt.lua, BookRares.lua, BookPet.lua, ...)
------------------------------------------------------------------------
-- Paging for tabs that lay out their own widgets: returns the current page
local function SetPager(pages)
  state.pages = math.max(1, pages or 1)
  state.page = math.max(1, math.min(state.page or 1, state.pages))
  pageText:SetText(("Page %d/%d"):format(state.page, state.pages))
  prevBtn:SetEnabled(state.page > 1)
  nextBtn:SetEnabled(state.page < state.pages)
  prevBtn:Show()
  nextBtn:Show()
  pageText:Show()
  return state.page
end

ns.Book = {
  frame = f, content = content, state = state,
  W = W, H = H, COLS = COLS, COL_W = COL_W, ROW_STEP = ROW_STEP,
  INK = INK, INK_DIM = INK_DIM, INK_GOOD = INK_GOOD, INK_RED = INK_RED,
  Font = Font, JournalFont = JournalFont, Ink = Ink,
  SetTitle = SetTitle,
  SetHeader = function(text) header:SetText(text or "") end,
  SetStats = SetStats,
  SetNote = function(text) note:SetText(text or "") end,
  SetFieldNote = function(text) fieldNote:SetText(text or "") end,
  SetBack = function(fn) backFn = fn end,
  ShowPage = ShowPage,
  SetPager = SetPager,
  SelectTab = SelectTab,
  Render = function() Render() end,
}

-- def = { render = function(page) end, search = true|nil }
-- `page` is a frame covering the content area, shown only while this tab is open.
function ns.Book.RegisterTab(index, def)
  def.page = CreateFrame("Frame", nil, content)
  def.page:SetAllPoints(content)
  def.page:Hide()
  tabDefs[index] = def
  return def.page
end

function ns.Book.Open(tab)
  if not ns.isHunter then return end
  if tab then state.tab, state.ab, state.page = tab, nil, 1 end
  if f:IsShown() then Render() else f:Show() end
end

f:SetScript("OnShow", function(self)
  local pos = ns.db and ns.db.bookPos
  if pos then
    self:ClearAllPoints()
    self:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  end
  Render()
end)

ns.OnRefresh(function() if f:IsShown() then Render() end end)

function ns.ToggleBook()
  if not ns.isHunter then return end
  f:SetShown(not f:IsShown())
end
