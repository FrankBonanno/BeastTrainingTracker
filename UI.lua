local _, ns = ...

-- Shared UI pieces that aren't part of either window: popups, the minimap
-- button, the window style choice (Hunter's Journal in Book.lua or the
-- classic window in ClassicUI.lua) and the entry points that open them.

local Geo = ns.Geo
local Say = ns.Say

-- Journal tab indices. The classic window uses the same keys (ns.Classic.TAB)
-- for the tabs it has.
ns.TAB = { abilities = 1, hunt = 2, rares = 3, pet = 4, chronicle = 5, trophies = 6, skinning = 7, map = 8, backup = 9 }

-- Tabs the classic window doesn't have
local JOURNAL_ONLY = { chronicle = "Chronicle", trophies = "Trophy Room", skinning = "Skinning" }

-- nil until the player picks one; the journal is used until then
local function Classic()
  return ns.db and ns.db.opts.uiStyle == "classic" and ns.Classic ~= nil
end

local function BookFrame() return ns.Book and ns.Book.frame end

function ns.ShowTab(i)
  if ns.Book then ns.Book.Open(i) end
end

-- Open a tab by key ("abilities", "hunt", "map", ...) in the chosen window
function ns.OpenTab(key)
  if Classic() then
    if JOURNAL_ONLY[key] then
      Say(("the %s is part of the Hunter's Journal. Type /btt journal to switch to it."):format(JOURNAL_ONLY[key]))
      return
    end
    ns.Classic.Show(key)
  else
    ns.ShowTab(ns.TAB[key])
  end
end

function ns.ToggleMain()
  if Classic() then
    ns.Classic.Toggle()
  elseif ns.ToggleBook then
    ns.ToggleBook()
  end
end

------------------------------------------------------------------------
-- Window size: one setting for both windows (text gets bigger with them)
------------------------------------------------------------------------
local SCALE_MIN, SCALE_MAX = 0.7, 1.5

function ns.ApplyUIScale()
  local s = (ns.db and ns.db.opts.uiScale) or 1
  local book = BookFrame()
  if book then book:SetScale(s) end
  if ns.Classic then ns.Classic.frame:SetScale(s) end
  -- the secure Beast Training buttons are placed by coordinates, so move them too
  if book and book:IsShown() and ns.Book.PlaceTeach then ns.Book.PlaceTeach() end
  if ns.Classic and ns.Classic.frame:IsShown() then ns.Classic.Place() end
end

function ns.SetUIScale(v)
  v = math.floor(v * 20 + 0.5) / 20
  v = math.max(SCALE_MIN, math.min(SCALE_MAX, v))
  ns.db.opts.uiScale = v
  ns.ApplyUIScale()
end

ns.OnInit(function() ns.ApplyUIScale() end)

------------------------------------------------------------------------
-- Text size: scales the body text inside a window without resizing it.
-- Each font string's own size is remembered the first time it's scaled, so
-- every font keeps its proportions and 100% puts them all back exactly.
-- Headings (over 16pt) are already large and keep their size, so they still
-- fit their place on the page.
------------------------------------------------------------------------
local TEXT_MIN, TEXT_MAX = 0.9, 1.4
local MAX_BODY = 16.5
local fontBase = setmetatable({}, { __mode = "k" }) -- font string -> { path, size, flags, applied }

local function SizeFontString(fs, scale)
  local path, size, flags = fs:GetFont()
  if not (path and size) then return end
  local b = fontBase[fs]
  -- new, or the window gave it a different font since we last sized it
  if not b or path ~= b.path or math.abs(size - b.applied) > 0.25 then
    if scale == 1 and not b then return end -- nothing to do at 100%
    b = { path = path, size = size, flags = flags or "", applied = size }
    fontBase[fs] = b
  end
  if b.size > MAX_BODY then return end
  local want = b.size * scale
  if math.abs(want - b.applied) > 0.01 or math.abs(size - want) > 0.25 then
    if pcall(fs.SetFont, fs, b.path, want, b.flags) then b.applied = want end
  end
end

-- Walks only the shown part of the window: hidden pages are sized when they're drawn
local function SizeFonts(frame, scale)
  if not frame:IsShown() then return end
  for _, r in ipairs({ frame:GetRegions() }) do
    if r:GetObjectType() == "FontString" then SizeFontString(r, scale) end
  end
  for _, c in ipairs({ frame:GetChildren() }) do SizeFonts(c, scale) end
end

-- Called by each window after it draws, and when the setting changes
function ns.ApplyTextSize(frame)
  if not (frame and ns.db) then return end
  SizeFonts(frame, ns.db.opts.textSize or 1)
end

function ns.SetTextSize(v)
  v = math.floor(v * 20 + 0.5) / 20
  v = math.max(TEXT_MIN, math.min(TEXT_MAX, v))
  ns.db.opts.textSize = v
  ns.ApplyTextSize(BookFrame())
  if ns.Classic then ns.ApplyTextSize(ns.Classic.frame) end
end

------------------------------------------------------------------------
-- Window style: "journal" or "classic"
------------------------------------------------------------------------
function ns.SetUIStyle(style)
  if style ~= "classic" then style = "journal" end
  local book = BookFrame()
  local wasOpen = (book and book:IsShown()) or (ns.Classic and ns.Classic.frame:IsShown())
  if book then book:Hide() end
  if ns.Classic then ns.Classic.frame:Hide() end
  ns.db.opts.uiStyle = style
  -- remembered account-wide: other characters start with it and are never asked
  if BeastTrainingTrackerBackup then BeastTrainingTrackerBackup.__uiStyle = style end
  -- reopen on Settings, where the switch was made
  if wasOpen then ns.OpenTab("map") end
  Say(style == "classic" and "using the classic window. Switch back in Settings or with /btt journal."
    or "using the Hunter's Journal. Switch back in Settings or with /btt classic.")
end

-- Asked once per account: the first answer is saved in BeastTrainingTrackerBackup
-- and every character after that uses it without asking.
StaticPopupDialogs["BTT_CHOOSE_STYLE"] = {
  text = "Beast Training Tracker\n\nWhich window would you like?\n\n"
    .. "|cffffd100Hunter's Journal|r (new in 2.0): drawn like the spellbook, with the Chronicle, Trophy Room and Skinning tabs.\n\n"
    .. "|cffffd100Classic|r: the simple dark window from 1.x, with light text.\n\n"
    .. "You can change this, and the window size, in Settings at any time.",
  button1 = "Hunter's Journal",
  button2 = "Classic",
  OnAccept = function() ns.SetUIStyle("journal") end,
  OnCancel = function(_, _, reason)
    -- the Classic button picks classic; if the popup is closed any other way,
    -- keep the journal so it still never comes back
    ns.SetUIStyle(reason == "clicked" and "classic" or "journal")
  end,
  timeout = 0,
  whileDead = true,
  hideOnEscape = false,
  preferredIndex = 3,
}

ns.OnLogin(function()
  if C_Timer then
    C_Timer.After(5, function()
      if not (ns.db and ns.isHunter) or ns.db.opts.uiStyle ~= nil then return end
      local chosen = BeastTrainingTrackerBackup and BeastTrainingTrackerBackup.__uiStyle
      if chosen then
        ns.db.opts.uiStyle = chosen -- already answered on another character
      else
        StaticPopup_Show("BTT_CHOOSE_STYLE")
      end
    end)
  end
end)

------------------------------------------------------------------------
-- Popups
------------------------------------------------------------------------
-- Shown after login when Questie isn't installed: without it, beast
-- locations are limited to what you've spotted yourself.
StaticPopupDialogs["BTT_NO_QUESTIE"] = {
  text = "Beast Training Tracker\n\nQuestie isn't installed, so most beast locations are unknown.\n\n"
    .. "Map pins, waypoints and hunt routes will only include beasts you've spotted yourself "
    .. "(targeted, moused over or seen a nameplate). Install Questie to see every beast's spawn points.",
  button1 = OKAY or "OK",
  button2 = "Don't remind me",
  OnCancel = function()
    -- "Don't remind me" (Escape is off for this popup, so it can't trigger this by accident)
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

------------------------------------------------------------------------
-- Minimap button (LibDBIcon - One For All picks this up automatically)
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
            -- Restore previous settings
            ns.db.opts.alertTarget = ns.db.alertsSaved.alertTarget
            ns.db.opts.alertNameplate = ns.db.alertsSaved.alertNameplate
            ns.db.opts.alertSound = ns.db.alertsSaved.alertSound
            ns.db.alertsOff = false
            ns.Say("Alerts enabled")
          else
            -- Save current settings and turn off
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
end

ns.OnRefresh(function()
  if launcher then
    local known, total = ns.Counts()
    launcher.text = ("%d/%d"):format(known, total)
  end
end)

ns.OnInit(function(db)
  if DBI and launcher and not DBI:IsRegistered("BeastTrainingTracker") then
    DBI:Register("BeastTrainingTracker", launcher, db.minimap)
  end
end)
