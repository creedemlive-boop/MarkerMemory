local addonName = ...
local MM = CreateFrame("Frame", "MarkerMemoryFrame", UIParent, "BasicFrameTemplateWithInset")
MM:SetSize(320, 320)
MM:SetPoint("CENTER")
MM:Hide()

-- Make frame movable
MM:EnableMouse(true)
MM:SetMovable(true)
MM:RegisterForDrag("LeftButton")
MM:SetClampedToScreen(true)
MM:SetScript("OnDragStart", function(self) self:StartMoving() end)
MM:SetScript("OnDragStop", function(self) self:StopMovingOrSizing() end)

SLASH_MARKERMEMORY1 = "/mm"
SlashCmdList["MARKERMEMORY"] = function()
    if MM:IsShown() then MM:Hide() else MM:Show() end
end

MM.title = MM:CreateFontString(nil, "OVERLAY")
MM.title:SetPoint("TOP", MM, "TOP", 0, -6)
MM.title:SetJustifyH("CENTER")
MM.title:SetFontObject("GameFontNormalLarge")
-- title will be set after localization is available

MM.sequence = {}
MM.playing = false
MM.ticker = nil
MM.autoOpenZoneIDs = {
    [2634] = true,
}
MM.selectedMarkerKeys = { "STAR", "CIRCLE", "DIAMOND", "TRIANGLE", "MOON", "SQUARE", "CROSS", "SKULL" }

local function shouldAutoOpen()
    local zoneID = C_Map.GetBestMapForUnit("player");
    return MM.autoOpenZoneIDs[zoneID] == true
end

local function updateAutoOpenState()
    if shouldAutoOpen() then
        MM:Show()
    else
        if MM:IsShown() and not MM.playing then
            MM:Hide()
        end
    end
end

local markers = {
    { id = 1, key = "STAR",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
    { id = 2, key = "CIRCLE",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_2" },
    { id = 3, key = "DIAMOND", icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_3" },
    { id = 4, key = "TRIANGLE",icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_4" },
    { id = 5, key = "MOON",    icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_5" },
    { id = 6, key = "SQUARE",  icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_6" },
    { id = 7, key = "CROSS",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_7" },
    { id = 8, key = "SKULL",   icon = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_8" },
}

-- localization is provided by MarkerMemory_Locales.lua; fall back to defaults if missing
local L = MarkerMemory_L or {
    TITLE = "MarkerMemory",
    READY = "Ready",
    SEQ_EMPTY = "Sequence: empty",
    SEQ = "Sequence: %d Marker",
    SPEED = "Speed",
    START = "Start",
    STAR = "Star",
    CIRCLE = "Circle",
    DIAMOND = "Diamond",
    TRIANGLE = "Triangle",
    MOON = "Moon",
    SQUARE = "Square",
    CROSS = "Cross",
    SKULL = "Skull",
}

-- set title now that localization is available
MM.title:SetText(L.TITLE)

local speeds = {
    { label = "1.5s", value = 1.5 },
    { label = "2.0s", value = 2.0 },
    { label = "2.5s", value = 2.5 },
    { label = "3.0s", value = 3.0 },
}
MM.speed = 2.0
MM.speedShow = "2.0s"

local display = CreateFrame("Frame", nil, MM, "BackdropTemplate")
display:SetSize(80, 80)
display:SetPoint("TOP", 0, -60)
display:SetBackdrop({
    bgFile = "Interface\\Buttons\\WHITE8x8",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    edgeSize = 16,
})
display:SetBackdropColor(0.08, 0.08, 0.08, 1)

local displayIcon = display:CreateTexture(nil, "ARTWORK")
displayIcon:SetAllPoints()
displayIcon:SetTexture(markers[1].icon)
displayIcon:Hide()

local displayText = display:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
displayText:SetPoint("CENTER")
displayText:SetText(L.READY)

local sequenceLabel = MM:CreateFontString(nil, "OVERLAY", "GameFontNormal")
sequenceLabel:SetPoint("TOP", display, "BOTTOM", 0, -8)
sequenceLabel:SetText(L.SEQ_EMPTY)
sequenceLabel:SetTextColor(1, 0.82, 0)

local preview = CreateFrame("Frame", nil, MM)
preview:SetSize(280, 24)
preview:SetPoint("TOP", sequenceLabel, "BOTTOM", 0, -6)
preview.icons = {}

local function updatePreview()
    for _, tex in ipairs(preview.icons) do
        tex:Hide()
    end

    local text = L.SEQ_EMPTY
    if #MM.sequence > 0 then
        text = string.format(L.SEQ, #MM.sequence)
    end
    sequenceLabel:SetText(text)

    for i, marker in ipairs(MM.sequence) do
        local tex = preview.icons[i]
        if not tex then
            tex = preview:CreateTexture(nil, "ARTWORK")
            tex:SetSize(24, 24)
            if i == 1 then
                tex:SetPoint("LEFT", preview, "LEFT", 0, 0)
            else
                tex:SetPoint("LEFT", preview.icons[i-1], "RIGHT", 6, 0)
            end
            preview.icons[i] = tex
        end
        tex:SetTexture(marker.icon)
        tex:Show()
    end
end

local function showMarker(marker)
    displayText:SetText("")
    displayIcon:SetTexture(marker.icon)
    displayIcon:Show()
end

local function resetDisplay()
    displayIcon:Hide()
    displayText:SetText(L.READY)
end

local function getSelectedMarkers()
    local selected = {}
    local selectedSet = {}
    for _, key in ipairs(MM.selectedMarkerKeys) do
        selectedSet[key] = true
    end
    for _, marker in ipairs(markers) do
        if selectedSet[marker.key] then
            table.insert(selected, marker)
        end
    end
    return selected
end

local function rebuildMarkerGrid()
    local grid = _G["MarkerMemoryGrid"]
    if not grid then
        grid = CreateFrame("Frame", "MarkerMemoryGrid", MM)
        grid:SetSize(260, 110)
        grid:SetPoint("TOP", preview, "BOTTOM", 0, -2)
        grid.buttons = {}
    end

    for _, btn in ipairs(grid.buttons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    grid.buttons = {}

    local selectedMarkers = getSelectedMarkers()
    local btnSize = 40
    local hSpacing = 12
    local vSpacing = 10
    local cols = math.min(4, #selectedMarkers)
    local rows = math.max(1, math.ceil(#selectedMarkers / cols))
    local totalWidth = cols * btnSize + (cols - 1) * hSpacing
    local leftOffset = math.floor((260 - totalWidth) / 2)
    local totalHeight = rows * btnSize + (rows - 1) * vSpacing
    grid:SetSize(260, math.max(110, totalHeight + 18))

    for i, marker in ipairs(selectedMarkers) do
        local btn = CreateFrame("Button", nil, grid, "BackdropTemplate")
        btn:SetSize(btnSize, btnSize)
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        btn:SetPoint("TOPLEFT", grid, "TOPLEFT", leftOffset + col * (btnSize + hSpacing), -(12 + row * (btnSize + vSpacing)))

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
        btn:SetBackdropColor(0.12, 0.12, 0.12, 1)

        btn:SetScript("OnEnter", function(self)
            self:SetBackdropColor(0.18, 0.18, 0.18, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[marker.key] or marker.key, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            self:SetBackdropColor(0.12, 0.12, 0.12, 1)
            GameTooltip:Hide()
        end)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -6)
        tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -6, 6)
        tex:SetTexture(marker.icon)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        btn:SetScript("OnClick", function()
            table.insert(MM.sequence, marker)
            updatePreview()
        end)

        table.insert(grid.buttons, btn)
    end
end

local grid = _G["MarkerMemoryGrid"] or CreateFrame("Frame", "MarkerMemoryGrid", MM)
grid:SetSize(260, 110)
grid:SetPoint("TOP", preview, "BOTTOM", 0, -2)
grid.buttons = {}

local function cloneKeyList(keys)
    local copy = {}
    for _, key in ipairs(keys) do
        table.insert(copy, key)
    end
    return copy
end

local selectionMode = false
local pendingSelectedKeys = cloneKeyList(MM.selectedMarkerKeys)
local selectionBtn = nil
local startBtn = nil

local function updateSelectionButtonsState()
    if selectionBtn then
        selectionBtn:SetEnabled(not MM.playing)
        selectionBtn:SetAlpha(not MM.playing and 1 or 0.45)
        selectionBtn:SetText(selectionMode and L.SAVE or L.EDIT)
    end
    if startBtn then
        startBtn:SetEnabled(not MM.playing and not selectionMode)
        startBtn:SetAlpha(not MM.playing and not selectionMode and 1 or 0.45)
    end
end

local function refreshGridSelectionMarks()
    for _, btn in ipairs(grid.buttons) do
        if btn and btn.marker then
            local active = false
            for _, key in ipairs(pendingSelectedKeys) do
                if key == btn.marker.key then
                    active = true
                    break
                end
            end

            if selectionMode then
                if active then
                    btn:SetBackdropColor(0.18, 0.42, 0.78, 1)
                    btn:SetAlpha(1)
                else
                    btn:SetBackdropColor(0.18, 0.18, 0.18, 1)
                    btn:SetAlpha(0.38)
                end
            else
                btn:SetBackdropColor(0.12, 0.12, 0.12, 1)
                btn:SetAlpha(1)
            end
        end
    end
end

local function rebuildGridButtons()
    for _, btn in ipairs(grid.buttons) do
        btn:Hide()
        btn:SetParent(nil)
    end
    grid.buttons = {}

    local visibleMarkers = selectionMode and markers or getSelectedMarkers()
    local btnSize = 40
    local hSpacing = 12
    local vSpacing = 10
    local cols = math.min(4, #visibleMarkers)
    local rows = math.max(1, math.ceil(#visibleMarkers / cols))
    local totalWidth = cols * btnSize + (cols - 1) * hSpacing
    local leftOffset = math.floor((260 - totalWidth) / 2)
    local totalHeight = rows * btnSize + (rows - 1) * vSpacing
    grid:SetSize(260, math.max(110, totalHeight + 18))

    for i, marker in ipairs(visibleMarkers) do
        local btn = CreateFrame("Button", nil, grid, "BackdropTemplate")
        btn.marker = marker
        btn:SetSize(btnSize, btnSize)
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        btn:SetPoint("TOPLEFT", grid, "TOPLEFT", leftOffset + col * (btnSize + hSpacing), -(12 + row * (btnSize + vSpacing)))

        btn:SetBackdrop({
            bgFile = "Interface\\Buttons\\WHITE8x8",
            edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
            edgeSize = 12,
        })
        btn:SetBackdropColor(0.12, 0.12, 0.12, 1)

        local tex = btn:CreateTexture(nil, "ARTWORK")
        tex:SetPoint("TOPLEFT", btn, "TOPLEFT", 6, -6)
        tex:SetPoint("BOTTOMRIGHT", btn, "BOTTOMRIGHT", -6, 6)
        tex:SetTexture(marker.icon)
        tex:SetTexCoord(0.07, 0.93, 0.07, 0.93)

        btn:SetScript("OnEnter", function(self)
            if selectionMode then
                return
            end
            self:SetBackdropColor(0.18, 0.18, 0.18, 1)
            GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
            GameTooltip:SetText(L[marker.key] or marker.key, 1, 1, 1)
            GameTooltip:Show()
        end)
        btn:SetScript("OnLeave", function(self)
            if selectionMode then
                return
            end
            self:SetBackdropColor(0.12, 0.12, 0.12, 1)
            GameTooltip:Hide()
        end)

        btn:SetScript("OnClick", function()
            if selectionMode then
                local nextKeys = {}
                local found = false
                for _, key in ipairs(pendingSelectedKeys) do
                    if key == marker.key then
                        found = true
                    else
                        table.insert(nextKeys, key)
                    end
                end
                if not found then
                    table.insert(nextKeys, marker.key)
                end
                pendingSelectedKeys = nextKeys
                refreshGridSelectionMarks()
                return
            end
            table.insert(MM.sequence, marker)
            updatePreview()
        end)

        table.insert(grid.buttons, btn)
    end

    refreshGridSelectionMarks()
end

local function saveSelectedMarkers()
    if MM.playing then
        return
    end

    local validKeys = {}
    local seen = {}
    for _, key in ipairs(pendingSelectedKeys) do
        if key and not seen[key] then
            seen[key] = true
            table.insert(validKeys, key)
        end
    end

    if #validKeys > 0 then
        MM.selectedMarkerKeys = validKeys
    end

    local allowed = {}
    for _, key in ipairs(MM.selectedMarkerKeys) do
        allowed[key] = true
    end

    local filtered = {}
    for _, seqMarker in ipairs(MM.sequence) do
        if allowed[seqMarker.key] then
            table.insert(filtered, seqMarker)
        end
    end
    MM.sequence = filtered

    selectionMode = false
    pendingSelectedKeys = cloneKeyList(MM.selectedMarkerKeys)
    refreshGridSelectionMarks()
    rebuildGridButtons()
    updatePreview()
    updateSelectionButtonsState()
end

local function openSelectionMode()
    if MM.playing then
        return
    end

    selectionMode = true
    pendingSelectedKeys = cloneKeyList(MM.selectedMarkerKeys)
    rebuildGridButtons()
    updateSelectionButtonsState()
end

local function closeSelectionMode()
    selectionMode = false
    pendingSelectedKeys = cloneKeyList(MM.selectedMarkerKeys)
    rebuildGridButtons()
    updateSelectionButtonsState()
end

rebuildMarkerGrid()

selectionBtn = CreateFrame("Button", nil, MM, "GameMenuButtonTemplate")
selectionBtn:SetSize(92, 26)
selectionBtn:SetText(L.EDIT)
selectionBtn:SetScript("OnClick", function()
    if MM.playing then
        return
    end

    if selectionMode then
        saveSelectedMarkers()
    else
        openSelectionMode()
    end
end)

rebuildGridButtons()

-- speedLabel and dropdown are created after `controls` to avoid nil anchors
local controls = CreateFrame("Frame", nil, MM)
controls:SetSize(320, 40)
controls:SetPoint("TOP", grid, "BOTTOM", 0, -12)

selectionBtn:SetParent(MM)
selectionBtn:SetPoint("TOPLEFT", MM, "TOPLEFT", 12, -32)

-- Single centered Start button (modern WoW style)
startBtn = CreateFrame("Button", nil, controls, "GameMenuButtonTemplate")
startBtn:SetSize(128, 32)
startBtn:SetPoint("CENTER", controls, "CENTER", 8, 0)
startBtn:SetText(L.START)
startBtn:SetNormalFontObject("GameFontNormalLarge")

-- Speed label and dropdown (created after controls exists)
local speedDropdown = CreateFrame("Frame", "MarkerMemorySpeedDropdown", MM, "UIDropDownMenuTemplate")
-- put label above dropdown so it doesn't mix with addon title
local speedLabel = MM:CreateFontString(nil, "OVERLAY", "GameFontNormal")
speedLabel:SetPoint("TOPRIGHT", MM, "TOPRIGHT", -14, -30)
speedLabel:SetText(L.SPEED)
speedDropdown:SetPoint("TOPRIGHT", MM, "TOPRIGHT", -14, -50)

UIDropDownMenu_SetWidth(speedDropdown, 64)
UIDropDownMenu_Initialize(speedDropdown, function(self, level)
    for _, entry in ipairs(speeds) do
        local info = UIDropDownMenu_CreateInfo()
        info.text = entry.label
        info.func = function()
            MM.speed = entry.value
            UIDropDownMenu_SetSelectedName(speedDropdown, entry.label)
        end
        UIDropDownMenu_AddButton(info)
    end
end)
UIDropDownMenu_SetSelectedName(speedDropdown, MM.speedShow)

local function stopPlayback()
    if MM.ticker then
        MM.ticker:Cancel()
        MM.ticker = nil
    end
    MM.playing = false
    startBtn:SetEnabled(true)
    updateSelectionButtonsState()
    resetDisplay()
end


startBtn:SetScript("OnClick", function()
    if MM.playing or #MM.sequence == 0 then return end

    MM.playing = true
    startBtn:SetEnabled(false)
    updateSelectionButtonsState()

    local index = 1
    showMarker(MM.sequence[index])

    MM.ticker = C_Timer.NewTicker(MM.speed, function(ticker)
        index = index + 1

        if index > #MM.sequence then
            ticker:Cancel()
            MM.ticker = nil
            MM.playing = false
            startBtn:SetEnabled(true)
            updateSelectionButtonsState()

            C_Timer.After(MM.speed * 0.5, function()
                -- Reset to same state as pressing "Löschen"
                wipe(MM.sequence)
                updatePreview()
                resetDisplay()
            end)
        else
            showMarker(MM.sequence[index])
        end
    end)
end)

MM:SetScript("OnHide", stopPlayback)
MM:RegisterEvent("PLAYER_ENTERING_WORLD")
MM:RegisterEvent("ZONE_CHANGED")
MM:RegisterEvent("ZONE_CHANGED_NEW_AREA")
MM:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED" or event == "ZONE_CHANGED_NEW_AREA" then
        updateAutoOpenState()
    end
end)

-- Addon compartment handler (used by TOC AddonCompartmentFunc)
function MarkerMemory_OnAddonCompartmentClick()
    if MM:IsShown() then MM:Hide() else MM:Show() end
end

updateAutoOpenState()
updatePreview()
resetDisplay()
