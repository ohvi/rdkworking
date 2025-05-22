-- RdK Group Tool Detonation Tracker
-- By @s0rdrak (PC / EU)

RdKGTool.util = RdKGTool.util or {}
local RdKGToolUtil = RdKGTool.util
RdKGTool.group = RdKGTool.group or {}
local RdKGToolGroup = RdKGTool.group
RdKGToolGroup.dt = RdKGToolGroup.dt or {}
local RdKGToolDt = RdKGToolGroup.dt
RdKGTool.menu = RdKGTool.menu or {}
local RdKGToolMenu = RdKGTool.menu
RdKGToolUtil.group = RdKGToolUtil.group or {}
local RdKGToolUtilGroup = RdKGToolUtil.group
RdKGToolUtil.fonts = RdKGToolUtil.fonts or {}
local RdKGToolFonts = RdKGToolUtil.fonts

RdKGToolDt.constants = RdKGToolDt.constants or {}
RdKGToolDt.constants.TLW = "RdKGTool.group.dt.tlw"

RdKGToolDt.constants.size = {}
RdKGToolDt.constants.size.SMALL = 1
RdKGToolDt.constants.size.BIG = 2

RdKGToolDt.constants.modes = {}
RdKGToolDt.constants.MODE_BOTH = 1
RdKGToolDt.constants.MODE_DETONATION = 2
RdKGToolDt.constants.MODE_SHALK = 3

RdKGToolDt.constants.TYPE_DETONATION = 1
RdKGToolDt.constants.TYPE_SUBTERRANEAN_ASSAULT = 2
RdKGToolDt.constants.TYPE_DEEP_FRISSURE = 3

RdKGToolDt.callbackName = RdKGTool.addonName .. "DetonationTracker"

RdKGToolDt.config = {}
RdKGToolDt.config.updateInterval = 100
RdKGToolDt.config.isClampedToScreen = false
RdKGToolDt.config.sizes = {}
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL] = {}
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].width = 150
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].blockHeight = 20
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].height = 200
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].fontSize = 15
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG] = {}
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].width = 300
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].blockHeight = 40
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].height = 400
RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].fontSize = 30

RdKGToolDt.state = {}
RdKGToolDt.state.initialized = false
RdKGToolDt.state.foreground = true
RdKGToolDt.state.registredConsumers = false
RdKGToolDt.state.activeLayerIndex = 1
RdKGToolDt.state.registredActiveConsumers = false
RdKGToolDt.state.width = RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].width
RdKGToolDt.state.blockHeight = RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].blockHeight
RdKGToolDt.state.height = RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].height
RdKGToolDt.state.fontSize = RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].fontSize
RdKGToolDt.state.font = nil

RdKGToolDt.controls = {}

local wm = WINDOW_MANAGER

function RdKGToolDt.Initialize()
	RdKGTool.profile.AddProfileChangeListener(RdKGToolDt.callbackName, RdKGToolDt.OnProfileChanged)
	
	RdKGToolDt.CreateUI()
	
	RdKGToolMenu.AddPositionFixedConsumer(RdKGToolDt.SetDtPositionLocked)
	
	RdKGToolDt.state.initialized = true
	RdKGToolDt.SetEnabled(RdKGToolDt.dtVars.enabled)
end

function RdKGToolDt.SetTlwLocation()
	RdKGToolDt.controls.TLW:ClearAnchors()
	if RdKGToolDt.dtVars.location == nil then
		RdKGToolDt.controls.TLW:SetAnchor(CENTER, GuiRoot, CENTER, -125, -125)
	else
		RdKGToolDt.controls.TLW:SetAnchor(TOPLEFT, GuiRoot, TOPLEFT, RdKGToolDt.dtVars.location.x, RdKGToolDt.dtVars.location.y)
	end
end

function RdKGToolDt.CreateUI()
	RdKGToolDt.controls.TLW = wm:CreateTopLevelWindow(RdKGToolDt.constants.TLW)
	
	RdKGToolDt.SetTlwLocation()

		
	RdKGToolDt.controls.TLW:SetClampedToScreen(RdKGToolDt.config.isClampedToScreen)
	RdKGToolDt.controls.TLW:SetHandler("OnMoveStop", RdKGToolDt.SaveWindowLocation)
	RdKGToolDt.controls.TLW:SetDimensions(RdKGToolDt.state.width, RdKGToolDt.state.height)
	
	RdKGToolDt.controls.TLW.rootControl = wm:CreateControl(nil, RdKGToolDt.controls.TLW, CT_CONTROL)
	
	local rootControl = RdKGToolDt.controls.TLW.rootControl
	
	rootControl:SetDimensions(RdKGToolDt.state.width, RdKGToolDt.state.height)
	rootControl:SetAnchor(TOPLEFT, RdKGToolDt.controls.TLW, TOPLEFT, 0, 0)
	
	rootControl.movableBackdrop = wm:CreateControl(nil, rootControl, CT_BACKDROP)
	
	rootControl.movableBackdrop:SetAnchor(TOPLEFT, rootControl, TOPLEFT, 0, 0)
	rootControl.movableBackdrop:SetDimensions(RdKGToolDt.state.width, RdKGToolDt.state.height)
	
	rootControl.movableBackdrop:SetCenterColor(1, 0, 0, 0.0)
	rootControl.movableBackdrop:SetEdgeColor(1, 0, 0, 0.0)
	
	rootControl.playerBlocks = RdKGToolDt.CreatePlayerBlocks(rootControl, RdKGToolDt.state.width, RdKGToolDt.state.blockHeight)
	RdKGToolDt.controls.TLW:SetHidden(true)
	RdKGToolDt.AdjustMode()
	RdKGToolDt.AdjustSize()
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.CreatePlayerBlock(parent, width, blockHeight, font)
	local playerBlock = wm:CreateControl(nil, parent, CT_CONTROL)
	--playerBlock:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (i - 1) * blockHeight)
	playerBlock:SetDimensions(width, blockHeight)
	playerBlock:SetHidden(true)
	
	playerBlock.edge = wm:CreateControl(nil, playerBlock, CT_BACKDROP)
	playerBlock.edge:SetAnchor(TOPLEFT, playerBlock, TOPLEFT, 0, 0)
	playerBlock.edge:SetDimensions(width, blockHeight)
	playerBlock.edge:SetEdgeTexture(nil, 2, 2, 2, 0)
	playerBlock.edge:SetCenterColor(0, 0, 0, 0)
	playerBlock.edge:SetEdgeColor(0, 0, 0, 1)
		
	playerBlock.progress = wm:CreateControl(nil, playerBlock, CT_STATUSBAR)
	playerBlock.progress:SetAnchor(CENTER, playerBlock, CENTER, 0, 0)
	playerBlock.progress:SetDimensions(width - 4, blockHeight - 4)
	playerBlock.progress:SetMinMax(0, 100)
	playerBlock.progress:SetValue(0)
	
	playerBlock.timeLabel = wm:CreateControl(nil, playerBlock, CT_LABEL)
	playerBlock.timeLabel:SetAnchor(CENTER, playerBlock, CENTER, 0, 0)
	playerBlock.timeLabel:SetFont(font)
	playerBlock.timeLabel:SetWrapMode(ELLIPSIS)
	playerBlock.timeLabel:SetDimensions(width - 6, blockHeight)
	playerBlock.timeLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	playerBlock.timeLabel:SetHorizontalAlignment(TEXT_ALIGN_LEFT)
	
	playerBlock.nameLabel = wm:CreateControl(nil, playerBlock, CT_LABEL)
	playerBlock.nameLabel:SetAnchor(CENTER, playerBlock, CENTER, 0, 0)
	playerBlock.nameLabel:SetFont(font)
	playerBlock.nameLabel:SetWrapMode(ELLIPSIS)
	playerBlock.nameLabel:SetDimensions(width - 50, blockHeight)
	playerBlock.nameLabel:SetVerticalAlignment(TEXT_ALIGN_CENTER)
	playerBlock.nameLabel:SetHorizontalAlignment(TEXT_ALIGN_CENTER)
	
	return playerBlock
end

function RdKGToolDt.CreatePlayerBlocks(parent, width, blockHeight)
	local playerBlocks = {}
	local font = RdKGToolFonts.CreateFontString(RdKGToolFonts.constants.MEDIUM_FONT, RdKGToolFonts.constants.INPUT_KB, blockHeight - 4, RdKGToolFonts.constants.WEIGHT_SOFT_SHADOW_THIN)
	RdKGToolDt.state.font = font
	
	for i = 1, 24 do
		playerBlocks[i] = RdKGToolDt.CreatePlayerBlock(parent, width, blockHeight, font)
		playerBlocks[i]:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (i - 1) * blockHeight)
		
	end
	
	return playerBlocks
end

function RdKGToolDt.GetDefaults()
	local defaults = {}
	defaults.enabled = false
	defaults.pvpOnly = true
	defaults.positionLocked = false
	defaults.detonation = {}
	defaults.detonation.fontColor = {}
	defaults.detonation.fontColor.r = 1
	defaults.detonation.fontColor.g = 1
	defaults.detonation.fontColor.b = 1
	defaults.detonation.progressColor = {}
	defaults.detonation.progressColor.r = 0.578125
	defaults.detonation.progressColor.g = 0.2890625
	defaults.detonation.progressColor.b = 0.640625
	defaults.subterraneanAssault = {}
	defaults.subterraneanAssault.fontColor = {}
	defaults.subterraneanAssault.fontColor.r = 1
	defaults.subterraneanAssault.fontColor.g = 1
	defaults.subterraneanAssault.fontColor.b = 1
	defaults.subterraneanAssault.progressColor = {}
	defaults.subterraneanAssault.progressColor.r = 0.1
	defaults.subterraneanAssault.progressColor.g = 0.95
	defaults.subterraneanAssault.progressColor.b = 0.1
	defaults.subterraneanAssault2 = {}
	defaults.subterraneanAssault2.fontColor = {}
	defaults.subterraneanAssault2.fontColor.r = 1
	defaults.subterraneanAssault2.fontColor.g = 1
	defaults.subterraneanAssault2.fontColor.b = 1
	defaults.subterraneanAssault2.progressColor = {}
	defaults.subterraneanAssault2.progressColor.r = 1
	defaults.subterraneanAssault2.progressColor.g = 0.8
	defaults.subterraneanAssault2.progressColor.b = 0.1
	defaults.deepFissure = {}
	defaults.deepFissure.fontColor = {}
	defaults.deepFissure.fontColor.r = 1
	defaults.deepFissure.fontColor.g = 1
	defaults.deepFissure.fontColor.b = 1
	defaults.deepFissure.progressColor = {}
	defaults.deepFissure.progressColor.r = 0.2890625
	defaults.deepFissure.progressColor.g = 0.2890625
	defaults.deepFissure.progressColor.b = 0.95
	defaults.deepFissure2 = {}
	defaults.deepFissure2.fontColor = {}
	defaults.deepFissure2.fontColor.r = 1
	defaults.deepFissure2.fontColor.g = 1
	defaults.deepFissure2.fontColor.b = 1
	defaults.deepFissure2.progressColor = {}
	defaults.deepFissure2.progressColor.r = 0.0890625
	defaults.deepFissure2.progressColor.g = 0.0
	defaults.deepFissure2.progressColor.b = 1.00
	defaults.size = RdKGToolDt.constants.size.SMALL
	defaults.mode = RdKGToolDt.constants.MODE_BOTH
	defaults.smoothTransition = true
	return defaults
end

function RdKGToolDt.AdjustSize()
	local sizeIncrease = RdKGToolDt.dtVars.size - RdKGToolDt.constants.size.SMALL
	local height = (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].height + (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].height - RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].height) * sizeIncrease)
	local width = (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].width + (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].width - RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].width) * sizeIncrease)
	local blockHeight = (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].blockHeight + (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].blockHeight - RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].blockHeight) * sizeIncrease)
	local fontSize = (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].fontSize + (RdKGToolDt.config.sizes[RdKGToolDt.constants.size.BIG].fontSize - RdKGToolDt.config.sizes[RdKGToolDt.constants.size.SMALL].fontSize) * sizeIncrease)
	local font = RdKGToolFonts.CreateFontString(RdKGToolFonts.constants.MEDIUM_FONT, RdKGToolFonts.constants.INPUT_KB, fontSize, RdKGToolFonts.constants.WEIGHT_SOFT_SHADOW_THIN)
	RdKGToolDt.state.width = width
	RdKGToolDt.state.blockHeight = blockHeight
	RdKGToolDt.state.height = height
	RdKGToolDt.state.fontSize = fontSize
	RdKGToolDt.state.font = font
	local rootControl = RdKGToolDt.controls.TLW.rootControl
	local playerBlocks = rootControl.playerBlocks
	for i = 1, #playerBlocks do
		playerBlocks[i]:ClearAnchors()
		playerBlocks[i]:SetAnchor(TOPLEFT, parent, TOPLEFT, 0, (i - 1) * blockHeight)
		playerBlocks[i]:SetDimensions(width, blockHeight)
		playerBlocks[i]:SetHidden(true)
		
		playerBlocks[i].edge:SetDimensions(width, blockHeight)
			
		playerBlocks[i].progress:SetDimensions(width - 4, blockHeight - 4)
		
		playerBlocks[i].timeLabel:SetFont(font)
		playerBlocks[i].timeLabel:SetDimensions(width - 6, blockHeight)
		
		playerBlocks[i].nameLabel:SetFont(font)
		playerBlocks[i].nameLabel:SetDimensions(width - 50, blockHeight)
	end
	RdKGToolDt.controls.TLW:SetDimensions(width, height)
	RdKGToolDt.controls.TLW.rootControl:SetDimensions(width, height)
	RdKGToolDt.controls.TLW.rootControl.movableBackdrop:SetDimensions(width, height)
end

function RdKGToolDt.AdjustMode()
	
	
	
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.AdjustColors()
	local playerBlocks = RdKGToolDt.controls.TLW.rootControl.playerBlocks
	for i = 1, #playerBlocks do
		if RdKGToolDt.dtVars.mode == RdKGToolDt.constants.MODE_DETONATION then
			playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.detonation.fontColor.r, RdKGToolDt.dtVars.detonation.fontColor.g, RdKGToolDt.dtVars.detonation.fontColor.b)
			playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.detonation.fontColor.r, RdKGToolDt.dtVars.detonation.fontColor.g, RdKGToolDt.dtVars.detonation.fontColor.b)
			playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.detonation.progressColor.r, RdKGToolDt.dtVars.detonation.progressColor.g, RdKGToolDt.dtVars.detonation.progressColor.b)
		end
	end
end

function RdKGToolDt.SetEnabled(value)
	if RdKGToolDt.state.initialized == true and value ~= nil then
		RdKGToolDt.dtVars.enabled = value
		if value == true then
			if RdKGToolDt.state.registredConsumers == false then
				
				EVENT_MANAGER:RegisterForEvent(RdKGToolDt.callbackName, EVENT_PLAYER_ACTIVATED, RdKGToolDt.OnPlayerActivated)
				
			end
			RdKGToolDt.state.registredConsumers = true
		else
			if RdKGToolDt.state.registredConsumers == true then
				
				EVENT_MANAGER:UnregisterForEvent(RdKGToolDt.callbackName, EVENT_PLAYER_ACTIVATED)
				
			end
			RdKGToolDt.state.registredConsumers = false
		end
		RdKGToolDt.OnPlayerActivated()
	end
end

function RdKGToolDt.SetControlVisibility()
	local enabled = RdKGToolDt.dtVars.enabled
	local pvpOnly = RdKGToolDt.dtVars.pvpOnly
	local setHidden = true
	if enabled ~= nil and pvpOnly ~= nil then

		if enabled == true and (pvpOnly == false or (pvpOnly == true and RdKGToolUtil.IsInPvPArea() == true)) then
			setHidden = false
		end
	end
	if setHidden == false then
		if RdKGToolDt.state.foreground == false then
			RdKGToolDt.controls.TLW:SetHidden(RdKGToolDt.state.activeLayerIndex > 2)
		else
			RdKGToolDt.controls.TLW:SetHidden(false)
		end
	else
		RdKGToolDt.controls.TLW:SetHidden(setHidden)
	end
end

function RdKGToolDt.SetPositionLocked(value)
	RdKGToolDt.dtVars.positionLocked = value
	RdKGToolDt.controls.TLW:SetMovable(not value)
	RdKGToolDt.controls.TLW:SetMouseEnabled(not value)
	
	if value == true then
		RdKGToolDt.controls.TLW.rootControl.movableBackdrop:SetCenterColor(1, 0, 0, 0.0)
		RdKGToolDt.controls.TLW.rootControl.movableBackdrop:SetEdgeColor(1, 0, 0, 0.0)
	else
		RdKGToolDt.controls.TLW.rootControl.movableBackdrop:SetCenterColor(1, 0, 0, 0.5)
		RdKGToolDt.controls.TLW.rootControl.movableBackdrop:SetEdgeColor(1, 0, 0, 0.0)
	end
end

function RdKGToolDt.ComparePlayersByDetonationUptime(playerA, playerB)
	if playerA.buffs.specialInformation.proximityDetonation.remaining < playerB.buffs.specialInformation.proximityDetonation.remaining  then
		return false
	elseif playerA.buffs.specialInformation.proximityDetonation.remaining > playerB.buffs.specialInformation.proximityDetonation.remaining  then
		return true
	else
		return playerA.name < playerB.name
	end
end

function RdKGToolDt.ComparePlayersByShalkUptime(playerA, playerB)
	local remainingA = nil
	local remainingB = nil
	if playerA.buffs.specialInformation.subterraneanAssault.active == true then
		remainingA = playerA.buffs.specialInformation.subterraneanAssault.remaining
	elseif playerA.buffs.specialInformation.deepFissure.active == true then
		remainingA = playerA.buffs.specialInformation.deepFissure.remaining
	end
	if playerB.buffs.specialInformation.subterraneanAssault.active == true then
		remainingB = playerB.buffs.specialInformation.subterraneanAssault.remaining
	elseif playerB.buffs.specialInformation.deepFissure.active == true then
		remainingB = playerB.buffs.specialInformation.deepFissure.remaining
	end
	if remainingA < remainingB then
		return false
	elseif remainingA > remainingB then
		return true
	else
		return playerA.name < playerB.name
	end
end

function RdKGToolDt.ComparePlayersByDetonationShalkUptime(playerA, playerB)
	if playerA.remaining < playerB.remaining then
		return false
	elseif playerA.remaining > playerB.remaining then
		return true
	else
		if playerA.name ~= playerB.name then
			return playerA.name < playerB.name
		else
			return playerA.buff < playerB.buff
		end
	end
end

function RdKGToolDt.GetSortedDetonationPlayerList(players)
	local detosOnly = {}
	local timeStamp = GetGameTimeMilliseconds() / 1000
	for i = 1, #players do
		if players[i] ~= nil and players[i].buffs ~= nil and players[i].buffs.specialInformation ~= nil and players[i].buffs.specialInformation.proximityDetonation ~= nil and players[i].buffs.specialInformation.proximityDetonation.active == true then
			players[i].buffs.specialInformation.proximityDetonation.remaining = players[i].buffs.specialInformation.proximityDetonation.ending - timeStamp
			table.insert(detosOnly, players[i])
		end
	end
	table.sort(detosOnly, RdKGToolDt.ComparePlayersByDetonationUptime)
	return detosOnly
end

function RdKGToolDt.GetSortedList(players)
	local displayItems = {}
	local timeStamp = GetGameTimeMilliseconds() / 1000
	if RdKGToolDt.dtVars.mode == RdKGToolDt.constants.MODE_BOTH then
		local localPlayers = {}
		for i = 1, #players do
			if players[i] ~= nil and players[i].buffs ~= nil and players[i].buffs.specialInformation ~= nil and players[i].buffs.specialInformation.proximityDetonation ~= nil and players[i].buffs.specialInformation.proximityDetonation.active == true then
				local localPlayer = {}
				localPlayer.buff = RdKGToolDt.constants.TYPE_DETONATION
				localPlayer.remaining = players[i].buffs.specialInformation.proximityDetonation.ending - timeStamp
				localPlayer.name =  players[i].name
				localPlayer.started = players[i].buffs.specialInformation.proximityDetonation.started
				localPlayer.ending = players[i].buffs.specialInformation.proximityDetonation.ending
				table.insert(displayItems, localPlayer)
			end
			if players[i] ~= nil and players[i].buffs ~= nil and players[i].buffs.specialInformation ~= nil and players[i].buffs.specialInformation.subterraneanAssault ~= nil and players[i].buffs.specialInformation.subterraneanAssault.active == true then
				local localPlayer = {}
				localPlayer.buff = RdKGToolDt.constants.TYPE_SUBTERRANEAN_ASSAULT
				localPlayer.remaining = players[i].buffs.specialInformation.subterraneanAssault.ending - timeStamp
				localPlayer.name =  players[i].name
				localPlayer.started = players[i].buffs.specialInformation.subterraneanAssault.started
				localPlayer.ending = players[i].buffs.specialInformation.subterraneanAssault.ending
				localPlayer.waveTwo = players[i].buffs.specialInformation.subterraneanAssault.waveTwo
				table.insert(displayItems, localPlayer)
				--d("assault")
			elseif players[i] ~= nil and players[i].buffs ~= nil and players[i].buffs.specialInformation ~= nil and players[i].buffs.specialInformation.deepFissure ~= nil and players[i].buffs.specialInformation.deepFissure.active == true then
				local localPlayer = {}
				localPlayer.buff = RdKGToolDt.constants.TYPE_DEEP_FRISSURE
				localPlayer.remaining = players[i].buffs.specialInformation.deepFissure.ending - timeStamp
				localPlayer.name =  players[i].name
				localPlayer.started = players[i].buffs.specialInformation.deepFissure.started
				localPlayer.ending = players[i].buffs.specialInformation.deepFissure.ending
				localPlayer.waveTwo = players[i].buffs.specialInformation.deepFissure.waveTwo
				table.insert(displayItems, localPlayer)
				--d("deep")
			end
		end
		table.sort(displayItems, RdKGToolDt.ComparePlayersByDetonationShalkUptime)
	elseif RdKGToolDt.dtVars.mode == RdKGToolDt.constants.MODE_DETONATION then
		for i = 1, #players do
			if players[i] ~= nil and players[i].buffs ~= nil and players[i].buffs.specialInformation ~= nil and players[i].buffs.specialInformation.proximityDetonation ~= nil and players[i].buffs.specialInformation.proximityDetonation.active == true then
				players[i].buffs.specialInformation.proximityDetonation.remaining = players[i].buffs.specialInformation.proximityDetonation.ending - timeStamp
				table.insert(displayItems, players[i])
			end
		end
		table.sort(displayItems, RdKGToolDt.ComparePlayersByDetonationUptime)
	elseif RdKGToolDt.dtVars.mode == RdKGToolDt.constants.MODE_SHALK then
		for i = 1, #players do
			if players[i] ~= nil and players[i].buffs ~= nil and players[i].buffs.specialInformation ~= nil and players[i].buffs.specialInformation.subterraneanAssault ~= nil and players[i].buffs.specialInformation.subterraneanAssault.active == true then
				players[i].buffs.specialInformation.subterraneanAssault.remaining = players[i].buffs.specialInformation.subterraneanAssault.ending - timeStamp
				table.insert(displayItems, players[i])
			elseif players[i] ~= nil and players[i].buffs ~= nil and players[i].buffs.specialInformation ~= nil and players[i].buffs.specialInformation.deepFissure ~= nil and players[i].buffs.specialInformation.deepFissure.active == true then
				players[i].buffs.specialInformation.deepFissure.remaining = players[i].buffs.specialInformation.deepFissure.ending - timeStamp
				table.insert(displayItems, players[i])
			end
		end
		table.sort(displayItems, RdKGToolDt.ComparePlayersByShalkUptime)
	end
	return displayItems
end

--callbacks
function RdKGToolDt.OnProfileChanged(currentProfile)
	if currentProfile ~= nil then
		RdKGToolDt.dtVars = currentProfile.group.dt
		if RdKGToolDt.state.initialized == true then
			RdKGToolDt.SetControlVisibility()
			RdKGToolDt.AdjustMode()
			RdKGToolDt.AdjustSize()
			RdKGToolDt.AdjustColors()
			RdKGToolDt.SetPositionLocked(RdKGToolDt.dtVars.positionLocked)
			RdKGToolDt.SetTlwLocation()
		end
		RdKGToolDt.SetEnabled(RdKGToolDt.dtVars.enabled)
		
	end
end

function RdKGToolDt.SaveWindowLocation()
	if RdKGToolDt.dtVars.positionLocked == false then
		RdKGToolDt.dtVars.location = RdKGToolDt.dtVars.location or {}
		RdKGToolDt.dtVars.location.x = RdKGToolDt.controls.TLW:GetLeft()
		RdKGToolDt.dtVars.location.y = RdKGToolDt.controls.TLW:GetTop()
	end
end

function RdKGToolDt.OnPlayerActivated(eventCode, initial)
	--d(RdKGToolDt.dtVars.enabled)
	if RdKGToolDt.dtVars.enabled == true and (RdKGToolDt.dtVars.pvpOnly == true and RdKGToolUtil.IsInPvPArea() == true or RdKGToolDt.dtVars.pvpOnly == false) then
		--d("register")
		if RdKGToolDt.state.registredActiveConsumers == false then
			EVENT_MANAGER:RegisterForEvent(RdKGToolDt.callbackName, EVENT_ACTION_LAYER_POPPED, RdKGToolDt.SetForegroundVisibility)
			EVENT_MANAGER:RegisterForEvent(RdKGToolDt.callbackName, EVENT_ACTION_LAYER_PUSHED, RdKGToolDt.SetForegroundVisibility)
			EVENT_MANAGER:RegisterForUpdate(RdKGToolDt.callbackName, RdKGToolDt.config.updateInterval, RdKGToolDt.UiLoop)
			RdKGToolUtilGroup.AddFeature(RdKGToolDt.callbackName, RdKGToolUtilGroup.features.FEATURE_GROUP_BUFFS, RdKGToolDt.config.updateInterval)
			RdKGToolDt.state.registredActiveConsumers = true
		end
	else
		--d("unregister")
		if RdKGToolDt.state.registredActiveConsumers == true then
			EVENT_MANAGER:UnregisterForEvent(RdKGToolDt.callbackName, EVENT_ACTION_LAYER_POPPED)
			EVENT_MANAGER:UnregisterForEvent(RdKGToolDt.callbackName, EVENT_ACTION_LAYER_PUSHED)
			EVENT_MANAGER:UnregisterForUpdate(RdKGToolDt.callbackName)
			RdKGToolUtilGroup.RemoveFeature(RdKGToolDt.callbackName, RdKGToolUtilGroup.features.FEATURE_GROUP_BUFFS)
			RdKGToolDt.state.registredActiveConsumers = false
		end
	end
	RdKGToolDt.SetControlVisibility()
end

function RdKGToolDt.SetForegroundVisibility(eventCode, layerIndex, activeLayerIndex)
	if eventCode == EVENT_ACTION_LAYER_POPPED then
		RdKGToolDt.state.foreground = true
	elseif eventCode == EVENT_ACTION_LAYER_PUSHED then
		RdKGToolDt.state.foreground = false
	end
	--hack?
	RdKGToolDt.state.activeLayerIndex = activeLayerIndex
	
	RdKGToolDt.SetControlVisibility()
end

function RdKGToolDt.UiLoop()
	--d("dt")
	if RdKGToolDt.dtVars.pvpOnly == false or (RdKGToolDt.dtVars.pvpOnly == true and RdKGToolUtil.IsInPvPArea()) then
		local players = RdKGToolUtilGroup.GetGroupInformation()
		--d("dt")
		if players ~= nil then
			--players = RdKGToolDt.GetSortedDetonationPlayerList(players)
			players = RdKGToolDt.GetSortedList(players)
			local playerBlocks = RdKGToolDt.controls.TLW.rootControl.playerBlocks
			if RdKGToolDt.dtVars.mode == RdKGToolDt.constants.MODE_BOTH then
				for i = 1, #players do
					local timespan = players[i].remaining
					local percent = 0.0
					if playerBlocks[i] == nil then
						playerBlocks[i] = RdKGToolDt.CreatePlayerBlock(RdKGToolDt.controls.TLW.rootControl, RdKGToolDt.state.width, RdKGToolDt.state.blockHeight, RdKGToolDt.state.font)
						playerBlocks[i]:SetAnchor(TOPLEFT, RdKGToolDt.controls.TLW.rootControl, TOPLEFT, 0, (i - 1) * RdKGToolDt.state.blockHeight)
					end
					if timespan < 0 then
						timespan = 0
					end
					if players[i].buff == RdKGToolDt.constants.TYPE_DETONATION then
						playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.detonation.fontColor.r, RdKGToolDt.dtVars.detonation.fontColor.g, RdKGToolDt.dtVars.detonation.fontColor.b)
						playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.detonation.fontColor.r, RdKGToolDt.dtVars.detonation.fontColor.g, RdKGToolDt.dtVars.detonation.fontColor.b)
						playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.detonation.progressColor.r, RdKGToolDt.dtVars.detonation.progressColor.g, RdKGToolDt.dtVars.detonation.progressColor.b)
						percent = players[i].remaining / (players[i].ending - players[i].started) * 100
					elseif players[i].buff == RdKGToolDt.constants.TYPE_SUBTERRANEAN_ASSAULT then
						if players[i].waveTwo == false then
							playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.subterraneanAssault.fontColor.r, RdKGToolDt.dtVars.subterraneanAssault.fontColor.g, RdKGToolDt.dtVars.subterraneanAssault.fontColor.b)
							playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.subterraneanAssault.fontColor.r, RdKGToolDt.dtVars.subterraneanAssault.fontColor.g, RdKGToolDt.dtVars.subterraneanAssault.fontColor.b)
							playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.subterraneanAssault.progressColor.r, RdKGToolDt.dtVars.subterraneanAssault.progressColor.g, RdKGToolDt.dtVars.subterraneanAssault.progressColor.b)
							--d(players[i].remaining)
						else
							playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.subterraneanAssault2.fontColor.r, RdKGToolDt.dtVars.subterraneanAssault2.fontColor.g, RdKGToolDt.dtVars.subterraneanAssault2.fontColor.b)
							playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.subterraneanAssault2.fontColor.r, RdKGToolDt.dtVars.subterraneanAssault2.fontColor.g, RdKGToolDt.dtVars.subterraneanAssault2.fontColor.b)
							playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.subterraneanAssault2.progressColor.r, RdKGToolDt.dtVars.subterraneanAssault2.progressColor.g, RdKGToolDt.dtVars.subterraneanAssault2.progressColor.b)
						end
						percent = players[i].remaining / (players[i].ending - players[i].started + 5) * 100
						--d("assault")
					elseif players[i].buff == RdKGToolDt.constants.TYPE_DEEP_FRISSURE then
						if players[i].waveTwo == false then
							playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.deepFissure.fontColor.r, RdKGToolDt.dtVars.deepFissure.fontColor.g, RdKGToolDt.dtVars.deepFissure.fontColor.b)
							playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.deepFissure.fontColor.r, RdKGToolDt.dtVars.deepFissure.fontColor.g, RdKGToolDt.dtVars.deepFissure.fontColor.b)
							playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.deepFissure.progressColor.r, RdKGToolDt.dtVars.deepFissure.progressColor.g, RdKGToolDt.dtVars.deepFissure.progressColor.b)
							percent = players[i].remaining / (players[i].ending - players[i].started + 5) * 100
						else
							playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.deepFissure2.fontColor.r, RdKGToolDt.dtVars.deepFissure2.fontColor.g, RdKGToolDt.dtVars.deepFissure2.fontColor.b)
							playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.deepFissure2.fontColor.r, RdKGToolDt.dtVars.deepFissure2.fontColor.g, RdKGToolDt.dtVars.deepFissure2.fontColor.b)
							playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.deepFissure2.progressColor.r, RdKGToolDt.dtVars.deepFissure2.progressColor.g, RdKGToolDt.dtVars.deepFissure2.progressColor.b)
							percent = players[i].remaining / (players[i].ending - players[i].started + 2) * 100
						end
						
						--d("deep")
					end
					playerBlocks[i]:SetHidden(false)
					playerBlocks[i].timeLabel:SetText(string.format("%.1f", timespan))
					playerBlocks[i].nameLabel:SetText(players[i].name)
					ZO_StatusBar_SmoothTransition(playerBlocks[i].progress, percent, 100, not RdKGToolDt.dtVars.smoothTransition)
				end
			elseif RdKGToolDt.dtVars.mode == RdKGToolDt.constants.MODE_DETONATION then
				for i = 1, #players do
					local timespan = players[i].buffs.specialInformation.proximityDetonation.remaining
					if playerBlocks[i] == nil then
						playerBlocks[i] = RdKGToolDt.CreatePlayerBlock(RdKGToolDt.controls.TLW.rootControl, RdKGToolDt.state.width, RdKGToolDt.state.blockHeight, RdKGToolDt.state.font)
						playerBlocks[i]:SetAnchor(TOPLEFT, RdKGToolDt.controls.TLW.rootControl, TOPLEFT, 0, (i - 1) * RdKGToolDt.state.blockHeight)
					end
					if timespan < 0 then
						timespan = 0
					end
					
					playerBlocks[i]:SetHidden(false)
					playerBlocks[i].timeLabel:SetText(string.format("%.1f", timespan))
					playerBlocks[i].nameLabel:SetText(players[i].name)
					ZO_StatusBar_SmoothTransition(playerBlocks[i].progress, players[i].buffs.specialInformation.proximityDetonation.remaining / (players[i].buffs.specialInformation.proximityDetonation.ending - players[i].buffs.specialInformation.proximityDetonation.started) * 100, 100, not RdKGToolDt.dtVars.smoothTransition)
				end
			elseif RdKGToolDt.dtVars.mode == RdKGToolDt.constants.MODE_SHALK then
				for i = 1, #players do
					local timespan = 0
					if playerBlocks[i] == nil then
						playerBlocks[i] = RdKGToolDt.CreatePlayerBlock(RdKGToolDt.controls.TLW.rootControl, RdKGToolDt.state.width, RdKGToolDt.state.blockHeight, RdKGToolDt.state.font)
						playerBlocks[i]:SetAnchor(TOPLEFT, RdKGToolDt.controls.TLW.rootControl, TOPLEFT, 0, (i - 1) * RdKGToolDt.state.blockHeight)
					end
					if players[i].buffs.specialInformation.subterraneanAssault.active == true then
						timespan = players[i].buffs.specialInformation.subterraneanAssault.remaining
						playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.subterraneanAssault.fontColor.r, RdKGToolDt.dtVars.subterraneanAssault.fontColor.g, RdKGToolDt.dtVars.subterraneanAssault.fontColor.b)
						playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.subterraneanAssault.fontColor.r, RdKGToolDt.dtVars.subterraneanAssault.fontColor.g, RdKGToolDt.dtVars.subterraneanAssault.fontColor.b)
						playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.subterraneanAssault.progressColor.r, RdKGToolDt.dtVars.subterraneanAssault.progressColor.g, RdKGToolDt.dtVars.subterraneanAssault.progressColor.b)
						ZO_StatusBar_SmoothTransition(playerBlocks[i].progress, players[i].buffs.specialInformation.subterraneanAssault.remaining / (players[i].buffs.specialInformation.subterraneanAssault.ending - players[i].buffs.specialInformation.subterraneanAssault.started) * 100, 100, not RdKGToolDt.dtVars.smoothTransition)
						--playerBlocks[i].progress:SetValue(players[i].buffs.specialInformation.subterraneanAssault.remaining / (players[i].buffs.specialInformation.subterraneanAssault.ending - players[i].buffs.specialInformation.subterraneanAssault.started) * 100)
					elseif players[i].buffs.specialInformation.deepFissure.active == true then
						timespan = players[i].buffs.specialInformation.deepFissure.remaining
						playerBlocks[i].timeLabel:SetColor(RdKGToolDt.dtVars.deepFissure.fontColor.r, RdKGToolDt.dtVars.deepFissure.fontColor.g, RdKGToolDt.dtVars.deepFissure.fontColor.b)
						playerBlocks[i].nameLabel:SetColor(RdKGToolDt.dtVars.deepFissure.fontColor.r, RdKGToolDt.dtVars.deepFissure.fontColor.g, RdKGToolDt.dtVars.deepFissure.fontColor.b)
						playerBlocks[i].progress:SetColor(RdKGToolDt.dtVars.deepFissure.progressColor.r, RdKGToolDt.dtVars.deepFissure.progressColor.g, RdKGToolDt.dtVars.deepFissure.progressColor.b)
						ZO_StatusBar_SmoothTransition(playerBlocks[i].progress, players[i].buffs.specialInformation.deepFissure.remaining / (players[i].buffs.specialInformation.deepFissure.ending - players[i].buffs.specialInformation.deepFissure.started) * 100, 100, not RdKGToolDt.dtVars.smoothTransition)
					end
					if timespan < 0 then
						timespan = 0
					end
					
					playerBlocks[i]:SetHidden(false)
					playerBlocks[i].timeLabel:SetText(string.format("%.1f", timespan))
					playerBlocks[i].nameLabel:SetText(players[i].name)
					
				end
			end
			for i = #players + 1, #playerBlocks do
				playerBlocks[i]:SetHidden(true)
			end
		end
	end
end

--menu interaction
function RdKGToolDt.GetMenu()
	local menu = {
		[1] = {
			type = "submenu",
			name = RdKGToolMenu.constants.DT_HEADER,
			controls = {
				[1] = {
					type = "checkbox",
					name = RdKGToolMenu.constants.DT_ENABLED,
					getFunc = RdKGToolDt.GetDtEnabled,
					setFunc = RdKGToolDt.SetDtEnabled
				},
				[2] = {
					type = "checkbox",
					name = RdKGToolMenu.constants.DT_POSITION_FIXED,
					getFunc = RdKGToolDt.GetDtPositionLocked,
					setFunc = RdKGToolDt.SetDtPositionLocked
				},
				[3] = {
					type = "checkbox",
					name = RdKGToolMenu.constants.DT_PVP_ONLY,
					getFunc = RdKGToolDt.GetDtPvpOnly,
					setFunc = RdKGToolDt.SetDtPvpOnly
				},
				[4] = {
					type = "dropdown",
					name = RdKGToolMenu.constants.DT_MODE,
					choices = RdKGToolDt.GetDtAvailableModes(),
					getFunc = RdKGToolDt.GetDtSelectedMode,
					setFunc = RdKGToolDt.SetDtSelectedMode,
					width = "full"
				},
				[5] = {
					type = "slider",
					name = RdKGToolMenu.constants.DT_SIZE,
					min = 1.0,
					max = 2.0,
					step = 0.01,
					getFunc = RdKGToolDt.GetDtSelectedSize,
					setFunc = RdKGToolDt.SetDtSelectedSize,
					width = "full",
					decimals = 2,
					default = 1.0
				},
				[6] = {
					type = "checkbox",
					name = RdKGToolMenu.constants.DT_SMOOTH_TRANSITION,
					getFunc = RdKGToolDt.GetDtSmoothTransition,
					setFunc = RdKGToolDt.SetDtSmoothTransition
				},
				[7] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_FONT_COLOR_DETONATION,
					getFunc = RdKGToolDt.GetDtDetonationFontColor,
					setFunc = RdKGToolDt.SetDtDetonationFontColor,
					width = "full"
				},
				[8] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_PROGRESS_COLOR_DETONATION,
					getFunc = RdKGToolDt.GetDtDetonationProgressColor,
					setFunc = RdKGToolDt.SetDtDetonationProgressColor,
					width = "full"
				},
				[9] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_FONT_COLOR_SUBTERRANEAN_ASSAULT,
					getFunc = RdKGToolDt.GetDtSubterraneanAssaultFontColor,
					setFunc = RdKGToolDt.SetDtSubterraneanAssaultFontColor,
					width = "full"
				},
				[10] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_PROGRESS_COLOR_SUBTERRANEAN_ASSAULT,
					getFunc = RdKGToolDt.GetDtSubterraneanAssaultProgressColor,
					setFunc = RdKGToolDt.SetDtSubterraneanAssaultProgressColor,
					width = "full"
				},
				[11] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_FONT_COLOR_SUBTERRANEAN_ASSAULT2,
					getFunc = RdKGToolDt.GetDtSubterraneanAssault2FontColor,
					setFunc = RdKGToolDt.SetDtSubterraneanAssault2FontColor,
					width = "full"
				},
				[12] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_PROGRESS_COLOR_SUBTERRANEAN_ASSAULT2,
					getFunc = RdKGToolDt.GetDtSubterraneanAssault2ProgressColor,
					setFunc = RdKGToolDt.SetDtSubterraneanAssault2ProgressColor,
					width = "full"
				},
				[13] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_FONT_COLOR_DEEP_FISSURE,
					getFunc = RdKGToolDt.GetDtDeepFissureFontColor,
					setFunc = RdKGToolDt.SetDtDeepFissureFontColor,
					width = "full"
				},
				[14] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_PROGRESS_COLOR_DEEP_FISSURE,
					getFunc = RdKGToolDt.GetDtDeepFissureProgressColor,
					setFunc = RdKGToolDt.SetDtDeepFissureProgressColor,
					width = "full"
				},
				[15] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_FONT_COLOR_DEEP_FISSURE2,
					getFunc = RdKGToolDt.GetDtDeepFissure2FontColor,
					setFunc = RdKGToolDt.SetDtDeepFissure2FontColor,
					width = "full"
				},
				[16] = {
					type = "colorpicker",
					name = RdKGToolMenu.constants.DT_PROGRESS_COLOR_DEEP_FISSURE2,
					getFunc = RdKGToolDt.GetDtDeepFissure2ProgressColor,
					setFunc = RdKGToolDt.SetDtDeepFissure2ProgressColor,
					width = "full"
				}
			}
		}
	}
	return menu
end

function RdKGToolDt.GetDtEnabled()
	return RdKGToolDt.dtVars.enabled
end

function RdKGToolDt.SetDtEnabled(value)
	RdKGToolDt.SetEnabled(value)
end

function RdKGToolDt.GetDtPositionLocked()
	return RdKGToolDt.dtVars.positionLocked
end

function RdKGToolDt.SetDtPositionLocked(value)
	RdKGToolDt.SetPositionLocked(value)
end

function RdKGToolDt.GetDtPvpOnly()
	return RdKGToolDt.dtVars.pvpOnly
end

function RdKGToolDt.SetDtPvpOnly(value)
	RdKGToolDt.dtVars.pvpOnly = value
	RdKGToolDt.SetEnabled(RdKGToolDt.dtVars.enabled)
end

function RdKGToolDt.GetDtAvailableModes()
	return RdKGToolDt.constants.modes
end

function RdKGToolDt.GetDtSelectedMode()
	return RdKGToolDt.constants.modes[RdKGToolDt.dtVars.mode]
end

function RdKGToolDt.SetDtSelectedMode(value)
	if value ~= nil then
		for i = 1, #RdKGToolDt.constants.modes do
			if RdKGToolDt.constants.modes[i] == value then
				RdKGToolDt.dtVars.mode = i
				RdKGToolDt.AdjustMode()
			end
		end
	end
end

function RdKGToolDt.GetDtSelectedSize()
	return RdKGToolDt.dtVars.size
end

function RdKGToolDt.SetDtSelectedSize(value)
	if value ~= nil and value >= RdKGToolDt.constants.size.SMALL and value <= RdKGToolDt.constants.size.BIG then
		RdKGToolDt.dtVars.size = value
		RdKGToolDt.AdjustSize()
	end
end

function RdKGToolDt.GetDtSmoothTransition()
	return RdKGToolDt.dtVars.smoothTransition
end

function RdKGToolDt.SetDtSmoothTransition(value)
	RdKGToolDt.dtVars.smoothTransition = value
end

function RdKGToolDt.GetDtDetonationFontColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.detonation.fontColor)
end

function RdKGToolDt.SetDtDetonationFontColor(r, g, b)
	RdKGToolDt.dtVars.detonation.fontColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtDetonationProgressColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.detonation.progressColor)
end

function RdKGToolDt.SetDtDetonationProgressColor(r, g, b)
	RdKGToolDt.dtVars.detonation.progressColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtSubterraneanAssaultFontColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.subterraneanAssault.fontColor)
end

function RdKGToolDt.SetDtSubterraneanAssaultFontColor(r, g, b)
	RdKGToolDt.dtVars.subterraneanAssault.fontColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtSubterraneanAssaultProgressColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.subterraneanAssault.progressColor)
end

function RdKGToolDt.SetDtSubterraneanAssaultProgressColor(r, g, b)
	RdKGToolDt.dtVars.subterraneanAssault.progressColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtSubterraneanAssault2FontColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.subterraneanAssault2.fontColor)
end

function RdKGToolDt.SetDtSubterraneanAssault2FontColor(r, g, b)
	RdKGToolDt.dtVars.subterraneanAssault2.fontColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtSubterraneanAssault2ProgressColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.subterraneanAssault2.progressColor)
end

function RdKGToolDt.SetDtSubterraneanAssault2ProgressColor(r, g, b)
	RdKGToolDt.dtVars.subterraneanAssault2.progressColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtDeepFissureFontColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.deepFissure.fontColor)
end

function RdKGToolDt.SetDtDeepFissureFontColor(r, g, b)
	RdKGToolDt.dtVars.deepFissure.fontColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtDeepFissureProgressColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.deepFissure.progressColor)
end

function RdKGToolDt.SetDtDeepFissureProgressColor(r, g, b)
	RdKGToolDt.dtVars.deepFissure.progressColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtDeepFissure2FontColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.deepFissure2.fontColor)
end

function RdKGToolDt.SetDtDeepFissure2FontColor(r, g, b)
	RdKGToolDt.dtVars.deepFissure2.fontColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end

function RdKGToolDt.GetDtDeepFissure2ProgressColor()
	return RdKGToolMenu.GetRGBColor(RdKGToolDt.dtVars.deepFissure2.progressColor)
end

function RdKGToolDt.SetDtDeepFissure2ProgressColor(r, g, b)
	RdKGToolDt.dtVars.deepFissure2.progressColor = RdKGToolMenu.GetColorFromRGB(r, g, b)
	RdKGToolDt.AdjustColors()
end