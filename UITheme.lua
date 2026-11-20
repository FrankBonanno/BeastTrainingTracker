local _, ns = ...

------------------------------------------------------------------------
-- UI Theme System for v2.0
-- Centralized color scheme, textures, fonts, and animations
------------------------------------------------------------------------

ns.UITheme = {
  -- Color Palette (Spellbook Parchment Aesthetic)
  colors = {
    parchment = { r = 0.95, g = 0.92, b = 0.82, a = 1.0 },        -- Main background
    parchmentDark = { r = 0.85, g = 0.80, b = 0.65, a = 1.0 },    -- Accents
    parchmentAged = { r = 0.70, g = 0.62, b = 0.45, a = 1.0 },    -- Borders
    parchmentGold = { r = 0.95, g = 0.85, b = 0.55, a = 1.0 },    -- Gold accents
    highlight = { r = 0.67, g = 0.83, b = 0.45, a = 1.0 },        -- Success/active
    gold = { r = 1.0, g = 0.82, b = 0.0, a = 1.0 },               -- Titles
    white = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },               -- Text
    gray = { r = 0.5, g = 0.5, b = 0.5, a = 1.0 },                -- Disabled
    dimText = { r = 0.6, g = 0.6, b = 0.6, a = 1.0 },             -- Secondary text
    success = { r = 0.25, g = 1.0, b = 0.25, a = 1.0 },           -- Known/learned
    warning = { r = 1.0, g = 0.56, b = 0.25, a = 1.0 },           -- Needs level
    error = { r = 0.8, g = 0.0, b = 0.0, a = 1.0 },               -- Unavailable
  },

  -- Textures
  textures = {
    parchmentBg = "Interface\\DialogFrame\\UI-DialogBox-Background",
    parchmentBorder = "Interface\\Tooltips\\UI-Tooltip-Border",
    highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    statusBar = "Interface\\TargetingFrame\\UI-StatusBar",
  },

  -- Font definitions
  fonts = {
    title = { font = "GameFontNormalLarge", size = 16, color = "gold" },
    header = { font = "GameFontNormal", size = 13, color = "gold" },
    normal = { font = "GameFontHighlightSmall", size = 11, color = "white" },
    small = { font = "GameFontDisableSmall", size = 10, color = "dimText" },
    tooltip = { font = "GameFontHighlightSmall", size = 10, color = "white" },
  },

  -- Window constraints
  window = {
    minWidth = 600,
    minHeight = 400,
    maxWidth = 1200,
    maxHeight = 800,
    defaultWidth = 900,
    defaultHeight = 630,
  },

  -- Grid sizing
  grid = {
    cellSize = 64,
    padding = 4,
    minColumns = 3,
  },

  -- Animation timings (in seconds)
  animations = {
    tabFade = 0.15,
    sectionExpand = 0.3,
    modalAppear = 0.2,
    tooltipDelay = 0.5,
  },
}

-- Get color by name or return a default
function ns.UITheme:GetColor(colorName)
  if not colorName or not self.colors[colorName] then
    return self.colors.white
  end
  local c = self.colors[colorName]
  return c.r, c.g, c.b, c.a or 1.0
end

-- Set color on a texture/fontstring
function ns.UITheme:SetColorOnFrame(frame, colorName)
  if frame.SetColorTexture then
    local r, g, b, a = self:GetColor(colorName)
    frame:SetColorTexture(r, g, b, a)
  elseif frame.SetTextColor then
    local r, g, b = self:GetColor(colorName)
    frame:SetTextColor(r, g, b)
  end
end

-- Calculate grid columns based on window width
function ns.UITheme:GetGridColumns(availableWidth)
  local cellWithPadding = self.grid.cellSize + self.grid.padding
  local columns = math.max(self.grid.minColumns, math.floor((availableWidth - 32) / cellWithPadding))
  return columns
end

-- Create a simple animation for opacity fade
function ns.UITheme:FadeFrame(frame, startAlpha, endAlpha, duration)
  if not frame.SetAlpha then return end

  frame:SetAlpha(startAlpha)
  local elapsed = 0

  local animator = CreateFrame("Frame")
  animator:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= duration then
      frame:SetAlpha(endAlpha)
      animator:SetScript("OnUpdate", nil)
    else
      local progress = elapsed / duration
      frame:SetAlpha(startAlpha + (endAlpha - startAlpha) * progress)
    end
  end)
end

-- Create a parchment background texture
function ns.UITheme:CreateParchmentBg(parent, x, y, w, h)
  local bg = parent:CreateTexture(nil, "BACKGROUND")
  bg:SetPoint("TOPLEFT", x, y)
  bg:SetSize(w, h)
  bg:SetColorTexture(self.colors.parchment.r, self.colors.parchment.g, self.colors.parchment.b)

  -- Add aged border effect
  local border = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  border:SetPoint("TOPLEFT", parent, "TOPLEFT", x - 2, y + 2)
  border:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -(w - 2), -(h - 2))
  if border.SetBackdrop then
    border:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    })
    border:SetBackdropBorderColor(
      self.colors.parchmentAged.r,
      self.colors.parchmentAged.g,
      self.colors.parchmentAged.b
    )
  end

  return bg, border
end
