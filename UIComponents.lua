local _, ns = ...

------------------------------------------------------------------------
-- UI Components Library for v2.0
-- Modular widget factory for parchment-themed UI
------------------------------------------------------------------------

ns.UIComponents = {}

-- Create an icon tab button
function ns.UIComponents:CreateIconTab(parent, icon, tooltipText, onSelect)
  local tab = CreateFrame("Button", nil, parent)
  tab:SetSize(48, 48)
  tab:SetNormalTexture(icon)
  tab:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")

  if onSelect then
    tab:SetScript("OnClick", onSelect)
  end

  if tooltipText then
    tab:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
      GameTooltip:AddLine(tooltipText, 1, 0.82, 0)
      GameTooltip:Show()
    end)
    tab:SetScript("OnLeave", GameTooltip_Hide)
  end

  return tab
end

-- Create a checkbox with label
function ns.UIComponents:CreateCheckbox(parent, label, key, tip, onChange)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(22, 22)

  local fs = cb.text or cb.Text
  if not fs then
    fs = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    fs:SetPoint("LEFT", cb, "RIGHT", 2, 0)
  end
  fs:SetFontObject("GameFontHighlightSmall")
  fs:SetText(label)

  cb:SetScript("OnClick", function(self)
    if onChange then
      onChange(self:GetChecked() and true or false)
    end
  end)

  if tip then
    cb:SetScript("OnEnter", function(self)
      GameTooltip:SetOwner(self, "ANCHOR_TOP")
      GameTooltip:AddLine(label, 1, 0.82, 0)
      GameTooltip:AddLine(tip, 1, 1, 1, true)
      GameTooltip:Show()
    end)
    cb:SetScript("OnLeave", GameTooltip_Hide)
  end

  cb.key = key
  return cb
end

-- Create a grid container for icons
function ns.UIComponents:CreateGridContainer(parent, columns)
  local grid = CreateFrame("Frame", nil, parent)
  grid.items = {}
  grid.columns = columns or 5
  grid.cellSize = 64
  grid.padding = 4

  function grid:AddItem(icon, text, onClick, onHover)
    local index = #self.items + 1
    local row = math.floor((index - 1) / self.columns)
    local col = (index - 1) % self.columns

    local item = CreateFrame("Button", nil, self)
    item:SetSize(self.cellSize, self.cellSize)
    item:SetPoint("TOPLEFT",
      col * (self.cellSize + self.padding),
      -(row * (self.cellSize + self.padding)))

    -- Icon texture
    local itemIcon = item:CreateTexture(nil, "ARTWORK")
    itemIcon:SetAllPoints(item)
    itemIcon:SetTexture(icon)
    itemIcon:SetTexCoord(0.07, 0.93, 0.07, 0.93)

    -- Highlight
    local hl = item:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints(item)
    hl:SetTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight")
    hl:SetBlendMode("ADD")

    if onClick then
      item:SetScript("OnClick", onClick)
    end

    if onHover then
      item:SetScript("OnEnter", function()
        onHover(true)
      end)
      item:SetScript("OnLeave", function()
        onHover(false)
      end)
    end

    self.items[index] = item
    return item
  end

  function grid:SetSize(w, h)
    CreateFrame.SetSize(self, w, h)
  end

  return grid
end

-- Create a collapsible section
function ns.UIComponents:CreateCollapsibleSection(parent, title, iconTexture)
  local section = CreateFrame("Frame", nil, parent)
  section:SetSize(300, 50)
  section.isExpanded = true
  section.content = {}

  -- Header button
  local header = CreateFrame("Button", nil, section)
  header:SetSize(300, 28)
  header:SetPoint("TOP", 0, 0)

  -- Background
  local headerBg = header:CreateTexture(nil, "BACKGROUND")
  headerBg:SetAllPoints(header)
  ns.UITheme:SetColorOnFrame(headerBg, "parchmentDark")

  -- Toggle icon
  local toggle = header:CreateTexture(nil, "ARTWORK")
  toggle:SetSize(14, 14)
  toggle:SetPoint("LEFT", 4, 0)
  toggle:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")

  -- Title text
  local titleFs = header:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  titleFs:SetPoint("LEFT", 24, 0)
  titleFs:SetText(title)
  local r, g, b = ns.UITheme:GetColor("gold")
  titleFs:SetTextColor(r, g, b)

  -- Content frame
  local content = CreateFrame("Frame", nil, section)
  content:SetSize(300, 100)
  content:SetPoint("TOP", header, "BOTTOM", 0, 0)

  local contentBg = content:CreateTexture(nil, "BACKGROUND")
  contentBg:SetAllPoints(content)
  ns.UITheme:SetColorOnFrame(contentBg, "parchment")

  function section:Toggle()
    self.isExpanded = not self.isExpanded
    if self.isExpanded then
      toggle:SetTexture("Interface\\Buttons\\UI-MinusButton-Up")
      content:Show()
    else
      toggle:SetTexture("Interface\\Buttons\\UI-PlusButton-Up")
      content:Hide()
    end
  end

  function section:AddContent(widget)
    table.insert(self.content, widget)
    widget:SetParent(content)
  end

  header:SetScript("OnClick", function()
    section:Toggle()
  end)

  section.header = header
  section.content = content
  section.toggle = toggle

  return section
end

-- Create a search box with filtering
function ns.UIComponents:CreateSearchBox(parent, onTextChanged, suggestions)
  local searchFrame = CreateFrame("Frame", nil, parent)
  searchFrame:SetSize(200, 24)

  local searchLabel = searchFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  searchLabel:SetPoint("LEFT", 0, 0)
  searchLabel:SetText("Search")

  local search = CreateFrame("EditBox", nil, searchFrame, "InputBoxTemplate")
  search:SetSize(200, 20)
  search:SetPoint("LEFT", searchLabel, "RIGHT", 12, 0)
  search:SetAutoFocus(false)

  search:SetScript("OnEscapePressed", function(self)
    self:SetText("")
    self:ClearFocus()
  end)

  search:SetScript("OnEnterPressed", function(self)
    self:ClearFocus()
  end)

  search:SetScript("OnTextChanged", function(self)
    if onTextChanged then
      local text = (self:GetText() or ""):lower():match("^%s*(.-)%s*$")
      onTextChanged(text)
    end
  end)

  searchFrame.editBox = search
  return searchFrame
end

-- Create a simple button
function ns.UIComponents:CreateButton(parent, text, width, onClick)
  local btn = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  btn:SetSize(width or 100, 22)
  btn:SetText(text)

  if onClick then
    btn:SetScript("OnClick", onClick)
  end

  return btn
end

-- Create a detail modal/overlay
function ns.UIComponents:CreateModal(parent, title, width, height)
  local modal = CreateFrame("Frame", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  modal:SetSize(width or 400, height or 300)
  modal:SetPoint("CENTER", parent, "CENTER", 0, 0)
  modal:SetFrameStrata("DIALOG")
  modal:EnableMouse(true)

  if modal.SetBackdrop then
    modal:SetBackdrop({
      bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    modal:SetBackdropColor(
      ns.UITheme.colors.parchment.r,
      ns.UITheme.colors.parchment.g,
      ns.UITheme.colors.parchment.b
    )
    modal:SetBackdropBorderColor(
      ns.UITheme.colors.parchmentAged.r,
      ns.UITheme.colors.parchmentAged.g,
      ns.UITheme.colors.parchmentAged.b
    )
  end

  -- Title
  local titleFs = modal:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  titleFs:SetPoint("TOP", 0, -10)
  titleFs:SetText(title)
  local r, g, b = ns.UITheme:GetColor("gold")
  titleFs:SetTextColor(r, g, b)

  -- Close button
  local closeBtn = CreateFrame("Button", nil, modal, "UIPanelCloseButton")
  closeBtn:SetPoint("TOPRIGHT", -2, -2)
  closeBtn:SetScript("OnClick", function()
    modal:Hide()
  end)

  -- Content frame
  local content = CreateFrame("Frame", nil, modal)
  content:SetPoint("TOPLEFT", 10, -30)
  content:SetPoint("BOTTOMRIGHT", -10, 10)

  modal.content = content
  modal.titleFs = titleFs

  -- Allow dragging
  modal:SetMovable(true)
  modal:EnableMouse(true)
  titleFs:SetScript("OnMouseDown", function(self)
    if GetMouseButtonClicked() == "LeftButton" then
      modal:StartMoving()
    end
  end)
  titleFs:SetScript("OnMouseUp", function()
    modal:StopMovingOrSizing()
  end)

  return modal
end

-- Create a status bar
function ns.UIComponents:CreateStatusBar(parent, label, width, height)
  local bar = CreateFrame("StatusBar", nil, parent)
  bar:SetSize(width or 200, height or 20)
  bar:SetStatusBarTexture("Interface\\TargetingFrame\\UI-StatusBar")

  local r, g, b = ns.UITheme:GetColor("highlight")
  bar:SetStatusBarColor(r, g, b)

  -- Background
  local bg = bar:CreateTexture(nil, "BACKGROUND")
  bg:SetAllPoints(bar)
  bg:SetColorTexture(0, 0, 0, 0.5)

  -- Border
  local border = CreateFrame("Frame", nil, bar, BackdropTemplateMixin and "BackdropTemplate" or nil)
  border:SetPoint("TOPLEFT", -2, 2)
  border:SetPoint("BOTTOMRIGHT", 2, -2)
  if border.SetBackdrop then
    border:SetBackdrop({
      edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
      edgeSize = 8
    })
    border:SetBackdropBorderColor(0.6, 0.6, 0.6, 0.9)
  end

  -- Label
  if label then
    local labelFs = bar:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    labelFs:SetPoint("CENTER", 0, 0)
    labelFs:SetText(label)
    bar.label = labelFs
  end

  bar.bg = bg
  bar.border = border

  return bar
end

-- Create a simple text label
function ns.UIComponents:CreateLabel(parent, text, fontType)
  local label = parent:CreateFontString(nil, "OVERLAY", fontType or "GameFontHighlightSmall")
  label:SetText(text)
  return label
end
