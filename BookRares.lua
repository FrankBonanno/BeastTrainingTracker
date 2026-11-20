local _, ns = ...

-- Tab 3: Special Pets. Rares, elites and quest spawns from Petopia, kept as a
-- collection: they teach what normal beasts do; their look and innate attack
-- speed are what make them worth hunting.

local Book = ns.Book
if not Book then return end

local Geo = ns.Geo
local state = Book.state
local INK, INK_DIM, INK_GOOD = Book.INK, Book.INK_DIM, Book.INK_GOOD
local Font, JournalFont, Ink = Book.Font, Book.JournalFont, Book.Ink

-- the ink colors as inline codes, for mixed-color lines
local HEX_GOOD, HEX_RED, HEX_DIM = "|cff14660f", "|cff8c1a0a", "|cff6b4f33"

local PER_PAGE = Book.COLS * 5
local GRID_TOP = 60
local RIGHT_X, RIGHT_W = 330, 378

local Render -- forward
local page = Book.RegisterTab(3, { render = function() Render() end, search = true })

------------------------------------------------------------------------
-- Helpers
------------------------------------------------------------------------
local function Plain(s) return (s:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")) end

-- "Echo Isles, Durotar" -> "Durotar"
local function ShortZone(z) return z:match(",%s*([^,]+)$") or z end

local function SpeedInk(speed)
  if not speed then return HEX_DIM .. "? speed|r" end
  local s = ("%.1f speed"):format(speed)
  if speed < 2.0 then return HEX_GOOD .. s .. "|r" end
  if speed > 2.0 then return HEX_RED .. s .. "|r" end
  return s
end

-- tooltip version (normal tooltip colors)
local function SpeedTip(speed)
  if not speed then return "|cff808080?|r" end
  local s = ns.RS.SpeedText(speed)
  if speed < 2.0 then return s .. " |cff40ff40fast|r" end
  if speed > 2.0 then return s .. " |cffff9040slow|r" end
  return s
end

-- 1800 -> "30m", 37800 -> "10.5h", 129600 -> "36h", 259200 -> "3d"
local function Dur(sec)
  if sec < 3600 then return math.floor(sec / 60 + 0.5) .. "m" end
  if sec <= 72 * 3600 then
    local h = math.floor(sec / 1800 + 0.5) / 2
    return (h == math.floor(h) and tostring(h) or ("%.1f"):format(h)) .. "h"
  end
  local d = math.floor(sec / 43200 + 0.5) / 2
  return (d == math.floor(d) and tostring(d) or ("%.1f"):format(d)) .. "d"
end

local function RespawnText(r)
  if r.t.dungeon then return "When the dungeon resets." end
  local rt = ns.respawnTimes and ns.respawnTimes[r.name]
  if not rt then return HEX_DIM .. "Unknown.|r" end
  local range = rt[1] == rt[2] and Dur(rt[1]) or (Dur(rt[1]) .. " - " .. Dur(rt[2]))
  local spots = (rt[3] or 1) > 1 and (HEX_DIM .. "  (%d spawn points)|r"):format(rt[3]) or ""
  return range .. spots
end

-- Family abilities this beast could learn (skipping the ones every family gets)
local function FamilyAbilities(family)
  local list = {}
  for _, ab in ipairs(ns.abilities) do
    if not ab.isAll and ns.AbilityFitsPet(ab, family) then list[#list + 1] = ab.name end
  end
  return table.concat(list, ", ")
end

local function Waypoint(r)
  local e = r.teaches[1]
  Geo.Waypoint(r.t, e and Geo.Label(e.ab, e.rank, r.t) or r.name)
end

-- NPC id: our rare list first, then Questie
local function NpcId(name)
  if ns.rareIds and ns.rareIds[name] then return ns.rareIds[name] end
  local db = _G.NpcDB
  if Geo.HasQuestie() and db and db.IdsByName then
    local ok, ids = pcall(db.IdsByName, name)
    if ok and type(ids) == "table" and ids[1] then return ids[1] end
  end
end

-- AllRares reads RareScanner for every pet; the book renders often, so reuse it
-- until something is tamed, the sort changes, or a few seconds pass.
local cache, cacheKey
local function AllRares()
  local bySpeed = ns.db.opts.rareSortSpeed and true or false
  local key = ("%d:%s:%d"):format(ns.tamedSerial or 0, tostring(bySpeed), math.floor(GetTime() / 5))
  if key ~= cacheKey then
    cache, cacheKey = ns.RS.AllRares(bySpeed), key
  end
  return cache
end

------------------------------------------------------------------------
-- Index: filter checkboxes above the spellbook grid
------------------------------------------------------------------------
local index = CreateFrame("Frame", nil, page)
index:SetAllPoints()

local checks = {}
local function Check(label, key, x, y, tip, onChange)
  local cb = CreateFrame("CheckButton", nil, index, "UICheckButtonTemplate")
  cb:SetSize(22, 22)
  cb:SetPoint("TOPLEFT", x, y)
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
    ns.db.opts[key] = self:GetChecked() and true or false
    if onChange then onChange(ns.db.opts[key]) end
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
  return cb
end

Check("Rares", "spShowRare", 0, 0, "Show rare pets.")
Check("Elites", "spShowElite", 110, 0, "Show elite pets (tough in the wild, normal once tamed).")
Check("Quest spawns", "spShowSpawned", 270, 0, "Show pets that only appear through a quest or trigger.")
Check("Dungeons & raids", "spShowDungeon", 400, 0, "Include pets that live inside dungeons and raids.")
Check("Hide tamed", "rareHideTamed", 0, -22, "Hide pets you've already tamed.")
Check("Hide above my level", "rareHideHigh", 110, -22, "Hide pets you're too low level to tame yet.")
Check("Fastest first", "rareSortSpeed", 270, -22, "Sort by attack speed (lowest number = fastest).")
Check("Map pins for untamed", "rarePins", 400, -22,
  "Pins for untamed rares (and outdoor elites / quest spawns) you can tame, even if they teach nothing you need.")

local rsText = Font(index, "GameFontNormalSmall")
rsText:SetPoint("TOPRIGHT", index, "TOPRIGHT", 0, -5)
rsText:SetJustifyH("RIGHT")

local indexDiv = index:CreateTexture(nil, "ARTWORK")
indexDiv:SetAtlas("spellbook-divider")
indexDiv:SetSize(420, 11)
indexDiv:SetPoint("TOPLEFT", -16, -45)

local empty = Font(index, "SystemFont_Med1")
empty:SetPoint("TOPLEFT", 0, -(GRID_TOP + 4))
empty:SetWidth(Book.W - 112)

------------------------------------------------------------------------
-- Detail page: 3D model on the left, journal notes on the right
------------------------------------------------------------------------
local detail = CreateFrame("Frame", nil, page)
detail:SetAllPoints()
detail:Hide()

local box = CreateFrame("Frame", nil, detail)
box:SetSize(300, 318)
box:SetPoint("TOPLEFT", 0, -2)
local wash = box:CreateTexture(nil, "BACKGROUND")
wash:SetAllPoints()
wash:SetColorTexture(INK[1], INK[2], INK[3], 0.07)
local function Edge(a, b, w, h)
  local t = box:CreateTexture(nil, "BORDER")
  t:SetColorTexture(INK[1], INK[2], INK[3], 0.45)
  t:SetPoint(a)
  t:SetPoint(b)
  if w then t:SetWidth(w) else t:SetHeight(h) end
end
Edge("TOPLEFT", "TOPRIGHT", nil, 1)
Edge("BOTTOMLEFT", "BOTTOMRIGHT", nil, 1)
Edge("TOPLEFT", "BOTTOMLEFT", 1, nil)
Edge("TOPRIGHT", "BOTTOMRIGHT", 1, nil)

-- drag to turn, wheel to zoom, slowly spins until you touch it
local model = CreateFrame("PlayerModel", nil, box)
model:SetPoint("TOPLEFT", 1, -1)
model:SetPoint("BOTTOMRIGHT", -1, 1)

local noModel = Font(box, "SystemFont_Med1", INK_DIM)
noModel:SetPoint("CENTER")
noModel:SetWidth(260)
noModel:SetJustifyH("CENTER")

local caption = Font(detail, "GameFontNormalSmall", INK_DIM)
caption:SetPoint("TOP", box, "BOTTOM", 0, -5)
caption:SetJustifyH("CENTER")

local facing, zoom, spin, dragX = 0, 1, true, nil
local modelName, modelId
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

local function ShowModel(name)
  modelName = name
  facing, zoom, spin, dragX = 0, 1, true, nil
  model:ClearModel()
  local id = NpcId(name)
  modelId = id
  if not id or not model.SetCreature then
    noModel:SetText("No sketch of this beast yet." ..
      (Geo.HasQuestie() and "" or "\n\nInstall Questie to see models of elites and quest spawns."))
    noModel:Show()
    return
  end
  noModel:Hide()
  model:SetCreature(id)
  if model.SetCamDistanceScale then model:SetCamDistanceScale(zoom) end
  model:SetFacing(facing)
  -- the creature may not be in your game cache yet; try again shortly
  if C_Timer then
    C_Timer.After(0.5, function()
      if detail:IsShown() and modelName == name then
        model:SetCreature(id)
        model:SetFacing(facing)
      end
    end)
  end
end

-- family block under the model
local famIcon = detail:CreateTexture(nil, "ARTWORK")
famIcon:SetSize(32, 32)
famIcon:SetPoint("TOPLEFT", box, "BOTTOMLEFT", 9, -28)
famIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
local famBorder = detail:CreateTexture(nil, "OVERLAY")
famBorder:SetAtlas("spellbook-item-iconframe")
famBorder:SetSize(42, 38)
famBorder:SetPoint("TOPLEFT", famIcon, "TOPLEFT", -9, 1)
local famName = Font(detail, "SystemFont_Large")
famName:SetPoint("TOPLEFT", famIcon, "TOPRIGHT", 10, 1)
local famLearn = Font(detail, "GameFontNormalSmall")
famLearn:SetPoint("TOPLEFT", famName, "BOTTOMLEFT", 0, -3)
famLearn:SetWidth(248)
famLearn:SetWordWrap(true)

-- right column: what kind of beast, where, then the notes
local typeLine = Font(detail, "GameFontNormalSmall", INK_DIM)
typeLine:SetPoint("TOPLEFT", RIGHT_X, -2)
local kindLine = Font(detail, "SystemFont_Large")
kindLine:SetPoint("TOPLEFT", typeLine, "BOTTOMLEFT", 0, -4)
local zoneLine = Font(detail, "SystemFont_Med1")
zoneLine:SetPoint("TOPLEFT", kindLine, "BOTTOMLEFT", 0, -3)
zoneLine:SetWidth(RIGHT_W)
zoneLine:SetWordWrap(true)

local noteDiv = detail:CreateTexture(nil, "ARTWORK")
noteDiv:SetAtlas("spellbook-divider")
noteDiv:SetSize(RIGHT_W, 10)
noteDiv:SetPoint("TOPLEFT", zoneLine, "BOTTOMLEFT", -4, -5)

local sections = {}
for i = 1, 5 do
  local head = JournalFont(detail, 15, "SystemFont_Med3")
  local body = Font(detail, "SystemFont_Med1")
  body:SetWidth(RIGHT_W)
  body:SetWordWrap(true)
  body:SetSpacing(2)
  sections[i] = { head = head, body = body }
end

local function SetSections(list)
  local prev
  for i, sec in ipairs(sections) do
    local d = list[i]
    if d then
      sec.head:ClearAllPoints()
      if prev then
        sec.head:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -9)
      else
        sec.head:SetPoint("TOPLEFT", noteDiv, "BOTTOMLEFT", 4, -5)
      end
      sec.head:SetText(d[1])
      sec.body:ClearAllPoints()
      sec.body:SetPoint("TOPLEFT", sec.head, "BOTTOMLEFT", 0, -3)
      sec.body:SetText(d[2])
      sec.head:Show()
      sec.body:Show()
      prev = sec.body
    else
      sec.head:Hide()
      sec.body:Hide()
    end
  end
end

local current -- the special pet on the detail page
local wayBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
wayBtn:SetSize(110, 22)
wayBtn:SetPoint("BOTTOMLEFT", detail, "BOTTOMLEFT", RIGHT_X, 2)
wayBtn:SetText("Waypoint")
wayBtn:SetScript("OnClick", function()
  if current then Waypoint(current) end
end)

local tameBtn = CreateFrame("Button", nil, detail, "UIPanelButtonTemplate")
tameBtn:SetSize(140, 22)
tameBtn:SetPoint("LEFT", wayBtn, "RIGHT", 10, 0)
tameBtn:SetText("Mark tamed")
tameBtn:SetScript("OnClick", function()
  if current then ns.RS.SetTamed(current.name, not ns.db.tamedRares[current.name]) end
end)
tameBtn:SetScript("OnEnter", function(self)
  GameTooltip:SetOwner(self, "ANCHOR_TOP")
  GameTooltip:AddLine(self:GetText(), 1, 0.82, 0)
  GameTooltip:AddLine("With this beast's family out as your pet, marking it tamed also links your pet to it, so renames are tracked.", 1, 1, 1, true)
  GameTooltip:Show()
end)
tameBtn:SetScript("OnLeave", GameTooltip_Hide)

------------------------------------------------------------------------
-- Navigation
------------------------------------------------------------------------
local indexPage, openSearch = 1, ""

local function Open(name)
  state.rares, indexPage, openSearch = name, state.page or 1, state.search or ""
  state.page = 1
  Book.Render()
end

local function Back()
  state.rares, modelName = nil, nil
  state.page = indexPage
  Book.Render()
end

-- closing the book or leaving the tab drops back to the index
page:HookScript("OnHide", function() state.rares, modelName = nil, nil end)

------------------------------------------------------------------------
-- Index render
------------------------------------------------------------------------
local function Item(r, tameable, isHere)
  local sp = r.t
  local tail
  if r.tamed then
    local nick = ns.db.tamedNicks and ns.db.tamedNicks[r.name]
    tail = HEX_GOOD .. "Tamed" .. (nick and (" (" .. nick .. ")") or "") .. "|r"
  elseif tameable and r.status and r.status.short then
    local c = r.status.up and HEX_GOOD or (r.status.up == false and HEX_RED or HEX_DIM)
    tail = c .. Plain(r.status.short) .. "|r"
  else
    tail = ShortZone(sp.zone)
  end
  return {
    icon = r.icon, name = r.name,
    sub = SpeedInk(r.speed) .. "  ·  " .. tail,
    nameColor = tameable and INK or INK_DIM,
    dim = not tameable, here = isHere, mastered = r.tamed and true or false,
    badge = sp.level, badgeColor = tameable and { 1, 1, 1 } or { 1, 0.35, 0.25 },
    onClick = function()
      if IsShiftKeyDown() then Waypoint(r) else Open(r.name) end
    end,
    onRightClick = function() ns.RS.SetTamed(r.name, not r.tamed) end,
    tip = function(tt)
      local cur = ns.RS.Info(r.name) or r
      tt:AddLine(r.name .. "  " .. ns.RS.TypeText(sp), 1, 0.82, 0)
      tt:AddLine(("%s, level %s"):format(sp.family, sp.level), 1, 1, 1)
      tt:AddLine(sp.zone, isHere and 0.25 or 0.8, isHere and 1 or 0.8, isHere and 0.25 or 0.8)
      tt:AddLine("Attack speed: " .. SpeedTip(r.speed) .. "  |cff9d9d9d(normal 2.0, lower = faster)|r", 1, 1, 1)
      for _, tr in ipairs(cur.traits) do tt:AddLine(tr.long, 1, 0.82, 0.3, true) end
      if cur.tamed then
        tt:AddLine(type(cur.tamed) == "number" and ("Tamed " .. date("%b %d, %Y", cur.tamed)) or "Tamed", 0.25, 1, 0.25)
      elseif not tameable then
        tt:AddLine(("You can tame it at level %d"):format(sp.minLevel), 1, 0.56, 0.25)
      end
      if #cur.teaches > 0 then
        tt:AddLine(" ")
        for _, e in ipairs(cur.teaches) do
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
      tt:AddLine("Click: field notes & 3D model  ·  Shift-click: waypoint", 0.5, 0.5, 0.5, true)
      tt:AddLine("Right-click: tamed / not tamed (with that pet out, links it)", 0.5, 0.5, 0.5, true)
    end,
  }
end

local function RenderIndex()
  index:Show()
  detail:Hide()
  local o = ns.db.opts
  for _, cb in ipairs(checks) do cb:SetChecked(o[cb.key] and true or false) end

  if ns.RS.Loaded() then
    rsText:SetText("Spawn timers from RareScanner")
    Ink(rsText, INK_GOOD)
  else
    rsText:SetText("Enable RareScanner for spawn timers")
    Ink(rsText, INK_DIM)
  end

  local all = AllRares()
  local zone = ns.CurrentZone()
  local s = state.search or ""
  local tamed, here, list = 0, 0, {}
  for _, r in ipairs(all) do
    if r.tamed then tamed = tamed + 1 end
    local sp = r.t
    local tameable = ns.CanTame(sp)
    local typeOk = (o.spShowRare and sp.rare) or (o.spShowElite and sp.elite) or (o.spShowSpawned and sp.spawned)
    local matches = s == "" or r.name:lower():find(s, 1, true) or sp.family:lower():find(s, 1, true)
      or sp.zone:lower():find(s, 1, true)
    if typeOk and (o.spShowDungeon or not sp.dungeon)
      and not (o.rareHideTamed and r.tamed) and not (o.rareHideHigh and not tameable) and matches then
      local isHere = not r.tamed and tameable and ns.InZone(sp, zone)
      if isHere then here = here + 1 end
      list[#list + 1] = Item(r, tameable, isHere)
    end
  end

  Book.SetStats({
    { "Tamed", ("%d / %d"):format(tamed, #all) },
    { "Listed", tostring(#list) },
    { "In this zone", tostring(here) },
  })
  if #list == 0 then
    empty:SetText(s ~= "" and "No special pet matches your search." or "Nothing matches these filters.")
  else
    empty:SetText("")
  end
  if here > 0 then
    Book.SetFieldNote(("%s: %d untamed special pet%s here. Look for the glowing icons."):format(
      zone, here, here == 1 and "" or "s"))
  else
    Book.SetFieldNote("Click a beast for its page. Shift-click: waypoint. Right-click: tamed / not tamed.")
  end
  Book.ShowPage(list, PER_PAGE, GRID_TOP)
end

------------------------------------------------------------------------
-- Detail render
------------------------------------------------------------------------
local function RenderDetail(r)
  index:Hide()
  detail:Show()
  current = r
  -- no paging here; keeps the mouse wheel from turning the index behind it
  state.pages, state.page = 1, 1
  Book.SetBack(Back)

  local sp = r.t
  local tameable = ns.CanTame(sp)
  local zone = ns.CurrentZone()
  local isHere = ns.InZone(sp, zone)

  Book.SetTitle("Beast Training Tracker - " .. r.name)
  Book.SetHeader(r.name)
  -- first column left empty so long names have room
  Book.SetStats({
    { "", "" },
    { "Level", tameable and sp.level or (HEX_RED .. sp.level .. "|r") },
    { "Attack speed", r.speed and ("%.1f"):format(r.speed) or "?" },
  })

  if modelName ~= r.name then ShowModel(r.name) end
  caption:SetText("Drag to turn  ·  Mouse wheel to zoom" .. (modelId and ("  ·  NPC %d"):format(modelId) or ""))

  famIcon:SetTexture(r.icon)
  famName:SetText(sp.family)
  local fam = FamilyAbilities(sp.family)
  famLearn:SetText(fam ~= "" and ("Can learn: " .. fam) or "")

  local kinds = {}
  if sp.rare then kinds[#kinds + 1] = "Rare" end
  if sp.elite then kinds[#kinds + 1] = "Elite" end
  if sp.spawned then kinds[#kinds + 1] = "Quest spawn" end
  if sp.dungeon then kinds[#kinds + 1] = "Dungeon" end
  typeLine:SetText(table.concat(kinds, "  ·  "):upper())
  kindLine:SetText(("%s, level %s"):format(sp.family, sp.level))
  zoneLine:SetText(sp.zone .. (isHere and "  -  you are here" or ""))
  Ink(zoneLine, isHere and INK_GOOD or INK)

  local list = {}

  local spd
  if not r.speed then
    spd = HEX_DIM .. "Not recorded yet.|r Normal is 2.0."
  elseif r.speed < 2.0 then
    spd = ("%s%.1f - faster than most.|r Normal is 2.0; it stays with this pet."):format(HEX_GOOD, r.speed)
  elseif r.speed > 2.0 then
    spd = ("%s%.1f - slower than most.|r Normal is 2.0."):format(HEX_RED, r.speed)
  else
    spd = "2.0, the normal speed."
  end
  list[#list + 1] = { "Attack speed", spd }

  local resp = RespawnText(r)
  if r.status then
    local c = r.status.up and HEX_GOOD or (r.status.up == false and HEX_RED or HEX_DIM)
    resp = resp .. "\n" .. c .. "RareScanner: " .. r.status.text .. "|r"
  elseif not sp.dungeon and not ns.RS.Loaded() then
    resp = resp .. "\n" .. HEX_DIM .. "Enable RareScanner for live spawn timers.|r"
  end
  list[#list + 1] = { "Respawn", resp }

  -- attack speed has its own section above
  local traits = {}
  for _, tr in ipairs(r.traits) do
    if not tr.long:find("^Attack speed") then traits[#traits + 1] = tr end
  end
  if #traits > 0 then
    local lines = {}
    for _, tr in ipairs(traits) do
      if #traits > 2 and tr.short ~= "" then
        lines[#lines + 1] = "- " .. Plain(tr.short)
      else
        lines[#lines + 1] = "- " .. tr.long
      end
    end
    list[#list + 1] = { "Traits", table.concat(lines, "\n") }
  end

  if #r.teaches > 0 then
    local lines = {}
    for _, e in ipairs(r.teaches) do
      local k = ns.IsKnown(e.ab, e.rank.rank)
      lines[#lines + 1] = (k and HEX_DIM or HEX_GOOD) .. ("%s %d%s|r"):format(e.ab.name, e.rank.rank, k and " (known)" or "")
    end
    list[#list + 1] = { "Teaches", table.concat(lines, "\n") }
  end

  local col
  if r.tamed then
    local nick = ns.db.tamedNicks and ns.db.tamedNicks[r.name]
    col = HEX_GOOD .. (type(r.tamed) == "number" and ("Tamed " .. date("%b %d, %Y", r.tamed)) or "Tamed")
      .. (nick and (", you call it " .. nick) or "") .. ".|r"
  elseif not tameable then
    col = HEX_RED .. ("You need level %d to tame it."):format(sp.minLevel) .. "|r"
  else
    col = "Not tamed yet. Taming it adds it to your collection on its own."
  end
  list[#list + 1] = { "Your collection", col }

  SetSections(list)
  tameBtn:SetText(r.tamed and "Mark not tamed" or "Mark tamed")

  if isHere and not r.tamed then
    Book.SetFieldNote(("It roams %s, where you are now. Keep your eyes open."):format(zone))
  elseif not tameable then
    Book.SetFieldNote(("Come back at level %d. Waypoint marks its haunt on your map."):format(sp.minLevel))
  else
    Book.SetFieldNote("Waypoint marks its haunt on your map. Normal attack speed is 2.0.")
  end
end

Render = function()
  local name = state.rares
  -- typing in the search box from a pet's page goes back to the index
  if name and (state.search or "") ~= openSearch then
    name, state.rares, modelName = nil, nil, nil
  end
  local r = name and ns.RS.Info(name)
  if r then
    RenderDetail(r)
  else
    state.rares = nil
    RenderIndex()
  end
end
