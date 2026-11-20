local _, ns = ...

local abilities = ns.abilities
local Geo = ns.Geo
local Say = ns.Say

-- Phase 1: Use UITheme for window constraints
local MIN_WIDTH, MAX_WIDTH = ns.UITheme.window.minWidth, ns.UITheme.window.maxWidth
local MIN_HEIGHT, MAX_HEIGHT = ns.UITheme.window.minHeight, ns.UITheme.window.maxHeight
local DEFAULT_WIDTH, DEFAULT_HEIGHT = ns.UITheme.window.defaultWidth, ns.UITheme.window.defaultHeight

local GREEN, GOLD = "|cff40ff40", "|cffffd100"
local HEAD_H, ROW_H = 26, 18
local TAB_HEIGHT = 60

local function C(r, g, b, a, tex) tex:SetColorTexture(r, g, b, a) return tex end

------------------------------------------------------------------------
-- Main frame: Resizable with Phase 1 parchment background
------------------------------------------------------------------------
local f = CreateFrame("Frame", "BeastTrainingTrackerFrame", UIParent, "BasicFrameTemplateWithInset")
f:SetSize(DEFAULT_WIDTH, DEFAULT_HEIGHT)
f:SetPoint("CENTER")
f:SetFrameStrata("HIGH")
f:SetMovable(true)
f:EnableMouse(true)
f:SetClampedToScreen(true)
f:RegisterForDrag("LeftButton")
f:SetResizable(true)
f:Hide()
tinsert(UISpecialFrames, "BeastTrainingTrackerFrame")

-- Parchment background from UITheme
local parchmentBg = f:CreateTexture(nil, "BACKGROUND")
parchmentBg:SetAllPoints()
parchmentBg:SetColorTexture(ns.UITheme.colors.parchment.r, ns.UITheme.colors.parchment.g, ns.UITheme.colors.parchment.b)

-- Title
local title = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
title:SetPoint("TOPLEFT", 16, -12)
title:SetText("|cffabd473Beast Training Tracker|r")

-- Resize handle (bottom-right corner)
local resizer = CreateFrame("Button", nil, f)
resizer:SetSize(16, 16)
resizer:SetPoint("BOTTOMRIGHT", -2, 2)
resizer:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIM-ResizeGrabber-Down")
resizer:SetHighlightTexture("Interface\\ChatFrame\\UI-ChatIM-ResizeGrabber-Highlight")
resizer:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIM-ResizeGrabber-Down")
resizer:SetScript("OnMouseDown", function(self, button)
  if button == "LeftButton" then
    f:StartSizing("BOTTOMRIGHT")
  end
end)
resizer:SetScript("OnMouseUp", function()
  f:StopMovingOrSizing()
  local w, h = f:GetSize()
  -- Clamp to min/max
  w = math.max(MIN_WIDTH, math.min(MAX_WIDTH, w))
  h = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, h))
  f:SetSize(w, h)
  -- Save to db
  if ns.db then
    local p, _, rp, x, y = f:GetPoint()
    ns.db.pos = { p, rp, x, y }
    ns.db.frameSize = { w, h }
  end
end)

------------------------------------------------------------------------
-- Icon tabs (60px height at top)
------------------------------------------------------------------------
local TAB_NAMES = { "Abilities", "Hunt Planner", "Special Pets", "My Pet", "Settings", "Backup" }
local TAB_ICONS = {
  "Interface\\Icons\\Ability_Hunter_BeastTraining",
  "Interface\\Icons\\Spell_Nature_HuntsmansMark",
  "Interface\\Icons\\Ability_Hunter_CmonCat",
  "Interface\\Icons\\Ability_Paladin_HolyLight",
  "Interface\\Icons\\Inv_Weapon_Hand_15",
  "Interface\\Icons\\Inv_Misc_SummonPouch"
}

ns.TAB = { abilities = 1, hunt = 2, rares = 3, pet = 4, map = 5, backup = 6 }
local tabs, panels = {}, {}

local tabContainer = CreateFrame("Frame", nil, f)
tabContainer:SetPoint("TOPLEFT", 0, -32)
tabContainer:SetPoint("TOPRIGHT", 0, -32)
tabContainer:SetHeight(TAB_HEIGHT)

-- Tab background
local tabBg = tabContainer:CreateTexture(nil, "BACKGROUND")
tabBg:SetAllPoints(tabContainer)
tabBg:SetColorTexture(ns.UITheme.colors.parchmentDark.r, ns.UITheme.colors.parchmentDark.g, ns.UITheme.colors.parchmentDark.b)

local tabDivider = C(0.67, 0.83, 0.45, 0.25, tabContainer:CreateTexture(nil, "ARTWORK"))
tabDivider:SetHeight(1)
tabDivider:SetPoint("BOTTOMLEFT")
tabDivider:SetPoint("BOTTOMRIGHT")

local function StyleTab(b, sel)
  if sel then
    b.bg:SetColorTexture(ns.UITheme.colors.highlight.r, ns.UITheme.colors.highlight.g, ns.UITheme.colors.highlight.b, 0.22)
    b.accent:Show()
  else
    b.bg:SetColorTexture(0, 0, 0, 0.35)
    b.accent:Hide()
  end
end

for i, name in ipairs(TAB_NAMES) do
  local b = CreateFrame("Button", nil, tabContainer)
  b:SetSize(56, TAB_HEIGHT - 4)
  b:SetPoint("TOPLEFT", 8 + (i - 1) * 62, -2)

  b.bg = b:CreateTexture(nil, "BACKGROUND")
  b.bg:SetAllPoints()
  b.accent = C(ns.UITheme.colors.highlight.r, ns.UITheme.colors.highlight.g, ns.UITheme.colors.highlight.b, 0.9, b:CreateTexture(nil, "ARTWORK"))
  b.accent:SetHeight(2)
  b.accent:SetPoint("BOTTOMLEFT")
  b.accent:SetPoint("BOTTOMRIGHT")

  local icon = b:CreateTexture(nil, "ARTWORK")
  icon:SetSize(40, 40)
  icon:SetPoint("CENTER")
  icon:SetTexture(TAB_ICONS[i])
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  local hl = b:CreateTexture(nil, "HIGHLIGHT")
  hl:SetAllPoints()
  hl:SetColorTexture(1, 1, 1, 0.06)

  b:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
    GameTooltip:AddLine(name, 1, 0.82, 0)
    GameTooltip:Show()
  end)
  b:SetScript("OnLeave", GameTooltip_Hide)
  b:SetScript("OnClick", function() ns.ShowTab(i) end)

  tabs[i] = b

  -- Create panel for this tab
  local p = CreateFrame("Frame", nil, f)
  p:SetPoint("TOPLEFT", 8, -98)
  p:SetPoint("BOTTOMRIGHT", -8, 8)
  p:Hide()
  panels[i] = p
end

------------------------------------------------------------------------
-- Pet info bar (under tabs, above content)
------------------------------------------------------------------------
local petContainer = CreateFrame("Frame", nil, f)
petContainer:SetPoint("TOPLEFT", 8, -98)
petContainer:SetPoint("TOPRIGHT", -8, -98)
petContainer:SetHeight(32)

local bigIcon = petContainer:CreateTexture(nil, "ARTWORK")
bigIcon:SetSize(24, 24)
bigIcon:SetPoint("TOPLEFT", 0, 0)
bigIcon:SetTexture("Interface\\Icons\\Ability_Hunter_BeastTraining")
bigIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

local petText = petContainer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
petText:SetPoint("TOPLEFT", bigIcon, "TOPRIGHT", 10, -2)
petText:SetJustifyH("LEFT")

local zoneText = petContainer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
zoneText:SetPoint("TOPLEFT", petText, "BOTTOMLEFT", 0, -4)
zoneText:SetJustifyH("LEFT")

local bar = CreateFrame("StatusBar", nil, petContainer)
bar:SetSize(200, 16)
bar:SetPoint("TOPRIGHT", -120, 2)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.67, 0.83, 0.45)
bar:SetMinMaxValues(0, 1)
C(0, 0, 0, 0.55, bar:CreateTexture(nil, "BACKGROUND")):SetAllPoints()
local barBorder = CreateFrame("Frame", nil, bar, BackdropTemplateMixin and "BackdropTemplate" or nil)
barBorder:SetPoint("TOPLEFT", -3, 3)
barBorder:SetPoint("BOTTOMRIGHT", 3, -3)
if barBorder.SetBackdrop then
  barBorder:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10 })
  barBorder:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
end
local barText = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
barText:SetPoint("CENTER")

local syncText = petContainer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
syncText:SetPoint("TOPRIGHT", bar, "BOTTOMRIGHT", 0, -4)
syncText:SetJustifyH("RIGHT")

-- Optional addon indicators
local addonStrip = CreateFrame("Button", nil, petContainer)
addonStrip:SetHeight(14)
addonStrip:SetPoint("TOPLEFT", zoneText, "BOTTOMLEFT", 0, -4)
addonStrip.text = addonStrip:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
addonStrip.text:SetPoint("LEFT")
addonStrip:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOMLEFT")
  GameTooltip:AddLine("Optional addons", 1, 0.82, 0)
  GameTooltip:AddLine("Beast Training Tracker works on its own. These add extras:", 0.8, 0.8, 0.8, true)
  GameTooltip:AddLine(" ")
  for _, a in ipairs(ns.Geo.AddonStatus()) do
    GameTooltip:AddLine((a.on and "|cff40ff40" or "|cff9d9d9d") .. a.name .. "|r", 1, 1, 1)
    GameTooltip:AddLine(a.text, 0.75, 0.75, 0.75, true)
  end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click for Settings", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end)
addonStrip:SetScript("OnLeave", GameTooltip_Hide)
addonStrip:SetScript("OnClick", function() if ns.ShowTab then ns.ShowTab(ns.TAB.map) end end)

local function UpdateAddonStrip()
  local parts = {}
  for _, a in ipairs(ns.Geo.AddonStatus()) do
    parts[#parts + 1] = ("|TInterface\\COMMON\\Indicator-%s:12:12|t%s%s|r"):format(a.on and "Green" or "Gray",
      a.on and "|cff40ff40" or "|cff9d9d9d", a.name)
  end
  addonStrip.text:SetText(table.concat(parts, "   "))
  addonStrip:SetWidth(addonStrip.text:GetStringWidth() + 4)
end

------------------------------------------------------------------------
-- "Beast Training" button (secure: casts the spell that opens the window)
------------------------------------------------------------------------
local BT_SPELL = (GetSpellInfo and GetSpellInfo(5149))
  or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(5149)) or "Beast Training"

local teach = CreateFrame("Button", "BeastTrainingTrackerTeachButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
teach:SetSize(124, 24)
teach:SetText("Beast Training")
teach:SetFrameStrata("DIALOG")
teach:SetAttribute("type", "spell")
teach:SetAttribute("spell", BT_SPELL)
teach:RegisterForClicks((GetCVarBool and GetCVarBool("ActionButtonUseKeyDown")) and "AnyDown" or "AnyUp")
teach:Hide()
teach:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:AddLine("Open Beast Training", 1, 0.82, 0)
  GameTooltip:AddLine("Teach your pet the ranks you've learned. The tracker syncs every time it opens.", 1, 1, 1, true)
  GameTooltip:Show()
end)
teach:SetScript("OnLeave", GameTooltip_Hide)

-- Clear the hunt route / waypoints
local clearRoute = CreateFrame("Button", nil, petContainer, "UIPanelButtonTemplate")
clearRoute:SetSize(120, 20)
clearRoute:SetPoint("TOPRIGHT", -4, 2)
clearRoute:SetText("Clear waypoints")
clearRoute:SetScript("OnClick", function() ns.Geo.ClearWaypoints() end)
clearRoute:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  local n = #ns.Geo.route
  GameTooltip:AddLine("Clear waypoints", 1, 0.82, 0)
  GameTooltip:AddLine(n > 0 and ("Removes the %d-stop hunt route and its waypoints."):format(n)
    or "No waypoints set. Click beasts in any tab to build a hunt route.", 1, 1, 1, true)
  GameTooltip:Show()
end)
clearRoute:SetScript("OnLeave", GameTooltip_Hide)

local function PlaceTeach()
  if InCombatLockdown() then return end
  if f:IsShown() and f:GetRight() then
    teach:SetScale(f:GetEffectiveScale() / UIParent:GetEffectiveScale())
    teach:ClearAllPoints()
    teach:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", f:GetRight() - 16, f:GetTop() - 60)
    teach:SetFrameLevel(f:GetFrameLevel() + 20)
    teach:Show()
  else
    teach:Hide()
  end
end

local tev = CreateFrame("Frame")
tev:RegisterEvent("PLAYER_REGEN_DISABLED")
tev:RegisterEvent("PLAYER_REGEN_ENABLED")
tev:SetScript("OnEvent", function(_, e)
  if e == "PLAYER_REGEN_DISABLED" then teach:Hide() else PlaceTeach() end
end)

f:SetScript("OnDragStart", function(self)
  self:StartMoving()
  self:SetScript("OnUpdate", PlaceTeach)
end)
f:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  self:SetScript("OnUpdate", nil)
  local p, _, rp, x, y = self:GetPoint()
  ns.db.pos = { p, rp, x, y }
  PlaceTeach()
end)

------------------------------------------------------------------------
-- Shared widgets
------------------------------------------------------------------------
local allChecks = {}

local function Check(parent, label, key, x, y, tip, onChange)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("TOPLEFT", x, y)
  local fs = cb.text or cb.Text
  if not fs then
    fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontHighlightSmall")
  fs:SetText(label)
  cb:SetScript("OnClick", function(self)
    ns.db.opts[key] = self:GetChecked() and true or false
    if onChange then onChange(ns.db.opts[key]) end
    ns.Refresh()
  end)
  if tip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(label, 1, 0.82, 0)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
  end
  cb.key = key
  allChecks[#allChecks + 1] = cb
  return cb
end

local function Button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function Text(parent, font, x, y, text)
  local fs = parent:CreateFontString(nil, "OVERLAY", font or "GameFontHighlightSmall")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetJustifyH("LEFT")
  if text then fs:SetText(text) end
  return fs
end

local function Divider(parent, y)
  local t = C(0.67, 0.83, 0.45, 0.25, parent:CreateTexture(nil, "ARTWORK"))
  t:SetHeight(1)
  t:SetPoint("TOPLEFT", 4, y)
  t:SetPoint("TOPRIGHT", -4, y)
  return t
end

local function Scroll(parent, top, bottom)
  local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
  scroll:SetPoint("TOPLEFT", 2, top)
  scroll:SetPoint("BOTTOMRIGHT", -26, bottom)
  local child = CreateFrame("Frame", nil, scroll)
  child:SetSize(400, 1)
  scroll:SetScrollChild(child)
  return scroll, child
end

-- Generic list for Hunt / Pet tabs
local function MakeList(parent, top, bottom)
  local L = { rows = {} }
  L.scroll, L.child = Scroll(parent, top, bottom)
  L.empty = L.child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  L.empty:SetPoint("TOP", 0, -40)
  return L
end

local function ListRow(L, i)
  local row = L.rows[i]
  if row then return row end
  row = CreateFrame("Button", nil, L.child)
  row.hl = row:CreateTexture(nil, "HIGHLIGHT")
  row.hl:SetAllPoints()
  row.hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
  row.hl:SetBlendMode("ADD")
  row.bg = row:CreateTexture(nil, "BACKGROUND")
  row.bg:SetAllPoints()
  row.line = C(0.85, 0.65, 0.15, 0.35, row:CreateTexture(nil, "BORDER"))
  row.line:SetHeight(1)
  row.line:SetPoint("BOTTOMLEFT")
  row.line:SetPoint("BOTTOMRIGHT")
  row.icon = row:CreateTexture(nil, "ARTWORK")
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  row.box = row:CreateTexture(nil, "ARTWORK")
  row.box:SetSize(16, 16)
  row.box:SetTexture("Interface\\Buttons\\UI-CheckBox-Up")
  row.chk = row:CreateTexture(nil, "OVERLAY")
  row.chk:SetAllPoints(row.box)
  row.chk:SetTexture("Interface\\Buttons\\UI-CheckBox-Check")
  row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  row.left = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.left:SetJustifyH("LEFT")
  row.left:SetWordWrap(false)
  row.right = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  row.right:SetJustifyH("RIGHT")
  row.right:SetWordWrap(false)
  row.btn = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
  row.btn:SetSize(90, 20)
  row.btn:SetPoint("RIGHT", -6, 0)
  row:SetScript("OnEnter", function(self)
    local it = self.item
    if it and it.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      it.tip(GameTooltip)
      GameTooltip:Show()
    end
  end)
  row:SetScript("OnLeave", GameTooltip_Hide)
  row:SetScript("OnClick", function(self, button)
    local it = self.item
    if not it then return end
    if button == "RightButton" then
      if it.onRightClick then it.onRightClick() end
    elseif it.onClick then
      it.onClick()
    end
    if GameTooltip:GetOwner() == self and self.item and self.item.tip then
      GameTooltip:ClearLines()
      self.item.tip(GameTooltip)
      GameTooltip:Show()
    end
  end)
  row.btn:SetScript("OnClick", function(self)
    local it = self:GetParent().item
    if it and it.button then it.button.onClick() end
  end)
  L.rows[i] = row
  return row
end

local function ListSet(L, items, emptyMsg)
  local y = 0
  for i, it in ipairs(items) do
    local row = ListRow(L, i)
    row.item = it
    local head = it.kind == "head"
    local h = head and HEAD_H or 20
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", L.child, "TOPLEFT", 0, -y)
    row:SetPoint("RIGHT", L.child, "RIGHT")
    row:SetHeight(h)
    y = y + h
    if head then
      row.bg:SetColorTexture(0.45, 0.33, 0.05, 0.28)
    elseif it.kind == "note" then
      row.bg:SetColorTexture(0, 0, 0, 0)
    else
      row.bg:SetColorTexture(1, 1, 1, (i % 2 == 0) and 0.04 or 0)
    end
    row.line:SetShown(head)
    row.hl:SetShown(it.onClick ~= nil or it.onRightClick ~= nil or it.tip ~= nil)
    row.left:SetFontObject(head and "GameFontNormal" or (it.kind == "note" and "GameFontDisableSmall" or "GameFontHighlightSmall"))
    local x = it.indent or 8
    if it.check ~= nil then
      row.box:ClearAllPoints()
      row.box:SetPoint("LEFT", x, 0)
      row.box:Show()
      row.chk:SetShown(it.check and true or false)
      x = x + 22
    else
      row.box:Hide()
      row.chk:Hide()
    end
    if it.icon then
      local s = head and 20 or 16
      row.icon:SetSize(s, s)
      row.icon:ClearAllPoints()
      row.icon:SetPoint("LEFT", x, 0)
      row.icon:SetTexture(it.icon)
      row.icon:Show()
      x = x + s + 8
    else
      row.icon:Hide()
    end
    row.btn:SetShown(it.button ~= nil)
    if it.button then row.btn:SetText(it.button.text) end
    row.right:ClearAllPoints()
    if it.button then row.right:SetPoint("RIGHT", row.btn, "LEFT", -8, 0) else row.right:SetPoint("RIGHT", -8, 0) end
    row.right:SetText(it.right or "")
    row.left:ClearAllPoints()
    row.left:SetPoint("LEFT", x, 0)
    row.left:SetPoint("RIGHT", row.right, "LEFT", -8, 0)
    row.left:SetText(it.left or "")
    -- optional fixed columns
    row.cols = row.cols or {}
    local cols = it.cols or {}
    for ci, c in ipairs(cols) do
      local fs = row.cols[ci]
      if not fs then
        fs = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        fs:SetJustifyH("LEFT")
        fs:SetWordWrap(false)
        row.cols[ci] = fs
      end
      fs:ClearAllPoints()
      fs:SetPoint("LEFT", c.x, 0)
      fs:SetWidth(c.w)
      fs:SetText(c.text or "")
      fs:Show()
    end
    for ci = #cols + 1, #row.cols do row.cols[ci]:Hide() end
    row:Show()
  end
  for i = #items + 1, #L.rows do L.rows[i]:Hide(); L.rows[i].item = nil end
  L.empty:SetText(emptyMsg or "")
  L.empty:SetShown(#items == 0)
  L.child:SetHeight(math.max(1, y))
end

------------------------------------------------------------------------
-- Tab display logic
------------------------------------------------------------------------
local function CurrentTab() return (ns.db and ns.db.tab) or 1 end

local function RefreshAll()
  if not ns.db or not f:IsShown() then return end
  for _, cb in ipairs(allChecks) do cb:SetChecked(ns.db.opts[cb.key]) end

  local fam, zone = ns.PetFamily(), ns.CurrentZone()
  if fam then
    petText:SetText(("%s  |cffffffffLevel %d|r"):format(UnitName("pet") or fam, UnitLevel("pet") or 0))
    zoneText:SetText(("|cff9d9d9d%s|r  ·  %s"):format(fam, zone ~= "" and zone or "?"))
  else
    petText:SetText("|cff9d9d9dNo pet out|r")
    zoneText:SetText(zone)
  end
  local known, total = ns.Counts()
  bar:SetValue(total > 0 and known / total or 0)
  barText:SetText(("%d / %d ranks learned  (%d%%)"):format(known, total, total > 0 and math.floor(known / total * 100 + 0.5) or 0))
  UpdateAddonStrip()
  clearRoute:SetEnabled(#ns.Geo.route > 0)
  syncText:SetText(ns.db.lastSync and ("Last Beast Training sync: " .. date("%b %d, %H:%M", ns.db.lastSync))
    or "Open Beast Training once to sync what you've learned")

  local p = panels[CurrentTab()]
  if p and p.Refresh then p.Refresh() end
end

function ns.ShowTab(i)
  if not ns.db or not ns.isHunter then return end
  ns.db.tab = i
  for k, b in ipairs(tabs) do
    StyleTab(b, k == i)
    panels[k]:SetShown(k == i)
  end
  if not f:IsShown() then f:Show() else RefreshAll() end
end

function ns.ToggleMain()
  if not ns.isHunter then return end
  f:SetShown(not f:IsShown())
end

f:SetScript("OnShow", function()
  ns.ShowTab(CurrentTab())
  RefreshAll()
  PlaceTeach()
end)
f:SetScript("OnHide", PlaceTeach)

ns.OnRefresh(RefreshAll)

-- keep RareScanner respawn timers ticking while the window is open
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(30, function() if f:IsShown() then RefreshAll() end end)
end

------------------------------------------------------------------------
-- Tab 1: Abilities - Phase 2: Icon Grid with Collapsible Sections
------------------------------------------------------------------------
do
  local p = panels[1]

  -- Filter checkboxes (top of tab)
  Check(p, "My pet's family", "petOnly", 4, -2, "Only abilities your current pet's family can use.")
  Check(p, "Hide learned", "hideKnown", 142, -2, "Hide ranks you've learned (or outgrown by learning a higher rank).")
  Check(p, "Hide trainer skills", "hideTrainer", 262, -2, "Hide abilities bought from a Pet Trainer (Growl, resistances...).")
  Check(p, "Hide above pet level", "hideHigh", 414, -2, "Hide ranks your pet isn't high enough level to use yet (orange pet lvl).")
  Check(p, "Tameable in this zone", "zoneOnly", 570, -2, "Only ranks taught by a beast in the zone you're in.")

  -- Search box
  local searchLabel = Text(p, "GameFontNormalSmall", 10, -36, "Search")
  local search = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
  search:SetSize(200, 20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
  search:SetAutoFocus(false)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  search:SetScript("OnTextChanged", function(self)
    ns.search = (self:GetText() or ""):lower():match("^%s*(.-)%s*$")
    p.Refresh()
  end)
  local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", search, "RIGHT", 10, 0)
  hint:SetText("ability, beast or zone")

  -- Collapse/Expand All buttons
  local collapseAll = Button(p, "Collapse all", 96, function()
    for _, ab in ipairs(abilities) do ns.db.collapsed[ab.name] = true end
    p.Refresh()
  end)
  collapseAll:SetPoint("TOPRIGHT", -4, -34)
  local expandAll = Button(p, "Expand all", 90, function()
    wipe(ns.db.collapsed)
    p.Refresh()
  end)
  expandAll:SetPoint("RIGHT", collapseAll, "LEFT", -4, 0)

  -- Scroll frame for content
  local scroll, child = Scroll(p, -64, 22)
  local emptyText = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  emptyText:SetPoint("TOP", 0, -40)
  emptyText:SetText("Nothing matches these filters.")

  -- Footer instructions
  local footer = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", 6, 4)
  footer:SetText("Click a rank: add a teacher to your route  ·  Shift-click: new route to all its teachers  ·  Click ability name to collapse")

  -- Helper: Find best teacher for a rank
  local function BestTeacher(r, zone)
    local best, bs
    for _, t in ipairs(r.teachers) do
      local s = (ns.InZone(t, zone) and 0 or 2) + (ns.CanTame(t) and 0 or 1)
      if not bs or s < bs then best, bs = t, s end
    end
    return best
  end

  -- Tooltip for rank cells
  local function RankCellTooltip(rankCell)
    local d = rankCell.data
    if not d then return end
    local ab = d.ab
    local r = d.rank
    GameTooltip:SetOwner(rankCell, "ANCHOR_RIGHT")
    GameTooltip:AddLine(("%s (Rank %d)"):format(ab.name, r.rank), 1, 0.82, 0)
    GameTooltip:AddLine(r.effect, 1, 1, 1, true)
    GameTooltip:AddLine(("Pet level %d  -  %d TP"):format(r.level, r.tp), 0.8, 0.8, 0.8)
    if not d.status and r.level > ns.PetLevel() then
      GameTooltip:AddLine(("You can learn it now - your pet needs level %d to use it."):format(r.level), 1, 0.56, 0.25, true)
    end
    if d.status == "known" then
      GameTooltip:AddLine("Learned", 0.25, 1, 0.25)
    elseif d.status == "implied" then
      GameTooltip:AddLine("Not needed - you know a higher rank", 0.25, 0.8, 0.25)
    end
    GameTooltip:AddLine(" ")
    if ab.src == "trainer" then
      GameTooltip:AddLine("Bought from a Pet Trainer", 0.6, 0.8, 1)
    elseif #r.teachers == 0 then
      GameTooltip:AddLine("No known training source", 0.6, 0.6, 0.6)
    else
      GameTooltip:AddLine("Tame one of these:", 1, 0.82, 0)
      local zone = ns.CurrentZone()
      for _, t in ipairs(r.teachers) do
        local here = ns.InZone(t, zone)
        local tame = ns.CanTame(t)
        GameTooltip:AddDoubleLine(("%s (%s %s)%s"):format(t.name, t.family, t.level, Geo.Tag(t.name)), t.zone,
          here and 0.25 or (tame and 1 or 0.6), here and 1 or (tame and 1 or 0.6), here and 0.25 or (tame and 1 or 0.6),
          here and 0.25 or 0.7, here and 1 or 0.7, here and 0.25 or 0.7)
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Click: waypoint  ·  Shift-click: waypoints to all", 0.5, 0.5, 0.5)
    end
    GameTooltip:Show()
  end

  -- Tooltip for ability headers
  local function HeaderTooltip(header)
    local d = header.data
    if not d then return end
    local ab = d.ab
    GameTooltip:SetOwner(header, "ANCHOR_RIGHT")
    GameTooltip:AddLine(ab.name, 1, 0.82, 0)
    GameTooltip:AddLine(ab.isAll and "All pet families" or ab.famText, 1, 1, 1, true)
    GameTooltip:AddLine(ab.src == "trainer" and "Bought from a Pet Trainer" or "Learned by taming a beast that has it", 0.6, 0.8, 1)
    GameTooltip:AddLine(" ")
    GameTooltip:AddLine(ns.db.collapsed[ab.name] and "Click to expand" or "Click to collapse", 0.5, 0.5, 0.5)
    GameTooltip:Show()
  end

  -- Search/filter matching logic
  local function Matches(s, ab, r)
    if not s or s == "" then return true end
    if ab.name:lower():find(s, 1, true) then return true end
    for _, t in ipairs(r.teachers) do
      if t.name:lower():find(s, 1, true) or t.zone:lower():find(s, 1, true) or t.family:lower():find(s, 1, true) then
        return true
      end
    end
  end

  -- Get color for a rank cell based on status
  local function GetRankColor(status, canGet)
    if status == "known" then
      return 0x40, 0xff, 0x40 -- Green: known/learned
    elseif status == "implied" then
      return 0x5f, 0x9f, 0x5f -- Muted green: implied
    elseif not canGet then
      return 0x80, 0x80, 0x80 -- Gray: too high level
    else
      return 0xff, 0xd1, 0x00 -- Gold: can learn now
    end
  end

  -- Sections and rank cells
  local abilityRows = {} -- { { header, gridFrame, rankCells } }
  local rankCells = {} -- Reusable rank cell frames

  local function GetRankCell(index)
    if rankCells[index] then return rankCells[index] end

    local cell = CreateFrame("Button", nil, child)
    cell:SetSize(60, 60)

    -- Background texture
    cell.bg = cell:CreateTexture(nil, "BACKGROUND")
    cell.bg:SetAllPoints(cell)
    cell.bg:SetColorTexture(0.5, 0.5, 0.5, 0.2)

    -- Highlight
    cell.hl = cell:CreateTexture(nil, "HIGHLIGHT")
    cell.hl:SetAllPoints(cell)
    cell.hl:SetColorTexture(1, 1, 1, 0.1)

    -- Border
    cell.border = cell:CreateTexture(nil, "ARTWORK")
    cell.border:SetAllPoints(cell)
    cell.border:SetColorTexture(0.5, 0.5, 0.5, 0.3)

    -- Icon (ability icon)
    cell.icon = cell:CreateTexture(nil, "ARTWORK")
    cell.icon:SetSize(48, 48)
    cell.icon:SetPoint("CENTER", 0, 4)
    cell.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Rank number text
    cell.rankText = cell:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    cell.rankText:SetPoint("BOTTOM", 0, 2)
    cell.rankText:SetText("R1")

    cell:SetScript("OnEnter", function(self)
      self.hl:SetColorTexture(1, 1, 1, 0.2)
      RankCellTooltip(self)
    end)

    cell:SetScript("OnLeave", function(self)
      self.hl:SetColorTexture(1, 1, 1, 0.1)
      GameTooltip_Hide()
    end)

    cell:SetScript("OnClick", function(self)
      local d = self.data
      if not d then return end
      local r = d.rank
      local ab = d.ab
      if ab.src == "trainer" or #r.teachers == 0 then return end
      if IsShiftKeyDown() then
        local list = {}
        for i2, t in ipairs(r.teachers) do
          if i2 > 12 then break end
          list[#list + 1] = { t = t, label = Geo.Label(ab, r, t) }
        end
        Geo.WaypointMany(list)
      else
        local t = BestTeacher(r, ns.CurrentZone())
        if t then Geo.Waypoint(t, Geo.Label(ab, r, t)) end
      end
    end)

    rankCells[index] = cell
    return cell
  end

  local function GetAbilityHeader(index)
    if abilityRows[index] then return abilityRows[index].header end

    local row = CreateFrame("Button", nil, child)
    row:SetHeight(26)

    -- Background
    row.bg = row:CreateTexture(nil, "BACKGROUND")
    row.bg:SetAllPoints(row)
    row.bg:SetColorTexture(0.45, 0.33, 0.05, 0.28)

    -- Toggle icon
    row.toggle = row:CreateTexture(nil, "ARTWORK")
    row.toggle:SetSize(14, 14)
    row.toggle:SetPoint("LEFT", 4, 0)

    -- Ability icon
    row.icon = row:CreateTexture(nil, "ARTWORK")
    row.icon:SetSize(20, 20)
    row.icon:SetPoint("LEFT", 22, 0)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Ability name
    row.name = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    row.name:SetPoint("LEFT", row.icon, "RIGHT", 8, 1)

    -- Ranks progress
    row.ranks = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    row.ranks:SetPoint("LEFT", row.name, "RIGHT", 12, 0)
    row.ranks:SetJustifyH("LEFT")

    -- Family info
    row.family = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    row.family:SetPoint("RIGHT", -8, 1)
    row.family:SetJustifyH("RIGHT")

    row:SetScript("OnEnter", function(self)
      self.bg:SetColorTexture(0.45, 0.33, 0.05, 0.4)
      HeaderTooltip(self)
    end)

    row:SetScript("OnLeave", function(self)
      self.bg:SetColorTexture(0.45, 0.33, 0.05, 0.28)
      GameTooltip_Hide()
    end)

    row:SetScript("OnClick", function(self)
      local d = self.data
      if not d then return end
      ns.db.collapsed[d.ab.name] = (not ns.db.collapsed[d.ab.name]) or nil
      p.Refresh()
      if GameTooltip:GetOwner() == self then HeaderTooltip(self) end
    end)

    local gridFrame = CreateFrame("Frame", nil, child)
    gridFrame:SetHeight(100)

    abilityRows[index] = { header = row, grid = gridFrame }
    return row
  end

  function p.Refresh()
    if not p:IsShown() then return end
    local o, lvl, fam, zone = ns.db.opts, ns.PetLevel(), ns.PetFamily(), ns.CurrentZone()
    local s = ns.search
    local searching = s and s ~= ""

    -- Collect filtered abilities and their visible ranks
    local visibleAbilities = {}

    for _, ab in ipairs(abilities) do
      local show = not (o.hideTrainer and ab.src == "trainer")
        and not (o.petOnly and not ns.AbilityFitsPet(ab, fam))
        and not (o.zoneOnly and ab.src == "trainer")

      if show then
        local ranks = {} -- Ranks that pass filters
        local have, hereCount = 0, 0

        for _, r in ipairs(ab.parsed) do
          local st = ns.Status(ab, r.rank)
          if st then have = have + 1 end

          local here = ns.HasTeacherHere(r, zone)
          if here and not st then hereCount = hereCount + 1 end

          -- Apply visibility filters
          if not (o.hideKnown and st) and not (o.hideHigh and r.level > lvl)
            and not (o.zoneOnly and not here) and Matches(s, ab, r) then
            ranks[#ranks + 1] = { ab = ab, rank = r, status = st }
          end
        end

        if #ranks > 0 then
          visibleAbilities[#visibleAbilities + 1] = {
            ab = ab,
            ranks = ranks,
            have = have,
            here = hereCount
          }
        end
      end
    end

    -- Layout abilities and their rank grids
    local y = 0
    local cellIndex = 1

    for abilityIndex, entry in ipairs(visibleAbilities) do
      local ab = entry.ab
      local ranks = entry.ranks
      local collapsed = ns.db.collapsed[ab.name] and not searching

      -- Create/reuse ability header row
      local header = GetAbilityHeader(abilityIndex)
      header:ClearAllPoints()
      header:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      header:SetPoint("RIGHT", child, "RIGHT")
      header:Show()

      header.data = { header = true, ab = ab }

      -- Update header appearance
      local complete = entry.have == #ab.parsed
      header.name:SetText(complete and (GREEN .. ab.name .. "|r") or ab.name)
      header.ranks:SetText(("|cffffffff%d/%d|r"):format(entry.have, #ab.parsed))

      local fams = ab.isAll and "all families" or ab.famText
      header.family:SetText(fams)

      local toggleTex = collapsed and "Interface\\Buttons\\UI-PlusButton-Up" or "Interface\\Buttons\\UI-MinusButton-Up"
      header.toggle:SetTexture(toggleTex)
      header.icon:SetTexture(ab.icon)

      y = y + 26

      -- Layout rank grid if expanded
      if not collapsed then
        local grid = abilityRows[abilityIndex].grid
        grid:ClearAllPoints()
        grid:SetPoint("TOPLEFT", child, "TOPLEFT", 4, -y)
        grid:SetPoint("RIGHT", child, "RIGHT", -4, 0)
        grid:Show()

        -- Determine number of columns based on available width
        local availWidth = grid:GetWidth() - 8
        local cellSize = 60
        local cellPadding = 6
        local numCols = math.max(3, math.floor((availWidth + cellPadding) / (cellSize + cellPadding)))

        -- Layout rank cells in a grid
        for rankIdx, rankData in ipairs(ranks) do
          local cell = GetRankCell(cellIndex)
          cell.data = rankData

          local col = (rankIdx - 1) % numCols
          local row = math.floor((rankIdx - 1) / numCols)

          cell:ClearAllPoints()
          cell:SetPoint("TOPLEFT", grid, "TOPLEFT", col * (cellSize + cellPadding), -(row * (cellSize + cellPadding)))
          cell:Show()

          -- Set rank cell appearance
          cell.icon:SetTexture(rankData.ab.icon)
          cell.rankText:SetText("R" .. rankData.rank.rank)

          -- Determine rank cell color
          local canGet = rankData.ab.src == "trainer" or #rankData.rank.teachers == 0
          if not canGet then
            for _, t in ipairs(rankData.rank.teachers) do
              if ns.CanTame(t) then canGet = true break end
            end
          end

          local r, g, b = GetRankColor(rankData.status, canGet)
          cell.border:SetColorTexture(r / 255, g / 255, b / 255, 0.6)
          cell.bg:SetColorTexture(r / 255, g / 255, b / 255, 0.1)

          cellIndex = cellIndex + 1
        end

        -- Calculate grid height
        local numRows = math.ceil(#ranks / numCols)
        local gridHeight = numRows * (cellSize + cellPadding) + cellPadding
        grid:SetHeight(gridHeight)

        y = y + gridHeight + 6
      end
    end

    -- Hide unused rank cells
    for i = cellIndex, #rankCells do
      rankCells[i]:Hide()
    end

    -- Hide unused ability headers
    for i = #visibleAbilities + 1, #abilityRows do
      abilityRows[i].header:Hide()
      abilityRows[i].grid:Hide()
    end

    emptyText:SetShown(#visibleAbilities == 0)
    child:SetHeight(math.max(1, y))
  end

  p:SetScript("OnShow", p.Refresh)
end

------------------------------------------------------------------------
-- Tab 2: Hunt Planner (Zone Cards with Beast Grid)
------------------------------------------------------------------------
do
  local p = panels[2]

  -- Terrain color mapping for zones
  local ZONE_COLORS = {
    -- Kalimdor
    ["Barrens"] = { r = 0.75, g = 0.65, b = 0.35, a = 0.15 },
    ["Dustwallow Marsh"] = { r = 0.5, g = 0.6, b = 0.3, a = 0.15 },
    ["Tanaris"] = { r = 0.8, g = 0.75, b = 0.3, a = 0.15 },
    ["Ashenvale"] = { r = 0.3, g = 0.6, b = 0.2, a = 0.15 },
    ["Thousand Needles"] = { r = 0.7, g = 0.5, b = 0.4, a = 0.15 },
    ["Desolace"] = { r = 0.6, g = 0.4, b = 0.3, a = 0.15 },
    ["Stonetalon Mountains"] = { r = 0.5, g = 0.5, b = 0.5, a = 0.15 },
    ["Azshara"] = { r = 0.3, g = 0.4, b = 0.6, a = 0.15 },
    ["The Hinterlands"] = { r = 0.4, g = 0.5, b = 0.3, a = 0.15 },
    ["Feralas"] = { r = 0.3, g = 0.6, b = 0.4, a = 0.15 },
    ["Silithus"] = { r = 0.7, g = 0.4, b = 0.2, a = 0.15 },
    ["Mulgore"] = { r = 0.7, g = 0.65, b = 0.35, a = 0.15 },
    ["Durotar"] = { r = 0.75, g = 0.65, b = 0.35, a = 0.15 },
    ["The Barrens"] = { r = 0.75, g = 0.65, b = 0.35, a = 0.15 },
    -- Eastern Kingdoms
    ["Westfall"] = { r = 0.5, g = 0.6, b = 0.3, a = 0.15 },
    ["Loch Modan"] = { r = 0.4, g = 0.5, b = 0.6, a = 0.15 },
    ["Redridge Mountains"] = { r = 0.5, g = 0.4, b = 0.3, a = 0.15 },
    ["Duskwood"] = { r = 0.3, g = 0.3, b = 0.4, a = 0.15 },
    ["Stranglethorn Vale"] = { r = 0.3, g = 0.6, b = 0.2, a = 0.15 },
    ["Swamp of Sorrows"] = { r = 0.4, g = 0.5, b = 0.2, a = 0.15 },
    ["Blighted Lands"] = { r = 0.4, g = 0.3, b = 0.5, a = 0.15 },
    ["Plaguelands"] = { r = 0.4, g = 0.3, b = 0.5, a = 0.15 },
    ["Eastern Plaguelands"] = { r = 0.4, g = 0.3, b = 0.5, a = 0.15 },
    ["Western Plaguelands"] = { r = 0.4, g = 0.3, b = 0.5, a = 0.15 },
    ["Stratholme"] = { r = 0.4, g = 0.3, b = 0.5, a = 0.15 },
    ["Undercity"] = { r = 0.3, g = 0.2, b = 0.4, a = 0.15 },
    ["Silverpine Forest"] = { r = 0.3, g = 0.4, b = 0.3, a = 0.15 },
    ["Tirisfal Glades"] = { r = 0.3, g = 0.4, b = 0.3, a = 0.15 },
    ["Hillsbrad Foothills"] = { r = 0.5, g = 0.4, b = 0.3, a = 0.15 },
    ["Arathi Highlands"] = { r = 0.5, g = 0.4, b = 0.3, a = 0.15 },
    ["Hinterlands"] = { r = 0.4, g = 0.5, b = 0.3, a = 0.15 },
    ["Wetlands"] = { r = 0.3, g = 0.5, b = 0.3, a = 0.15 },
    ["Burning Steppes"] = { r = 0.7, g = 0.4, b = 0.2, a = 0.15 },
    ["Searing Gorge"] = { r = 0.7, g = 0.4, b = 0.2, a = 0.15 },
    ["Blackrock Mountain"] = { r = 0.4, g = 0.3, b = 0.3, a = 0.15 },
    ["Deadwind Pass"] = { r = 0.3, g = 0.2, b = 0.4, a = 0.15 },
  }

  local function GetZoneTerrainColor(zone)
    local c = ZONE_COLORS[zone]
    return c or { r = 0.5, g = 0.5, b = 0.5, a = 0.1 }
  end

  local intro = Text(p, "GameFontHighlightSmall", 6, -4)
  intro:SetWidth(600)
  Check(p, "My pet's family only", "huntPetOnly", 2, -34, "Only count abilities your current pet's family can use.")
  Check(p, "Include dungeons", "huntDungeons", 160, -34, "Also count beasts that live inside dungeons.")
  Check(p, "Sort by most new ranks", "huntSortCount", 290, -34, "Show the zones with the most new ranks first, instead of lowest level first.")
  Check(p, "Show enemy faction zones", "huntBothFactions", 470, -34,
    "Also list zones that belong to the other faction (marked in red). Contested zones are always shown.")
  Check(p, "Show my current zone first", "huntHereFirst", 2, -56,
    "If the zone you're in has something to tame, list it at the top.")
  local questieNote = Text(p, "GameFontHighlightSmall", 210, -61)
  questieNote:SetWidth(600)
  questieNote:SetWordWrap(false)
  Divider(p, -82)

  -- Route preview at bottom
  Text(p, "GameFontNormalSmall", 6, -86, "Current route:")
  local routeText = Text(p, "GameFontDisableSmall", 6, -102)
  routeText:SetWidth(650)
  routeText:SetJustifyH("LEFT")

  local clearRoute = Button(p, "Clear route", 110, function()
    ns.db.huntRoute = {}
    p.Refresh()
  end)
  clearRoute:SetPoint("TOPRIGHT", -8, -100)

  -- Scroll container for zone cards
  local scrollContainer = CreateFrame("ScrollFrame", nil, p)
  scrollContainer:SetPoint("TOPLEFT", 2, -120)
  scrollContainer:SetPoint("BOTTOMRIGHT", -2, 2)
  scrollContainer:EnableMouseWheel(true)

  local scrollChild = CreateFrame("Frame", nil, scrollContainer)
  scrollChild:SetWidth(scrollContainer:GetWidth())
  scrollContainer:SetScrollChild(scrollChild)

  scrollContainer:SetScript("OnMouseWheel", function(self, delta)
    self:SetVerticalScroll(self:GetVerticalScroll() - delta * 30)
  end)

  -- Zone cards cache
  local cards = {}

  local function MakeBeastIcon(parent, entry, x, y)
    local btn = CreateFrame("Button", nil, parent)
    btn:SetSize(60, 60)
    btn:SetPoint("TOPLEFT", x, y)

    -- Icon texture
    local icon = btn:CreateTexture(nil, "ARTWORK")
    icon:SetAllPoints(btn)
    icon:SetTexture(entry.ab.icon)
    icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Rarity border - determine from ability source
    local rarity = entry.ab.src == "trainer" and "rare" or "common"
    local borderColor = { common = {0.9, 0.9, 0.9, 1}, rare = {0.5, 0.75, 1, 1}, elite = {0.8, 0.5, 1, 1} }
    local bc = borderColor[rarity] or borderColor.common

    local border = btn:CreateTexture(nil, "OVERLAY")
    border:SetAllPoints(btn)
    border:SetTexture("Interface\\Buttons\\UI-ActionButton-Border")
    border:SetVertexColor(bc[1], bc[2], bc[3], bc[4])

    -- Tooltip
    btn:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(entry.ab.name .. " Rank " .. entry.rank.rank, 1, 0.82, 0)
      GameTooltip:AddLine(entry.rank.effect, 1, 1, 1, true)
      GameTooltip:AddLine(" ")
      local teachers = {}
      for i, t in ipairs(entry.teachers) do
        if i > 2 then
          teachers[#teachers + 1] = ("|cff9d9d9d+%d more|r"):format(#entry.teachers - 2)
          break
        end
        teachers[#teachers + 1] = t.name
      end
      GameTooltip:AddLine("Teachers: " .. table.concat(teachers, ", "), 0.8, 0.8, 0.8)
      GameTooltip:Show()
    end)

    btn:SetScript("OnLeave", GameTooltip_Hide)

    -- Right-click waypoint
    btn:SetScript("OnClick", function(self, button)
      if button == "RightButton" then
        local list = {}
        for _, t in ipairs(entry.teachers) do
          list[#list + 1] = { t = t, label = Geo.Label(entry.ab, entry.rank, t) }
        end
        Geo.WaypointMany(list)
      end
    end)

    return btn
  end

  local function MakeZoneCard(zoneData, index, parent)
    local card = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetSize(200, 150)
    card:SetPoint("TOPLEFT", 10 + (index - 1) * 220, 0)

    if card.SetBackdrop then
      card:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
      })
      card:SetBackdropColor(0.1, 0.1, 0.1, 0.4)
      card:SetBackdropBorderColor(0.5, 0.4, 0.2, 0.6)
    end

    -- Terrain color background
    local terrainBg = card:CreateTexture(nil, "BACKGROUND")
    terrainBg:SetAllPoints(card)
    local tc = GetZoneTerrainColor(zoneData.zone)
    terrainBg:SetColorTexture(tc.r, tc.g, tc.b, tc.a)

    -- Zone name (title)
    local zoneName = card:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    zoneName:SetPoint("TOPLEFT", 6, -6)
    zoneName:SetWidth(188)
    zoneName:SetJustifyH("LEFT")
    zoneName:SetText(("|cffffd700%s|r"):format(zoneData.zone))

    -- Level range (color coded)
    local lvl = ns.PlayerLevel()
    local rc = (zoneData.maxLevel < lvl) and "|cff9d9d9d" or ((zoneData.minLevel > lvl) and "|cffff9040" or GREEN)
    local levelText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    levelText:SetPoint("TOPLEFT", 6, -22)
    levelText:SetText(("%s%d-%d|r"):format(rc, zoneData.minLevel, zoneData.maxLevel))

    -- Beast count
    local countText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    countText:SetPoint("TOPRIGHT", -6, -22)
    countText:SetText(("|cff40ff40%d rank%s|r"):format(#zoneData.entries, #zoneData.entries == 1 and "" or "s"))

    -- You are here indicator
    if zoneData.here then
      local hereText = card:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
      hereText:SetPoint("BOTTOMRIGHT", -6, 6)
      hereText:SetText("|cff40ff40(You're here)|r")
    end

    -- Beast icon grid (4 icons max, arranged in 2x2)
    local gridY = -38
    for i = 1, math.min(4, #zoneData.entries) do
      local row = math.floor((i - 1) / 2)
      local col = (i - 1) % 2
      local x = 6 + col * 92
      local y = gridY - row * 60
      MakeBeastIcon(card, zoneData.entries[i], x, y)
    end

    -- Waypoint button for all beasts
    local waypointBtn = CreateFrame("Button", nil, card, "UIPanelButtonTemplate")
    waypointBtn:SetSize(70, 20)
    waypointBtn:SetPoint("BOTTOMLEFT", 6, 4)
    waypointBtn:SetText("Route")
    waypointBtn:SetScript("OnClick", function()
      local list = {}
      for _, e in ipairs(zoneData.entries) do
        for _, t in ipairs(e.teachers) do
          if #list < 15 then
            list[#list + 1] = { t = t, label = Geo.Label(e.ab, e.rank, t) }
          end
        end
      end
      Geo.WaypointMany(list)
      -- Add to route
      if not ns.db.huntRoute then ns.db.huntRoute = {} end
      ns.db.huntRoute[zoneData.zone] = zoneData
    end)

    -- Enable mouse for tooltip
    card:EnableMouse(true)

    card:SetScript("OnMouseDown", function(self)
      -- Show details tooltip
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      GameTooltip:AddLine(zoneData.zone, 1, 0.82, 0)
      GameTooltip:AddLine(("Level %d-%d"):format(zoneData.minLevel, zoneData.maxLevel), 0.8, 0.8, 0.8)
      GameTooltip:AddLine(" ")
      for _, e in ipairs(zoneData.entries) do
        GameTooltip:AddLine(("%s Rank %d"):format(e.ab.name, e.rank.rank), 1, 1, 1)
      end
      GameTooltip:AddLine(" ")
      GameTooltip:AddLine("Right-click beasts for waypoints", 0.5, 0.5, 0.5)
      GameTooltip:Show()
    end)

    card:SetScript("OnLeave", GameTooltip_Hide)

    return card
  end

  function p.Refresh()
    if not p:IsShown() then return end
    local o = ns.db.opts
    intro:SetText(("Zone cards with ranks you can tame at |cffffffffyour level (%d)|r. " ..
      "Click beasts for waypoints. Shift-drag cards to reorder your hunt route."):format(ns.PlayerLevel()))

    local plan = ns.HuntPlan(o.huntPetOnly, o.huntDungeons, o.huntSortCount and "count" or "level")

    questieNote:SetText(Geo.HasQuestie() and ""
      or "|cffff9040Questie not installed: routes only include beasts you've spotted yourself.|r")

    if o.huntHereFirst then
      for i, z in ipairs(plan) do
        if z.here then
          table.remove(plan, i)
          table.insert(plan, 1, z)
          break
        end
      end
    end

    -- Clear old cards
    for i, card in ipairs(cards) do
      card:Hide()
    end
    cards = {}

    -- Create new zone cards
    for i, zoneData in ipairs(plan) do
      cards[i] = MakeZoneCard(zoneData, i, scrollChild)
    end

    -- Update scroll child height
    local rows = math.ceil(#plan / 2)
    scrollChild:SetHeight(math.max(160, rows * 160))

    -- Update route preview text
    if ns.db.huntRoute and ns.db.huntRoute ~= {} then
      local routeStr = {}
      for zone, _ in pairs(ns.db.huntRoute) do
        table.insert(routeStr, zone)
      end
      routeText:SetText("Route: " .. table.concat(routeStr, " > "))
    else
      routeText:SetText("(No route planned yet)")
    end
  end

  p:SetScript("OnShow", p.Refresh)
end

------------------------------------------------------------------------
-- Tab 3: Rare Pets (a collection: they don't teach anything unique)
------------------------------------------------------------------------
do
  local p = panels[ns.TAB.rares]
  local intro = Text(p, "GameFontHighlightSmall", 6, -4)
  intro:SetWidth(600)
  Check(p, "Rares", "spShowRare", 2, -30, "Show rare pets.")
  Check(p, "Elites", "spShowElite", 72, -30, "Show elite pets (tough in the wild, normal once tamed).")
  Check(p, "Quest spawns", "spShowSpawned", 142, -30, "Show pets that only appear through a quest or trigger.")
  Check(p, "Dungeon / raid", "spShowDungeon", 248, -30, "Include pets that live inside dungeons and raids.")
  Check(p, "Hide tamed", "rareHideTamed", 362, -30, "Hide pets you've already tamed.")
  Check(p, "Hide above my level", "rareHideHigh", 450, -30, "Hide pets you're too low level to tame yet.")
  Check(p, "Fastest first", "rareSortSpeed", 590, -30, "Sort by attack speed (lowest number = fastest).")
  Check(p, "Show untamed specials on the map", "rarePins", 2, -52,
    "Pins for untamed rares (and outdoor elites / quest spawns) you can tame, even if they teach nothing you need.")
  local count = p:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  count:SetPoint("TOPRIGHT", -8, -56)

  local searchLabel = Text(p, "GameFontNormalSmall", 10, -80, "Search")
  local search = CreateFrame("EditBox", nil, p, "InputBoxTemplate")
  search:SetSize(200, 20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
  search:SetAutoFocus(false)
  search:SetScript("OnEscapePressed", function(self) self:SetText(""); self:ClearFocus() end)
  search:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
  search:SetScript("OnTextChanged", function(self)
    ns.rareSearch = (self:GetText() or ""):lower():match("^%s*(.-)%s*$")
    p.Refresh()
  end)
  local hint = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  hint:SetPoint("LEFT", search, "RIGHT", 10, 0)
  hint:SetText("name, family or zone")

  local COLS = {
    { x = 52, w = 132, head = "Name" },
    { x = 186, w = 72, head = "Type" },
    { x = 260, w = 66, head = "Family" },
    { x = 328, w = 34, head = "Lvl" },
    { x = 364, w = 58, head = "Atk speed" },
    { x = 424, w = 104, head = "Traits" },
    { x = 530, w = 104, head = "Zone" },
  }
  local headY = -103
  for _, c in ipairs(COLS) do
    local fs = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("TOPLEFT", 2 + c.x, headY)
    fs:SetText(c.head)
  end
  local st = p:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  st:SetPoint("TOPRIGHT", -34, headY)
  st:SetText("Status")
  Divider(p, headY - 14)
  local L = MakeList(p, headY - 18, 22)
  local footer = p:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  footer:SetPoint("BOTTOMLEFT", 6, 4)
  footer:SetText("Click: details & 3D model  ·  Shift-click: waypoint  ·  Right-click: mark tamed / not tamed (with that pet out, links it)  ·  Normal speed 2.0")

  local function SpeedCell(speed)
    if not speed then return "|cff808080?|r" end
    local s = ns.RS.SpeedText(speed)
    if speed < 2.0 then return s .. " |cff40ff40fast|r" end
    if speed > 2.0 then return s .. " |cffff9040slow|r" end
    return s
  end

  local DW = 270
  local drawer = CreateFrame("Frame", "BeastTrainingTrackerPetDrawer", f, BackdropTemplateMixin and "BackdropTemplate" or nil)
  drawer:SetSize(DW, 500)
  drawer:SetFrameLevel(math.max(0, f:GetFrameLevel() - 1))
  drawer:EnableMouse(true)
  drawer:Hide()
  if drawer.SetBackdrop then
    drawer:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    drawer:SetBackdropBorderColor(0.67, 0.83, 0.45, 0.9)
  end
  local dClose = CreateFrame("Button", nil, drawer, "UIPanelCloseButton")
  dClose:SetPoint("TOPRIGHT", -2, -2)
  dClose:SetScript("OnClick", function() drawer:Hide() end)

  local dName = drawer:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  dName:SetPoint("TOPLEFT", 14, -14)
  dName:SetPoint("RIGHT", -30, 0)
  dName:SetJustifyH("LEFT")
  local dSub = drawer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dSub:SetPoint("TOPLEFT", dName, "BOTTOMLEFT", 0, -4)
  dSub:SetPoint("RIGHT", -14, 0)
  dSub:SetJustifyH("LEFT")

  local model = CreateFrame("PlayerModel", nil, drawer)
  model:SetPoint("TOPLEFT", 10, -56)
  model:SetPoint("TOPRIGHT", -10, -56)
  model:SetHeight(220)
  local modelBg = C(0, 0, 0, 0.35, model:CreateTexture(nil, "BACKGROUND"))
  modelBg:SetAllPoints()
  local noModel = model:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  noModel:SetPoint("CENTER")
  noModel:SetWidth(DW - 40)
  local modelHint = drawer:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
  modelHint:SetPoint("TOP", model, "BOTTOM", 0, -2)
  modelHint:SetText("Drag to turn  ·  Mouse wheel to zoom")

  local facing, zoom, spin, dragX = 0, 1, true, nil
  model:EnableMouse(true)
  model:EnableMouseWheel(true)
  model:SetScript("OnMouseDown", function(_, button)
    if button == "LeftButton" then dragX, spin = GetCursorPosition(), false end
  end)
  model:SetScript("OnMouseUp", function() dragX = nil end)
  model:SetScript("OnMouseWheel", function(self, delta)
    zoom = math.min(3, math.max(0.4, zoom - delta * 0.15))
    if self.SetCamDistanceScale then self:SetCamDistanceScale(zoom) end
  end)
  model:SetScript("OnUpdate", function(self, elapsed)
    if dragX then
      local x = GetCursorPosition()
      facing = facing + (x - dragX) * 0.02
      dragX = x
      self:SetFacing(facing)
    elseif spin then
      facing = facing + elapsed * 0.6
      self:SetFacing(facing)
    end
  end)

  local function NpcId(name)
    if ns.rareIds and ns.rareIds[name] then return ns.rareIds[name] end
    if Geo.HasQuestie() then
      local ok, ids = pcall(NpcDB.IdsByName, name)
      if ok and ids and ids[1] then return ids[1] end
    end
  end

  local function ShowModel(name)
    facing, zoom, spin = 0, 1, true
    model:ClearModel()
    local id = NpcId(name)
    if not id or not model.SetCreature then
      noModel:SetText("No 3D model available for this beast yet." ..
        (Geo.HasQuestie() and "" or "\n\nInstall Questie to see models of elites and quest spawns."))
      noModel:Show()
      return
    end
    noModel:Hide()
    model:SetCreature(id)
    if model.SetCamDistanceScale then model:SetCamDistanceScale(zoom) end
    model:SetFacing(facing)
    if C_Timer then
      C_Timer.After(0.5, function()
        if drawer:IsShown() and drawer.name == name then model:SetCreature(id); model:SetFacing(facing) end
      end)
    end
  end

  local dInfo = drawer:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  dInfo:SetPoint("TOPLEFT", model, "BOTTOMLEFT", 4, -20)
  dInfo:SetPoint("RIGHT", -14, 0)
  dInfo:SetJustifyH("LEFT")
  dInfo:SetJustifyV("TOP")
  dInfo:SetSpacing(3)

  local current
  local dWaypoint = Button(drawer, "Waypoint", 110, function()
    if not current then return end
    local e = current.teaches[1]
    Geo.Waypoint(current.t, e and Geo.Label(e.ab, e.rank, current.t) or current.name)
  end)
  dWaypoint:SetPoint("BOTTOMLEFT", 14, 14)
  local dTamed = Button(drawer, "Mark tamed", 120, function()
    if current then ns.RS.SetTamed(current.name, not current.tamed) end
  end)
  dTamed:SetPoint("BOTTOMRIGHT", -14, 14)

  local function Dur(sec)
    if sec < 3600 then return math.floor(sec / 60 + 0.5) .. "m" end
    if sec <= 72 * 3600 then
      local h = math.floor(sec / 1800 + 0.5) / 2
      return (h == math.floor(h) and tostring(h) or ("%.1f"):format(h)) .. "h"
    end
    local d = math.floor(sec / 43200 + 0.5) / 2
    return (d == math.floor(d) and tostring(d) or ("%.1f"):format(d)) .. "d"
  end

  local function RespawnLine(r)
    if r.t.dungeon then return "Respawn: |cffffffffwhen the dungeon resets|r" end
    local rt = ns.respawnTimes and ns.respawnTimes[r.name]
    if not rt then return "Respawn: |cff808080unknown|r" end
    local range = rt[1] == rt[2] and Dur(rt[1]) or (Dur(rt[1]) .. " - " .. Dur(rt[2]))
    local spots = (rt[3] or 1) > 1 and ("  |cff9d9d9d(%d spawn points)|r"):format(rt[3]) or ""
    return "Respawn: |cffffffff" .. range .. "|r" .. spots
  end

  local function FamilyAbilities(family)
    local list = {}
    for _, ab in ipairs(abilities) do
      if not ab.isAll and ns.AbilityFitsPet(ab, family) then list[#list + 1] = ab.name end
    end
    return table.concat(list, ", ")
  end

  local function FillDrawer(r)
    current = r
    local sp = r.t
    dName:SetText((r.tamed and "|cff9d9d9d" or "|cffff8000") .. r.name .. "|r")
    dSub:SetText(("%s  ·  %s, level %s\n|cff9d9d9d%s|r"):format(ns.RS.TypeText(sp), sp.family, sp.level, sp.zone))
    local cur = ns.RS.Info(r.name)
    local out = { "Attack speed: " .. SpeedCell(r.speed) .. "  |cff9d9d9d(normal 2.0)|r", RespawnLine(r) }
    for _, tr in ipairs(cur.traits) do out[#out + 1] = "|cffffd14d" .. tr.long .. "|r" end
    local fam = FamilyAbilities(sp.family)
    if fam ~= "" then out[#out + 1] = ("Can learn (%s): |cffd0d0d0%s|r"):format(sp.family, fam) end
    if #r.teaches > 0 then
      out[#out + 1] = " "
      for _, e in ipairs(r.teaches) do
        local k = ns.IsKnown(e.ab, e.rank.rank)
        out[#out + 1] = (k and "|cff808080" or "|cff40ff40") .. ("Teaches %s %d%s|r"):format(e.ab.name, e.rank.rank, k and " (known)" or "")
      end
    end
    if cur.tamed then
      out[#out + 1] = " "
      local nick = ns.db.tamedNicks and ns.db.tamedNicks[r.name]
      out[#out + 1] = "|cff40ff40" .. (type(cur.tamed) == "number" and ("Tamed " .. date("%b %d, %Y", cur.tamed)) or "Tamed")
        .. (nick and (" (" .. nick .. ")") or "") .. "|r"
    elseif not ns.CanTame(sp) then
      out[#out + 1] = " "
      out[#out + 1] = ("|cff808080You need level %d to tame it.|r"):format(sp.minLevel)
    end
    if cur.status then
      out[#out + 1] = " "
      out[#out + 1] = "|cffff9940RareScanner: " .. cur.status.text .. "|r"
    end
    local id = NpcId(r.name)
    if id then
      out[#out + 1] = " "
      out[#out + 1] = ("|cff808080NPC ID %d|r"):format(id)
    end
    dInfo:SetText(table.concat(out, "\n"))
    dTamed:SetText(r.tamed and "Mark not tamed" or "Mark tamed")
  end

  local slideT
  local function Anchor(offset)
    drawer:ClearAllPoints()
    local right = (f:GetRight() or 0) + DW <= (UIParent:GetRight() or math.huge) / (f:GetEffectiveScale() / UIParent:GetEffectiveScale())
    if right then
      drawer:SetPoint("TOPLEFT", f, "TOPRIGHT", offset - DW, -20)
    else
      drawer:SetPoint("TOPRIGHT", f, "TOPLEFT", DW - offset, -20)
    end
  end
  drawer:SetScript("OnUpdate", function()
    if not slideT then return end
    local t = math.min(1, (GetTime() - slideT) / 0.18)
    Anchor(DW * (1 - (1 - t) ^ 2))
    if t >= 1 then slideT = nil end
  end)

  local function OpenDrawer(r)
    if drawer:IsShown() and drawer.name == r.name then drawer:Hide() return end
    local wasOpen = drawer:IsShown()
    drawer.name = r.name
    FillDrawer(r)
    ShowModel(r.name)
    if wasOpen then return end
    Anchor(0)
    slideT = GetTime()
    drawer:Show()
  end
  drawer:SetScript("OnHide", function() drawer.name, current, slideT = nil, nil, nil end)
  p:HookScript("OnHide", function() drawer:Hide() end)

  function p.Refresh()
    if not p:IsShown() then return end
    local o = ns.db.opts
    local linked = ns.RS.Loaded()
    intro:SetText("Rare, elite and quest-spawned beasts (Petopia). They teach the same abilities as normal beasts - what makes them special is " ..
      "their look and innate traits like attack speed, which stay with that pet. " ..
      (linked and "|cff40ff40Spawn timers from RareScanner.|r" or "|cff9d9d9dEnable RareScanner for spawn timers.|r"))

    local list = ns.RS.AllRares(o.rareSortSpeed)
    local tamed = 0
    local items = {}
    local s = ns.rareSearch
    local searching = s and s ~= ""
    for _, r in ipairs(list) do
      if r.tamed then tamed = tamed + 1 end
      local tameable = ns.CanTame(r.t)
      local sp = r.t
      local typeOk = (o.spShowRare and sp.rare) or (o.spShowElite and sp.elite) or (o.spShowSpawned and sp.spawned)
      local matches = not searching or r.name:lower():find(s, 1, true) or sp.family:lower():find(s, 1, true) or sp.zone:lower():find(s, 1, true)
      if typeOk and (o.spShowDungeon or not sp.dungeon)
        and not (o.rareHideTamed and r.tamed) and not (o.rareHideHigh and not tameable) and matches then
        local nameColor = r.tamed and "|cff9d9d9d" or (tameable and "|cffff8000" or "|cff996030")
        local status
        if r.tamed then
          local nick = ns.db.tamedNicks and ns.db.tamedNicks[r.name]
          status = "|cff40ff40tamed|r" .. (nick and (" |cff9d9d9d(" .. nick .. ")|r") or "")
        elseif not tameable then
          status = ("|cff808080need lvl %d|r"):format(r.t.minLevel)
        else
          status = r.status and r.status.short or ""
        end
        local traits = {}
        for _, tr in ipairs(r.traits) do
          if tr.short ~= "" then traits[#traits + 1] = tr.short end
        end
        items[#items + 1] = {
          kind = "row", check = r.tamed, icon = r.icon, indent = 6,
          cols = {
            { x = COLS[1].x, w = COLS[1].w, text = nameColor .. r.name .. "|r" },
            { x = COLS[2].x, w = COLS[2].w, text = ns.RS.TypeText(sp) },
            { x = COLS[3].x, w = COLS[3].w, text = "|cffd0d0d0" .. sp.family .. "|r" },
            { x = COLS[4].x, w = COLS[4].w, text = (tameable and "|cffffffff" or "|cff808080") .. sp.level .. "|r" },
            { x = COLS[5].x, w = COLS[5].w, text = SpeedCell(r.speed) },
            { x = COLS[6].x, w = COLS[6].w, text = table.concat(traits, "  ") },
            { x = COLS[7].x, w = COLS[7].w, text = "|cff9d9d9d" .. sp.zone .. "|r" },
          },
          right = status,
          onClick = function()
            if IsShiftKeyDown() then
              local e = r.teaches[1]
              Geo.Waypoint(r.t, e and Geo.Label(e.ab, e.rank, r.t) or r.name)
            else
              OpenDrawer(r)
            end
          end,
          onRightClick = function()
            ns.RS.SetTamed(r.name, not r.tamed)
          end,
          tip = function(tt)
            local cur = ns.RS.Info(r.name)
            tt:AddLine(r.name .. "  " .. ns.RS.TypeText(r.t), 1, 0.82, 0)
            tt:AddLine(("%s, level %s - %s"):format(r.t.family, r.t.level, r.t.zone), 0.8, 0.8, 0.8)
            tt:AddLine("Attack speed: " .. SpeedCell(r.speed) .. "  |cff9d9d9d(normal 2.0, lower = faster)|r", 1, 1, 1)
            for _, tr in ipairs(cur.traits) do tt:AddLine(tr.long, 1, 0.82, 0.3, true) end
            if cur.tamed then
              tt:AddLine(type(cur.tamed) == "number" and ("Tamed " .. date("%b %d, %Y", cur.tamed)) or "Tamed", 0.25, 1, 0.25)
            end
            if #r.teaches > 0 then
              tt:AddLine(" ")
              for _, e in ipairs(r.teaches) do
                local k = ns.IsKnown(e.ab, e.rank.rank)
                tt:AddLine(("Teaches %s %d%s"):format(e.ab.name, e.rank.rank, k and " (known)" or ""),
                  k and 0.5 or 0.25, k and 0.5 or 1, k and 0.5 or 0.25)
              end
            end
            if cur.status then
              tt:AddLine(" ")
              tt:AddLine("RareScanner: " .. cur.status.text, 1, 0.6, 0.25, true)
            end
            tt:AddLine(" ")
            tt:AddLine("Click: details & 3D model  ·  Shift-click: waypoint  ·  Right-click: toggle tamed", 0.5, 0.5, 0.5, true)
          end,
        }
      end
    end
    count:SetText(("Tamed |cffffffff%d / %d|r"):format(tamed, #list))
    ListSet(L, items, "Nothing matches these filters.")
    if drawer:IsShown() then
      for _, r in ipairs(list) do
        if r.name == drawer.name then FillDrawer(r) break end
      end
    end
  end
  p:SetScript("OnShow", p.Refresh)
end

------------------------------------------------------------------------
-- Tab 4: My Pet (Card-based redesign)
------------------------------------------------------------------------
do
  local p = panels[ns.TAB.pet]

  local scroll, child = Scroll(p, -6, 4)
  local emptyText = child:CreateFontString(nil, "OVERLAY", "GameFontDisable")
  emptyText:SetPoint("TOP", 0, -40)

  local function CreateCard(parent, title, subtitle)
    local card = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.95, 0.92, 0.82, 0.3)
    card:SetBackdropBorderColor(0.70, 0.62, 0.45, 0.6)

    if title then
      local titleFs = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      titleFs:SetPoint("TOPLEFT", 10, -8)
      titleFs:SetText(title)
      titleFs:SetTextColor(1, 0.82, 0)
      card.title = titleFs
    end

    if subtitle then
      local subFs = card:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      subFs:SetPoint("TOPLEFT", 10, -26)
      subFs:SetText(subtitle)
      subFs:SetTextColor(0.9, 0.9, 0.9)
      card.subtitle = subFs
    end

    return card
  end

  function p.Refresh()
    if not p:IsShown() then return end
    local y = 0

    if not UnitExists("pet") then
      emptyText:SetText("|cff9d9d9dSummon your pet to see upgrades for it.|r")
      emptyText:Show()
      child:SetHeight(1)
      return
    end
    emptyText:Hide()

    ns.ScanPet()
    local fam, plvl = ns.PetFamily() or "?", ns.PetLevel()
    local petName = UnitName("pet") or "Pet"

    -- Pet Status Card
    local statusCard = CreateCard(child, petName .. "  |cffffffff" .. fam .. "|r, Level " .. plvl)
    statusCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    statusCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    statusCard:SetHeight(60)

    if GetPetTrainingPoints then
      local total, spent = GetPetTrainingPoints()
      if total then
        local tpText = statusCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        tpText:SetPoint("TOPLEFT", 10, -44)
        tpText:SetText(("Training points: |cffffffff%d free|r of %d"):format((total or 0) - (spent or 0), total or 0))
      end
    end
    y = y + 70

    -- Upgrades Section
    local ups = ns.Upgrades()
    local readyUps, levelUps = {}, {}
    for _, u in ipairs(ups) do
      if u.needLevel then
        levelUps[#levelUps + 1] = u
      else
        readyUps[#readyUps + 1] = u
      end
    end

    if #readyUps > 0 then
      local readyCard = CreateCard(child, "|cff40ff40Ready Now|r (" .. #readyUps .. ")")
      readyCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      readyCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
      local contentY = -40
      for _, u in ipairs(readyUps) do
        local row = readyCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", 10, contentY)
        row:SetWidth(500)
        row:SetJustifyH("LEFT")
        row:SetWordWrap(true)
        row:SetText("|cffffffff" .. u.ab.name .. "|r: pet has rank " .. u.from .. " → you know rank " .. u.to)
        contentY = contentY - 18
      end
      readyCard:SetHeight(math.abs(contentY) + 10)
      y = y + math.abs(contentY) + 20
    end

    if #levelUps > 0 then
      local levelCard = CreateCard(child, "|cffff9040Needs Level|r (" .. #levelUps .. ")")
      levelCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      levelCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
      local contentY = -40
      for _, u in ipairs(levelUps) do
        local row = levelCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", 10, contentY)
        row:SetWidth(500)
        row:SetJustifyH("LEFT")
        row:SetWordWrap(true)
        row:SetText("|cffffffff" .. u.ab.name .. "|r: pet needs level " .. u.needLevel)
        contentY = contentY - 18
      end
      levelCard:SetHeight(math.abs(contentY) + 10)
      y = y + math.abs(contentY) + 20
    end

    if #readyUps == 0 and #levelUps == 0 then
      local noUpsCard = CreateCard(child, "|cff9d9d9dNo Upgrades")
      noUpsCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      noUpsCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
      noUpsCard:SetHeight(50)
      local msg = noUpsCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      msg:SetPoint("TOPLEFT", 10, -30)
      msg:SetText("Your pet already has the best ranks you know.")
      y = y + 60
    end

    -- Coming Up Timeline
    local soon = ns.ComingUp(6)
    if #soon > 0 then
      local comingCard = CreateCard(child, "Coming Up (Next 6 Levels)", nil)
      comingCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      comingCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
      local contentY = -40
      for _, s in ipairs(soon) do
        local row = comingCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", 10, contentY)
        row:SetWidth(500)
        row:SetJustifyH("LEFT")
        row:SetWordWrap(true)
        local status = s.known and ("|cff40ff40known|r") or ("|cff9d9d9d" .. ns.TeacherZones(s.ab, s.rank, 2) .. "|r")
        row:SetText("|cffffd100Lvl " .. s.rank.level .. "|r: |cffffffff" .. s.ab.name .. " " .. s.rank.rank .. "|r  " .. status)
        contentY = contentY - 18
      end
      comingCard:SetHeight(math.abs(contentY) + 10)
      y = y + math.abs(contentY) + 20
    end

    -- Extra Abilities Section
    local fam2 = ns.PetFamily()
    local extra = {}
    for _, ab in ipairs(abilities) do
      if not ns.petRank[ab.name] and ns.AbilityFitsPet(ab, fam2) then
        local best = ns.BestKnown(ab, plvl)
        if best > 0 then extra[#extra + 1] = { ab = ab, rank = best } end
      end
    end

    if #extra > 0 then
      local extraCard = CreateCard(child, "Learn These Next", nil)
      extraCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
      extraCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
      local contentY = -40
      for _, x in ipairs(extra) do
        local r = x.ab.parsed[x.rank]
        local row = extraCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        row:SetPoint("TOPLEFT", 10, contentY)
        row:SetWidth(500)
        row:SetJustifyH("LEFT")
        row:SetWordWrap(true)
        local cost = r and ("|cff9d9d9d" .. r.tp .. " TP|r") or ""
        row:SetText("|cffffffff" .. x.ab.name .. " " .. x.rank .. "|r  " .. cost)
        contentY = contentY - 18
      end
      extraCard:SetHeight(math.abs(contentY) + 10)
      y = y + math.abs(contentY) + 20
    end

    child:SetHeight(math.max(1, y))
  end
  p:SetScript("OnShow", p.Refresh)
end

------------------------------------------------------------------------
-- Tab 5: Settings (Card-based redesign)
------------------------------------------------------------------------
local mmCheck
do
  local p = panels[ns.TAB.map]

  local scroll, child = Scroll(p, -6, 4)

  local function CreateSettingsCard(parent, title)
    local card = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.95, 0.92, 0.82, 0.3)
    card:SetBackdropBorderColor(0.70, 0.62, 0.45, 0.6)
    card:EnableMouse(true)

    local titleFs = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleFs:SetPoint("TOPLEFT", 10, -8)
    titleFs:SetText(title)
    titleFs:SetTextColor(1, 0.82, 0)

    local toggle = card:CreateTexture(nil, "ARTWORK")
    toggle:SetSize(14, 14)
    toggle:SetPoint("TOPRIGHT", -8, -8)
    toggle:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")

    card.title = titleFs
    card.toggle = toggle
    card.isExpanded = true

    return card
  end

  local function CreateCheckRow(card, label, key, tip, onChange)
    local cb = Check(card, label, key, 10, 0, tip, onChange)
    cb:SetParent(card)
    return cb
  end

  function p.Refresh()
    if not p:IsShown() then return end
    local y = 0

    -- Optional Addons Card
    local addonsCard = CreateSettingsCard(child, "Optional Addons")
    addonsCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    addonsCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    local contentY = -40
    for i, a in ipairs(Geo.AddonStatus()) do
      local row = addonsCard:CreateFrame("Frame", nil, addonsCard)
      row:SetSize(500, 16)
      row:SetPoint("TOPLEFT", 10, contentY)

      local dot = row:CreateTexture(nil, "ARTWORK")
      dot:SetSize(12, 12)
      dot:SetPoint("LEFT", 0, 0)
      dot:SetTexture(a.on and "Interface\\COMMON\\Indicator-Green" or "Interface\\COMMON\\Indicator-Gray")

      local name = row:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
      name:SetPoint("LEFT", 20, 0)
      name:SetText(a.on and ("|cff40ff40" .. a.name .. "|r") or ("|cff9d9d9d" .. a.name .. "|r"))

      local text = row:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
      text:SetPoint("LEFT", 100, 0)
      text:SetWidth(400)
      text:SetJustifyH("LEFT")
      text:SetWordWrap(false)
      text:SetText(a.on and a.text or ("|cff9d9d9d" .. a.text .. "|r"))

      contentY = contentY - 18
    end
    addonsCard:SetHeight(math.abs(contentY) + 10)
    y = y + math.abs(contentY) + 20

    -- Map Pins Card
    local mapCard = CreateSettingsCard(child, "Map & Pins")
    mapCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    mapCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    contentY = -40

    local c1 = Check(mapCard, "Show teachers on world map", "mapPins", 10, contentY, "Pins for every beast that teaches a missing rank you can tame now.")
    c1:SetParent(mapCard)
    contentY = contentY - 24

    local c2 = Check(mapCard, "Show teachers on minimap", "minimapPins", 10, contentY, "Pins on minimap for the nearest teachers in your zone.")
    c2:SetParent(mapCard)
    contentY = contentY - 24

    local c3 = Check(mapCard, "Hide ALL beast pins", "pinsOff", 10, contentY, "Master switch for every pin.", function() Geo.QueuePins(true) end)
    c3:SetParent(mapCard)
    contentY = contentY - 24

    local c4 = Check(mapCard, "Show untamed special pets", "rarePins", 10, contentY, "Pins for untamed rares you can tame.")
    c4:SetParent(mapCard)
    contentY = contentY - 24

    local c5 = Check(mapCard, "Open map on first waypoint", "routeOpenMap", 10, contentY, "Opens world map when you set waypoints.")
    c5:SetParent(mapCard)
    contentY = contentY - 24

    local c6 = Check(mapCard, "Draw hunt route on map", "routeLines", 10, contentY, "Numbered stops joined by dotted line.", function() ns.Geo.DrawRoute() end)
    c6:SetParent(mapCard)
    contentY = contentY - 30

    mapCard:SetHeight(math.abs(contentY) + 10)
    y = y + math.abs(contentY) + 20

    -- Route Color Card
    local colorCard = CreateSettingsCard(child, "Route Line Settings")
    colorCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    colorCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    contentY = -40

    local colorLabel = colorCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    colorLabel:SetPoint("TOPLEFT", 10, contentY)
    colorLabel:SetText("Color & Opacity")
    contentY = contentY - 24

    local swatch = CreateFrame("Button", nil, colorCard, BackdropTemplateMixin and "BackdropTemplate" or nil)
    swatch:SetSize(48, 20)
    swatch:SetPoint("TOPLEFT", 10, contentY)
    if swatch.SetBackdrop then
      swatch:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
      swatch:SetBackdropBorderColor(0.8, 0.8, 0.8, 1)
    end
    swatch.color = swatch:CreateTexture(nil, "ARTWORK")
    swatch.color:SetPoint("TOPLEFT", 3, -3)
    swatch.color:SetPoint("BOTTOMRIGHT", -3, 3)

    local function SetRouteColor(r, g, b)
      ns.db.opts.routeColor = { r = r, g = g, b = b }
      swatch.color:SetColorTexture(r, g, b, 1)
      ns.Geo.DrawRoute()
    end

    swatch:SetScript("OnClick", function()
      local r, g, b = ns.Geo.RouteColor()
      local function apply() SetRouteColor(ColorPickerFrame:GetColorRGB()) end
      local function cancel() SetRouteColor(r, g, b) end
      if ColorPickerFrame.SetupColorPickerAndShow then
        ColorPickerFrame:SetupColorPickerAndShow({ r = r, g = g, b = b, hasOpacity = false, swatchFunc = apply, cancelFunc = cancel })
      else
        ColorPickerFrame.hasOpacity = false
        ColorPickerFrame.opacityFunc = nil
        ColorPickerFrame.previousValues = { r, g, b }
        ColorPickerFrame.func = apply
        ColorPickerFrame.cancelFunc = cancel
        ColorPickerFrame:SetColorRGB(r, g, b)
        ColorPickerFrame:Hide()
        ColorPickerFrame:Show()
      end
    end)

    local alpha = CreateFrame("Slider", "BeastTrainingTrackerRouteAlpha", colorCard, "OptionsSliderTemplate")
    alpha:SetWidth(160)
    alpha:SetPoint("LEFT", swatch, "RIGHT", 20, 0)
    alpha:SetMinMaxValues(0.1, 1)
    alpha:SetValueStep(0.05)
    if alpha.SetObeyStepOnDrag then alpha:SetObeyStepOnDrag(true) end
    local low = alpha.Low or _G["BeastTrainingTrackerRouteAlphaLow"]
    local high = alpha.High or _G["BeastTrainingTrackerRouteAlphaHigh"]
    local label = alpha.Text or _G["BeastTrainingTrackerRouteAlphaText"]
    if low then low:SetText("10%") end
    if high then high:SetText("100%") end
    alpha:SetScript("OnValueChanged", function(self, v)
      v = math.floor(v * 20 + 0.5) / 20
      if label then label:SetText(("Opacity: %d%%"):format(v * 100)) end
      if ns.db and ns.db.opts.routeAlpha ~= v then
        ns.db.opts.routeAlpha = v
        ns.Geo.DrawRoute()
      end
    end)

    local resetColor = Button(colorCard, "Default", 80, function()
      local d = ns.Geo.ROUTE_DEFAULT
      ns.db.opts.routeAlpha = d.a
      alpha:SetValue(d.a)
      SetRouteColor(d.r, d.g, d.b)
    end)
    resetColor:SetPoint("LEFT", alpha, "RIGHT", 20, 0)

    colorCard:SetHeight(80)
    y = y + 90

    -- Alerts Card
    local alertsCard = CreateSettingsCard(child, "Alerts")
    alertsCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    alertsCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    contentY = -40

    local a1 = Check(alertsCard, "Alert on target/mouseover", "alertTarget", 10, contentY, "Big message when you target a teaching beast.")
    a1:SetParent(alertsCard)
    contentY = contentY - 24

    local a2 = Check(alertsCard, "Alert on nameplate", "alertNameplate", 10, contentY, "Alert when teacher nameplate appears nearby.")
    a2:SetParent(alertsCard)
    contentY = contentY - 24

    local a3 = Check(alertsCard, "Play alert sound", "alertSound", 10, contentY, "Raid-warning sound with alerts.")
    a3:SetParent(alertsCard)
    contentY = contentY - 24

    local a4 = Check(alertsCard, "Pet upgrade reminders", "upgradeAlert", 10, contentY, "Chat message about available upgrades.")
    a4:SetParent(alertsCard)
    contentY = contentY - 24

    local a5 = Check(alertsCard, "Pet level-up nudges", "levelNudge", 10, contentY, "Chat message when pet reaches new rank level.")
    a5:SetParent(alertsCard)
    contentY = contentY - 24

    local a6 = Check(alertsCard, "Let RareScanner alert", "rsHandlesRares", 10, contentY, "Skip alerts for rares if RareScanner handles them.")
    a6:SetParent(alertsCard)
    contentY = contentY - 24

    local a7 = Check(alertsCard, "Popup on new ability", "learnToast", 10, contentY, "On-screen popup when learning new rank.")
    a7:SetParent(alertsCard)
    contentY = contentY - 24

    local a8 = Check(alertsCard, "Show pet XP bar", "petXpBar", 10, contentY, "Display pet experience bar under pet frame.")
    a8:SetParent(alertsCard)
    contentY = contentY - 24

    local petXpOpts = Button(alertsCard, "Customize XP Bar", 120, function() if ns.TogglePetXPOptions then ns.TogglePetXPOptions() end end)
    petXpOpts:SetPoint("LEFT", 140, contentY + 2)
    contentY = contentY - 24

    alertsCard:SetHeight(math.abs(contentY) + 10)
    y = y + math.abs(contentY) + 20

    -- Zone Tracker Card
    local trackerCard = CreateSettingsCard(child, "Zone Tracker")
    trackerCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    trackerCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    contentY = -40

    local t1 = Check(trackerCard, "Show zone tracker", "tracker", 10, contentY, "Show panel listing tameable beasts in current zone.")
    t1:SetParent(trackerCard)
    contentY = contentY - 24

    local t2 = Check(trackerCard, "Hide when nothing to tame", "trackerAutoHide", 10, contentY, "Only show when new ranks available.")
    t2:SetParent(trackerCard)
    contentY = contentY - 24

    local resetPos = Button(trackerCard, "Reset Tracker Position", 160, function()
      ns.db.trackerPos = nil
      if ns.PlaceTracker then ns.PlaceTracker() end
    end)
    resetPos:SetPoint("TOPLEFT", 10, contentY + 2)
    contentY = contentY - 24

    trackerCard:SetHeight(math.abs(contentY) + 10)
    y = y + math.abs(contentY) + 20

    -- Minimap Button Card
    local minimapCard = CreateSettingsCard(child, "Minimap & Waypoints")
    minimapCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    minimapCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    contentY = -40

    mmCheck = CreateFrame("CheckButton", nil, minimapCard, "UICheckButtonTemplate")
    mmCheck:SetSize(22, 22)
    mmCheck:SetPoint("TOPLEFT", 10, contentY)
    mmCheck:SetChecked(not ns.db.minimap.hide)
    local mmText = mmCheck.text or mmCheck.Text or mmCheck:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    mmText:SetFontObject("GameFontHighlightSmall")
    mmText:ClearAllPoints()
    mmText:SetPoint("LEFT", mmCheck, "RIGHT", 2, 0)
    mmText:SetText("Show minimap button")
    mmCheck:SetScript("OnClick", function() if ns.ToggleMinimapButton then ns.ToggleMinimapButton() end end)

    local clear = Button(minimapCard, "Clear Waypoints", 130, function() Geo.ClearWaypoints() end)
    clear:SetPoint("LEFT", 140, contentY + 2)
    contentY = contentY - 30

    minimapCard:SetHeight(math.abs(contentY) + 10)
    y = y + math.abs(contentY) + 20

    -- Version Card
    local versionCard = CreateSettingsCard(child, "About")
    versionCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    versionCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)

    local versionText = versionCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    versionText:SetPoint("TOPLEFT", 10, -40)
    versionText:SetText("Beast Training Tracker  |cffffffff" .. ns.VersionText() .. "|r")

    versionCard:SetHeight(60)
    y = y + 70

    child:SetHeight(math.max(1, y))

    -- Update route color display
    local r, g, b, a = ns.Geo.RouteColor()
    swatch.color:SetColorTexture(r, g, b, 1)
    alpha:SetValue(a)
  end
  p:SetScript("OnShow", p.Refresh)
end

------------------------------------------------------------------------
-- Tab 6: Backup (Card-based redesign)
------------------------------------------------------------------------
StaticPopupDialogs["BTT_NO_QUESTIE"] = {
  text = "Beast Training Tracker\n\nQuestie isn't installed, so most beast locations are unknown.\n\n"
    .. "Map pins, waypoints and hunt routes will only include beasts you've spotted yourself "
    .. "(targeted, moused over or seen a nameplate). Install Questie to see every beast's spawn points.",
  button1 = OKAY or "OK",
  button2 = "Don't remind me",
  OnCancel = function()
    if ns.db then ns.db.opts.hideQuestieWarning = true end
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = false,
  preferredIndex = 3,
}

ns.OnLogin(function()
  if C_Timer then
    C_Timer.After(8, function()
      if ns.db and not ns.db.opts.hideQuestieWarning and not ns.Geo.HasQuestie() then
        StaticPopup_Show("BTT_NO_QUESTIE")
      end
    end)
  end
end)

StaticPopupDialogs["BTT_RESET_DATA"] = {
  text = "Beast Training Tracker\n\nWipe ALL saved learned ranks for this character?\nOpen Beast Training afterwards to resync.",
  button1 = YES or "Yes",
  button2 = NO or "No",
  OnAccept = function() ns.ResetData() end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = true,
  showAlert = true,
  preferredIndex = 3,
}

local function TextArea(parent, x, y, w, h)
  local bg = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  bg:SetPoint("TOPLEFT", x, y)
  bg:SetSize(w, h)
  if bg.SetBackdrop then
    bg:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 12,
      insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    bg:SetBackdropColor(0, 0, 0, 0.6)
    bg:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
  end
  local sf = CreateFrame("ScrollFrame", nil, bg, "UIPanelScrollFrameTemplate")
  sf:SetPoint("TOPLEFT", 8, -8)
  sf:SetPoint("BOTTOMRIGHT", -28, 8)
  local eb = CreateFrame("EditBox", nil, sf)
  eb:SetMultiLine(true)
  eb:SetFontObject("ChatFontNormal")
  eb:SetWidth(w - 40)
  eb:SetHeight(h - 16)
  eb:SetAutoFocus(false)
  eb:SetScript("OnEscapePressed", eb.ClearFocus)
  sf:SetScrollChild(eb)
  bg:EnableMouse(true)
  bg:SetScript("OnMouseDown", function() eb:SetFocus() end)
  return eb, bg
end

do
  local p = panels[ns.TAB.backup]
  local scroll, child = Scroll(p, -6, 4)

  local function CreateBackupCard(title)
    local card = CreateFrame("Frame", nil, child, BackdropTemplateMixin and "BackdropTemplate" or nil)
    card:SetBackdrop({
      bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    card:SetBackdropColor(0.95, 0.92, 0.82, 0.3)
    card:SetBackdropBorderColor(0.70, 0.62, 0.45, 0.6)

    if title then
      local titleFs = card:CreateFontString(nil, "OVERLAY", "GameFontNormal")
      titleFs:SetPoint("TOPLEFT", 10, -8)
      titleFs:SetText(title)
      titleFs:SetTextColor(1, 0.82, 0)
      card.title = titleFs
    end

    return card
  end

  function p.Refresh()
    if not p:IsShown() then return end
    local y = 0

    -- Export Card
    local exportCard = CreateBackupCard("|cff40ff40Export Your Data|r")
    exportCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    exportCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    exportCard:SetHeight(150)

    local exportDesc = exportCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    exportDesc:SetPoint("TOPLEFT", 10, -28)
    exportDesc:SetWidth(500)
    exportDesc:SetJustifyH("LEFT")
    exportDesc:SetWordWrap(true)
    exportDesc:SetText("Copy this text to back up your learned ranks or move them to another character/PC.")

    local exportBox, exportBg = TextArea(exportCard, 10, -50, 540, 80)
    exportBox:SetScript("OnTextChanged", function(self, user)
      if user then self:SetText(ns.Export()); self:HighlightText() end
    end)
    exportBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

    local selectBtn = Button(exportCard, "Select All", 100, function() exportBox:SetFocus(); exportBox:HighlightText() end)
    selectBtn:SetPoint("TOPLEFT", 10, -136)

    y = y + 160

    -- Import Card
    local importCard = CreateBackupCard("|cff69ccf0Import Data|r")
    importCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    importCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)
    importCard:SetHeight(170)

    local importDesc = importCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    importDesc:SetPoint("TOPLEFT", 10, -28)
    importDesc:SetWidth(500)
    importDesc:SetJustifyH("LEFT")
    importDesc:SetWordWrap(true)
    importDesc:SetText("Paste an export text below and click Import. This only ADDS ranks - nothing is removed.")

    local importBox, importBg = TextArea(importCard, 10, -50, 540, 80)

    local result = importCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    result:SetPoint("TOPLEFT", 10, -136)

    local importBtn = Button(importCard, "Import", 100, function()
      local added, skipped, tamedAdded = ns.Import(importBox:GetText())
      if not added then
        result:SetText("|cffff4040Error: " .. skipped .. "|r")
      else
        result:SetText(("%sImported: %d new rank%s, %d tamed pet%s|r%s"):format(GREEN, added, added == 1 and "" or "s",
          tamedAdded or 0, tamedAdded == 1 and "" or "s",
          skipped > 0 and ("  |cff808080(%d skipped)|r"):format(skipped) or ""))
        importBox:SetText("")
        exportBox:SetText(ns.Export())
      end
    end)
    importBtn:SetPoint("LEFT", result, "RIGHT", 12, 0)

    y = y + 180

    -- Data Info Card
    local infoCard = CreateBackupCard("|cffffd100Data Storage|r")
    infoCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    infoCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)

    local infoText = infoCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    infoText:SetPoint("TOPLEFT", 10, -28)
    infoText:SetWidth(500)
    infoText:SetJustifyH("LEFT")
    infoText:SetWordWrap(true)

    local explicit = 0
    for _ in pairs(ns.db.known) do explicit = explicit + 1 end
    infoText:SetText(("%d ranks saved for this character. A copy is also kept account-wide and restored automatically if data is lost."):format(explicit))

    infoCard:SetHeight(80)
    y = y + 90

    -- Reset Card
    local resetCard = CreateBackupCard("|cffff6060Reset Data|r")
    resetCard:SetPoint("TOPLEFT", child, "TOPLEFT", 0, -y)
    resetCard:SetPoint("RIGHT", child, "RIGHT", -4, 0)

    local resetDesc = resetCard:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    resetDesc:SetPoint("TOPLEFT", 10, -28)
    resetDesc:SetWidth(500)
    resetDesc:SetJustifyH("LEFT")
    resetDesc:SetWordWrap(true)
    resetDesc:SetText("If your saved data looks broken: export a backup first, then reset it. Open Beast Training afterwards to rebuild.")

    local resetBtn = Button(resetCard, "Reset Data", 110, function() StaticPopup_Show("BTT_RESET_DATA") end)
    resetBtn:SetPoint("TOPLEFT", 10, -60)

    resetCard:SetHeight(100)
    y = y + 110

    child:SetHeight(math.max(1, y))
  end
  p:SetScript("OnShow", p.Refresh)
end

------------------------------------------------------------------------
-- Minimap button (LibDBIcon)
------------------------------------------------------------------------
local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
local DBI = LibStub and LibStub("LibDBIcon-1.0", true)
local launcher

if LDB then
  launcher = LDB:NewDataObject("BeastTrainingTracker", {
    type = "launcher",
    label = "Beast Training",
    text = "Beast Training",
    icon = "Interface\\Icons\\Ability_Hunter_BeastTraining",
    OnClick = function(_, button)
      if button == "RightButton" then
        if IsShiftKeyDown() then
          if ns.db.alertsOff then
            ns.db.opts.alertTarget = ns.db.alertsSaved.alertTarget
            ns.db.opts.alertNameplate = ns.db.alertsSaved.alertNameplate
            ns.db.opts.alertSound = ns.db.alertsSaved.alertSound
            ns.db.alertsOff = false
            ns.Say("Alerts enabled")
          else
            ns.db.alertsSaved = {
              alertTarget = ns.db.opts.alertTarget,
              alertNameplate = ns.db.opts.alertNameplate,
              alertSound = ns.db.opts.alertSound,
            }
            ns.db.opts.alertTarget = false
            ns.db.opts.alertNameplate = false
            ns.db.opts.alertSound = false
            ns.db.alertsOff = true
            ns.Say("Alerts disabled")
          end
          ns.Refresh()
        else
          Geo.TogglePins()
        end
      elseif button == "MiddleButton" then
        ns.db.opts.tracker = not ns.db.opts.tracker
        ns.Refresh()
      else
        ns.ToggleMain()
      end
    end,
    OnTooltipShow = function(tt)
      if not ns.db then return end
      tt:AddLine("|cffabd473Beast Training Tracker|r")
      local known, total = ns.Counts()
      tt:AddDoubleLine("Ranks learned", ("%d / %d"):format(known, total), 1, 0.82, 0, 1, 1, 1)
      local fam = ns.PetFamily()
      if fam then
        tt:AddDoubleLine("Pet", ("%s (%s, lvl %d)"):format(UnitName("pet") or fam, fam, UnitLevel("pet") or 0), 1, 0.82, 0, 1, 1, 1)
        local ups = 0
        for _, u in ipairs(ns.Upgrades()) do if not u.needLevel then ups = ups + 1 end end
        if ups > 0 then tt:AddDoubleLine("Upgrades to teach", ups, 1, 0.82, 0, 0.25, 1, 0.25) end
      end
      local need = ns.NeededHere()
      tt:AddLine(" ")
      if #need > 0 then
        tt:AddLine(("Tameable in %s:"):format(ns.CurrentZone()), 0.25, 1, 0.25)
        for i = 1, math.min(8, #need) do
          local e = need[i]
          local who = {}
          for _, t in ipairs(e.teachers) do
            who[#who + 1] = t.name
            if #who >= 2 then break end
          end
          tt:AddDoubleLine(("%s %d"):format(e.ab.name, e.rank.rank), table.concat(who, ", "), 1, 1, 1, 0.25, 1, 0.25)
        end
        if #need > 8 then tt:AddLine(("+%d more"):format(#need - 8), 0.5, 0.5, 0.5) end
      else
        tt:AddLine("Nothing new to tame in this zone", 0.6, 0.6, 0.6)
      end
      local plan = ns.HuntPlan(ns.db.opts.huntPetOnly, ns.db.opts.huntDungeons, "count")
      if plan[1] then
        tt:AddDoubleLine("Best next hunt", ("%s (%d)"):format(plan[1].zone, #plan[1].entries), 1, 0.82, 0, 1, 1, 1)
      end
      tt:AddLine(" ")
      tt:AddLine("|cffffffffLeft-click|r open / close", 0.6, 0.6, 0.6)
      tt:AddLine(("|cffffffffRight-click|r %s beast pins on the map"):format(ns.db.opts.pinsOff and "show" or "hide"), 0.6, 0.6, 0.6)
      tt:AddLine("|cffffffffShift+Right-click|r toggle alerts", 0.6, 0.6, 0.6)
      tt:AddLine("|cffffffffMiddle-click|r toggle zone tracker", 0.6, 0.6, 0.6)
    end,
  })
end

function ns.ToggleMinimapButton()
  ns.db.minimap.hide = not ns.db.minimap.hide
  if DBI then
    if ns.db.minimap.hide then DBI:Hide("BeastTrainingTracker") else DBI:Show("BeastTrainingTracker") end
  end
  Say("minimap button " .. (ns.db.minimap.hide and "hidden" or "shown"))
  if mmCheck then mmCheck:SetChecked(not ns.db.minimap.hide) end
end

ns.OnRefresh(function()
  if launcher then
    local known, total = ns.Counts()
    launcher.text = ("%d/%d"):format(known, total)
  end
end)

ns.OnInit(function(db)
  if db.pos then
    f:ClearAllPoints()
    f:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
  end
  if db.frameSize then
    local w, h = db.frameSize[1], db.frameSize[2]
    w = math.max(MIN_WIDTH, math.min(MAX_WIDTH, w))
    h = math.max(MIN_HEIGHT, math.min(MAX_HEIGHT, h))
    f:SetSize(w, h)
  end
  if DBI and launcher and not DBI:IsRegistered("BeastTrainingTracker") then
    DBI:Register("BeastTrainingTracker", launcher, db.minimap)
  end
end)
