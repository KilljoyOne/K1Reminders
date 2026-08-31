local addonName, addon = ...

-- LibSharedMedia-3.0 integration
local LSM = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)

----------------------------------------------------
-- Default SavedVariables Data
----------------------------------------------------
local defaultSettings = {
    enabled = true,
    preWarning = 3, -- seconds before timestamp
    fontSize = 24,
    fontName = "Friz Quadrata TT",
    fontOutline = "OUTLINE",
    barTexture = "Blizzard Raid Bar",
    playSound = true,
    showIcons = true,
    lockFrame = true, -- Ticked (locked) by default on first install
    frameWidth = 450,
    frameHeight = 70,
    frameX = 0,
    frameY = 180,
    framePoint = { "CENTER", "UIParent", "CENTER", 0, 180 }
}

-- Target tracking variables
local playerName = UnitName("player")
local playerClass = select(2, UnitClass("player")):lower()
local playerRole = "DAMAGER"
local isMelee = false

local activeReminders = {}
local combatStartTime = 0
local isCombatActive = false
local isPreviewActive = false
local isUpdatingSliders = false

-- Raid Icon Textures
local RAID_MARKERS = {
    ["{rt1}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1:22|t",
    ["{rt2}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2:22|t",
    ["{rt3}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3:22|t",
    ["{rt4}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4:22|t",
    ["{rt5}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5:22|t",
    ["{rt6}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6:22|t",
    ["{rt7}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7:22|t",
    ["{rt8}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8:22|t",
    ["{star}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_1:22|t",
    ["{circle}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_2:22|t",
    ["{diamond}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_3:22|t",
    ["{triangle}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_4:22|t",
    ["{moon}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_5:22|t",
    ["{square}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_6:22|t",
    ["{cross}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_7:22|t",
    ["{skull}"] = "|TInterface\\TARGETINGFRAME\\UI-RaidTargetingIcon_8:22|t",
}

----------------------------------------------------
-- Main Alert Display Frame
----------------------------------------------------
local alertFrame = CreateFrame("Frame", "K1RemindersAlertFrame", UIParent, "BackdropTemplate")
alertFrame:SetSize(defaultSettings.frameWidth, defaultSettings.frameHeight)
alertFrame:SetClampedToScreen(true)
alertFrame:SetMovable(true)
alertFrame:EnableMouse(true)
alertFrame:RegisterForDrag("LeftButton")

-- Frame Background Texture
local alertTexture = alertFrame:CreateTexture(nil, "BACKGROUND")
alertTexture:SetAllPoints(true)

local backdropTable = {
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true,
    tileSize = 16,
    edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 }
}
alertFrame:SetBackdrop(backdropTable)
alertFrame:SetBackdropBorderColor(0.8, 0.6, 0, 1)

local alertText = alertFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalHuge")
alertText:SetPoint("CENTER", alertFrame, "CENTER")
alertText:SetTextColor(1, 0.82, 0)

alertFrame:SetScript("OnDragStart", function(self)
    if not K1RemindersDB.lockFrame then
        self:StartMoving()
    end
end)

alertFrame:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    
    local left = self:GetLeft()
    local top = self:GetTop()
    
    if left and top then
        K1RemindersDB.framePoint = { "TOPLEFT", "UIParent", "TOPLEFT", left, top - UIParent:GetHeight() }
        
        local centerX, centerY = self:GetCenter()
        local uiCenterX, uiCenterY = UIParent:GetCenter()
        if centerX and uiCenterX then
            K1RemindersDB.frameX = math.floor((centerX - uiCenterX) + 0.5)
            K1RemindersDB.frameY = math.floor((centerY - uiCenterY) + 0.5)

            isUpdatingSliders = true
            if K1RemindersXSlider then K1RemindersXSlider:SetValue(K1RemindersDB.frameX) end
            if K1RemindersYSlider then K1RemindersYSlider:SetValue(K1RemindersDB.frameY) end
            if K1RemindersXEditBox then K1RemindersXEditBox:SetText(tostring(K1RemindersDB.frameX)) end
            if K1RemindersYEditBox then K1RemindersYEditBox:SetText(tostring(K1RemindersDB.frameY)) end
            isUpdatingSliders = false
        end
    end
end)

alertFrame:Hide()

----------------------------------------------------
-- Dynamic Media Loaders (Fonts & Textures)
----------------------------------------------------
local function GetFontPath(name)
    if LSM and name then
        local path = LSM:Fetch("font", name)
        if path then return path end
    end
    if name == "Arial Narrow" then return "Fonts\\ARIALN.TTF" end
    if name == "Skurri" then return "Fonts\\SKURRI.TTF" end
    if name == "Morpheus" then return "Fonts\\MORPHEUS.TTF" end
    return "Fonts\\FRIZQT__.TTF"
end

local function GetTexturePath(name)
    if LSM and name then
        local path = LSM:Fetch("statusbar", name)
        if path then return path end
    end
    return "Interface\\ChatFrame\\ChatFrameBackground"
end

local function RefreshAlertFrameStyle()
    local fontPath = GetFontPath(K1RemindersDB.fontName)
    alertText:SetFont(fontPath, K1RemindersDB.fontSize or 24, K1RemindersDB.fontOutline or "OUTLINE")
    
    local texturePath = GetTexturePath(K1RemindersDB.barTexture)
    alertTexture:SetTexture(texturePath)
    alertTexture:SetVertexColor(0, 0, 0, 0.75)

    alertFrame:SetSize(K1RemindersDB.frameWidth or 450, K1RemindersDB.frameHeight or 70)
    alertFrame:ClearAllPoints()

    if K1RemindersDB.framePoint and #K1RemindersDB.framePoint > 0 then
        local pt, _, relPt, x, y = unpack(K1RemindersDB.framePoint)
        alertFrame:SetPoint(pt, UIParent, relPt or "CENTER", x, y)
    else
        alertFrame:SetPoint("CENTER", UIParent, "CENTER", K1RemindersDB.frameX or 0, K1RemindersDB.frameY or 180)
    end
end

local function UpdatePlayerProfile()
    playerName = UnitName("player")
    playerClass = select(2, UnitClass("player")):lower()
    
    local role = UnitGroupRolesAssigned("player")
    if role and role ~= "NONE" then playerRole = role end

    local spec = GetSpecialization()
    if spec then
        local roleType = GetSpecializationRole(spec)
        isMelee = (roleType == "TANK" or (roleType == "DAMAGER" and (playerClass == "warrior" or playerClass == "rogue" or playerClass == "deathknight" or playerClass == "paladin" or playerClass == "demonhunter" or (playerClass == "druid" and spec == 2) or (playerClass == "shaman" and spec == 2) or (playerClass == "monk" and spec == 3) or (playerClass == "survival" and spec == 3))))
    end
end

local function FetchNoteText()
    if VBM and VBM.Note and VBM.Note.Text then
        return VBM.Note.Text
    elseif MRT and MRT.F and MRT.F.NoteGetText then
        return MRT.F:NoteGetText()
    elseif GMRT and GMRT.F and GMRT.F.NoteGetText then
        return GMRT.F:NoteGetText()
    end
    return nil
end

local function ParseRaidNote()
    UpdatePlayerProfile()
    activeReminders = {}
    
    local noteText = FetchNoteText()
    if not noteText or noteText == "" then return end

    local playerGroup = 1
    if IsInRaid() then
        for i = 1, GetNumGroupMembers() do
            local name, _, subgroup = GetRaidRosterInfo(i)
            if name and name:find(playerName) then
                playerGroup = subgroup
                break
            end
        end
    end

    for line in noteText:gmatch("[^\r\n]+") do
        local lowerLine = line:lower()

        local matchesPlayer = false
        if lowerLine:find(playerName:lower(), 1, true) or
           lowerLine:find(playerClass, 1, true) or
           lowerLine:find("g" .. playerGroup, 1, true) or
           lowerLine:find("group " .. playerGroup, 1, true) or
           (playerRole == "HEALER" and lowerLine:find("healers", 1, true)) or
           (playerRole == "TANK" and lowerLine:find("tanks", 1, true)) or
           (isMelee and lowerLine:find("melee", 1, true)) or
           (not isMelee and playerRole == "DAMAGER" and lowerLine:find("ranged", 1, true)) then
            matchesPlayer = true
        end

        if matchesPlayer then
            local min, sec = line:match("{time:(%d+):(%d+)}")
            if not min then min, sec = line:match("(%d+):(%d+)") end

            if min and sec then
                local triggerSeconds = (tonumber(min) * 60) + tonumber(sec)
                local cleanMessage = line

                if K1RemindersDB.showIcons then
                    for token, iconTexture in pairs(RAID_MARKERS) do
                        cleanMessage = cleanMessage:gsub(token, iconTexture)
                    end
                else
                    for token, _ in pairs(RAID_MARKERS) do
                        cleanMessage = cleanMessage:gsub(token, "")
                    end
                end

                cleanMessage = cleanMessage:gsub("{.-}", ""):gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")

                table.insert(activeReminders, {
                    time = triggerSeconds,
                    message = cleanMessage,
                    triggered = false
                })
            end
        end
    end
end

local function DisplayReminderAlert(message)
    if isPreviewActive then
        isPreviewActive = false
        if K1RemindersPreviewBtn then K1RemindersPreviewBtn:SetText("Preview Alert Window") end
    end

    alertText:SetText(message)
    alertFrame:Show()
    
    if K1RemindersDB.playSound then
        PlaySound(8959, "Master")
    end

    C_Timer.After(4, function()
        if not isCombatActive or alertText:GetText() == message then
            if not isPreviewActive then
                alertFrame:Hide()
            end
        end
    end)
end

local function SetPreviewState(state)
    isPreviewActive = state

    if isPreviewActive then
        alertText:SetText(RAID_MARKERS["{rt8}"] .. " PREVIEW: " .. playerName .. " Personal Cooldown " .. RAID_MARKERS["{rt8}"])
        alertFrame:Show()
        if K1RemindersPreviewBtn then K1RemindersPreviewBtn:SetText("Hide Preview") end
    else
        alertFrame:Hide()
        if K1RemindersPreviewBtn then K1RemindersPreviewBtn:SetText("Preview Alert Window") end
    end
end

local function TogglePreviewMode()
    SetPreviewState(not isPreviewActive)
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

optionsWindow.title = optionsWindow:CreateFontString(nil, "OVERLAY", "GameFontNormal")
optionsWindow.title:SetPoint("TOPLEFT", optionsWindow.TitleBg, "TOPLEFT", 10, -3)
optionsWindow.title:SetText("K1 Reminders Configuration")

local function BuildCustomOptionsUI()
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
            SetPreviewState(false) -- Hide preview when locked
        else
            SetPreviewState(true)  -- Show preview when unlocked
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
                RefreshAlertFrameStyle()
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
        RefreshAlertFrameStyle()
    end)

    CreateSliderWithEditBox(optionsWindow, "K1RemindersWidth", "Window Width", 200, 800, 10, K1RemindersDB.frameWidth or 450, 20, -350, function(val)
        K1RemindersDB.frameWidth = val
        RefreshAlertFrameStyle()
    end)

    CreateSliderWithEditBox(optionsWindow, "K1RemindersHeight", "Window Height", 30, 200, 5, K1RemindersDB.frameHeight or 70, 20, -410, function(val)
        K1RemindersDB.frameHeight = val
        RefreshAlertFrameStyle()
    end)

    ----------------------------------------------------
    -- Sliders & Text Boxes (Column 2)
    ----------------------------------------------------
    CreateSliderWithEditBox(optionsWindow, "K1RemindersX", "Position X Offset", -1000, 1000, 1, K1RemindersDB.frameX or 0, 270, -230, function(val)
        if not isUpdatingSliders then
            K1RemindersDB.frameX = val
            K1RemindersDB.framePoint = { "CENTER", "UIParent", "CENTER", val, K1RemindersDB.frameY or 180 }
            RefreshAlertFrameStyle()
        end
    end)

    CreateSliderWithEditBox(optionsWindow, "K1RemindersY", "Position Y Offset", -600, 600, 1, K1RemindersDB.frameY or 180, 270, -290, function(val)
        if not isUpdatingSliders then
            K1RemindersDB.frameY = val
            K1RemindersDB.framePoint = { "CENTER", "UIParent", "CENTER", K1RemindersDB.frameX or 0, val }
            RefreshAlertFrameStyle()
        end
    end)

    ----------------------------------------------------
    -- Preview Toggle Button
    ----------------------------------------------------
    local btnPreview = CreateFrame("Button", "K1RemindersPreviewBtn", optionsWindow, "UIPanelButtonTemplate")
    btnPreview:SetPoint("TOPLEFT", optionsWindow, "TOPLEFT", 270, -350)
    btnPreview:SetSize(190, 32)
    btnPreview:SetText(isPreviewActive and "Hide Preview" or "Preview Alert Window")
    btnPreview:SetScript("OnClick", function(self)
        TogglePreviewMode()
    end)
end

----------------------------------------------------
-- Engine Events & Update Timers
----------------------------------------------------
local engine = CreateFrame("Frame")
engine:RegisterEvent("ADDON_LOADED")
engine:RegisterEvent("PLAYER_REGEN_DISABLED")
engine:RegisterEvent("PLAYER_REGEN_ENABLED")
engine:RegisterEvent("PLAYER_ENTERING_WORLD")

engine:SetScript("OnEvent", function(self, event, arg1)
    if event == "ADDON_LOADED" and arg1 == addonName then
        K1RemindersDB = K1RemindersDB or defaultSettings
        for k, v in pairs(defaultSettings) do
            if K1RemindersDB[k] == nil then K1RemindersDB[k] = v end
        end

        if LSM then
            LSM:RegisterCallback("LibSharedMedia_Registered", function()
                RefreshAlertFrameStyle()
            end)
        end

        RefreshAlertFrameStyle()
        BuildCustomOptionsUI()

    elseif event == "PLAYER_REGEN_DISABLED" then
        if isPreviewActive then
            SetPreviewState(false)
        end

        if K1RemindersDB.enabled then
            combatStartTime = GetTime()
            isCombatActive = true
            ParseRaidNote()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        isCombatActive = false
        if not isPreviewActive then
            alertFrame:Hide()
        end

    elseif event == "PLAYER_ENTERING_WORLD" then
        UpdatePlayerProfile()
    end
end)

engine:SetScript("OnUpdate", function(self, elapsed)
    if not isCombatActive or not K1RemindersDB.enabled or #activeReminders == 0 then return end

    local currentCombatTime = GetTime() - combatStartTime

    for _, reminder in ipairs(activeReminders) do
        if not reminder.triggered and currentCombatTime >= (reminder.time - K1RemindersDB.preWarning) then
            reminder.triggered = true
            DisplayReminderAlert(reminder.message)
        end
    end
end)

----------------------------------------------------
-- Slash Command Access
----------------------------------------------------
SLASH_K1R1 = "/k1r"
SLASH_K1R2 = "/k1reminders"
SlashCmdList["K1R"] = function(msg)
    if msg == "test" or msg == "preview" then
        TogglePreviewMode()
    else
        if optionsWindow:IsShown() then
            optionsWindow:Hide()
        else
            optionsWindow:Show()
        end
    end
end
