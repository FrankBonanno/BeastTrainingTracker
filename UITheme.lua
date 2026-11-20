local _, ns = ...

------------------------------------------------------------------------
-- UI Theme System for Hunter's Field Guide v2.0
-- Spellbook-inspired color scheme, textures, fonts, and animations
-- Provides centralized styling foundation for all UI tabs
------------------------------------------------------------------------

ns.UITheme = {
  -- Color Palette (WoW Forever Spellbook Aesthetic)
  -- Rich brown parchment with gold accents and light tan text
  colors = {
    -- Parchment backgrounds - darker, more saturated brown
    spellbookBg = { r = 0.353, g = 0.290, b = 0.227, a = 1.0 },     -- Rich brown #5a4a3a
    spellbookDark = { r = 0.267, g = 0.212, b = 0.157, a = 1.0 },   -- Darker brown for depth
    spellbookLight = { r = 0.420, g = 0.345, b = 0.267, a = 1.0 },  -- Slightly lighter brown

    -- Borders and decorative elements
    spellbookBorder = { r = 0.149, g = 0.118, b = 0.075, a = 1.0 }, -- Very dark brown borders
    parchmentEdge = { r = 0.608, g = 0.502, b = 0.345, a = 1.0 },  -- Aged gold/bronze edge

    -- Text colors
    spellbookText = { r = 0.902, g = 0.855, b = 0.737, a = 1.0 },  -- Light tan/cream text
    spellbookTextDim = { r = 0.698, g = 0.655, b = 0.561, a = 1.0 }, -- Muted tan for secondary text
    spellbookTextBright = { r = 0.980, g = 0.969, b = 0.918, a = 1.0 }, -- Brightest tan for emphasis

    -- Headers and accents
    gold = { r = 0.941, g = 0.784, b = 0.165, a = 1.0 },           -- Bright gold for headers
    goldDim = { r = 0.804, g = 0.667, b = 0.098, a = 1.0 },        -- Dimmer gold for inactive

    -- Icon frames
    iconBg = { r = 0.267, g = 0.212, b = 0.157, a = 1.0 },         -- Dark background for icons
    iconBorder = { r = 0.608, g = 0.502, b = 0.345, a = 1.0 },     -- Bronze border for icons
    iconHover = { r = 0.420, g = 0.345, b = 0.267, a = 1.0 },      -- Hover highlight

    -- Status colors (kept for compatibility)
    highlight = { r = 0.675, g = 0.843, b = 0.451, a = 1.0 },      -- Known/learned (green)
    success = { r = 0.251, g = 0.996, b = 0.251, a = 1.0 },        -- Success state
    warning = { r = 1.0, g = 0.561, b = 0.251, a = 1.0 },          -- Needs level (orange)
    error = { r = 0.804, g = 0.0, b = 0.0, a = 1.0 },              -- Unavailable (red)

    -- Pagination and control elements
    buttonNormal = { r = 0.420, g = 0.345, b = 0.267, a = 1.0 },   -- Button background
    buttonHover = { r = 0.498, g = 0.408, b = 0.306, a = 1.0 },    -- Button hover
    buttonActive = { r = 0.941, g = 0.784, b = 0.165, a = 1.0 },   -- Button pressed

    -- Utility colors
    white = { r = 1.0, g = 1.0, b = 1.0, a = 1.0 },                -- Pure white (rarely used)
    transparent = { r = 0.0, g = 0.0, b = 0.0, a = 0.0 },          -- Transparent

    -- Backward compatibility with old color names
    parchment = { r = 0.353, g = 0.290, b = 0.227, a = 1.0 },      -- spellbookBg alias
    parchmentDark = { r = 0.267, g = 0.212, b = 0.157, a = 1.0 },  -- spellbookDark alias
    parchmentAged = { r = 0.608, g = 0.502, b = 0.345, a = 1.0 },  -- parchmentEdge alias
  },

  -- Textures (WoW interface paths)
  textures = {
    -- Background
    spellbookBg = "Interface\\DialogFrame\\UI-DialogBox-Background",

    -- Borders and decorative elements
    spellbookBorder = "Interface\\Tooltips\\UI-Tooltip-Border",
    decorativeBorder = "Interface\\TalentFrame\\TalentFrame-CornerGlow",

    -- Icon frames
    iconFrame = "Interface\\Buttons\\UI-Quickslot-Depress",
    iconBorder = "Interface\\ItemSocketingFrame\\ItemSocket-Border",

    -- Bars and buttons
    statusBar = "Interface\\TargetingFrame\\UI-StatusBar",
    buttonTexture = "Interface\\Buttons\\UI-Panel-Button-Up",

    -- Pagination
    paginationFrame = "Interface\\DialogFrame\\UI-DialogBox-Border",

    -- Highlight effects
    highlight = "Interface\\QuestFrame\\UI-QuestTitleHighlight",
    glow = "Interface\\Tooltips\\UI-Tooltip-OnUse-Border",
  },

  -- Font definitions (using WoW game fonts)
  fonts = {
    -- Section headers - gold, prominent
    title = {
      font = "GameFontNormalLarge",
      size = 16,
      color = "gold",
      flags = "OUTLINE"
    },
    -- Tab/section headers
    header = {
      font = "GameFontNormal",
      size = 13,
      color = "gold",
      flags = "OUTLINE"
    },
    -- Normal body text
    normal = {
      font = "GameFontHighlightSmall",
      size = 11,
      color = "spellbookText",
      flags = ""
    },
    -- Secondary/smaller text
    small = {
      font = "GameFontDisableSmall",
      size = 10,
      color = "spellbookTextDim",
      flags = ""
    },
    -- Tooltip text
    tooltip = {
      font = "GameFontHighlightSmall",
      size = 10,
      color = "spellbookText",
      flags = "OUTLINE"
    },
    -- Pagination controls
    pagination = {
      font = "GameFontNormalSmall",
      size = 11,
      color = "spellbookText",
      flags = ""
    },
    -- Search/input field
    input = {
      font = "GameFontNormal",
      size = 11,
      color = "spellbookText",
      flags = ""
    },
  },

  -- Window constraints (Spellbook-inspired sizing)
  window = {
    minWidth = 600,
    minHeight = 400,
    maxWidth = 1200,
    maxHeight = 850,
    defaultWidth = 950,
    defaultHeight = 680,
    padding = 12,                          -- Padding around main content
  },

  -- Grid sizing (2-column default like spellbook page)
  grid = {
    cellSize = 70,                          -- Size of grid cells (icons + labels)
    cellPadding = 8,                        -- Padding between cells
    columnSpacing = 12,                     -- Space between columns
    rowSpacing = 8,                         -- Space between rows
    defaultColumns = 2,                     -- 2-column layout like spellbook
    responsiveThreshold = 400,              -- Min width before switching to 1 column
  },

  -- Spacing and layout
  spacing = {
    contentMargin = 16,                     -- Margin around main content
    sectionGap = 12,                        -- Gap between sections
    elementGap = 8,                         -- Gap between small elements
    borderWidth = 2,                        -- Width of decorative borders
  },

  -- Border styling
  borders = {
    -- Outer window border
    window = {
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 12,
      bgFile = nil,
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    },
    -- Section borders
    section = {
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8,
      bgFile = nil,
      insets = { left = 1, right = 1, top = 1, bottom = 1 }
    },
    -- Icon frame borders
    icon = {
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 6,
      bgFile = nil,
      insets = { left = 1, right = 1, top = 1, bottom = 1 }
    },
    -- Button borders
    button = {
      edgeFile = "Interface\\Buttons\\UI-Panel-Button-Border",
      edgeSize = 8,
      bgFile = "Interface\\Buttons\\UI-Panel-Button-Up",
      insets = { left = 2, right = 2, top = 2, bottom = 2 }
    },
  },

  -- Animation timings (in seconds)
  animations = {
    tabFade = 0.15,                         -- Tab transition fade
    sectionExpand = 0.3,                    -- Section expand/collapse
    iconHover = 0.1,                        -- Icon hover effect
    buttonPress = 0.08,                     -- Button press feedback
    tooltipDelay = 0.5,                     -- Tooltip appearance delay
    pageTransition = 0.2,                   -- Pagination page transition
  },

  -- Button styling
  buttons = {
    height = 24,
    width = 100,
    textInset = 4,
  },

  -- Search bar styling
  searchBar = {
    height = 28,
    width = 200,
    textInset = 6,
    placeholderColor = "spellbookTextDim",
  },

  -- Pagination styling
  pagination = {
    height = 28,
    buttonWidth = 80,
    buttonHeight = 24,
    spaceBetweenButtons = 8,
  },
}

------------------------------------------------------------------------
-- Color Helper Functions
------------------------------------------------------------------------

-- Get color by name or return a default
function ns.UITheme:GetColor(colorName)
  if not colorName or not self.colors[colorName] then
    return self.colors.spellbookText.r, self.colors.spellbookText.g, self.colors.spellbookText.b, self.colors.spellbookText.a
  end
  local c = self.colors[colorName]
  return c.r, c.g, c.b, c.a or 1.0
end

-- Set color on a texture/fontstring
function ns.UITheme:SetColorOnFrame(frame, colorName)
  if not frame then return end

  local r, g, b, a = self:GetColor(colorName)

  if frame.SetColorTexture then
    frame:SetColorTexture(r, g, b, a)
  elseif frame.SetTextColor then
    frame:SetTextColor(r, g, b)
  elseif frame.SetVertexColor then
    frame:SetVertexColor(r, g, b, a)
  end
end

-- Get color table by name
function ns.UITheme:GetColorTable(colorName)
  if not colorName or not self.colors[colorName] then
    return self.colors.spellbookText
  end
  return self.colors[colorName]
end

------------------------------------------------------------------------
-- Grid and Layout Functions
------------------------------------------------------------------------

-- Calculate grid columns based on window width (responsive)
function ns.UITheme:GetGridColumns(availableWidth)
  local theme = self

  -- If width is too narrow, use 1 column
  if availableWidth < theme.grid.responsiveThreshold then
    return 1
  end

  -- Calculate columns based on cell size and spacing
  local cellWithSpace = theme.grid.cellSize + theme.grid.columnSpacing
  local columns = math.floor((availableWidth - theme.window.padding * 2) / cellWithSpace)

  -- Clamp to default columns
  return math.max(1, math.min(columns, theme.grid.defaultColumns))
end

-- Get grid dimensions for a given number of items
function ns.UITheme:GetGridDimensions(itemCount, availableWidth)
  local columns = self:GetGridColumns(availableWidth)
  local rows = math.ceil(itemCount / columns)

  local totalWidth = (self.grid.cellSize + self.grid.columnSpacing) * columns - self.grid.columnSpacing
  local totalHeight = (self.grid.cellSize + self.grid.rowSpacing) * rows - self.grid.rowSpacing

  return totalWidth, totalHeight, columns, rows
end

------------------------------------------------------------------------
-- Animation Functions
------------------------------------------------------------------------

-- Create a simple animation for opacity fade
function ns.UITheme:FadeFrame(frame, startAlpha, endAlpha, duration)
  if not frame or not frame.SetAlpha then return end

  frame:SetAlpha(startAlpha)
  local elapsed = 0

  local animator = CreateFrame("Frame")
  animator:SetScript("OnUpdate", function(_, delta)
    elapsed = elapsed + delta
    if elapsed >= duration then
      frame:SetAlpha(endAlpha)
      animator:SetScript("OnUpdate", nil)
      animator = nil
    else
      local progress = elapsed / duration
      frame:SetAlpha(startAlpha + (endAlpha - startAlpha) * progress)
    end
  end)
end

-- Create a hover glow effect on a frame
function ns.UITheme:CreateHoverEffect(frame)
  if not frame then return end

  local originalAlpha = frame:GetAlpha() or 1.0

  frame:SetScript("OnEnter", function(self)
    self:SetAlpha(1.0)
  end)

  frame:SetScript("OnLeave", function(self)
    self:SetAlpha(originalAlpha)
  end)
end

-- Scale frame on hover
function ns.UITheme:CreateScaleHoverEffect(frame, scale)
  if not frame then return end
  scale = scale or 1.1

  local originalScale = frame:GetScale() or 1.0

  frame:SetScript("OnEnter", function(self)
    self:SetScale(originalScale * scale)
  end)

  frame:SetScript("OnLeave", function(self)
    self:SetScale(originalScale)
  end)
end

------------------------------------------------------------------------
-- Background and Border Creation Functions
------------------------------------------------------------------------

-- Create a spellbook-style parchment background
function ns.UITheme:CreateSpellbookBg(parent, width, height, offsetX, offsetY)
  if not parent then return nil, nil end

  offsetX = offsetX or 0
  offsetY = offsetY or 0

  -- Main background
  local bg = parent:CreateTexture(nil, "BACKGROUND")
  bg:SetColorTexture(
    self.colors.spellbookBg.r,
    self.colors.spellbookBg.g,
    self.colors.spellbookBg.b,
    self.colors.spellbookBg.a
  )
  bg:SetSize(width, height)
  bg:SetPoint("TOPLEFT", offsetX, offsetY)

  -- Decorative border frame
  local borderFrame = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  borderFrame:SetSize(width, height)
  borderFrame:SetPoint("TOPLEFT", offsetX, offsetY)

  if borderFrame.SetBackdrop then
    borderFrame:SetBackdrop(self.borders.window)
    borderFrame:SetBackdropBorderColor(
      self.colors.spellbookBorder.r,
      self.colors.spellbookBorder.g,
      self.colors.spellbookBorder.b,
      self.colors.spellbookBorder.a
    )
  end

  return bg, borderFrame
end

-- Create a section background with borders
function ns.UITheme:CreateSectionBg(parent, width, height, offsetX, offsetY)
  if not parent then return nil, nil end

  offsetX = offsetX or 0
  offsetY = offsetY or 0

  -- Section background (slightly lighter than main)
  local sectionBg = parent:CreateTexture(nil, "BACKGROUND")
  sectionBg:SetColorTexture(
    self.colors.spellbookDark.r,
    self.colors.spellbookDark.g,
    self.colors.spellbookDark.b,
    self.colors.spellbookDark.a
  )
  sectionBg:SetSize(width, height)
  sectionBg:SetPoint("TOPLEFT", offsetX, offsetY)

  -- Section border
  local sectionBorder = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  sectionBorder:SetSize(width, height)
  sectionBorder:SetPoint("TOPLEFT", offsetX, offsetY)

  if sectionBorder.SetBackdrop then
    sectionBorder:SetBackdrop(self.borders.section)
    sectionBorder:SetBackdropBorderColor(
      self.colors.parchmentEdge.r,
      self.colors.parchmentEdge.g,
      self.colors.parchmentEdge.b,
      self.colors.parchmentEdge.a
    )
  end

  return sectionBg, sectionBorder
end

-- Create an icon frame with border
function ns.UITheme:CreateIconFrame(parent, size, offsetX, offsetY)
  if not parent then return nil, nil end

  offsetX = offsetX or 0
  offsetY = offsetY or 0
  size = size or self.grid.cellSize

  -- Icon background
  local iconFrame = parent:CreateTexture(nil, "BACKGROUND")
  iconFrame:SetColorTexture(
    self.colors.iconBg.r,
    self.colors.iconBg.g,
    self.colors.iconBg.b,
    self.colors.iconBg.a
  )
  iconFrame:SetSize(size, size)
  iconFrame:SetPoint("TOPLEFT", offsetX, offsetY)

  -- Icon border
  local iconBorder = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  iconBorder:SetSize(size, size)
  iconBorder:SetPoint("TOPLEFT", offsetX, offsetY)

  if iconBorder.SetBackdrop then
    iconBorder:SetBackdrop(self.borders.icon)
    iconBorder:SetBackdropBorderColor(
      self.colors.iconBorder.r,
      self.colors.iconBorder.g,
      self.colors.iconBorder.b,
      self.colors.iconBorder.a
    )
  end

  return iconFrame, iconBorder
end

------------------------------------------------------------------------
-- Font Helper Functions
------------------------------------------------------------------------

-- Apply font styling to a FontString
function ns.UITheme:ApplyFont(fontString, fontName)
  if not fontString or not self.fonts[fontName] then return end

  local fontDef = self.fonts[fontName]
  local r, g, b, a = self:GetColor(fontDef.color)

  -- Set font
  fontString:SetFont("Fonts\\" .. fontDef.font .. ".ttf", fontDef.size)

  -- Set color
  fontString:SetTextColor(r, g, b)

  -- Set text flags (outline, etc.)
  if fontDef.flags and fontDef.flags ~= "" then
    fontString:SetShadowColor(0, 0, 0, 0.5)
    fontString:SetShadowOffset(1, -1)
    if string.find(fontDef.flags, "OUTLINE") then
      fontString:SetTextOutline("OUTLINE")
    end
  end
end

------------------------------------------------------------------------
-- Utility Functions
------------------------------------------------------------------------

-- Check if a color is valid
function ns.UITheme:IsValidColor(colorName)
  return self.colors[colorName] ~= nil
end

-- Get contrast color (light/dark based on background)
function ns.UITheme:GetContrastColor(bgColorName)
  -- Spellbook uses light text on dark backgrounds
  return self.colors.spellbookText
end
