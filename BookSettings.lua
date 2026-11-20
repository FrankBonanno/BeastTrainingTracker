local _, ns = ...

-- Book tab 5: Settings, laid out as the preferences pages of a hunter's journal.
-- Same db keys, callbacks and tooltips as the old Settings tab in UI.lua.

local B = ns.Book
local Geo = ns.Geo
local INK, INK_DIM, INK_GOOD = B.INK, B.INK_DIM, B.INK_GOOD

local COL_W = 330
local COL_X = { 0, 372 }
local STEP = 24

local Render -- forward
local page = B.RegisterTab(8, { render = function() Render() end })

local sheets = {}
for i = 1, 2 do
  local s = CreateFrame("Frame", nil, page)
  s:SetAllPoints()
  s:Hide()
  sheets[i] = s
end

------------------------------------------------------------------------
-- Widgets
------------------------------------------------------------------------
local checks = {}

-- Morpheus heading + swirl divider; returns the y where the section's rows start
local function Section(parent, col, y, text)
  local fs = B.JournalFont(parent, 18, "GameFontNormalLarge")
  fs:SetPoint("TOPLEFT", COL_X[col], -y)
  fs:SetText(text)
  local d = parent:CreateTexture(nil, "ARTWORK")
  d:SetAtlas("spellbook-divider")
  d:SetSize(COL_W, 11)
  d:SetPoint("TOPLEFT", COL_X[col] - 8, -(y + 21))
  return y + 36
end

local function Tip(owner, title, text)
  owner:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title, 1, 0.82, 0)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  owner:SetScript("OnLeave", GameTooltip_Hide)
end

local function CheckBox(parent, col, y, label)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("TOPLEFT", COL_X[col], -y)
  local fs = cb.text or cb.Text
  if not fs then
    fs = cb:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontNormalSmall")
  fs:SetShadowOffset(0, 0)
  B.Ink(fs, INK)
  fs:SetText(label)
  return cb
end

-- Same semantics as Check() in UI.lua: write the option, run onChange, refresh everything
local function Check(parent, col, y, label, key, tip, onChange)
  local cb = CheckBox(parent, col, y, label)
  cb:SetScript("OnClick", function(self)
    ns.db.opts[key] = self:GetChecked() and true or false
    if onChange then onChange(ns.db.opts[key]) end
    ns.Refresh()
  end)
  if tip then Tip(cb, label, tip) end
  cb.key = key
  checks[#checks + 1] = cb
  return cb
end

local function Button(parent, text, w, onClick)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

local function InkText(fs, color)
  if not fs then return end
  fs:SetShadowOffset(0, 0)
  B.Ink(fs, color or INK)
end

------------------------------------------------------------------------
-- Page 1: map pins, hunt route (left)  ·  optional addons (right)
------------------------------------------------------------------------
local s1 = sheets[1]

local y = Section(s1, 1, 0, "Map Pins")
Check(s1, 1, y, "Show teachers on the world map", "mapPins",
  "Pins for every beast that teaches a missing rank you can tame now. Click a pin for a waypoint.")
y = y + STEP
Check(s1, 1, y, "Show teachers on the minimap", "minimapPins",
  "Pins on the minimap for the nearest teachers in your zone.")
y = y + STEP
Check(s1, 1, y, "Hide ALL beast pins", "pinsOff",
  "Master switch for every pin this addon draws. Same as right-clicking the minimap button.",
  function() Geo.QueuePins(true) end)
y = y + STEP
Check(s1, 1, y, "Show untamed special pets on the map", "rarePins",
  "Pins for untamed rares (and outdoor elites / quest spawns) you can tame, even if they teach nothing you need.")
y = y + STEP + 18

y = Section(s1, 1, y, "Hunt Route")
Check(s1, 1, y, "Open the map on the first waypoint", "routeOpenMap",
  "When you set waypoints, open the world map on the first stop (not in combat).")
y = y + STEP
Check(s1, 1, y, "Draw the hunt route on the world map", "routeLines",
  "Numbered stops joined by a dotted line, nearest first. Pick the color and opacity below.",
  function() ns.Geo.DrawRoute() end)
y = y + STEP + 8

-- Route line color + opacity (ColorPickerFrame handling copied from UI.lua)
local colorLabel = B.Font(s1, "GameFontNormalSmall")
colorLabel:SetPoint("TOPLEFT", COL_X[1] + 4, -(y + 5))
colorLabel:SetText("Route line color")

local swatch = CreateFrame("Button", nil, s1, BackdropTemplateMixin and "BackdropTemplate" or nil)
swatch:SetSize(48, 20)
swatch:SetPoint("LEFT", colorLabel, "RIGHT", 12, 0)
if swatch.SetBackdrop then
  swatch:SetBackdrop({ edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 8 })
  swatch:SetBackdropBorderColor(INK[1], INK[2], INK[3], 1)
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
Tip(swatch, "Route line color", "Click to pick the color of the dotted hunt route on the world map.")

local alpha = CreateFrame("Slider", "BeastTrainingTrackerBookRouteAlpha", s1, "OptionsSliderTemplate")
alpha:SetWidth(200)
alpha:SetPoint("TOPLEFT", COL_X[1] + 8, -(y + 52))
alpha:SetMinMaxValues(0.1, 1)
alpha:SetValueStep(0.05)
if alpha.SetObeyStepOnDrag then alpha:SetObeyStepOnDrag(true) end
local low = alpha.Low or _G["BeastTrainingTrackerBookRouteAlphaLow"]
local high = alpha.High or _G["BeastTrainingTrackerBookRouteAlphaHigh"]
local alphaLabel = alpha.Text or _G["BeastTrainingTrackerBookRouteAlphaText"]
InkText(low, INK_DIM)
InkText(high, INK_DIM)
InkText(alphaLabel, INK)
if low then low:SetText("10%") end
if high then high:SetText("100%") end

local function AlphaText(v)
  if alphaLabel then alphaLabel:SetText(("Opacity: %d%%"):format(v * 100)) end
end

alpha:SetScript("OnValueChanged", function(self, v)
  v = math.floor(v * 20 + 0.5) / 20
  AlphaText(v)
  if ns.db and ns.db.opts.routeAlpha ~= v then
    ns.db.opts.routeAlpha = v
    ns.Geo.DrawRoute()
  end
end)

local resetColor = Button(s1, "Default", 80, function()
  local d = ns.Geo.ROUTE_DEFAULT
  ns.db.opts.routeAlpha = d.a
  alpha:SetValue(d.a)
  SetRouteColor(d.r, d.g, d.b)
end)
resetColor:SetPoint("LEFT", swatch, "RIGHT", 16, 0)

local function ShowRouteColor()
  local r, g, b, a = ns.Geo.RouteColor()
  swatch.color:SetColorTexture(r, g, b, 1)
  alpha:SetValue(a)
  -- SetValue doesn't fire OnValueChanged when the value is unchanged
  AlphaText(math.floor(a * 20 + 0.5) / 20)
end

-- Optional addons: green = detected, grey = not installed
local ry = Section(s1, 2, 0, "Optional Addons")
local addonNote = B.Font(s1, "GameFontNormalSmall", INK_DIM)
addonNote:SetPoint("TOPLEFT", COL_X[2], -ry)
addonNote:SetWidth(COL_W)
addonNote:SetWordWrap(true)
addonNote:SetText("Beast Training Tracker works on its own; these add extras.")

local addonRows = {}
local prev = addonNote
for i = 1, 3 do
  local r = {}
  r.dot = s1:CreateTexture(nil, "ARTWORK")
  r.dot:SetSize(12, 12)
  if i == 1 then
    r.dot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 2, -14)
  else
    r.dot:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", -18, -12)
  end
  r.name = B.Font(s1, "GameFontNormal")
  r.name:SetPoint("LEFT", r.dot, "RIGHT", 6, 0)
  r.text = B.Font(s1, "GameFontNormalSmall")
  r.text:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.text:SetWidth(COL_W - 20)
  r.text:SetWordWrap(true)
  addonRows[i] = r
  prev = r.text
end

------------------------------------------------------------------------
-- Page 2: alerts, pet XP bar (left)  ·  zone tracker, minimap & waypoints (right)
------------------------------------------------------------------------
local s2 = sheets[2]

y = Section(s2, 1, 0, "Alerts")
Check(s2, 1, y, "Alert when I target or mouse over a teacher", "alertTarget",
  "Big on-screen message when a beast you can tame teaches something you need.")
y = y + STEP
Check(s2, 1, y, "Alert when a teacher's nameplate appears", "alertNameplate",
  "Same alert as soon as a teacher's nameplate shows up nearby (needs enemy nameplates on).")
y = y + STEP
Check(s2, 1, y, "Play a sound with alerts", "alertSound", "Raid-warning sound when an alert fires.")
y = y + STEP
Check(s2, 1, y, "Remind me about pet upgrades", "upgradeAlert",
  "Chat reminder when you know a better rank than your pet has.")
y = y + STEP
Check(s2, 1, y, "Pet level-up nudges", "levelNudge", "Chat message when your pet reaches the level for a new rank.")
y = y + STEP
Check(s2, 1, y, "Let RareScanner alert for rares", "rsHandlesRares",
  "If RareScanner is installed it already alerts for rares on its list. With this on, Beast Training Tracker skips its own alert for those so you don't get two.")
y = y + STEP
Check(s2, 1, y, "Popup when I learn a new ability", "learnToast",
  "On-screen popup (with sound) whenever a new pet ability rank is learned - e.g. from a beast you just tamed.")
y = y + STEP + 18

y = Section(s2, 1, y, "Pet XP Bar")
Check(s2, 1, y, "Show a pet XP bar", "petXpBar",
  "Thin bar with your pet's experience, under your pet's frame. Mouse over it for numbers. Drag to move it, right-click it for options.")
y = y + STEP + 4
local petXpOpts = Button(s2, "Customize...", 100, function() if ns.TogglePetXPOptions then ns.TogglePetXPOptions() end end)
petXpOpts:SetPoint("TOPLEFT", COL_X[1] + 4, -y)

y = Section(s2, 2, 0, "Zone Tracker")
Check(s2, 2, y, "Show the zone tracker", "tracker",
  "Small movable panel listing what you can tame in your current zone. Click a line for a waypoint.")
y = y + STEP
Check(s2, 2, y, "Hide it when there's nothing to tame", "trackerAutoHide",
  "Only show the tracker in zones with something new for you.")
y = y + STEP + 4
local resetPos = Button(s2, "Reset tracker position", 160, function()
  ns.db.trackerPos = nil
  if ns.PlaceTracker then ns.PlaceTracker() end
end)
resetPos:SetPoint("TOPLEFT", COL_X[2] + 4, -y)
y = y + 22 + 22

y = Section(s2, 2, y, "Minimap & Waypoints")
-- Not an opts key: the LibDBIcon state lives in ns.db.minimap and ns.ToggleMinimapButton flips it
local mmCheck = CheckBox(s2, 2, y, "Show the minimap button")
mmCheck:SetScript("OnClick", function(self)
  if ns.ToggleMinimapButton then ns.ToggleMinimapButton() end
  self:SetChecked(not (ns.db.minimap and ns.db.minimap.hide))
end)
Tip(mmCheck, "Show the minimap button", "Works with minimap button collectors.")
y = y + STEP + 4
local clear = Button(s2, "Clear waypoints", 160, function() Geo.ClearWaypoints() end)
clear:SetPoint("TOPLEFT", COL_X[2] + 4, -y)

------------------------------------------------------------------------
-- Render
------------------------------------------------------------------------
local function VersionNote()
  if ns.Version() == "dev" then
    return "Beast Training Tracker - " .. ns.VersionText()
  end
  return "Beast Training Tracker, version " .. ns.VersionText()
end

Render = function()
  local n = B.SetPager(#sheets)
  for i, s in ipairs(sheets) do s:SetShown(i == n) end

  local o = ns.db.opts
  for _, cb in ipairs(checks) do cb:SetChecked(o[cb.key] and true or false) end
  mmCheck:SetChecked(not (ns.db.minimap and ns.db.minimap.hide))
  ShowRouteColor()

  local found, status = 0, Geo.AddonStatus()
  for i, a in ipairs(status) do
    if a.on then found = found + 1 end
    local r = addonRows[i]
    if r then
      r.dot:SetTexture(a.on and "Interface\\COMMON\\Indicator-Green" or "Interface\\COMMON\\Indicator-Gray")
      r.name:SetText(a.name)
      B.Ink(r.name, a.on and INK_GOOD or INK_DIM)
      r.text:SetText(a.text)
      B.Ink(r.text, a.on and INK or INK_DIM)
    end
  end
  B.SetStats({
    { "Addons found", ("%d / %d"):format(found, #status) },
    { "Version", ns.Version() },
  })

  if n == 1 then
    B.SetFieldNote(VersionNote())
  else
    B.SetFieldNote("Right-click the minimap button to hide every pin; middle-click it for the zone tracker.")
  end
end
