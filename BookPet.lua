local _, ns = ...

-- Book tab 4 (My Pet): a journal page about your current pet. Page 1 has its
-- portrait (3D model) and notes; the sections below flow onto later pages.

local Book = ns.Book
if not Book then return end
local Geo = ns.Geo

local INK, INK_DIM, INK_GOOD, INK_RED = Book.INK, Book.INK_DIM, Book.INK_GOOD, Book.INK_RED
local Font, JournalFont, Ink = Book.Font, Book.JournalFont, Book.Ink
local COLS, COL_W = Book.COLS, Book.COL_W

local PAGE_H = 428      -- height of the content area
local PROFILE_H = 200   -- page 1: sections start below the portrait and notes
local HEAD_H, ROW_H, NOTE_H, GAP = 32, 46, 22, 8
local NOTES_X = 200
local SOON_LEVELS = 6
local ICON = 32

local HAPPY = {
  [1] = { "Unhappy", INK_RED },
  [2] = { "Content", INK },
  [3] = { "Happy", INK_GOOD },
}

local Render -- forward
local page = Book.RegisterTab(4, { render = function() Render() end })

local function Num(n)
  n = math.floor(n or 0)
  return BreakUpLargeNumbers and BreakUpLargeNumbers(n) or tostring(n)
end

local function PetStats()
  local s = {}
  if GetPetExperience then s.xp, s.xpMax = GetPetExperience() end
  if GetPetHappiness then s.happy, s.dmg, s.loyaltyRate = GetPetHappiness() end
  if GetPetTrainingPoints then
    local total, spent = GetPetTrainingPoints()
    if total then s.tp, s.tpTotal = (total or 0) - (spent or 0), total end
  end
  if GetPetLoyalty then s.loyalty = GetPetLoyalty() end
  if GetPetFoodTypes then
    local foods = { GetPetFoodTypes() }
    if #foods > 0 then s.diet = table.concat(foods, ", ") end
  end
  return s
end

local function RankOf(ab, n)
  for _, r in ipairs(ab.parsed) do
    if r.rank == n then return r end
  end
end

-- Opens the ability's own page in the Abilities tab
local function OpenAbility(ab, rank)
  local st = Book.state
  st.tab, st.ab, st.rank, st.abPage, st.page = 1, ab, rank, 1, 1
  Book.Render()
end

local function WaypointTeachers(ab, r)
  if not (Geo and r) or ab.src == "trainer" or #r.teachers == 0 then return end
  local many = {}
  for pass = 1, 2 do
    for _, t in ipairs(r.teachers) do
      if #many >= 12 then break end
      if (pass == 1) == ns.CanTame(t) then
        many[#many + 1] = { t = t, label = Geo.Label(ab, r, t) }
      end
    end
  end
  Geo.WaypointMany(many)
end

local function AddTeachers(tt, ab, r)
  if ab.src == "trainer" then
    tt:AddLine("Sold by any Pet Trainer", 0.6, 0.8, 1)
    return
  end
  if not r or #r.teachers == 0 then
    tt:AddLine("No known beast teaches this rank", 0.6, 0.6, 0.6)
    return
  end
  for i, t in ipairs(r.teachers) do
    if i > 8 then
      tt:AddLine(("+%d more"):format(#r.teachers - 8), 0.6, 0.6, 0.6)
      break
    end
    local tag = Geo and Geo.Tag and Geo.Tag(t.name) or ""
    tt:AddDoubleLine(t.name .. tag, t.zone, 1, 1, 1, 0.7, 0.7, 0.7)
  end
end

------------------------------------------------------------------------
-- "Beast Training" button. Secure (it casts the spell), so it lives on
-- UIParent and is placed over the page by coordinates: parenting or
-- anchoring it to the book would make the book protected in combat.
------------------------------------------------------------------------
local BT_SPELL = (GetSpellInfo and GetSpellInfo(5149))
  or (C_Spell and C_Spell.GetSpellName and C_Spell.GetSpellName(5149)) or "Beast Training"

local teach = CreateFrame("Button", "BeastTrainingTrackerBookTeachButton", UIParent, "SecureActionButtonTemplate,UIPanelButtonTemplate")
teach:SetSize(124, 22)
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

local function PlaceTeach()
  if InCombatLockdown() then return end
  if page:IsVisible() and UnitExists("pet") and page:GetRight() then
    teach:SetScale(page:GetEffectiveScale() / UIParent:GetEffectiveScale())
    teach:ClearAllPoints()
    teach:SetPoint("TOPRIGHT", UIParent, "BOTTOMLEFT", page:GetRight(), page:GetTop() + 2)
    teach:Show()
  else
    teach:Hide()
  end
end

page:HookScript("OnShow", PlaceTeach)
page:HookScript("OnHide", function()
  if not InCombatLockdown() then teach:Hide() end
end)

-- follow the book while it is dragged
local mover = CreateFrame("Frame")
Book.frame:HookScript("OnDragStart", function() mover:SetScript("OnUpdate", PlaceTeach) end)
Book.frame:HookScript("OnDragStop", function()
  mover:SetScript("OnUpdate", nil)
  PlaceTeach()
end)

------------------------------------------------------------------------
-- Page 1: portrait plate (3D model) + journal notes
------------------------------------------------------------------------
local profile = CreateFrame("Frame", nil, page)
profile:SetPoint("TOPLEFT")
profile:SetPoint("TOPRIGHT")
profile:SetHeight(PROFILE_H - 8)

local plate = CreateFrame("Frame", nil, profile)
plate:SetPoint("TOPLEFT", 0, 0)
plate:SetSize(180, 188)
-- a faint ink wash inside a thin bronze frame, like a sketch pasted into the journal
plate.wash = plate:CreateTexture(nil, "BACKGROUND", nil, 1)
plate.wash:SetAllPoints()
plate.wash:SetColorTexture(INK[1], INK[2], INK[3], 0.10)
for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT" }, { "BOTTOMLEFT", "BOTTOMRIGHT" }, { "TOPLEFT", "BOTTOMLEFT" }, { "TOPRIGHT", "BOTTOMRIGHT" } }) do
  local t = plate:CreateTexture(nil, "BORDER")
  t:SetColorTexture(0.60, 0.48, 0.28, 0.9)
  t:SetPoint(side[1])
  t:SetPoint(side[2])
  if side[1] == "TOPLEFT" and side[2] == "BOTTOMLEFT" or side[1] == "TOPRIGHT" then
    t:SetWidth(1)
  else
    t:SetHeight(1)
  end
end

local model = CreateFrame("PlayerModel", nil, plate)
model:SetPoint("TOPLEFT", 2, -2)
model:SetPoint("BOTTOMRIGHT", -2, 2)

-- drag to turn, wheel to zoom, slowly spins until you touch it
local facing, zoom, spin, dragX, modelGUID = 0, 1, true, nil, nil

local function ShowPetModel(reset)
  if not UnitExists("pet") then
    model:ClearModel()
    modelGUID = nil
    return
  end
  if reset then facing, zoom, spin = 0, 1, true end
  model:SetUnit("pet")
  if model.SetCamDistanceScale then model:SetCamDistanceScale(zoom) end
  model:SetFacing(facing)
  modelGUID = UnitGUID("pet")
end

model:EnableMouse(true)
model:EnableMouseWheel(true)
model:SetScript("OnShow", function() ShowPetModel(false) end)
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
model:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
  GameTooltip:AddLine(UnitName("pet") or "Your pet", 1, 0.82, 0)
  GameTooltip:AddLine("Drag to turn  ·  Mouse wheel to zoom", 0.8, 0.8, 0.8)
  GameTooltip:Show()
end)
model:SetScript("OnLeave", GameTooltip_Hide)

local levelLine = Font(profile, "SystemFont_Large")
levelLine:SetPoint("TOPLEFT", NOTES_X, -2)

-- XP bar styled like the book's pet card
local bar = CreateFrame("StatusBar", nil, profile)
bar:SetSize(300, 6)
bar:SetPoint("TOPLEFT", NOTES_X + 1, -28)
bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")
bar:SetStatusBarColor(0.62, 0.42, 0.95)
bar.edge = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
bar.edge:SetPoint("TOPLEFT", -1, 1)
bar.edge:SetPoint("BOTTOMRIGHT", 1, -1)
bar.edge:SetColorTexture(0.60, 0.48, 0.28, 0.9)
bar.bg = bar:CreateTexture(nil, "BACKGROUND", nil, 2)
bar.bg:SetAllPoints()
bar.bg:SetColorTexture(0.16, 0.11, 0.07, 1)

local xpText = Font(profile, "GameFontNormalSmall", INK_DIM)
xpText:SetPoint("TOPLEFT", NOTES_X, -40)

-- 2 x 2 facts: small caps label over an ink value. Forever doesn't give
-- addons every pet stat, so the slots go to whatever the game does report.
local facts = {}
for i = 1, 4 do
  local col, row = (i - 1) % 2, math.floor((i - 1) / 2)
  local l = Font(profile, "GameFontNormalSmall", INK_DIM)
  l:SetPoint("TOPLEFT", NOTES_X + col * 250, -64 - row * 42)
  local v = Font(profile, "SystemFont_Med1")
  v:SetPoint("TOPLEFT", l, "BOTTOMLEFT", 0, -3)
  v:SetWidth(240)
  v:SetWordWrap(true)
  facts[i] = { label = l, value = v }
end

local function Readable(...)
  if not issecretvalue then return true end
  for i = 1, select("#", ...) do
    if issecretvalue((select(i, ...))) then return false end
  end
  return true
end

local function FillFacts(list)
  for i, f in ipairs(facts) do
    local d = list[i]
    f.label:SetText(d and d[1]:upper() or "")
    f.value:SetText(d and d[2] or "")
    Ink(f.value, d and d[3] or INK)
  end
end

local checks = {}
local function Check(label, key, x, tip)
  local cb = CreateFrame("CheckButton", nil, profile, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("TOPLEFT", x, -154)
  local fs = cb.text or cb.Text
  if not fs then
    fs = cb:CreateFontString(nil, "OVERLAY")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontNormalSmall")
  fs:SetShadowOffset(0, 0)
  Ink(fs, INK)
  fs:SetText(label)
  cb:SetScript("OnClick", function(self)
    if not ns.db then return end
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
end
Check("Remind me about upgrades", "upgradeAlert", NOTES_X - 4, "Chat reminder when you know a better rank than your pet has.")
Check("Pet level-up nudges", "levelNudge", NOTES_X + 246, "Chat message when your pet reaches the level for a new rank.")

local function FillProfile(s)
  if UnitGUID("pet") ~= modelGUID then ShowPetModel(true) end

  local plvl = ns.PetLevel()
  levelLine:SetText(("Level %d %s"):format(plvl, ns.PetFamily() or ""))

  if s.xpMax and s.xpMax > 0 then
    local xp = s.xp or 0
    bar:SetMinMaxValues(0, s.xpMax)
    bar:SetValue(xp)
    bar:Show()
    local txt = ("%s / %s XP (%d%%)"):format(Num(xp), Num(s.xpMax), math.floor(xp / s.xpMax * 100))
    if plvl >= ns.PlayerLevel() then
      txt = txt .. "  ·  can't level past you"
    else
      txt = txt .. ("  ·  %s to level %d"):format(Num(s.xpMax - xp), plvl + 1)
    end
    xpText:SetText(txt)
  else
    bar:Hide()
    xpText:SetText("")
  end

  local list = {}
  local function Fact(label, text, color)
    if text then list[#list + 1] = { label, text, color } end
  end
  local h = s.happy and HAPPY[s.happy]
  if h then Fact("Happiness", s.dmg and ("%s  ·  %d%% damage"):format(h[1], s.dmg) or h[1], h[2]) end
  local loyal = s.loyalty
  if loyal and s.loyaltyRate and s.loyaltyRate < 0 then
    loyal = loyal .. "  ·  |cff8c1a0alosing loyalty|r"
  end
  Fact("Loyalty", loyal)
  Fact("Training points", s.tp and ("%d free of %d"):format(s.tp, s.tpTotal or 0), s.tp and s.tp > 0 and INK_GOOD or INK)
  Fact("Diet", s.diet)
  -- combat stats every client reports, to fill the slots left over
  local speed = UnitAttackSpeed and UnitAttackSpeed("pet")
  if Readable(speed) and speed then Fact("Attack speed", ("%.2f sec"):format(speed)) end
  local lo, hi
  if UnitDamage then lo, hi = UnitDamage("pet") end
  if Readable(lo, hi) and lo and hi then Fact("Damage", ("%d - %d"):format(lo, hi)) end
  local hp = UnitHealthMax("pet")
  if Readable(hp) and hp and hp > 0 then Fact("Health", Num(hp)) end
  if UnitArmor then
    local base, effective = UnitArmor("pet")
    local armor = effective or base
    if Readable(armor) and armor then Fact("Armor", Num(armor)) end
  end
  FillFacts(list)

  for _, cb in ipairs(checks) do cb:SetChecked(ns.db.opts[cb.key] and true or false) end
end

------------------------------------------------------------------------
-- Section widgets (pooled): Morpheus heading + swirl, notes, ability cells
------------------------------------------------------------------------
local heads, notes, cells = {}, {}, {}

local function GetHead(i)
  if heads[i] then return heads[i] end
  local h = {}
  h.text = JournalFont(page, 18, "SystemFont_Med3")
  h.right = Font(page, "GameFontNormalSmall", INK_DIM)
  h.right:SetPoint("LEFT", h.text, "RIGHT", 12, -1)
  h.line = page:CreateTexture(nil, "ARTWORK")
  h.line:SetAtlas("spellbook-divider")
  h.line:SetSize(420, 11)
  heads[i] = h
  return h
end

local function GetNote(i)
  if notes[i] then return notes[i] end
  local fs = Font(page, "SystemFont_Med1", INK_DIM)
  fs:SetWidth(COL_W * COLS - 8)
  fs:SetWordWrap(false)
  notes[i] = fs
  return fs
end

local function GetCell(i)
  if cells[i] then return cells[i] end
  local b = CreateFrame("Button", nil, page)
  b:SetSize(COL_W - 6, ROW_H - 4)
  b:RegisterForClicks("LeftButtonUp", "RightButtonUp")

  b.icon = b:CreateTexture(nil, "ARTWORK")
  b.icon:SetSize(ICON, ICON)
  b.icon:SetPoint("TOPLEFT", 10, -4)
  b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

  b.border = b:CreateTexture(nil, "OVERLAY")
  b.border:SetAtlas("spellbook-item-iconframe")
  b.border:SetSize(42, 38)
  b.border:SetPoint("TOPLEFT", b.icon, "TOPLEFT", -9, 1)

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
  b.seal:SetSize(15, 15)
  b.seal:SetPoint("CENTER", b.icon, "BOTTOMRIGHT", -2, 2)
  b.seal:Hide()

  b.name = Font(b, "SystemFont_Large")
  b.name:SetPoint("TOPLEFT", b.icon, "TOPRIGHT", 9, 1)
  b.name:SetWidth(COL_W - 64)
  b.name:SetWordWrap(false)

  b.sub = Font(b, "SystemFont_Med1")
  b.sub:SetPoint("TOPLEFT", b.name, "BOTTOMLEFT", 0, -2)
  b.sub:SetWidth(COL_W - 64)
  b.sub:SetWordWrap(false)

  b:SetScript("OnEnter", function(self)
    self.glow:Show()
    if self.tip then
      GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
      self.tip(GameTooltip)
      GameTooltip:Show()
    end
  end)
  b:SetScript("OnLeave", function(self)
    self.glow:SetShown(self.here and true or false)
    GameTooltip_Hide()
  end)
  b:SetScript("OnClick", function(self, button)
    if button == "LeftButton" and self.onClick then self.onClick() end
  end)
  cells[i] = b
  return b
end

local function FillCell(b, d)
  b.icon:SetTexture(d.icon)
  b.icon:SetDesaturated(d.dim and true or false)
  b.icon:SetAlpha(d.dim and 0.75 or 1)
  b.name:SetText(d.name)
  b.sub:SetText(d.sub or "")
  Ink(b.sub, d.subColor or INK)
  b.badge:SetText(d.badge or "")
  b.seal:SetShown(d.mastered and true or false)
  b.here = d.here
  b.glow:SetShown(d.here and true or false)
  b.tip, b.onClick = d.tip, d.onClick
end

------------------------------------------------------------------------
-- Sections
------------------------------------------------------------------------
local function BuildSections(s)
  local fam, plvl = ns.PetFamily(), ns.PetLevel()
  local info = {}

  -- Upgrades: ranks you know that the pet doesn't have yet
  local ups = ns.Upgrades()
  local ready, upgradeBy = {}, {}
  local waiting = {}
  for _, u in ipairs(ups) do
    upgradeBy[u.ab.name] = u
    if u.needLevel then waiting[#waiting + 1] = u else ready[#ready + 1] = u end
  end
  info.ready = #ready
  local upItems = {}
  for _, u in ipairs(ready) do
    local r = RankOf(u.ab, u.to)
    upItems[#upItems + 1] = {
      icon = u.ab.icon, name = u.ab.name, badge = tostring(u.to), here = true,
      sub = ("Teach rank %d (has %d)"):format(u.to, u.from), subColor = INK_GOOD,
      onClick = function() OpenAbility(u.ab, u.to) end,
      tip = function(tt)
        tt:AddLine(("%s (Rank %d)"):format(u.ab.name, u.to), 1, 0.82, 0)
        if r then tt:AddLine(r.effect, 1, 1, 1, true) end
        tt:AddLine(("Your pet has rank %d. You know rank %d."):format(u.from, u.to), 0.8, 0.8, 0.8)
        if r then tt:AddLine(("Costs %d training points"):format(r.tp), 0.8, 0.8, 0.8) end
        tt:AddLine("Open Beast Training to teach it", 0.25, 1, 0.25)
        tt:AddLine(" ")
        tt:AddLine("Click to see all its ranks", 0.5, 0.5, 0.5)
      end,
    }
  end
  for _, u in ipairs(waiting) do
    upItems[#upItems + 1] = {
      icon = u.ab.icon, name = u.ab.name, badge = tostring(u.to), dim = true,
      sub = ("Rank %d at pet level %d"):format(u.to, u.needLevel or 0), subColor = INK_DIM,
      onClick = function() OpenAbility(u.ab, u.to) end,
      tip = function(tt)
        tt:AddLine(("%s (Rank %d)"):format(u.ab.name, u.to), 1, 0.82, 0)
        tt:AddLine(("Your pet has rank %d. You know rank %d,"):format(u.from, u.to), 0.8, 0.8, 0.8)
        tt:AddLine(("but your pet needs level %d to learn it."):format(u.needLevel or 0), 1, 0.56, 0.25)
        tt:AddLine(" ")
        tt:AddLine("Click to see all its ranks", 0.5, 0.5, 0.5)
      end,
    }
  end
  local upRight, upColor = "none", INK_DIM
  if #ready > 0 then
    upRight, upColor = ("%d ready to teach"):format(#ready), INK_GOOD
  elseif #waiting > 0 then
    upRight = "waiting on your pet's level"
  end

  -- What the pet has now
  local hasItems = {}
  for _, ab in ipairs(ns.abilities) do
    local has = ns.petRank[ab.name]
    if has then
      local top = ab.parsed[#ab.parsed]
      local maxRank = top and top.rank or has
      local u = upgradeBy[ab.name]
      local r = RankOf(ab, has)
      local sub, color = ("Rank %d of %d"):format(has, #ab.parsed), INK
      if u and not u.needLevel then
        sub, color = ("Rank %d  ·  upgrade ready"):format(has), INK_GOOD
      elseif has >= maxRank then
        sub, color = #ab.parsed == 1 and "Learned" or "Highest rank", INK_GOOD
      end
      hasItems[#hasItems + 1] = {
        icon = ab.icon, name = ab.name, badge = #ab.parsed > 1 and tostring(has) or nil,
        mastered = has >= maxRank, sub = sub, subColor = color,
        onClick = function() OpenAbility(ab, has) end,
        tip = function(tt)
          tt:AddLine(("%s (Rank %d)"):format(ab.name, has), 1, 0.82, 0)
          if r then tt:AddLine(r.effect, 1, 1, 1, true) end
          tt:AddLine(("Rank %d of %d"):format(has, #ab.parsed), 0.8, 0.8, 0.8)
          local best = ns.BestKnown(ab)
          if best > has then
            tt:AddLine(("You know rank %d"):format(best), 0.25, 1, 0.25)
          end
          tt:AddLine(" ")
          tt:AddLine("Click to see all its ranks", 0.5, 0.5, 0.5)
        end,
      }
    end
  end

  -- Ranks unlocking over the next few pet levels
  local soon = ns.ComingUp(SOON_LEVELS)
  info.next = soon[1]
  for _, e in ipairs(soon) do
    if not e.known then info.nextUnknown = info.nextUnknown or e end
  end
  local soonItems = {}
  for _, e in ipairs(soon) do
    local ab, r = e.ab, e.rank
    local where = e.known and "you know it" or ns.TeacherZones(ab, r, 1)
    soonItems[#soonItems + 1] = {
      icon = ab.icon, name = ab.name, badge = tostring(r.level), dim = not e.known,
      sub = ("Rank %d  ·  %s"):format(r.rank, where), subColor = e.known and INK_GOOD or INK,
      onClick = function()
        if IsShiftKeyDown() then WaypointTeachers(ab, r) else OpenAbility(ab, r.rank) end
      end,
      tip = function(tt)
        tt:AddLine(("%s (Rank %d)"):format(ab.name, r.rank), 1, 0.82, 0)
        tt:AddLine(r.effect, 1, 1, 1, true)
        tt:AddLine(("Your pet can learn it at level %d  -  %d TP"):format(r.level, r.tp), 0.8, 0.8, 0.8)
        if e.known then
          tt:AddLine("You already know it", 0.25, 1, 0.25)
        else
          tt:AddLine(" ")
          AddTeachers(tt, ab, r)
        end
        tt:AddLine(" ")
        tt:AddLine(e.known and "Click to see all its ranks"
          or "Click: its ranks and teachers  ·  Shift-click: waypoints", 0.5, 0.5, 0.5, true)
      end,
    }
  end

  -- Abilities you know that would fit this pet but it doesn't have
  local extraItems = {}
  for _, ab in ipairs(ns.abilities) do
    if not ns.petRank[ab.name] and ns.AbilityFitsPet(ab, fam) then
      local best = ns.BestKnown(ab, plvl)
      if best > 0 then
        local r = RankOf(ab, best)
        local cost = r and r.tp or 0
        local short = s.tp and cost > s.tp
        extraItems[#extraItems + 1] = {
          icon = ab.icon, name = ab.name, badge = #ab.parsed > 1 and tostring(best) or nil,
          sub = ("Rank %d  ·  %d TP"):format(best, cost), subColor = short and INK_RED or INK,
          onClick = function() OpenAbility(ab, best) end,
          tip = function(tt)
            tt:AddLine(("%s (Rank %d)"):format(ab.name, best), 1, 0.82, 0)
            if r then tt:AddLine(r.effect, 1, 1, 1, true) end
            tt:AddLine("You know it, your pet doesn't have it.", 0.8, 0.8, 0.8)
            tt:AddLine(("Teaching it costs %d training points"):format(cost), short and 1 or 0.8, short and 0.35 or 0.8, short and 0.25 or 0.8)
            tt:AddLine(" ")
            tt:AddLine("Click to see all its ranks", 0.5, 0.5, 0.5)
          end,
        }
      end
    end
  end

  return {
    { title = "Upgrades to teach", right = upRight, rightColor = upColor, items = upItems,
      empty = "Your pet already has the best rank you know of everything it uses." },
    { title = "Abilities on your pet", right = #hasItems > 0 and ("%d known"):format(#hasItems) or "", items = hasItems,
      empty = "No trainable abilities found on your pet yet." },
    { title = "Coming up", right = ("next %d pet levels"):format(SOON_LEVELS), items = soonItems,
      empty = ("No new ranks for your pet's abilities in the next %d levels."):format(SOON_LEVELS) },
    { title = "You know these, your pet doesn't", right = #extraItems > 0 and ("%d to teach"):format(#extraItems) or "",
      items = extraItems, empty = "Nothing else you've learned fits this pet right now." },
  }, info
end

-- Flows the sections onto pages: { { {kind, s, y, first}, ... }, ... }
local function Paginate(sections)
  local pages = { {} }
  local y = PROFILE_H
  local function NewPage()
    pages[#pages + 1] = {}
    y = 0
  end
  local function Put(op, h)
    op.y = y
    local pg = pages[#pages]
    pg[#pg + 1] = op
    y = y + h
  end
  for _, s in ipairs(sections) do
    local need = HEAD_H + (#s.items > 0 and ROW_H or NOTE_H)
    if y + need > PAGE_H then NewPage() end
    Put({ kind = "head", s = s }, HEAD_H)
    if #s.items == 0 then
      Put({ kind = "note", s = s }, NOTE_H)
    else
      for i = 1, #s.items, COLS do
        if y + ROW_H > PAGE_H then
          NewPage()
          Put({ kind = "head", s = s, cont = true }, HEAD_H)
        end
        Put({ kind = "row", s = s, first = i }, ROW_H)
      end
    end
    y = y + GAP
  end
  return pages
end

local function DrawPage(ops)
  local nh, nn, nc = 0, 0, 0
  for _, op in ipairs(ops or {}) do
    if op.kind == "head" then
      nh = nh + 1
      local h = GetHead(nh)
      h.text:ClearAllPoints()
      h.text:SetPoint("TOPLEFT", page, "TOPLEFT", 0, -op.y)
      h.text:SetText(op.cont and (op.s.title .. " (continued)") or op.s.title)
      h.right:SetText(op.cont and "" or (op.s.right or ""))
      Ink(h.right, op.s.rightColor or INK_DIM)
      h.line:ClearAllPoints()
      h.line:SetPoint("TOPLEFT", page, "TOPLEFT", -16, -(op.y + 20))
      h.text:Show()
      h.right:Show()
      h.line:Show()
    elseif op.kind == "note" then
      nn = nn + 1
      local fs = GetNote(nn)
      fs:ClearAllPoints()
      fs:SetPoint("TOPLEFT", page, "TOPLEFT", 4, -(op.y + 2))
      fs:SetText(op.s.empty or "")
      fs:Show()
    else
      for c = 0, COLS - 1 do
        local d = op.s.items[op.first + c]
        if d then
          nc = nc + 1
          local b = GetCell(nc)
          FillCell(b, d)
          b:ClearAllPoints()
          b:SetPoint("TOPLEFT", page, "TOPLEFT", c * COL_W, -op.y)
          b:Show()
        end
      end
    end
  end
  for i = nh + 1, #heads do
    heads[i].text:Hide()
    heads[i].right:Hide()
    heads[i].line:Hide()
  end
  for i = nn + 1, #notes do notes[i]:Hide() end
  for i = nc + 1, #cells do cells[i]:Hide() end
end

------------------------------------------------------------------------
-- Render
------------------------------------------------------------------------
Render = function()
  if not UnitExists("pet") then
    profile:Hide()
    DrawPage(nil)
    Book.SetNote("Summon your pet to open its page in the journal.\n\n" ..
      "Here you'll find its portrait, experience, happiness, loyalty and training points, " ..
      "the abilities it knows, the upgrades you can teach it and the ranks coming up as it levels.")
    Book.SetFieldNote("No companion at your side. Call Pet, then come back to this page.")
    PlaceTeach()
    return
  end

  ns.ScanPet()
  Book.SetHeader(UnitName("pet") or "My Pet")
  local s = PetStats()
  local sections, info = BuildSections(s)
  local pages = Paginate(sections)
  local cur = Book.SetPager(#pages)

  profile:SetShown(cur == 1)
  if cur == 1 then FillProfile(s) end
  DrawPage(pages[cur])

  local stats = {}
  if s.tp then stats[#stats + 1] = { "Training points", ("%d free"):format(s.tp) } end
  stats[#stats + 1] = { "Upgrades", info.ready > 0 and ("%d ready"):format(info.ready) or "None" }
  stats[#stats + 1] = { "Next new rank", info.next and ("Level %d"):format(info.next.rank.level) or "None soon" }
  Book.SetStats(stats)

  local name = UnitName("pet") or "Your pet"
  if info.ready > 0 then
    Book.SetFieldNote(("%d upgrade%s ready - open Beast Training to teach %s."):format(
      info.ready, info.ready == 1 and "" or "s", info.ready == 1 and "it" or "them"))
  elseif s.happy == 1 then
    Book.SetFieldNote(("%s is unhappy and fights at reduced damage. Feed it soon."):format(name))
  elseif info.nextUnknown then
    local e = info.nextUnknown
    Book.SetFieldNote(("At level %d, %s can learn %s %d. Find a teacher in %s."):format(
      e.rank.level, name, e.ab.name, e.rank.rank, ns.TeacherZones(e.ab, e.rank, 2)))
  elseif info.next then
    Book.SetFieldNote(("At level %d, %s can learn %s %d, and you already know it."):format(
      info.next.rank.level, name, info.next.ab.name, info.next.rank.rank))
  else
    Book.SetFieldNote(("%s has the best of everything you know. Time to tame something new."):format(name))
  end

  PlaceTeach()
end

------------------------------------------------------------------------
-- Events: stats the core doesn't refresh on, the 3D model, combat
------------------------------------------------------------------------
local ev = CreateFrame("Frame")
for _, e in ipairs({ "UNIT_PET", "UNIT_MODEL_CHANGED", "UNIT_PET_EXPERIENCE", "UNIT_HAPPINESS",
  "UNIT_PET_TRAINING_POINTS", "PET_UI_UPDATE", "PLAYER_REGEN_DISABLED", "PLAYER_REGEN_ENABLED" }) do
  pcall(ev.RegisterEvent, ev, e)
end
ev:SetScript("OnEvent", function(_, e, unit)
  if e == "PLAYER_REGEN_DISABLED" then
    teach:Hide()
  elseif e == "PLAYER_REGEN_ENABLED" then
    PlaceTeach()
  elseif not page:IsVisible() then
    return
  elseif e == "UNIT_PET" then
    -- the new pet's model isn't ready the moment it appears
    if unit == "player" and C_Timer then
      C_Timer.After(0.3, function()
        if model:IsVisible() then ShowPetModel(true) end
      end)
    end
  elseif e == "UNIT_MODEL_CHANGED" then
    if unit == "pet" and model:IsVisible() then ShowPetModel(false) end
  else
    ns.Refresh()
  end
end)
