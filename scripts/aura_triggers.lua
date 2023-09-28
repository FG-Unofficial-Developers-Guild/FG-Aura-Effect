--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals bDebug bDebugPerformance handleTokenMovement notifyTokenMove
-- luacheck: globals updateAurasForMap updateAurasForActor updateAurasForEffect
-- luacheck: globals updateAurasForTurnStart AuraEffect.clearOncePerTurn AuraTracker AuraToken
bDebug = false
bDebugPerformance = false

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'

-- Trigger AURA effect calculation on supplied effect node.
function updateAurasForEffect(nodeEffect, nodeCTMoved)
	if type(nodeEffect) ~= 'databasenode' then return end -- sometimes userdata shows up here when used with BCE
	local rAuraDetails = AuraEffect.getAuraDetails(nodeEffect)
	if rAuraDetails.nRange == 0 then return end -- 0 means no valid aura found
	local tokenSource = CombatManager.getTokenFromCT(DB.findNode(rAuraDetails.sSource))
	AuraEffect.updateAura(tokenSource, nodeEffect, rAuraDetails, nodeCTMoved)
end

-- Trigger AURA effect calculation on all effects in a supplied CT node.
-- If supplied with windowFilter instance, abort if actor's map doesn't match
-- If supplied with effectFilter node, skip that effect
function updateAurasForActor(nodeCT, windowFilter, effectFilter, nodeCTMoved)
	if windowFilter then -- if windowFilter is provided, save winImage to filterImage
		local _, winImage, _ = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
		if winImage ~= windowFilter then return end -- if filterImage is set and doesn't match, abort
	end
	for _, nodeEffect in ipairs(DB.getChildList(nodeCT, 'effects')) do
		if not effectFilter and nodeEffect ~= effectFilter then updateAurasForEffect(nodeEffect, nodeCTMoved) end
	end
end

-- Calls updateAurasForActor on each CT node whose token is on the same image supplied as 'window'
function updateAurasForMap(window, nodeCTMoved)
	if not window or not StringManager.contains({ 'imagepanelwindow', 'imagewindow' }, window.getClass()) then return end

	-- If we have a node that has moved (nodeCTMoved), use the aura tracker else we haven't initialized the tracker yet
	-- so do the inefficient way (when a map is opened).
	if nodeCTMoved then
		local aAuras = AuraTracker.getAllTrackedAuras()
		for sSourceNode, _ in pairs(aAuras) do
			local nodeCT = DB.findNode(sSourceNode)
			local _, winImage = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
			if winImage == window then updateAurasForActor(nodeCT, winImage, nil, nodeCTMoved) end
		end
	else
		for _, nodeCT in ipairs(DB.getChildList(CombatManager.CT_LIST)) do
			local _, winImage = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
			if winImage == window then updateAurasForActor(nodeCT, winImage) end
		end
	end
end

--SINGLE aura type to update on turn start
function updateAurasForTurnStart(nodeCTStart)
	AuraEffect.clearOncePerTurn()
	local _, window = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCTStart))
	local aAuras = AuraTracker.getAllTrackedAuras()

	for sSourceNode, _ in pairs(aAuras) do
		local nodeCT = DB.findNode(sSourceNode)
		local _, winImage = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
		if winImage == window then updateAurasForActor(nodeCT, winImage, nil, nodeCTStart) end
	end
end

local sTime = ''
function handleTokenMovement(msgOOB)
	local time1 = nil
	if bDebugPerformance then time1 = os.clock() end
	local _, winImage = ImageManager.getImageControl(CombatManager.getTokenFromCT(msgOOB.sCTNode))
	if AuraToken.isMovedFilter(DB.findNode(msgOOB.sCTNode),CombatManager.getTokenFromCT(msgOOB.sCTNode)) then
		updateAurasForMap(winImage,DB.findNode(msgOOB.sCTNode))
		if bDebugPerformance then
			sTime = string.format('%s%s,', sTime, tostring(os.clock() - time1))
			Debug.console(sTime)
		end
	end
end

---	This function requests aura processing to be performed on the host FG instance.
function notifyTokenMove(token)
	local nodeCT = CombatManager.getCTFromToken(token)
	if not nodeCT then return end

	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_AURATOKENMOVE
	msgOOB.sCTNode = DB.getPath(nodeCT)

	Comm.deliverOOBMessage(msgOOB, '')
end

local function onMove(token) notifyTokenMove(token) end

-- Recalculate auras when opening images
local onWindowOpened_old
local function onWindowOpened_new(window, ...)
	if onWindowOpened_old then onWindowOpened_old(window, ...) end
	updateAurasForMap(window)
end

-- Recalculate auras when adding tokens
local handleStandardCombatAddPlacement_old
local function handleStandardCombatAddPlacement_new(tCustom, ...)
	if handleStandardCombatAddPlacement_old then handleStandardCombatAddPlacement_old(tCustom, ...) end
	updateAurasForActor(tCustom.nodeCT)
end

---	Recalculate auras when effect text is changed to facilitate conditionals before aura effects
local function onEffectChanged(nodeLabel)
	local nodeEffect = DB.getParent(nodeLabel)
	local sEffect = DB.getValue(nodeEffect, 'label', '')
	if string.match(sEffect, 'AURA[:;]') and not string.match(sEffect, 'FROMAURA[:;]') then
		local sNode = DB.getPath(DB.getChild(nodeEffect, '...'))
		local sAuraEffect = DB.getPath(nodeEffect)
		AuraTracker.removeTrackedFromAura(sNode,sAuraEffect) -- Effect changed
		AuraTracker.addTrackedAura(sNode,sAuraEffect) -- Effect changed to no AURA and then back to AURA
	else
		AuraTracker.removeTrackedAura(DB.getPath(DB.getChild(nodeEffect, '...')), DB.getPath(nodeEffect))
	end

	if sEffect == '' or string.match(sEffect, 'AURA[:;]') then return end -- don't recalculate when changing aura or fromaura
	updateAurasForActor(DB.getChild(nodeEffect, '...'))
end

---	Remove fromaura effects just before source aura is removed
local function onEffectToBeRemoved(nodeEffect)
	local sEffect = DB.getValue(nodeEffect, 'label', '')
	if string.find(sEffect, AuraEffect.fromAuraString) then return end
	if not string.find(sEffect, AuraEffect.auraString) then return end
	AuraEffect.removeAllFromAuras(nodeEffect)
	AuraTracker.removeTrackedAura(DB.getPath(DB.getChild(nodeEffect, '...')), DB.getPath(nodeEffect))
end

---	Recalculate auras after effects are removed to ensure conditionals before aura are respected
local function onEffectRemoved(nodeEffects) updateAurasForActor(DB.getParent(nodeEffects)) end

function onInit()
	-- register OOB message handlers to allow player movement
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURATOKENMOVE, handleTokenMovement)

	-- create proxy function to recalculate auras when adding tokens
	handleStandardCombatAddPlacement_old = CombatRecordManager.handleStandardCombatAddPlacement
	CombatRecordManager.handleStandardCombatAddPlacement = handleStandardCombatAddPlacement_new

	-- create proxy function to recalculate auras when new windows are opened
	onWindowOpened_old = Interface.onWindowOpened
	Interface.onWindowOpened = onWindowOpened_new

	-- create the proxy function to trigger aura calculation on token movement.
	Token.addEventHandler('onMove', onMove)

	-- all handlers should be created on GM machine
	if not Session.IsHost then return end
	DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*.label'), 'onUpdate', onEffectChanged)
	DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*.isactive'), 'onUpdate', onEffectChanged)
	DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*'), 'onDelete', onEffectToBeRemoved)
	DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects'), 'onChildDeleted', onEffectRemoved)

	CombatManager.setCustomTurnStart(updateAurasForTurnStart)
end
