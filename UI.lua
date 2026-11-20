local _, ns = ...

-- Shared UI pieces that aren't part of the book window (Book.lua): popups,
-- the minimap button, and the entry points other files call to open the book.

local Geo = ns.Geo
local Say = ns.Say

ns.TAB = { abilities = 1, hunt = 2, rares = 3, pet = 4, chronicle = 5, trophies = 6, skinning = 7, map = 8, backup = 9 }

function ns.ShowTab(i)
  if ns.Book then ns.Book.Open(i) end
end

function ns.ToggleMain()
  if ns.ToggleBook then ns.ToggleBook() end
end

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
