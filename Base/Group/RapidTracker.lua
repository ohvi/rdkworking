-- Base/RapidTracker.lua
-- Complete file with distance display feature

-- Namespace
RDK = RDK or {}
RDK.RapidTracker = {}
local RT = RDK.RapidTracker

-- Module info
RT.name = "RapidTracker"
RT.version = "1.0.1" -- Increased for distance feature

-- Debug colors
local COLOR_PREFIX = "|cFFA500[RDK-RT]|r "
local COLOR_ERROR = "|cFF0000"
local COLOR_WARNING = "|cFFFF00"
local COLOR_SUCCESS = "|c00FF00"
local COLOR_INFO = "|cFFFFFF"
local COLOR_END = "|r"

-- Debug function
local function Debug(msg, level)
    level = level or 1
    if CHAT_SYSTEM then
        d(COLOR_PREFIX .. msg)
    end
end

-- Message functions by type
local function InfoMessage(msg)
    Debug(COLOR_INFO .. msg .. COLOR_END, 1)
end

local function WarningMessage(msg)
    Debug(COLOR_WARNING .. msg .. COLOR_END, 1)
end

local function ErrorMessage(msg)
    Debug(COLOR_ERROR .. msg .. COLOR_END, 1)
end

local function SuccessMessage(msg)
    Debug(COLOR_SUCCESS .. msg .. COLOR_END, 1)
end

-- UI elements
RT.window = nil
RT.encounterList = nil
RT.groupList = nil
RT.detailView = nil
RT.settings = nil
RT.unitControls = {}

-- Tracking state
RT.isTracking = false
RT.currentEncounter = nil
RT.encounters = {}
RT.groupMembers = {}
RT.distanceUpdateHandle = nil

-- Constants
RT.ROLE_ICONS = {
    [LFG_ROLE_DPS] = "/esoui/art/lfg/lfg_icon_dps.dds",
    [LFG_ROLE_HEAL] = "/esoui/art/lfg/lfg_icon_healer.dds",
    [LFG_ROLE_TANK] = "/esoui/art/lfg/lfg_icon_tank.dds",
}

-- ========================
-- Distance Tracking Logic
-- ========================

-- Distance tracking settings
RT.showPlayerDistance = true  -- Default to showing distances
RT.distanceUpdateInterval = 500  -- Update every 500ms
RT.distanceFormat = "meters"  -- Options: "meters", "yards"
RT.distanceNameFormat = "append"  -- Options: "append", "prefix"
RT.distancePrecision = 0  -- Decimal points to show (0 = whole numbers)
RT.maxDistance = 9999  -- Cap for displayed distance
RT.distanceThresholds = {
    close = 7,      -- 0-7 meters: green
    medium = 20,    -- 8-20 meters: yellow
    far = 40        -- 21-40 meters: orange, >40: red
}

-- Calculate the distance between player and target
function RT:GetPlayerDistance(unitTag)
    if not DoesUnitExist(unitTag) then return nil end
    
    -- Get world positions
    local playerX, playerY, playerZ = GetUnitWorldPosition("player")
    local targetX, targetY, targetZ = GetUnitWorldPosition(unitTag)
    
    -- Ensure both positions are valid
    if not (playerX and playerY and playerZ and targetX and targetY and targetZ) then
        return nil
    end
    
    -- Calculate 3D Euclidean distance
    local distance = math.sqrt(
        (targetX - playerX)^2 + 
        (targetY - playerY)^2 + 
        (targetZ - playerZ)^2
    )
    
    -- ESO distances are in "world units" - convert to more familiar units
    -- Approximation: 100 world units ≈ 1 meter
    local distanceInMeters = distance / 100
    
    -- Convert to yards if that setting is selected
    if self.distanceFormat == "yards" then
        return distanceInMeters * 1.09361  -- Convert meters to yards
    end
    
    return distanceInMeters
end

-- Get and format player distances for all group members
function RT:GetFormattedDistances()
    local distances = {}
    
    -- Iterate through group members
    for i = 1, GetGroupSize() do
        local unitTag = GetGroupUnitTagByIndex(i)
        if DoesUnitExist(unitTag) and unitTag ~= "player" then
            local distance = self:GetPlayerDistance(unitTag)
            
            if distance then
                -- Cap at max distance
                distance = math.min(distance, self.maxDistance)
                
                -- Format with specified precision
                local formattedDistance = zo_strformat("<<1>>", 
                    zo_roundToNearest(distance, 10^(-self.distancePrecision)))
                
                -- Determine color based on distance thresholds
                local distanceColor = "|cFF0000"  -- Default to red for far away
                
                if distance <= self.distanceThresholds.close then
                    distanceColor = "|c00FF00"  -- Green for close
                elseif distance <= self.distanceThresholds.medium then
                    distanceColor = "|cFFFF00"  -- Yellow for medium
                elseif distance <= self.distanceThresholds.far then
                    distanceColor = "|cFF8000"  -- Orange for far
                end
                
                -- Store formatted distance with color
                distances[unitTag] = {
                    raw = distance,
                    formatted = distanceColor .. formattedDistance .. 
                               (self.distanceFormat == "meters" and "m|r" or "yd|r")
                }
            end
        end
    end
    
    return distances
end

-- Start distance tracking updates
function RT:StartDistanceTracking()
    -- Clear any existing update timer
    if self.distanceUpdateHandle then
        EVENT_MANAGER:UnregisterForUpdate("RapidTrackerDistance")
        self.distanceUpdateHandle = nil
    end
    
    -- Only start if distance display is enabled
    if not self.showPlayerDistance then return end
    
    -- Create update timer
    self.distanceUpdateHandle = EVENT_MANAGER:RegisterForUpdate(
        "RapidTrackerDistance", 
        self.distanceUpdateInterval, 
        function() self:UpdateDistanceDisplay() end
    )
end

-- Handle distance display updates
function RT:UpdateDistanceDisplay()
    -- Skip if disabled or player is not in a group
    if not self.showPlayerDistance or GetGroupSize() <= 1 then return end
    
    -- Get formatted distances
    local distances = self:GetFormattedDistances()
    
    -- Update the display controls with distances
    for unitTag, distanceData in pairs(distances) do
        -- Get the unitControl for this unit tag
        local unitControl = self.unitControls[unitTag]
        if unitControl and unitControl.nameLabel then
            -- Get original name
            local name = GetUnitName(unitTag)
            
            -- Format with distance
            local nameWithDistance
            if self.distanceNameFormat == "append" then
                -- Append distance to name: "Player (10m)"
                nameWithDistance = zo_strformat("<<1>> (<<2>>)", 
                    name, distanceData.formatted)
            else
                -- Prefix distance before name: "[10m] Player"
                nameWithDistance = zo_strformat("[<<1>>] <<2>>", 
                    distanceData.formatted, name)
            end
            
            -- Update the name label
            unitControl.nameLabel:SetText(nameWithDistance)
        end
    end
end

-- ========================
-- RapidTracker Core Logic
-- ========================

-- Check if player is in combat
function RT:IsInCombat()
    return IsUnitInCombat("player")
end

-- Get player's current role
function RT:GetPlayerRole()
    return GetGroupMemberSelectedRole("player")
end

-- Start encounter tracking
function RT:StartTracking()
    if self.isTracking then return end
    
    self.isTracking = true
    self.currentEncounter = {
        id = GetTimeStamp(),
        start = GetGameTimeMilliseconds(),
        end = nil,
        name = "Encounter " .. os.date("%H:%M:%S"),
        data = {},
        events = {},
        groupMembers = self:GetGroupMemberInfo(),
    }
    
    -- Register events for combat data
    EVENT_MANAGER:RegisterForEvent(self.name .. "Combat", EVENT_COMBAT_EVENT, function(...) self:OnCombatEvent(...) end)
    
    -- Update UI
    self:UpdateUI()
    
    InfoMessage("Started tracking encounter: " .. self.currentEncounter.name)
end

-- Stop encounter tracking
function RT:StopTracking()
    if not self.isTracking then return end
    
    -- Unregister combat events
    EVENT_MANAGER:UnregisterForEvent(self.name .. "Combat", EVENT_COMBAT_EVENT)
    
    -- Finalize encounter
    self.currentEncounter.end = GetGameTimeMilliseconds()
    self.currentEncounter.duration = (self.currentEncounter.end - self.currentEncounter.start) / 1000
    
    -- Add to encounters list
    table.insert(self.encounters, self.currentEncounter)
    
    -- Reset current encounter
    self.isTracking = false
    self.currentEncounter = nil
    
    -- Limit stored encounters
    if #self.encounters > 20 then
        table.remove(self.encounters, 1)
    end
    
    -- Update UI
    self:UpdateUI()
    
    InfoMessage("Stopped tracking encounter")
end

-- Get group member information
function RT:GetGroupMemberInfo()
    local members = {}
    local groupSize = GetGroupSize()
    
    for i = 1, groupSize do
        local unitTag = GetGroupUnitTagByIndex(i)
        if DoesUnitExist(unitTag) then
            local member = {
                name = GetUnitName(unitTag),
                displayName = GetUnitDisplayName(unitTag),
                role = GetGroupMemberSelectedRole(unitTag),
                class = GetUnitClassId(unitTag),
                level = GetUnitLevel(unitTag),
                championPoints = GetUnitChampionPoints(unitTag),
                isOnline = IsUnitOnline(unitTag),
                unitTag = unitTag,
            }
            members[unitTag] = member
        end
    end
    
    return members
end

-- Handle combat events
function RT:OnCombatEvent(eventCode, result, isError, abilityName, abilityGraphic, abilityActionSlotType, 
                          sourceName, sourceType, targetName, targetType, hitValue, powerType, damageType, log, sourceUnitId, targetUnitId, abilityId)
    
    if not self.isTracking or not self.currentEncounter then return end
    
    -- Skip non-player events if configured
    if self.settings and self.settings.playerEventsOnly then
        if sourceType ~= COMBAT_UNIT_TYPE_PLAYER and targetType ~= COMBAT_UNIT_TYPE_PLAYER then
            return
        end
    end
    
    -- Create event data
    local eventData = {
        timestamp = GetGameTimeMilliseconds(),
        result = result,
        abilityName = abilityName,
        abilityId = abilityId,
        sourceName = sourceName,
        sourceType = sourceType,
        targetName = targetName,
        targetType = targetType,
        value = hitValue,
        powerType = powerType,
        damageType = damageType,
        isDamage = IsAbilityDamageTypeResult(result),
        isHealing = IsAbilityHealingResult(result),
    }
    
    -- Add to events list
    table.insert(self.currentEncounter.events, eventData)
    
    -- Process event for summary data
    self:ProcessEvent(eventData)
    
    -- Update UI if needed
    if self.settings and self.settings.updateFrequency and self.settings.updateFrequency > 0 then
        if (#self.currentEncounter.events % self.settings.updateFrequency) == 0 then
            self:UpdateUI()
        end
    end
end

-- Process event for summary data
function RT:ProcessEvent(eventData)
    -- Initialize data structures if needed
    self.currentEncounter.data.damage = self.currentEncounter.data.damage or {}
    self.currentEncounter.data.healing = self.currentEncounter.data.healing or {}
    
    -- Process damage
    if eventData.isDamage then
        -- Source tracking
        self.currentEncounter.data.damage.sources = self.currentEncounter.data.damage.sources or {}
        self.currentEncounter.data.damage.sources[eventData.sourceName] = self.currentEncounter.data.damage.sources[eventData.sourceName] or {
            total = 0,
            hits = 0,
            crits = 0,
            abilities = {},
        }
        
        local source = self.currentEncounter.data.damage.sources[eventData.sourceName]
        source.total = source.total + eventData.value
        source.hits = source.hits + 1
        
        if resultType == ACTION_RESULT_CRITICAL_DAMAGE then
            source.crits = source.crits + 1
        end
        
        -- Ability tracking
        source.abilities[eventData.abilityName] = source.abilities[eventData.abilityName] or {
            total = 0,
            hits = 0,
            crits = 0,
        }
        
        local ability = source.abilities[eventData.abilityName]
        ability.total = ability.total + eventData.value
        ability.hits = ability.hits + 1
        
        if resultType == ACTION_RESULT_CRITICAL_DAMAGE then
            ability.crits = ability.crits + 1
        end
        
        -- Target tracking
        self.currentEncounter.data.damage.targets = self.currentEncounter.data.damage.targets or {}
        self.currentEncounter.data.damage.targets[eventData.targetName] = self.currentEncounter.data.damage.targets[eventData.targetName] or {
            total = 0,
            hits = 0,
            crits = 0,
        }
        
        local target = self.currentEncounter.data.damage.targets[eventData.targetName]
        target.total = target.total + eventData.value
        target.hits = target.hits + 1
        
        if resultType == ACTION_RESULT_CRITICAL_DAMAGE then
            target.crits = target.crits + 1
        end
    end
    
    -- Process healing
    if eventData.isHealing then
        -- Source tracking
        self.currentEncounter.data.healing.sources = self.currentEncounter.data.healing.sources or {}
        self.currentEncounter.data.healing.sources[eventData.sourceName] = self.currentEncounter.data.healing.sources[eventData.sourceName] or {
            total = 0,
            hits = 0,
            crits = 0,
            abilities = {},
        }
        
        local source = self.currentEncounter.data.healing.sources[eventData.sourceName]
        source.total = source.total + eventData.value
        source.hits = source.hits + 1
        
        if resultType == ACTION_RESULT_CRITICAL_HEAL then
            source.crits = source.crits + 1
        end
        
        -- Ability tracking
        source.abilities[eventData.abilityName] = source.abilities[eventData.abilityName] or {
            total = 0,
            hits = 0,
            crits = 0,
        }
        
        local ability = source.abilities[eventData.abilityName]
        ability.total = ability.total + eventData.value
        ability.hits = ability.hits + 1
        
        if resultType == ACTION_RESULT_CRITICAL_HEAL then
            ability.crits = ability.crits + 1
        end
        
        -- Target tracking
        self.currentEncounter.data.healing.targets = self.currentEncounter.data.healing.targets or {}
        self.currentEncounter.data.healing.targets[eventData.targetName] = self.currentEncounter.data.healing.targets[eventData.targetName] or {
            total = 0,
            hits = 0,
            crits = 0,
        }
        
        local target = self.currentEncounter.data.healing.targets[eventData.targetName]
        target.total = target.total + eventData.value
        target.hits = target.hits + 1
        
        if resultType == ACTION_RESULT_CRITICAL_HEAL then
            target.crits = target.crits + 1
        end
    end
end

-- Update UI with current data
function RT:UpdateUI()
    -- Update group list
    self:UpdateGroupList()
    
    -- Update encounter list
    self:UpdateEncounterList()
    
    -- Update detail view if an encounter is selected
    if self.selectedEncounter then
        self:UpdateDetailView(self.selectedEncounter)
    end
end

-- Update group list display
function RT:UpdateGroupList()
    -- Skip if no group list control
    if not self.groupList then return end
    
    -- Clear existing controls
    for _, control in pairs(self.unitControls) do
        control:SetHidden(true)
    end
    
    -- Get current group information
    local members = self:GetGroupMemberInfo()
    self.groupMembers = members
    
    -- Get distances if enabled
    local distances = {}
    if self.showPlayerDistance then
        distances = self:GetFormattedDistances()
    end
    
    -- Update or create controls for each member
    local i = 1
    for unitTag, member in pairs(members) do
        local control = self.unitControls[unitTag]
        
        -- Create control if it doesn't exist
        if not control then
            control = self:CreateGroupMemberControl(unitTag)
            self.unitControls[unitTag] = control
        end
        
        -- Update control data
        self:UpdateGroupMemberControl(control, member, distances[unitTag])
        
        -- Position control
        control:ClearAnchors()
        if i == 1 then
            control:SetAnchor(TOPLEFT, self.groupList, TOPLEFT, 5, 5)
        else
            local prevControl = self.unitControls[GetGroupUnitTagByIndex(i-1)]
            control:SetAnchor(TOPLEFT, prevControl, BOTTOMLEFT, 0, 2)
        end
        
        -- Show control
        control:SetHidden(false)
        
        i = i + 1
    end
end

-- Create a control for a group member
function RT:CreateGroupMemberControl(unitTag)
    local control = WINDOW_MANAGER:CreateControl(nil, self.groupList, CT_CONTROL)
    control:SetDimensions(200, 30)
    
    -- Background
    local bg = WINDOW_MANAGER:CreateControl(nil, control, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.5)
    bg:SetEdgeColor(0.3, 0.3, 0.3, 1)
    control.bg = bg
    
    -- Role icon
    local roleIcon = WINDOW_MANAGER:CreateControl(nil, control, CT_TEXTURE)
    roleIcon:SetDimensions(24, 24)
    roleIcon:SetAnchor(LEFT, control, LEFT, 3, 0)
    control.roleIcon = roleIcon
    
    -- Name label
    local nameLabel = WINDOW_MANAGER:CreateControl(nil, control, CT_LABEL)
    nameLabel:SetFont("ZoFontGame")
    nameLabel:SetColor(1, 1, 1, 1)
    nameLabel:SetAnchor(LEFT, roleIcon, RIGHT, 5, 0)
    nameLabel:SetDimensions(170, 24)
    nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
    control.nameLabel = nameLabel
    
    return control
end

-- Update a group member control with current data
function RT:UpdateGroupMemberControl(control, member, distance)
    -- Set role icon
    local roleIcon = self.ROLE_ICONS[member.role] or self.ROLE_ICONS[LFG_ROLE_DPS]
    control.roleIcon:SetTexture(roleIcon)
    
    -- Set name label
    local name = member.name
    
    -- Add distance if available
    if distance and self.showPlayerDistance then
        if self.distanceNameFormat == "append" then
            name = zo_strformat("<<1>> (<<2>>)", name, distance.formatted)
        else
            name = zo_strformat("[<<1>>] <<2>>", distance.formatted, name)
        end
    end
    
    control.nameLabel:SetText(name)
    
    -- Highlight if not online
    if not member.isOnline then
        control.nameLabel:SetColor(0.5, 0.5, 0.5, 1)
    else
        control.nameLabel:SetColor(1, 1, 1, 1)
    end
end

-- Update encounter list display
function RT:UpdateEncounterList()
    -- Skip if no encounter list control
    if not self.encounterList then return end
    
    -- TODO: Implement encounter list display
    -- This would typically create a scrollable list of encounters
    -- For brevity, this is left as an exercise
end

-- Update detail view for selected encounter
function RT:UpdateDetailView(encounter)
    -- Skip if no detail view control
    if not self.detailView then return end
    
    -- TODO: Implement detail view display
    -- This would show detailed statistics for the selected encounter
    -- For brevity, this is left as an exercise
end

-- ========================
-- Settings
-- ========================

-- Get options table for settings panel
function RT:GetOptions()
    local optionsTable = {
        {
            type = "submenu",
            name = "RapidTracker",
            controls = {
                {
                    type = "header",
                    name = "General Settings",
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Auto-track Encounters",
                    tooltip = "Automatically start tracking when entering combat and stop when leaving combat.",
                    getFunc = function() return self.settings.autoTrack end,
                    setFunc = function(value) self.settings.autoTrack = value end,
                    default = true,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Track Player Events Only",
                    tooltip = "Only track events where a player is either the source or target.",
                    getFunc = function() return self.settings.playerEventsOnly end,
                    setFunc = function(value) self.settings.playerEventsOnly = value end,
                    default = true,
                    width = "full",
                },
                {
                    type = "slider",
                    name = "UI Update Frequency",
                    tooltip = "How often to update the UI during combat (in number of events). Higher values may improve performance.",
                    min = 0,
                    max = 100,
                    step = 5,
                    getFunc = function() return self.settings.updateFrequency end,
                    setFunc = function(value) self.settings.updateFrequency = value end,
                    default = 10,
                    width = "full",
                },
                {
                    type = "header",
                    name = "Distance Display",
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Show Player Distances",
                    tooltip = "Display the distance between you and other group members.",
                    getFunc = function() return self.showPlayerDistance end,
                    setFunc = function(value)
                        self.showPlayerDistance = value
                        self:StartDistanceTracking()
                    end,
                    default = true,
                    width = "full",
                },
                {
                    type = "dropdown",
                    name = "Distance Format",
                    tooltip = "Choose the unit of measurement for distances.",
                    choices = {"meters", "yards"},
                    getFunc = function() return self.distanceFormat end,
                    setFunc = function(value)
                        self.distanceFormat = value
                    end,
                    default = "meters",
                    disabled = function() return not self.showPlayerDistance end,
                    width = "half",
                },
                {
                    type = "dropdown",
                    name = "Name Format",
                    tooltip = "How to display the distance with player names.",
                    choices = {"append", "prefix"},
                    choicesDisplays = {"Player (10m)", "[10m] Player"},
                    getFunc = function() return self.distanceNameFormat or "append" end,
                    setFunc = function(value)
                        self.distanceNameFormat = value
                    end,
                    default = "append",
                    disabled = function() return not self.showPlayerDistance end,
                    width = "half",
                },
                {
                    type = "slider",
                    name = "Update Frequency",
                    tooltip = "How often to update distance information (milliseconds).",
                    min = 100,
                    max = 2000,
                    step = 100,
                    getFunc = function() return self.distanceUpdateInterval end,
                    setFunc = function(value)
                        self.distanceUpdateInterval = value
                        self:StartDistanceTracking()
                    end,
                    default = 500,
                    disabled = function() return not self.showPlayerDistance end,
                    width = "full",
                },
                {
                    type = "slider",
                    name = "Close Distance Threshold",
                    tooltip = "Distance in meters considered 'close' (green).",
                    min = 1,
                    max = 20,
                    step = 1,
                    getFunc = function() return self.distanceThresholds.close end,
                    setFunc = function(value)
                        self.distanceThresholds.close = value
                    end,
                    default = 7,
                    disabled = function() return not self.showPlayerDistance end,
                    width = "half",
                },
                {
                    type = "slider",
                    name = "Medium Distance Threshold",
                    tooltip = "Distance in meters considered 'medium' (yellow).",
                    min = 5,
                    max = 30,
                    step = 1,
                    getFunc = function() return self.distanceThresholds.medium end,
                    setFunc = function(value)
                        self.distanceThresholds.medium = value
                    end,
                    default = 20,
                    disabled = function() return not self.showPlayerDistance end,
                    width = "half",
                },
                {
                    type = "slider",
                    name = "Far Distance Threshold",
                    tooltip = "Distance in meters considered 'far' (orange). Beyond this is red.",
                    min = 10,
                    max = 100,
                    step = 5,
                    getFunc = function() return self.distanceThresholds.far end,
                    setFunc = function(value)
                        self.distanceThresholds.far = value
                    end,
                    default = 40,
                    disabled = function() return not self.showPlayerDistance end,
                    width = "full",
                },
            }
        }
    }
    
    return optionsTable
end

-- Initialize the module
function RT:Initialize()
    -- Default settings
    self.settings = {
        autoTrack = true,
        playerEventsOnly = true,
        updateFrequency = 10,
    }
    
    -- Load saved settings
    local savedSettings = RDK.GetSettings().RapidTracker
    if savedSettings then
        -- General settings
        self.settings = savedSettings
        
        -- Distance display settings
        self.showPlayerDistance = savedSettings.showPlayerDistance or self.showPlayerDistance
        self.distanceFormat = savedSettings.distanceFormat or self.distanceFormat
        self.distanceNameFormat = savedSettings.distanceNameFormat or self.distanceNameFormat
        self.distanceUpdateInterval = savedSettings.distanceUpdateInterval or self.distanceUpdateInterval
        self.distanceThresholds = savedSettings.distanceThresholds or self.distanceThresholds
        self.distancePrecision = savedSettings.distancePrecision or self.distancePrecision
    end
    
    -- Create UI
    self:CreateUI()
    
    -- Register events
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if self.settings.autoTrack then
            if inCombat then
                self:StartTracking()
            else
                self:StopTracking()
            end
        end
    end)
    
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_JOINED, function()
        self:UpdateGroupList()
    end)
    
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_LEFT, function()
        self:UpdateGroupList()
    end)
    
    EVENT_MANAGER:RegisterForEvent(self.name, EVENT_GROUP_MEMBER_ROLE_CHANGED, function()
        self:UpdateGroupList()
    end)
    
    -- Start distance tracking
    self:StartDistanceTracking()
    
    -- Initial update
    self:UpdateUI()
    
    -- Register slash command
    SLASH_COMMANDS["/rt"] = function(cmd)
        if cmd == "start" then
            self:StartTracking()
        elseif cmd == "stop" then
            self:StopTracking()
        elseif cmd == "reset" then
            self.encounters = {}
            self:UpdateUI()
            InfoMessage("Reset all encounters")
        elseif cmd == "show" then
            self.window:SetHidden(false)
        elseif cmd == "hide" then
            self.window:SetHidden(true)
        else
            InfoMessage("RapidTracker commands: /rt start, /rt stop, /rt reset, /rt show, /rt hide")
        end
    end
    
    InfoMessage("v" .. self.version .. " initialized")
    return true
end

-- Create UI elements
function RT:CreateUI()
    -- Main window
    self.window = WINDOW_MANAGER:CreateTopLevelWindow("RapidTrackerWindow")
    self.window:SetDimensions(400, 500)
    self.window:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, 100, 100)
    self.window:SetHidden(true)
    self.window:SetClampedToScreen(true)
    self.window:SetMovable(true)
    self.window:SetMouseEnabled(true)
    
    -- Background
    local bg = WINDOW_MANAGER:CreateControl("RapidTrackerBackground", self.window, CT_BACKDROP)
    bg:SetAnchorFill()
    bg:SetCenterColor(0, 0, 0, 0.8)
    bg:SetEdgeColor(0.3, 0.3, 0.3, 1)
    
    -- Title bar
    local titleBar = WINDOW_MANAGER:CreateControl("RapidTrackerTitleBar", self.window, CT_CONTROL)
    titleBar:SetDimensions(400, 30)
    titleBar:SetAnchor(TOPLEFT, self.window, TOPLEFT, 0, 0)
    
    local titleBg = WINDOW_MANAGER:CreateControl("RapidTrackerTitleBg", titleBar, CT_BACKDROP)
    titleBg:SetAnchorFill()
    titleBg:SetCenterColor(0.1, 0.1, 0.1, 1)
    titleBg:SetEdgeColor(0.3, 0.3, 0.3, 1)
    
    local titleText = WINDOW_MANAGER:CreateControl("RapidTrackerTitleText", titleBar, CT_LABEL)
    titleText:SetFont("ZoFontWinH3")
    titleText:SetColor(1, 1, 1, 1)
    titleText:SetText("RapidTracker")
    titleText:SetAnchor(LEFT, titleBar, LEFT, 10, 0)
    
    local closeButton = WINDOW_MANAGER:CreateControl("RapidTrackerCloseButton", titleBar, CT_BUTTON)
    closeButton:SetDimensions(24, 24)
    closeButton:SetAnchor(RIGHT, titleBar, RIGHT, -5, 0)
    closeButton:SetFont("ZoFontGame")
    closeButton:SetText("X")
    closeButton:SetHandler("OnClicked", function()
        self.window:SetHidden(true)
    end)
    
    -- Create tabs
    self:CreateTabs()
    
    -- Create group list
    self.groupList = WINDOW_MANAGER:CreateControl("RapidTrackerGroupList", self.window, CT_CONTROL)
    self.groupList:SetDimensions(200, 440)
    self.groupList:SetAnchor(TOPLEFT, titleBar, BOTTOMLEFT, 0, 10)
    self.groupList:SetHidden(false)
    
    -- Create encounter list
    self.encounterList = WINDOW_MANAGER:CreateControl("RapidTrackerEncounterList", self.window, CT_CONTROL)
    self.encounterList:SetDimensions(200, 440)
    self.encounterList:SetAnchor(TOPLEFT, titleBar, BOTTOMLEFT, 0, 10)
    self.encounterList:SetHidden(true)
    
    -- Create detail view
    self.detailView = WINDOW_MANAGER:CreateControl("RapidTrackerDetailView", self.window, CT_CONTROL)
    self.detailView:SetDimensions(190, 440)
    self.detailView:SetAnchor(TOPLEFT, self.groupList, TOPRIGHT, 10, 0)
    
    local detailBg = WINDOW_MANAGER:CreateControl("RapidTrackerDetailBg", self.detailView, CT_BACKDROP)
    detailBg:SetAnchorFill()
    detailBg:SetCenterColor(0.1, 0.1, 0.1, 0.5)
    detailBg:SetEdgeColor(0.3, 0.3, 0.3, 1)
end

-- Create tabs for the window
function RT:CreateTabs()
    -- TODO: Implement tabs for Group, Encounters, and Settings views
    -- For brevity, this is left as an exercise
end

-- Save settings
function RT:SaveSettings()
    local settings = RDK.GetSettings()
    settings.RapidTracker = settings.RapidTracker or {}
    
    -- General settings
    settings.RapidTracker = self.settings
    
    -- Distance display settings
    settings.RapidTracker.showPlayerDistance = self.showPlayerDistance
    settings.RapidTracker.distanceFormat = self.distanceFormat
    settings.RapidTracker.distanceNameFormat = self.distanceNameFormat
    settings.RapidTracker.distanceUpdateInterval = self.distanceUpdateInterval
    settings.RapidTracker.distanceThresholds = self.distanceThresholds
    settings.RapidTracker.distancePrecision = self.distancePrecision
    
    -- Save settings
    RDK.SaveSettings(settings)
end

-- Return true to indicate the module loaded successfully
return true