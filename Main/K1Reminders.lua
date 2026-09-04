local addonName, addon = ...
addon.engine = addon.engine or {}

-- LibSharedMedia-3.0 integration
local LSM = LibStub and LibStub:GetLibrary("LibSharedMedia-3.0", true)

----------------------------------------------------
-- Default SavedVariables Data
----------------------------------------------------
addon.defaultSettings = {
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
addon.isPreviewActive = false

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
addon.RAID_MARKERS = RAID_MARKERS

----------------------------------------------------
-- Main Alert Display Frame
----------------------------------------------------
local alertFrame = CreateFrame("Frame", "K1RemindersAlertFrame", UIParent, "BackdropTemplate")
alertFrame:SetSize(addon.defaultSettings.frameWidth, addon.defaultSettings.frameHeight)
alertFrame:SetClampedToScreen(true)
alertFrame:SetMovable(true)
alertFrame:EnableMouse(true)
alertFrame:RegisterForDrag("LeftButton")
addon.alertFrame = alertFrame

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
addon.alertText = alertText

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

            if addon.UpdateOptionsSliders then
                addon.UpdateOptionsSliders(K1RemindersDB.frameX, K1RemindersDB.frameY)
            end
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

function addon.RefreshAlertFrameStyle()
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
    if addon.isPreviewActive then
        addon.SetPreviewState(false)
    end

    alertText:SetText(message)
    alertFrame:Show()
    
    if K1RemindersDB.playSound then
        PlaySound(8959, "Master")
    end

    C_Timer.After(4, function()
        if not isCombatActive or alertText:GetText() == message then
            if not addon.isPreviewActive then
                alertFrame:Hide()
            end
        end
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
        K1RemindersDB = K1RemindersDB or addon.defaultSettings
        for k, v in pairs(addon.defaultSettings) do
            if K1RemindersDB[k] == nil then K1RemindersDB[k] = v end
        end

        if LSM then
            LSM:RegisterCallback("LibSharedMedia_Registered", function()
                addon.RefreshAlertFrameStyle()
            end)
        end

        addon.RefreshAlertFrameStyle()
        if addon.BuildCustomOptionsUI then
            addon.BuildCustomOptionsUI()
        end

    elseif event == "PLAYER_REGEN_DISABLED" then
        if addon.isPreviewActive then
            addon.SetPreviewState(false)
        end

        if K1RemindersDB.enabled then
            combatStartTime = GetTime()
            isCombatActive = true
            ParseRaidNote()
        end

    elseif event == "PLAYER_REGEN_ENABLED" then
        isCombatActive = false
        if not addon.isPreviewActive then
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
        addon.TogglePreviewMode()
    else
        if addon.optionsWindow:IsShown() then
            addon.optionsWindow:Hide()
        else
            addon.optionsWindow:Show()
        end
    end
end
