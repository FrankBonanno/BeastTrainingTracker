local _, ns = ...

-- Tab 6: Backup. Export / import on a two-column spread, then "Your records" and Reset.

local Book = ns.Book
local INK, INK_DIM, INK_GOOD, INK_RED = Book.INK, Book.INK_DIM, Book.INK_GOOD, Book.INK_RED

local tab = {}
local page = Book.RegisterTab(9, tab)

local PAGE_W = Book.W - 62 - 50
local GAP = 28
local COL = math.floor((PAGE_W - GAP) / 2)
local RIGHT_X = COL + GAP
local BOX_TOP, BOX_H = -66, 124
local RECORDS_TOP = -236
local DIM_HEX = "|cff6b4f33" -- INK_DIM as a color code

local function Heading(x, y, text, w)
  local h = Book.JournalFont(page, 18, "SystemFont_Med3")
  h:SetPoint("TOPLEFT", x, y)
  h:SetText(text)
  local d = page:CreateTexture(nil, "ARTWORK")
  d:SetAtlas("spellbook-divider")
  d:SetSize(w, 11)
  d:SetPoint("TOPLEFT", x - 6, y - 22)
  return h
end

local function Body(x, y, w, text)
  local fs = Book.Font(page, "SystemFont_Med1")
  fs:SetPoint("TOPLEFT", x, y)
  fs:SetWidth(w)
  fs:SetWordWrap(true)
  fs:SetText(text)
  return fs
end

-- Dark inset with a bronze edge so the edit box reads on parchment
local function TextArea(x, y, w, h)
  local bg = CreateFrame("Frame", nil, page)
  bg:SetPoint("TOPLEFT", x, y)
  bg:SetSize(w, h)
  local edge = bg:CreateTexture(nil, "BACKGROUND", nil, 1)
  edge:SetAllPoints()
  edge:SetColorTexture(0.60, 0.48, 0.28, 1)
  local fill = bg:CreateTexture(nil, "BACKGROUND", nil, 2)
  fill:SetPoint("TOPLEFT", 1, -1)
  fill:SetPoint("BOTTOMRIGHT", -1, 1)
  fill:SetColorTexture(0.16, 0.11, 0.07, 0.85)

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

local function Button(text, w, onClick)
  local b = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
  b:SetSize(w, 22)
  b:SetText(text)
  b:SetScript("OnClick", onClick)
  return b
end

------------------------------------------------------------------------
-- Export (left column)
------------------------------------------------------------------------
Heading(0, 0, "Export", COL + 12)
Body(0, -34, COL, "Copy this text (Ctrl+C) to back up your learned ranks or move them to another PC.")

local exportBox, exportBg = TextArea(0, BOX_TOP, COL, BOX_H)
local exportSig
-- read-only: any typing puts the export back
exportBox:SetScript("OnTextChanged", function(self, user)
  if user then self:SetText(ns.Export()); self:HighlightText() end
end)
exportBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)

local selectAll = Button("Select all", 100, function() exportBox:SetFocus(); exportBox:HighlightText() end)
selectAll:SetPoint("TOPLEFT", exportBg, "BOTTOMLEFT", 0, -8)

------------------------------------------------------------------------
-- Import (right column)
------------------------------------------------------------------------
Heading(RIGHT_X, 0, "Import", COL + 12)
Body(RIGHT_X, -34, COL, "Paste an export (Ctrl+V) and press Import. It only ADDS ranks - nothing you have is removed.")

local importBox, importBg = TextArea(RIGHT_X, BOX_TOP, COL, BOX_H)
local hint = importBg:CreateFontString(nil, "OVERLAY", "GameFontDisable")
hint:SetPoint("TOPLEFT", 10, -10)
hint:SetText("Paste an export here")
local function UpdateHint()
  hint:SetShown(importBox:GetText() == "" and not importBox:HasFocus())
end
importBox:SetScript("OnTextChanged", UpdateHint)
importBox:SetScript("OnEditFocusGained", UpdateHint)
importBox:SetScript("OnEditFocusLost", UpdateHint)

local status = Book.Font(page, "GameFontNormalSmall")
local importBtn = Button("Import", 100, function()
  local added, skipped, tamedAdded = ns.Import(importBox:GetText())
  if not added then
    Book.Ink(status, INK_RED)
    status:SetText(skipped)
  else
    Book.Ink(status, INK_GOOD)
    status:SetText(("Imported: %d new rank%s, %d tamed pet%s%s"):format(added, added == 1 and "" or "s",
      tamedAdded or 0, tamedAdded == 1 and "" or "s",
      skipped > 0 and ("  %s(%d entries skipped)|r"):format(DIM_HEX, skipped) or ""))
    importBox:SetText("")
    importBox:ClearFocus()
    exportBox:SetText(ns.Export())
    exportSig = (ns.learnedSerial or 0) .. ":" .. (ns.tamedSerial or 0)
  end
end)
importBtn:SetPoint("TOPLEFT", importBg, "BOTTOMLEFT", 0, -8)
status:SetPoint("LEFT", importBtn, "RIGHT", 12, 0)
status:SetWidth(COL - 112)
status:SetWordWrap(true)

------------------------------------------------------------------------
-- Your records (full width): spellbook-style stat lines + reset
------------------------------------------------------------------------
Heading(0, RECORDS_TOP, "Your records", PAGE_W + 12)

local function Record(i, icon)
  local r = CreateFrame("Frame", nil, page)
  r:SetSize(Book.COL_W - 6, 56)
  r:SetPoint("TOPLEFT", (i - 1) * Book.COL_W, RECORDS_TOP - 40)
  r:EnableMouse(true)
  r.plate = r:CreateTexture(nil, "BACKGROUND")
  r.plate:SetAtlas("spellbook-item-backplate")
  r.plate:SetPoint("TOPLEFT", -4, 4)
  r.plate:SetPoint("BOTTOMRIGHT", 8, -8)
  r.plate:SetAlpha(0.25)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(40, 40)
  r.icon:SetPoint("TOPLEFT", 11, -6)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.icon:SetTexture(icon)
  r.border = r:CreateTexture(nil, "OVERLAY")
  r.border:SetAtlas("spellbook-item-iconframe")
  r.border:SetSize(52, 48)
  r.border:SetPoint("TOPLEFT", r.icon, "TOPLEFT", -11, 1)
  r.name = Book.Font(r, "SystemFont_Large")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 9, -1)
  r.name:SetWidth(Book.COL_W - 72)
  r.name:SetWordWrap(false)
  r.sub = Book.Font(r, "SystemFont_Med1")
  r.sub:SetPoint("TOPLEFT", r.name, "BOTTOMLEFT", 0, -3)
  r.sub:SetWidth(Book.COL_W - 72)
  r.sub:SetWordWrap(false)
  r:SetScript("OnLeave", GameTooltip_Hide)
  return r
end

-- Characters in the account-wide backup (skips debug entries like __uiDump)
local function BackupKeys()
  local keys = {}
  for k, v in pairs(BeastTrainingTrackerBackup or {}) do
    if type(k) == "string" and type(v) == "table" and not k:find("^__") then keys[#keys + 1] = k end
  end
  table.sort(keys)
  return keys
end

local function CountKeys(t)
  local n = 0
  for _ in pairs(type(t) == "table" and t or {}) do n = n + 1 end
  return n
end

local ranksRec = Record(1, "Interface\\Icons\\Ability_Hunter_BeastTraining")
ranksRec:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Saved for this character", 1, 0.82, 0)
  GameTooltip:AddLine("Learned ranks recorded by Beast Training Tracker. Export them to keep a copy of your own.", 1, 1, 1, true)
  GameTooltip:Show()
end)

local charsRec = Record(2, "Interface\\Icons\\INV_Misc_Book_09")
charsRec:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Account-wide backup", 1, 0.82, 0)
  GameTooltip:AddLine("Restored automatically if a character's data goes missing.", 1, 1, 1, true)
  local backup = BeastTrainingTrackerBackup or {}
  for _, k in ipairs(BackupKeys()) do
    -- entries from 2.1.0 and older have no name; their key is "First-Realm"
    local label = backup[k].name or (k .. " (older backup)")
    GameTooltip:AddDoubleLine(label, ("%d ranks"):format(CountKeys(backup[k].known)), 0.8, 0.8, 0.8, 1, 1, 1)
  end
  GameTooltip:Show()
end)

local syncRec = Record(3, "Interface\\Icons\\INV_Misc_PocketWatch_01")
syncRec:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine("Last Beast Training sync", 1, 0.82, 0)
  GameTooltip:AddLine("Opening the Beast Training window records every rank your pets know.", 1, 1, 1, true)
  GameTooltip:Show()
end)

local reset = Button("Reset data", 110, function() StaticPopup_Show("BTT_RESET_DATA") end)
reset:SetPoint("TOPLEFT", 0, RECORDS_TOP - 118)
local warning = Book.Font(page, "SystemFont_Med1", INK_RED)
warning:SetPoint("LEFT", reset, "RIGHT", 12, 0)
warning:SetWidth(PAGE_W - 122)
warning:SetWordWrap(true)
warning:SetText("If the saved data looks broken: wipe it, then open Beast Training to rebuild it. Export first if unsure.")

------------------------------------------------------------------------
-- Render
------------------------------------------------------------------------
-- forces a fresh export the next time the tab is opened
page:SetScript("OnHide", function() exportSig = nil end)

function tab.render()
  local sig = (ns.learnedSerial or 0) .. ":" .. (ns.tamedSerial or 0)
  if sig ~= exportSig and not exportBox:HasFocus() then
    exportSig = sig
    exportBox:SetText(ns.Export())
    exportBox:SetCursorPosition(0)
  end
  UpdateHint()

  local ranks = CountKeys(ns.db.known)
  local pets = CountKeys(ns.db.tamedRares)
  local chars = #BackupKeys()

  ranksRec.name:SetText(("%d rank%s"):format(ranks, ranks == 1 and "" or "s"))
  ranksRec.sub:SetText("Saved for this character")
  charsRec.name:SetText(("%d character%s"):format(chars, chars == 1 and "" or "s"))
  charsRec.sub:SetText("In the account-wide backup")
  if ns.db.lastSync then
    syncRec.name:SetText(date("%b %d, %H:%M", ns.db.lastSync))
    Book.Ink(syncRec.name, INK)
    syncRec.sub:SetText("Last Beast Training sync")
  else
    syncRec.name:SetText("Never synced")
    Book.Ink(syncRec.name, INK_DIM)
    syncRec.sub:SetText("Open Beast Training once")
  end

  Book.SetStats({
    { "Ranks saved", tostring(ranks) },
    { "Special pets", tostring(pets) },
    { "Characters", tostring(chars) },
  })
  Book.SetFieldNote("A copy is also kept account-wide and restored automatically if this character's data goes missing.")
end
