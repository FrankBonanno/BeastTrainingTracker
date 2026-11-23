local _, ns = ...

-- A cut-out of a zone map with a path drawn on it, for the Chronicle.
-- Built from the client's own map art: the zone's base tiles plus the
-- overlays of the areas this character has explored (a classic zone's base
-- art is only its outline; the explored overlays fill it in), laid out the
-- way Blizzard's world map lays them. Nothing here touches WorldMapFrame.

local M = {}
ns.BookMap = M

local INK_RED = { 0.55, 0.10, 0.04 }
local MAX_SEGMENTS = 300 -- path lines drawn at most (long days are thinned)
local JUMP = 0.15        -- a step longer than this is a flight or a hearth, not a walk

-- least power of two from 16 up that holds `pixels` (an overlay's last tile)
local function FileSize(pixels)
  local size = 16
  while size < pixels do size = size * 2 end
  return size
end

local layerCache = {}

-- the map's first art layer and its pieces: { file, x, y, w, h, fw, fh, explored }
local function Layer(mapID)
  if layerCache[mapID] ~= nil then return layerCache[mapID] or nil end
  local result = false
  if C_Map and C_Map.GetMapArtLayers and C_Map.GetMapArtLayerTextures then
    local layers = C_Map.GetMapArtLayers(mapID)
    local layer = layers and layers[1]
    local files = layer and C_Map.GetMapArtLayerTextures(mapID, 1)
    if layer and (layer.layerWidth or 0) > 0 and files and #files > 0 then
      local TW, TH = layer.tileWidth, layer.tileHeight
      local cols, rows = math.ceil(layer.layerWidth / TW), math.ceil(layer.layerHeight / TH)
      local pieces = {}
      for row = 1, rows do
        for col = 1, cols do
          local file = files[(row - 1) * cols + col]
          if file then
            pieces[#pieces + 1] = { file = file, x = (col - 1) * TW, y = (row - 1) * TH, w = TW, h = TH, fw = TW, fh = TH }
          end
        end
      end
      result = { layer = layer, pieces = pieces, base = #pieces }
    end
  end
  layerCache[mapID] = result
  return result or nil
end

-- explored areas change as you travel, so they're read fresh each time
local function AddExplored(pieces, mapID, TW, TH)
  local get = C_MapExplorationInfo and C_MapExplorationInfo.GetExploredMapTextures
  if not get then return end
  local ok, areas = pcall(get, mapID)
  if not ok then return end
  for _, a in ipairs(areas or {}) do
    local AW, AH, files = a.textureWidth, a.textureHeight, a.fileDataIDs
    if files and not a.isShownByMouseOver and (AW or 0) > 0 and (AH or 0) > 0 then
      local wide, tall = math.ceil(AW / TW), math.ceil(AH / TH)
      for j = 1, tall do
        local h = j < tall and TH or (AH - (tall - 1) * TH)
        for k = 1, wide do
          local file = files[(j - 1) * wide + k]
          if file then
            local w = k < wide and TW or (AW - (wide - 1) * TW)
            pieces[#pieces + 1] = { file = file, explored = true,
              x = a.offsetX + (k - 1) * TW, y = a.offsetY + (j - 1) * TH, w = w, h = h,
              fw = k < wide and TW or FileSize(w), fh = j < tall and TH or FileSize(h) }
          end
        end
      end
    end
  end
end

-- the part of the layer to show: x0, y0, w, h in layer pixels, around the points
-- and shaped like the box
local function Window(layer, pts, boxW, boxH, loose)
  local LW, LH = layer.layerWidth, layer.layerHeight
  local minx, maxx, miny, maxy = 1, 0, 1, 0
  for _, p in ipairs(pts) do
    minx, maxx = math.min(minx, p[1]), math.max(maxx, p[1])
    miny, maxy = math.min(miny, p[2]), math.max(maxy, p[2])
  end
  if maxx < minx then minx, maxx, miny, maxy = 0, 1, 0, 1 end
  local pad = loose and 1.7 or 1.35
  local least = loose and 0.35 or 0.22
  local w = math.max((maxx - minx) * LW * pad, LW * least)
  local h = math.max((maxy - miny) * LH * pad, LH * least)
  local aspect = boxW / boxH
  if w / h < aspect then w = h * aspect else h = w / aspect end
  if w > LW then w = LW; h = w / aspect end
  if h > LH then h = LH; w = h * aspect end
  local cx, cy = (minx + maxx) / 2 * LW, (miny + maxy) / 2 * LH
  local x0 = math.max(0, math.min(LW - w, cx - w / 2))
  local y0 = math.max(0, math.min(LH - h, cy - h / 2))
  return x0, y0, w, h
end

------------------------------------------------------------------------
-- A map view: New(parent, w, h) then :Draw(mapID, trail, marks, loose)
--   trail = { {m, x, y}, ... } (x, y in thousandths, any maps; only mapID's are drawn)
--   marks = { {x=, y=, icon=, tip=fn(tooltip)}, ... } (x, y in thousandths)
------------------------------------------------------------------------
local View = {}
View.__index = View

function M.New(parent, w, h, markSize)
  local v = setmetatable({}, View)
  v.w, v.h, v.markSize = w, h, markSize or 14
  v.frame = CreateFrame("Frame", nil, parent)
  v.frame:SetSize(w, h)
  v.scroll = CreateFrame("ScrollFrame", nil, v.frame)
  v.scroll:SetAllPoints()
  v.canvas = CreateFrame("Frame", nil, v.scroll)
  v.canvas:SetSize(w, h)
  v.scroll:SetScrollChild(v.canvas)
  v.overlay = CreateFrame("Frame", nil, v.canvas)
  v.overlay:SetAllPoints()
  v.overlay:SetFrameLevel(v.canvas:GetFrameLevel() + 2)
  v.tiles, v.lines, v.marks = {}, {}, {}
  return v
end

function View:Draw(mapID, trail, marks, loose)
  -- pooled views get reused for other days, so the ends of the path go in the key too
  local first, last = trail and trail[1], trail and trail[#trail]
  local sig = ("%s:%d:%d:%s:%s:%s"):format(tostring(mapID), #(trail or {}), #(marks or {}), tostring(loose),
    first and (first[2] .. "," .. first[3]) or "", last and (last[2] .. "," .. last[3]) or "")
  if sig == self.sig then
    -- same drawing, but the marks may belong to another entry now
    for i, mk in ipairs(marks or {}) do
      local b = self.marks[i]
      if b then b.tip, b.click = mk.tip, mk.click; b.icon:SetTexture(mk.icon or "Interface\\Icons\\Ability_Hunter_BeastCall") end
    end
    return self.ok
  end
  self.sig = sig
  self.ok = false
  local info = mapID and Layer(mapID)
  if not info then
    for _, t in ipairs(self.tiles) do t:Hide() end
    for _, l in ipairs(self.lines) do l:Hide() end
    for _, m in ipairs(self.marks) do m:Hide() end
    return false
  end
  local layer = info.layer
  local LW, LH = layer.layerWidth, layer.layerHeight

  local pts = {}
  for _, p in ipairs(trail or {}) do
    if p[1] == mapID then pts[#pts + 1] = { p[2] / 1000, p[3] / 1000 } end
  end
  for _, mk in ipairs(marks or {}) do pts[#pts + 1] = { mk.x / 1000, mk.y / 1000 } end

  local x0, y0, ww = Window(layer, pts, self.w, self.h, loose)
  local s = self.w / ww
  self.canvas:SetSize(LW * s, LH * s)

  -- tiles: the base, then the explored overlays on top
  local pieces = {}
  for i = 1, info.base do pieces[i] = info.pieces[i] end
  AddExplored(pieces, mapID, layer.tileWidth, layer.tileHeight)
  for i, p in ipairs(pieces) do
    local t = self.tiles[i]
    if not t then
      t = self.canvas:CreateTexture(nil, "ARTWORK")
      self.tiles[i] = t
    end
    t:SetDrawLayer(p.explored and "ARTWORK" or "BACKGROUND")
    t:SetTexture(p.file)
    t:ClearAllPoints()
    t:SetPoint("TOPLEFT", self.canvas, "TOPLEFT", p.x * s, -p.y * s)
    t:SetSize(p.w * s, p.h * s)
    t:SetTexCoord(0, p.w / p.fw, 0, p.h / p.fh)
    -- a little warmth so the map sits on the parchment
    t:SetVertexColor(1, 0.95, 0.84)
    t:Show()
  end
  for i = #pieces + 1, #self.tiles do self.tiles[i]:Hide() end
  self.scroll:SetHorizontalScroll(x0 * s)
  self.scroll:SetVerticalScroll(y0 * s)

  -- the path, thinned on long days; jumps (flights, hearths) aren't joined
  local path = {}
  for _, p in ipairs(trail or {}) do
    if p[1] == mapID then path[#path + 1] = p end
  end
  local step = math.max(1, math.ceil(#path / MAX_SEGMENTS))
  local n = 0
  local prev
  for i = 1, #path, step do
    local p = path[i]
    if prev then
      local dx, dy = (p[2] - prev[2]) / 1000, (p[3] - prev[3]) / 1000
      if math.abs(dx) + math.abs(dy) < JUMP then
        n = n + 1
        local l = self.lines[n]
        if not l then
          l = self.overlay:CreateLine(nil, "OVERLAY")
          l:SetColorTexture(INK_RED[1], INK_RED[2], INK_RED[3], 0.85)
          self.lines[n] = l
        end
        l:SetThickness(loose and 3 or 2)
        l:SetStartPoint("TOPLEFT", self.canvas, prev[2] / 1000 * LW * s, -prev[3] / 1000 * LH * s)
        l:SetEndPoint("TOPLEFT", self.canvas, p[2] / 1000 * LW * s, -p[3] / 1000 * LH * s)
        l:Show()
      end
    end
    prev = p
  end
  for i = n + 1, #self.lines do self.lines[i]:Hide() end

  -- the day's events, where they happened
  for i, mk in ipairs(marks or {}) do
    local b = self.marks[i]
    if not b then
      b = CreateFrame("Button", nil, self.overlay)
      b:SetFrameLevel(self.overlay:GetFrameLevel() + 2)
      b.ring = b:CreateTexture(nil, "BACKGROUND")
      b.ring:SetPoint("TOPLEFT", -2, 2)
      b.ring:SetPoint("BOTTOMRIGHT", 2, -2)
      b.ring:SetColorTexture(0.18, 0.11, 0.06, 0.9)
      b.icon = b:CreateTexture(nil, "ARTWORK")
      b.icon:SetAllPoints()
      b.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
      b:SetScript("OnEnter", function(self)
        if not self.tip then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        self.tip(GameTooltip)
        GameTooltip:Show()
      end)
      b:SetScript("OnLeave", GameTooltip_Hide)
      -- a click on a mark is a click on whatever holds the map
      b:SetScript("OnClick", function(self) if self.click then self.click() end end)
      self.marks[i] = b
    end
    b:SetSize(self.markSize, self.markSize)
    b:ClearAllPoints()
    b:SetPoint("CENTER", self.canvas, "TOPLEFT", mk.x / 1000 * LW * s, -mk.y / 1000 * LH * s)
    b.icon:SetTexture(mk.icon or "Interface\\Icons\\Ability_Hunter_BeastCall")
    b.tip, b.click = mk.tip, mk.click
    b:EnableMouse(mk.tip ~= nil or mk.click ~= nil)
    b:Show()
  end
  for i = #(marks or {}) + 1, #self.marks do self.marks[i]:Hide() end

  self.ok = true
  return true
end

-- the uiMapID with the most of the day's points, and its name
function M.MainMap(trail)
  local counts, best, n = {}, nil, 0
  for _, p in ipairs(trail or {}) do
    counts[p[1]] = (counts[p[1]] or 0) + 1
    if counts[p[1]] > n then best, n = p[1], counts[p[1]] end
  end
  if not best then return end
  local info = C_Map and C_Map.GetMapInfo and C_Map.GetMapInfo(best)
  return best, info and info.name, n
end

function M.HasArt(mapID) return Layer(mapID) ~= nil end
