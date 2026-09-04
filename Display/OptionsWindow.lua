local addonName, addon = ...
local LSM = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)

local isUpdatingSliders = false

----------------------------------------------------
-- Preview Toggle Helpers
----------------------------------------------------
function addon.SetPreviewState(state)
    addon.isPreviewActive = state

    if addon.isPreviewActive then
        local playerName = UnitName("player") or "Player"
        addon.alertText:SetText(addon.RAID_MARKERS["{rt8}"] .. " PREVIEW: " .. playerName .. " Personal Cooldown " .. addon.RAID_MARKERS["{rt8}"])
        addon.alertFrame:Show()
        if K1RemindersPreviewBtn then K1RemindersPreviewBtn:SetText("Hide Preview") end
    else
        addon.alertFrame:Hide()
        if K1RemindersPreviewBtn then K1RemindersPreviewBtn:SetText("Preview Alert Window") end
    end
end

function addon.TogglePreviewMode()
    addon.SetPreviewState(not addon.isPreviewActive)
end

function addon.UpdateOptionsSliders(xVal, yVal)
    isUpdatingSliders = true
    if K1RemindersXSlider then K1RemindersXSlider:SetValue(xVal) end
    if K1RemindersYSlider then K1RemindersYSlider:SetValue(yVal) end
    if K1RemindersXEditBox then K1RemindersXEditBox:SetText(tostring(xVal)) end
    if K1RemindersYEditBox then K1RemindersYEditBox:SetText(tostring(yVal)) end
    isUpdatingSliders = false
end

----------------------------------------------------
-- Helper: Create Slider with Linked EditBox
----------------------------------------------------
local function CreateSliderWithEditBox(parent, name, titleText, minVal, maxVal, step, defaultVal, xOfs, yOfs, onValueChangeFunc)
    local slider = CreateFrame("Slider", name .. "Slider", parent, "OptionsSliderTemplate")
    slider:SetPoint("TOPLEFT", parent, "TOPLEFT", xOfs, yOfs)
    slider:SetMinMaxValues(minVal, maxVal)
    slider:SetValueStep(step)
    slider:SetObeyStepOnDrag(true)

    local titleLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    titleLabel:SetPoint("BOTTOMLEFT", slider, "TOPLEFT", 0, 5)
    titleLabel:SetText(titleText)

    -- Text Edit Box
    local editBox = CreateFrame("EditBox", name .. "EditBox", parent, "InputBoxTemplate")
    editBox:SetSize(45, 20)
    editBox:SetPoint("LEFT", slider, "RIGHT", 15, 0)
    editBox:SetAutoFocus(false)

    -- Sync Initial Values
    slider:SetValue(defaultVal)
    editBox:SetText(tostring(defaultVal))

    slider:SetScript("OnValueChanged", function(self, value)
        local val = math.floor(value + 0.5)
        if not isUpdatingSliders then
            editBox:SetText(tostring(val))
            onValueChangeFunc(val)
        end
    end)

    local function ApplyEditBoxValue()
        local text = editBox:GetText()
        local val = tonumber(text)
        if val then
            val = math.max(minVal, math.min(maxVal, math.floor(val + 0.5)))
            editBox:SetText(tostring(val))
            isUpdatingSliders = true
            slider:SetValue(val)
            isUpdatingSliders = false
            onValueChangeFunc(val)
        else
            editBox:SetText(tostring(slider:GetValue()))
        end
    end

    editBox:SetScript("OnEnterPressed", function(self)
        ApplyEditBoxValue()
        self:ClearFocus()
    end)

    editBox:SetScript("OnEditFocusLost", function(self)
        ApplyEditBoxValue()
    end)

    return slider, editBox
end

----------------------------------------------------
-- Custom Standalone Options Window UI
----------------------------------------------------
local optionsWindow = CreateFrame("Frame", "K1RemindersCustomOptionsFrame", UIParent, "BasicFrameTemplateWithInset")
optionsWindow:SetSize(520, 480)
optionsWindow:SetPoint("CENTER", UIParent, "CENTER")
optionsWindow:SetMovable(true)
optionsWindow:EnableMouse(true)
optionsWindow:RegisterForDrag("LeftButton")
optionsWindow:SetScript("OnDragStart", optionsWindow.StartMoving)
optionsWindow:SetScript("OnDragStop", optionsWindow.StopMovingOrSizing)
optionsWindow:Hide()

tinsert(UISpecialFrames, "K1RemindersCustomOptionsFrame")
addon.optionsWindow = optionsWindow

optionsWindow.title = optionsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optionsWindow.title:SetPoint("TOPLEFT", optionsWindow.TitleBg, "TOPLEFT", 10, -3)
optionsWindow.title:SetText("K1 Reminders Configuration")

function addon.BuildCustomOptionsUI()
    local title = optionsWindow:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 20, -35)
    title:SetText("K1 Reminders (by KilljoyOne)")

    -- Checkboxes
    local cbEnable = CreateFrame("CheckButton", nil, optionsWindow, "InterfaceOptionsCheckButtonTemplate")
    cbEnable:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -10)
    cbEnable.Text:SetText("Enable Addon")
    cbEnable:SetChecked(K1RemindersDB.enabled)
    cbEnable:SetScript("OnClick", function(self) K1RemindersDB.enabled = self:GetChecked() end)

    local cbLock = CreateFrame("CheckButton", nil, optionsWindow, "InterfaceOptionsCheckButtonTemplate")
    cbLock:SetPoint("TOPLEFT", cbEnable, "BOTTOMLEFT", 0, -5)
    cbLock.Text:SetText("Lock Alert Frame Position")
    cbLock:SetChecked(K1RemindersDB.lockFrame)
    cbLock:SetScript("OnClick", function(self)
        local isLocked = self:GetChecked()
        K1RemindersDB.lockFrame = isLocked
        
        -- Automatically toggle preview based on lock state
        if isLocked then
            addon.SetPreviewState(false) -- Hide preview when locked
        else
            addon.SetPreviewState(true)  -- Show preview when unlocked
        end
    end)

    local cbSound = CreateFrame("CheckButton", nil, optionsWindow, "InterfaceOptionsCheckButtonTemplate")
    cbSound:SetPoint("TOPLEFT", cbLock, "BOTTOMLEFT", 0, -5)
    cbSound.Text:SetText("Play Alert Sound")
    cbSound:SetChecked(K1RemindersDB.playSound)
    cbSound:SetScript("OnClick", function(self) K1RemindersDB.playSound = self:GetChecked() end)

    ----------------------------------------------------
    -- Font Selection Dropdown
    ----------------------------------------------------
    local fontLabel = optionsWindow:CreateFontString(nil, "ARTWORK", "GameFontNormal")
    fontLabel:SetPoint("TOPLEFT", cbSound, "BOTTOMLEFT", 10, -15)
    fontLabel:SetText("Select Font:")

    local fontDropdown = CreateFrame("Frame", "K1RemindersFontDropdown", optionsWindow, "UIDropDownMenuTemplate")
    fontDropdown:SetPoint("TOPLEFT", fontLabel, "BOTTOMLEFT", -15, -5)

    local fontList = { "Friz Quadrata TT", "Arial Narrow", "Skurri", "Morpheus" }
    if LSM then fontList = LSM:List("font") end

    UIDropDownMenu_SetWidth(fontDropdown, 160)
    UIDropDownMenu_SetText(fontDropdown, K1RemindersDB.fontName or "Friz Quadrata TT")

    UIDropDownMenu_Initialize(fontDropdown, function(self, level, menuList)
        local info = UIDropDownMenu_CreateInfo()
        for _, name in ipairs(fontList) do
            info.text = name
            info.checked = (K1RemindersDB.fontName == name)
            info.func = function()
                K1RemindersDB.fontName = name
                UIDropDownMenu_SetText(fontDropdown, name)
                addon.RefreshAlertFrameStyle()
            end
            UIDropDownMenu_AddButton(info)
        end
    end)

    ----------------------------------------------------
    -- Sliders & Text Boxes (Column 1)
    ----------------------------------------------------
    CreateSliderWithEditBox(optionsWindow, "K1RemindersPreWarn", "Pre-Warning Offset (sec)", 0, 10, 1, K1RemindersDB.preWarning or 3, 20, -230, function(val)
        K1RemindersDB.preWarning = val
    end)

    CreateSliderWithEditBox(optionsWindow, "K1RemindersFont", "Font Size", 14, 40, 1, K1RemindersDB.fontSize or 24, 20, -290, function(val)
        K1RemindersDB.fontSize = val
        addon.RefreshAlertFrameStyle()
    end)

    CreateSliderWithEditBox(optionsWindow, "K1RemindersWidth", "Window Width", 200, 800, 10, K1RemindersDB.frameWidth or 450, 20, -350, function(val)
        K1RemindersDB.frameWidth = val
        addon.RefreshAlertFrameStyle()
    end)

    CreateSliderWithEditBox(optionsWindow, "K1RemindersHeight", "Window Height", 30, 200, 5, K1RemindersDB.frameHeight or 70, 20, -410, function(val)
        K1RemindersDB.frameHeight = val
        addon.RefreshAlertFrameStyle()
    end)

    ----------------------------------------------------
    -- Sliders & Text Boxes (Column 2)
    ----------------------------------------------------
    CreateSliderWithEditBox(optionsWindow, "K1RemindersX", "Position X Offset", -1000, 1000, 1, K1RemindersDB.frameX or 0, 270, -230, function(val)
        if not isUpdatingSliders then
            K1RemindersDB.frameX = val
            K1RemindersDB.framePoint = { "CENTER", "UIParent", "CENTER", val, K1RemindersDB.frameY or 180 }
            addon.RefreshAlertFrameStyle()
        end
    end)

    CreateSliderWithEditBox(optionsWindow, "K1RemindersY", "Position Y Offset", -600, 600, 1, K1RemindersDB.frameY or 180, 270, -290, function(val)
        if not isUpdatingSliders then
            K1RemindersDB.frameY = val
            K1RemindersDB.framePoint = { "CENTER", "UIParent", "CENTER", K1RemindersDB.frameX or 0, val }
            addon.RefreshAlertFrameStyle()
        end
    end)

    ----------------------------------------------------
    -- Preview Toggle Button
    ----------------------------------------------------
    local btnPreview = CreateFrame("Button", "K1RemindersPreviewBtn", optionsWindow, "UIPanelButtonTemplate")
    btnPreview:SetPoint("TOPLEFT", optionsWindow, "TOPLEFT", 270, -350)
    btnPreview:SetSize(190, 32)
    btnPreview:SetText(addon.isPreviewActive and "Hide Preview" or "Preview Alert Window")
    btnPreview:SetScript("OnClick", function(self)
        addon.TogglePreviewMode()
    end)
end
