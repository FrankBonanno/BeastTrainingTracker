local _, ns = ...

-- Book tab 7: Skinning (only shown to skinners). A session panel with a live
-- clock, rates and the haul so far, Start / End session; a row of records;
-- then past sessions and the all-time ledger, each opening onto its items.

local Book, J = ns.Book, ns.Journal
if not (Book and J) then return end

local INK, INK_DIM, INK_GOOD = Book.INK, Book.INK_DIM, Book.INK_GOOD
local Font, JournalFont, Ink = Book.Font, Book.JournalFont, Book.Ink
local COLS = Book.COLS
local state = Book.state

local PAGE_W = Book.COLS * Book.COL_W
local PANEL_H = 82
local NOTES_Y, NOTE_H, NOTE_W, NOTE_STEP = PANEL_H + 10, 46, 226, 241
local GRID_TOP = NOTES_Y + NOTE_H + 14
local STRIP_MAX = 8
local PELT = "Interface\\Icons\\INV_Misc_Pelt_Wolf_01"

local Render -- forward
local page = Book.RegisterTab(7, { render = function() Render() end })

local function Dur(s) return ns.Chronicle and ns.Chronicle.Duration(s) or (math.floor(s / 60) .. " min") end

local function Clock(s)
  s = math.max(0, math.floor(s))
  return ("%d:%02d:%02d"):format(math.floor(s / 3600), math.floor(s % 3600 / 60), s % 60)
end

-- the item you got most of (cheap: no price lookups)
local function TopItem(items)
  local best, n = nil, 0
  for id, c in pairs(items or {}) do
    if c > n then best, n = id, c end
  end
  return best
end

local function Sources(haul)
  local seen, src = {}, {}
  for _, e in ipairs(haul) do
    if e.source then seen[e.source] = true end
  end
  for _, s in ipairs({ "Naowh Forever", "Auctionator", "TSM", "vendor" }) do
    if seen[s] then src[#src + 1] = s end
  end
  return src
end

local function PriceNote(haul)
  local src = Sources(haul)
  if #src == 0 then return "Prices fill in as the game learns each item." end
  if #src == 1 and src[1] == "vendor" then
    return "Vendor prices. Auctionator, TSM or Naowh Forever (optional) add auction values."
  end
  return "Values from " .. table.concat(src, ", ") .. " - a rough guide, not a promise."
end

local function OpenLedger(key)
  state.skinLedger, state.page = key, 1
  Book.Render()
end

local function Frame(parent, wash)
  local w = parent:CreateTexture(nil, "BACKGROUND")
  w:SetAllPoints()
  w:SetColorTexture(INK[1], INK[2], INK[3], wash)
  for _, side in ipairs({ { "TOPLEFT", "TOPRIGHT", "h" }, { "BOTTOMLEFT", "BOTTOMRIGHT", "h" },
    { "TOPLEFT", "BOTTOMLEFT", "w" }, { "TOPRIGHT", "BOTTOMRIGHT", "w" } }) do
    local t = parent:CreateTexture(nil, "BORDER")
    t:SetColorTexture(0.60, 0.48, 0.28, 0.9)
    t:SetPoint(side[1])
    t:SetPoint(side[2])
    if side[3] == "w" then t:SetWidth(1) else t:SetHeight(1) end
  end
end

------------------------------------------------------------------------
-- Session panel: icon, title, rates, haul strip, live clock, buttons
------------------------------------------------------------------------
local panel = CreateFrame("Button", nil, page)
panel:SetPoint("TOPLEFT", 0, 0)
panel:SetSize(PAGE_W, PANEL_H)
Frame(panel, 0.08)

panel.icon = panel:CreateTexture(nil, "ARTWORK")
panel.icon:SetSize(40, 40)
panel.icon:SetPoint("TOPLEFT", 18, -12)
panel.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
panel.frame = panel:CreateTexture(nil, "OVERLAY")
panel.frame:SetAtlas("spellbook-item-iconframe")
panel.frame:SetSize(52, 48)
panel.frame:SetPoint("TOPLEFT", panel.icon, "TOPLEFT", -11, 1)

panel.title = JournalFont(panel, 17, "SystemFont_Med3")
panel.title:SetPoint("TOPLEFT", panel.icon, "TOPRIGHT", 14, 2)
panel.title:SetWidth(330)
panel.title:SetWordWrap(false)
panel.sub = Font(panel, "SystemFont_Med1")
panel.sub:SetPoint("TOPLEFT", panel.title, "BOTTOMLEFT", 0, -4)
panel.sub:SetWidth(360)
panel.sub:SetWordWrap(false)

-- the session's items so far: small icons with counts
local strip = {}
for i = 1, STRIP_MAX do
  local icon = panel:CreateTexture(nil, "ARTWORK")
  icon:SetSize(16, 16)
  icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  local count = Font(panel, "GameFontNormalSmall")
  count:SetPoint("LEFT", icon, "RIGHT", 3, 0)
  strip[i] = { icon = icon, count = count }
end

local function LayoutStrip(items)
  local list = {}
  for id, n in pairs(items or {}) do list[#list + 1] = { id = id, n = n } end
  table.sort(list, function(a, b) return a.n > b.n end)
  local prev
  for i, s in ipairs(strip) do
    local e = list[i]
    if e then
      s.icon:ClearAllPoints()
      if prev then
        s.icon:SetPoint("LEFT", prev, "RIGHT", 10, 0)
      else
        s.icon:SetPoint("TOPLEFT", panel.sub, "BOTTOMLEFT", 0, -6)
      end
      s.icon:SetTexture(J.ItemIcon(e.id))
      s.count:SetText("x" .. e.n)
      s.icon:Show()
      s.count:Show()
      prev = s.count
    else
      s.icon:Hide()
      s.count:Hide()
    end
  end
end

local startBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
startBtn:SetSize(116, 24)
startBtn:SetPoint("RIGHT", -14, 0)
startBtn:SetText("Start session")
startBtn:SetScript("OnClick", function() J.StartSession() end)

local endBtn = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
endBtn:SetSize(116, 24)
endBtn:SetPoint("RIGHT", -14, 0)
endBtn:SetText("End session")
endBtn:SetScript("OnClick", function() J.EndSession("manual") end)

panel.clockLabel = Font(panel, "GameFontNormalSmall", INK_DIM)
panel.clockLabel:SetPoint("BOTTOMRIGHT", startBtn, "BOTTOMLEFT", -20, 22)
panel.clockLabel:SetJustifyH("RIGHT")
panel.clockLabel:SetText("SESSION TIME")
panel.clock = JournalFont(panel, 28, "SystemFont_Huge2")
panel.clock:SetPoint("TOPRIGHT", panel.clockLabel, "BOTTOMRIGHT", 0, -2)
panel.clock:SetJustifyH("RIGHT")

local function ButtonTip(btn, title, text)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_TOP")
    GameTooltip:AddLine(title, 1, 0.82, 0)
    GameTooltip:AddLine(text, 1, 1, 1, true)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)
end
ButtonTip(startBtn, "Start session", "Start logging a skinning session now. You don't have to: your first skin "
  .. "starts one on its own.")
ButtonTip(endBtn, "End session", "Close this session and save its ledger. Sessions also end on their own when "
  .. "you're back in a city or inn, or after 30 minutes without a skin.")

panel:SetScript("OnClick", function()
  if J.Session() then OpenLedger("current") end
end)
panel:SetScript("OnEnter", function(self)
  local s = J.Session()
  if not s then return end
  GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
  GameTooltip:AddLine("This session", 1, 0.82, 0)
  GameTooltip:AddLine(("Started %s"):format(date("%H:%M", s.start)), 0.8, 0.8, 0.8)
  local haul = J.Haul(s.items)
  for i = 1, math.min(8, #haul) do
    GameTooltip:AddDoubleLine(J.ItemName(haul[i].itemID), tostring(haul[i].count), 1, 1, 1, 1, 1, 1)
  end
  if #haul == 0 then GameTooltip:AddLine("Nothing skinned yet", 0.6, 0.6, 0.6) end
  GameTooltip:AddLine(" ")
  GameTooltip:AddLine("Click to open its ledger", 0.5, 0.5, 0.5)
  GameTooltip:Show()
end)
panel:SetScript("OnLeave", GameTooltip_Hide)

-- the clock ticks every second while a session runs and the page is open
local tick = 0
panel:SetScript("OnUpdate", function(_, elapsed)
  tick = tick + elapsed
  if tick < 1 then return end
  tick = 0
  local s = J.Session()
  if s then panel.clock:SetText(Clock(time() - s.start)) end
end)

local function UpdatePanel()
  local s = J.Session()
  startBtn:SetShown(s == nil)
  endBtn:SetShown(s ~= nil)
  if not s then
    panel.icon:SetTexture(PELT)
    panel.icon:SetDesaturated(true)
    panel.title:SetText("No session running")
    panel.sub:SetText("Your first skin starts one, or press Start session.")
    Ink(panel.sub, INK_DIM)
    panel.clock:SetText("0:00:00")
    Ink(panel.clock, INK_DIM)
    LayoutStrip(nil)
    return
  end
  local top = TopItem(s.items)
  panel.icon:SetTexture(top and J.ItemIcon(top) or PELT)
  panel.icon:SetDesaturated(false)
  panel.title:SetText(s.skins > 0 and ("Session in " .. J.SessionZone(s)) or "Session running")
  local elapsed = time() - s.start
  local worth = J.SessionValue(s)
  local parts = { ("%d skin%s"):format(s.skins, s.skins == 1 and "" or "s"), "~" .. J.Money(worth) }
  -- rates once there's enough of a session to mean something
  if elapsed >= 300 and s.skins > 0 then
    local hours = elapsed / 3600
    parts[#parts + 1] = ("%d skins/hr"):format(math.floor(s.skins / hours + 0.5))
    parts[#parts + 1] = ("~%s/hr"):format(J.Money(worth / hours))
  end
  panel.sub:SetText(table.concat(parts, "  ·  "))
  Ink(panel.sub, INK_GOOD)
  panel.clock:SetText(Clock(elapsed))
  Ink(panel.clock, INK)
  LayoutStrip(s.items)
end

------------------------------------------------------------------------
-- Records: best haul, favourite ground, average gold an hour
------------------------------------------------------------------------
local notes = {}
for i = 1, 3 do
  local n = CreateFrame("Frame", nil, page)
  n:SetSize(NOTE_W, NOTE_H)
  n:SetPoint("TOPLEFT", (i - 1) * NOTE_STEP, -NOTES_Y)
  local shadow = n:CreateTexture(nil, "BACKGROUND", nil, 1)
  shadow:SetPoint("TOPLEFT", 2, -2)
  shadow:SetPoint("BOTTOMRIGHT", 2, -2)
  shadow:SetColorTexture(0, 0, 0, 0.18)
  local card = n:CreateTexture(nil, "BACKGROUND", nil, 2)
  card:SetAllPoints()
  card:SetColorTexture(0.98, 0.94, 0.82, 1)
  local tape = n:CreateTexture(nil, "ARTWORK")
  tape:SetSize(44, 12)
  tape:SetPoint("CENTER", n, "TOPLEFT", 28, 0)
  tape:SetColorTexture(0.86, 0.78, 0.52, 0.8)
  if tape.SetRotation then tape:SetRotation(math.rad(i % 2 == 0 and 8 or -10)) end
  n.label = Font(n, "GameFontNormalSmall", INK_DIM)
  n.label:SetPoint("TOPLEFT", 10, -9)
  n.title = JournalFont(n, 15, "SystemFont_Med1")
  n.title:SetPoint("TOPLEFT", n.label, "BOTTOMLEFT", 0, -3)
  n.title:SetWidth(NOTE_W - 18)
  n.title:SetWordWrap(false)
  notes[i] = n
end

local function SetNote(i, label, title)
  notes[i].label:SetText(label:upper())
  notes[i].title:SetText(title)
end

local function Records()
  local best, zones, seconds, worth = nil, {}, 0, 0
  for _, s in ipairs(J.Sessions()) do
    local w = s.worth or 0
    if not best or w > (best.worth or 0) then best = s end
    for z, n in pairs(s.zones or {}) do zones[z] = (zones[z] or 0) + n end
    seconds = seconds + math.max(0, (s.finish or s.last or s.start) - s.start)
    worth = worth + w
  end
  local cur = J.Session()
  if cur then
    for z, n in pairs(cur.zones or {}) do zones[z] = (zones[z] or 0) + n end
  end
  local ground, n = nil, 0
  for z, c in pairs(zones) do
    if c > n then ground, n = z, c end
  end
  if best then
    SetNote(1, "Best haul", ("%s, %s"):format(J.Money(best.worth or 0), J.SessionZone(best)))
  else
    SetNote(1, "Best haul", "None yet")
  end
  SetNote(2, "Favourite ground", ground and ("%s (%d skins)"):format(ground, n) or "Still scouting")
  if seconds >= 600 then
    SetNote(3, "Average", ("~%s an hour"):format(J.Money(worth / (seconds / 3600))))
  else
    SetNote(3, "Average", "Needs a longer session")
  end
end

------------------------------------------------------------------------
-- Grid of past sessions + the all-time ledger
------------------------------------------------------------------------
local empty = Font(page, "SystemFont_Med1")
empty:SetWidth(PAGE_W)
empty:SetWordWrap(true)

local function SessionItem(s)
  local zone, top = J.SessionZone(s), TopItem(s.items)
  local worth = s.worth or J.SessionValue(s)
  return {
    icon = top and J.ItemIcon(top) or PELT,
    name = zone,
    sub = ("%s  ·  %d skin%s  ·  ~%s"):format(date("%b %d", s.start), s.skins, s.skins == 1 and "" or "s", J.Money(worth)),
    badge = tostring(s.skins),
    onClick = function() OpenLedger(s.start) end,
    tip = function(tt)
      tt:AddLine("Skinning in " .. zone, 1, 0.82, 0)
      tt:AddLine(("%s  -  lasted %s"):format(date("%b %d, %H:%M", s.start), Dur((s.finish or s.last) - s.start)), 0.8, 0.8, 0.8)
      tt:AddLine(" ")
      local haul = J.Haul(s.items)
      for i = 1, math.min(5, #haul) do
        tt:AddDoubleLine(J.ItemName(haul[i].itemID), tostring(haul[i].count), 1, 1, 1, 1, 1, 1)
      end
      tt:AddDoubleLine("Worth about", J.Money(worth), 1, 0.82, 0, 1, 1, 1)
      tt:AddLine(" ")
      tt:AddLine("Click to open its ledger", 0.5, 0.5, 0.5)
    end,
  }
end

------------------------------------------------------------------------
-- A ledger: one session's items (or everything ever skinned)
------------------------------------------------------------------------
local function ShowTop(on)
  panel:SetShown(on)
  for _, n in ipairs(notes) do n:SetShown(on) end
end

-- seconds: how long the session(s) behind this ledger lasted; when: its date and hours
local function RenderLedger(title, items, seconds, skinned, when)
  ShowTop(false)
  local haul = J.Haul(items)
  local total, count, list = 0, 0, {}
  for _, e in ipairs(haul) do
    total, count = total + e.value, count + e.count
    list[#list + 1] = {
      icon = J.ItemIcon(e.itemID), name = J.ItemName(e.itemID), badge = tostring(e.count),
      sub = e.price and ("%s  ·  %s each"):format(J.Money(e.value), J.Money(e.price)) or "No price known",
      subColor = e.price and INK or INK_DIM,
      tip = function(tt)
        if tt.SetItemByID then tt:SetItemByID(e.itemID) else tt:AddLine(J.ItemName(e.itemID), 1, 1, 1) end
        tt:AddLine(" ")
        tt:AddDoubleLine("Skinned", tostring(e.count), 1, 0.82, 0, 1, 1, 1)
        if e.price then
          tt:AddDoubleLine("Price each", J.Money(e.price), 1, 0.82, 0, 1, 1, 1)
          tt:AddDoubleLine("Worth", J.Money(e.value), 1, 0.82, 0, 1, 1, 1)
          tt:AddLine("Price from " .. e.source, 0.5, 0.5, 0.5)
        end
      end,
    }
  end
  Book.SetHeader(title)
  Book.SetStats({
    { "Time", seconds and seconds > 0 and Dur(seconds) or "-" },
    { "Skinned", tostring(skinned) },
    { "Worth", J.Money(total) },
  })
  Book.SetBack(function() OpenLedger(nil) end)
  if #list == 0 then
    empty:ClearAllPoints()
    empty:SetPoint("TOPLEFT", 0, -4)
    empty:SetText("Nothing in this ledger yet.")
  end
  local bits = {}
  if when then bits[#bits + 1] = when end
  if seconds and seconds >= 300 and total > 0 then
    bits[#bits + 1] = ("~%s an hour"):format(J.Money(total / (seconds / 3600)))
  end
  bits[#bits + 1] = ("%d items"):format(count)
  Book.SetFieldNote(table.concat(bits, "  ·  ") .. ".  " .. PriceNote(haul))
  Book.ShowPage(list, COLS * 6, 0)
end

------------------------------------------------------------------------
Render = function()
  empty:SetText("")
  empty:ClearAllPoints()
  empty:SetPoint("TOPLEFT", 0, -(GRID_TOP + 4))
  local rank, max = J.SkinningRank()
  local skill = { "Skinning", rank and ("%d / %d"):format(rank, max or rank) or "Learned" }
  local cur, ledger = J.Session(), state.skinLedger

  if ledger == "current" and cur then
    RenderLedger("This session", cur.items, time() - cur.start, cur.skins,
      ("Since %s, still going"):format(date("%H:%M", cur.start)))
    return
  elseif ledger == "all" then
    local seconds = 0
    for _, s in ipairs(J.Sessions()) do seconds = seconds + math.max(0, (s.finish or s.last or s.start) - s.start) end
    if cur then seconds = seconds + (time() - cur.start) end
    RenderLedger("All time", ns.db.journal and ns.db.journal.skinned, seconds, J.Skins(), "Time is across every session")
    return
  elseif ledger then
    for _, s in ipairs(J.Sessions()) do
      if s.start == ledger then
        local finish = s.finish or s.last or s.start
        RenderLedger(J.SessionZone(s), s.items, finish - s.start, s.skins,
          ("%s, %s - %s"):format(date("%b %d", s.start), date("%H:%M", s.start), date("%H:%M", finish)))
        return
      end
    end
    state.skinLedger = nil
  end

  ShowTop(true)
  UpdatePanel()
  Records()
  local past = J.Sessions()
  local list = {}
  for _, s in ipairs(past) do list[#list + 1] = SessionItem(s) end
  if J.Skins() > 0 then
    list[#list + 1] = {
      icon = PELT, name = "All time", mastered = true,
      sub = ("%d skins  ·  ~%s"):format(J.Skins(), J.Money(J.SkinValue())),
      onClick = function() OpenLedger("all") end,
      tip = function(tt)
        tt:AddLine("All time", 1, 0.82, 0)
        tt:AddLine("Everything you've skinned since the journal began.", 1, 1, 1, true)
        tt:AddLine(" ")
        tt:AddLine("Click to open the ledger", 0.5, 0.5, 0.5)
      end,
    }
  end

  Book.SetStats({
    skill,
    { "Sessions", tostring(#past + (cur and 1 or 0)) },
    { "Lifetime", ("%d skins"):format(J.Skins()) },
  })
  if #list == 0 then
    empty:SetText("No sessions yet. When one ends, its ledger is kept here with what it was worth.")
  end
  Book.SetFieldNote(cur and "A session ends when you're back in town, after 30 quiet minutes, or by hand."
    or PriceNote(J.SkinHaul()))
  Book.ShowPage(list, COLS * 4, GRID_TOP)
end

-- item names and prices arrive after the first lookup; redraw when they do
local ev = CreateFrame("Frame")
pcall(ev.RegisterEvent, ev, "GET_ITEM_INFO_RECEIVED")
pcall(ev.RegisterEvent, ev, "ITEM_DATA_LOAD_RESULT")
ev:SetScript("OnEvent", function()
  if page:IsVisible() then ns.Refresh() end
end)

-- rates and value move with the clock; refresh them now and then
if C_Timer and C_Timer.NewTicker then
  C_Timer.NewTicker(30, function()
    if page:IsVisible() and J.Session() and not state.skinLedger then UpdatePanel() end
  end)
end
