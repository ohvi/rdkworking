-- Base/EncounterLogRotator.lua

-- Create module namespace within RDK
RDK = RDK or {}
RDK.EncounterLogRotator = {}
local ELR = RDK.EncounterLogRotator

-- Module info
ELR.name = "EncounterLogRotator"
ELR.version = "1.0.0"

-- Debug levels: 0 = off, 1 = basic, 2 = verbose
local DEBUG_LEVEL = 1 

-- Colors for debug messages
local COLOR_PREFIX = "|cFFA500[RDK-ELR]|r "
local COLOR_ERROR = "|cFF0000"
local COLOR_WARNING = "|cFFFF00"
local COLOR_SUCCESS = "|c00FF00"
local COLOR_INFO = "|cFFFFFF"
local COLOR_END = "|r"

-- Debug function with levels
local function Debug(msg, level)
    level = level or 1
    if DEBUG_LEVEL >= level and CHAT_SYSTEM then
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

-- Check if player is in combat
local function IsInCombat()
    return IsUnitInCombat("player")
end

-- Function to check encounter log status using the correct API function
local function IsEncounterLogActive()
    -- Try the current API function first
    if IsEncounterLogEnabled ~= nil then
        return IsEncounterLogEnabled()
    -- Fall back to legacy function if available
    elseif DoesEncounterLogRecordCombat ~= nil then 
        return DoesEncounterLogRecordCombat()
    end
    
    -- If neither function exists, we can't determine status
    return nil
end

-- Toggle the encounter log off and then back on
function ELR:ToggleEncounterLog()
    -- Check if player is in combat first
    if IsInCombat() then
        ErrorMessage("Skipped log rotation due to combat.")
        return false
    end
    
    -- Check if encounter log is enabled before rotating
    local isEnabled = IsEncounterLogActive()
    
    -- If we can't determine status, proceed with rotation to be safe
    if isEnabled == nil then
        InfoMessage("Could not determine log status, proceeding with rotation.")
    -- If log is not enabled, don't rotate
    elseif not isEnabled then
        InfoMessage("Encounter log is not currently active. Skipping rotation.")
        return false
    end
    
    InfoMessage("Rotating encounter log...")
    
    -- Toggle off
    ExecuteChatCommand("/encounterlog")
    
    -- Toggle back on after delay
    zo_callLater(function()
        ExecuteChatCommand("/encounterlog")
        SuccessMessage("Log restarted successfully.")
    end, 1000)
    
    return true
end

-- Start the rotation timer
function ELR:StartRotation()
    -- Clear any existing timer
    EVENT_MANAGER:UnregisterForUpdate(ELR.name)
    
    -- Don't start if addon is disabled
    if not self.savedVars or not self.savedVars.enabled then 
        InfoMessage("Auto-rotation is disabled.")
        return 
    end

    -- Calculate delay in milliseconds
    local delay = self.savedVars.interval * 60 * 1000
    
    -- Register timer event
    EVENT_MANAGER:RegisterForUpdate(ELR.name, delay, function()
        if not self.savedVars.enabled then return end
        
        if IsInCombat() then
            ErrorMessage("Skipped scheduled log rotation due to combat.")
            -- Retry after combat
            if self.savedVars.retryAfterCombat then
                self:RegisterCombatExitRotation()
            end
        else
            self:ToggleEncounterLog()
        end
    end)
    
    InfoMessage("Auto-rotation scheduled every " .. self.savedVars.interval .. " minutes.")
end

-- Register for combat exit to retry rotation
function ELR:RegisterCombatExitRotation()
    -- Prevent duplicate registrations
    EVENT_MANAGER:UnregisterForEvent(ELR.name .. "CombatExit", EVENT_PLAYER_COMBAT_STATE)
    
    EVENT_MANAGER:RegisterForEvent(ELR.name .. "CombatExit", EVENT_PLAYER_COMBAT_STATE, function(_, inCombat)
        if not inCombat and self.savedVars.enabled and self.savedVars.retryAfterCombat then
            EVENT_MANAGER:UnregisterForEvent(ELR.name .. "CombatExit", EVENT_PLAYER_COMBAT_STATE)
            InfoMessage("Combat ended, performing delayed log rotation.")
            zo_callLater(function() 
                self:ToggleEncounterLog() 
            end, 2000)  -- Small delay after combat ends
        end
    end)
end

-- Create settings controls to be included in RDK settings panel
function ELR:GetOptions()
    local optionsTable = {
        {
            type = "submenu",
            name = "Encounter Log Rotator",
            controls = {
                {
                    type = "checkbox",
                    name = "Enable Auto Rotation",
                    tooltip = "Enable or disable automatic log rotation.",
                    getFunc = function() return self.savedVars.enabled end,
                    setFunc = function(value)
                        self.savedVars.enabled = value
                        self:StartRotation()
                        if value then
                            InfoMessage("Auto-rotation enabled.")
                        else
                            InfoMessage("Auto-rotation disabled.")
                        end
                    end,
                    default = self.defaults.enabled,
                    width = "full",
                },
                {
                    type = "slider",
                    name = "Rotation Interval (Minutes)",
                    tooltip = "How often to rotate the log.",
                    min = 1,
                    max = 60,
                    step = 1,
                    getFunc = function() return self.savedVars.interval end,
                    setFunc = function(value)
                        self.savedVars.interval = value
                        self:StartRotation()
                        InfoMessage("Rotation interval set to " .. value .. " minutes.")
                    end,
                    default = self.defaults.interval,
                    disabled = function() return not self.savedVars.enabled end,
                    width = "full",
                },
                {
                    type = "checkbox",
                    name = "Retry After Combat",
                    tooltip = "If a scheduled rotation is skipped due to combat, retry once combat ends.",
                    getFunc = function() return self.savedVars.retryAfterCombat end,
                    setFunc = function(value)
                        self.savedVars.retryAfterCombat = value
                    end,
                    default = self.defaults.retryAfterCombat,
                    width = "full",
                },
                {
                    type = "header",
                    name = "Manual Controls",
                },
                {
                    type = "button",
                    name = "Rotate Log Now",
                    tooltip = "Immediately rotate the log (if not in combat).",
                    func = function() 
                        if not IsInCombat() then
                            self:ToggleEncounterLog() 
                        else
                            ErrorMessage("Cannot rotate now: Player is in combat.")
                        end
                    end,
                    width = "half",
                },
                {
                    type = "button",
                    name = "Check Log Status",
                    tooltip = "Check if the encounter log is currently active.",
                    func = function() 
                        local status = IsEncounterLogActive()
                        if status ~= nil then
                            if status then
                                InfoMessage("Encounter log is currently ACTIVE.")
                            else
                                InfoMessage("Encounter log is currently INACTIVE.")
                            end
                        else
                            InfoMessage("Cannot determine log status - API function unavailable.")
                        end
                    end,
                    width = "half",
                },
                {
                    type = "description",
                    text = "Use |cffffff/logrotate|r to manually rotate the log.",
                    width = "full",
                },
            }
        }
    }

    return optionsTable
end

-- Initialize the module
function ELR:Initialize()
    -- Default settings
    self.defaults = {
        enabled = true,
        interval = 10,
        retryAfterCombat = true,
    }

    -- Initialize saved variables using RDK's saved variable structure
    self.savedVars = RDK.GetSettings().EncounterLogRotator or self.defaults
    
    -- Register slash commands
    SLASH_COMMANDS["/logrotate"] = function()
        if IsInCombat() then
            ErrorMessage("Cannot rotate log: Player is in combat.")
        else
            self:ToggleEncounterLog()
        end
    end
    
    -- Start rotation timer
    self:StartRotation()
    
    -- Show initialization message
    InfoMessage("v" .. self.version .. " initialized. Rotation every " .. self.savedVars.interval .. " min.")
    
    -- Return true to indicate successful initialization
    return true
end