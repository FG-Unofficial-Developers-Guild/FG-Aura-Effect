--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals bDebug handleTokenMovement notifyTokenMove
-- luacheck: globals updateAurasForMap updateAurasForActor updateAurasForEffect
-- luacheck: globals AuraFactionConditional AuraEffect.updateAura

bDebug = false

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'

local fromAuraString = 'FROMAURA;'
local auraString = 'AURA: %d+'
local auraDetailSearchString = 'AURA:%s*([%d%.]*)%s*([~%!]*%a*);'

local function getAuraDetails(sEffect)
	if string.find(sEffect, fromAuraString) or not string.match(sEffect, auraString) then
		return 0 -- only run on auras
	end
	local nRange, auraType = string.match(sEffect, auraDetailSearchString)
	nRange = tonumber(nRange or 0)
	if not auraType then auraType = 'all' end
	return nRange, auraType
end

-- Trigger AURA effect calculation on supplied effect node.
function updateAurasForEffect(nodeEffect)
	local sEffect = DB.getValue(nodeEffect, 'label', '')
	local nRange, auraType = getAuraDetails(sEffect)
	if nRange == 0 then return end
	local nodeSource = DB.getChild(nodeEffect, '...')
	local tokenSource = CombatManager.getTokenFromCT(nodeSource)
	AuraEffect.updateAura(tokenSource, nodeEffect, nRange, auraType)
end

-- Trigger AURA effect calculation on all effects in a supplied CT node.
-- If supplied with windowFilter instance, abort if actor's map doesn't match
-- If supplied with effectFilter node, skip that effect
function updateAurasForActor(nodeCT, windowFilter, effectFilter)
	if windowFilter then -- if windowFilter is provided, save winImage to filterImage
		local _, winImage, _ = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
		if windowFilter and winImage ~= windowFilter then return end -- if filterImage is set and doesn't match, abort
	end
	for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
		if not effectFilter or nodeEffect ~= effectFilter then updateAurasForEffect(nodeEffect) end
	end
end

-- Calls updateAurasForActor on each CT node whose token is on the same image supplied as 'window'
function updateAurasForMap(window)
	if not window or not StringManager.contains({ 'imagewindow', 'imagepanelwindow' }, window.getClass()) then return end
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		local _, winImage = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
		if winImage and winImage == window then updateAurasForActor(nodeCT, winImage) end
	end
end

function handleTokenMovement(msgOOB)
	local nodeCT = DB.findNode(msgOOB.sCTNode)
	local token = CombatManager.getTokenFromCT(nodeCT)
	local _, winImage = ImageManager.getImageControl(token)
	updateAurasForMap(winImage)
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

local function onMove(token)
	if not CombatManager.getCTFromToken(token) then return end
	notifyTokenMove(token)
end

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
	if sEffect == '' or string.find(sEffect, fromAuraString) or string.find(sEffect, auraString) then return end
	updateAurasForActor(DB.getChild(nodeEffect, '...'))
end

---	Remove fromaura effects just before source aura is removed
local function onEffectToBeRemoved(nodeEffect)
	local sEffect = DB.getValue(nodeEffect, 'label', '')
	if string.find(sEffect, fromAuraString) then return end
	if string.find(sEffect, auraString) then AuraEffect.removeAllFromAuras(nodeEffect) end
end

---	Recalculate auras after effects are removed to ensure conditionals before aura are respected
local function onEffectRemoved(nodeEffects)
	updateAurasForActor(DB.getParent(nodeEffects))
end

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
	if Session.IsHost then
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*.label'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*.isactive'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*'), 'onDelete', onEffectToBeRemoved)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects'), 'onChildDeleted', onEffectRemoved)
	end
end
