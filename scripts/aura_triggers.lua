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

local function checkConditionalBeforeAura(nodeEffect, nodeCT, targetNodeCT)
	if AuraFactionConditional.DetectedEffectManager.parseEffectComp then -- check conditionals if supported
		for _, sEffectComp in ipairs(EffectManager.parseEffect(DB.getValue(nodeEffect, 'label', ''))) do
			local rEffectComp = AuraFactionConditional.DetectedEffectManager.parseEffectComp(sEffectComp)
			local rActor = ActorManager.resolveActor(nodeCT)
			-- Check conditionals
			if rEffectComp.type == 'IF' then
				if not AuraFactionConditional.DetectedEffectManager.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then return false end
			elseif rEffectComp.type == 'IFT' then
				local rTarget = ActorManager.resolveActor(targetNodeCT)
				if
					rTarget and not AuraFactionConditional.DetectedEffectManager.checkConditional(rTarget, nodeEffect, rEffectComp.remainder, rActor)
				then
					return false
				end
			elseif rEffectComp.type == 'AURA' then
				break
			end
		end
	end
	return true
end

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
	if not checkConditionalBeforeAura(nodeEffect, nodeSource) then return end -- allows for IF/IFT before AURA effects
	AuraEffect.updateAura(tokenSource, nodeEffect, nRange, auraType)
end

-- Trigger AURA effect calculation on all effects in a supplied CT node.
-- If supplied with windowFilter instance, abort if actor's map doesn't match
function updateAurasForActor(nodeCT, windowFilter)
	if windowFilter then -- if windowFilter is provided, save winImage to filterImage
		local _, winImage, _ = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
		if windowFilter and winImage ~= windowFilter then return end -- if filterImage is set and doesn't match, abort
	end
	for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
		updateAurasForEffect(nodeEffect)
	end
end

function handleTokenMovement(msgOOB) updateAurasForActor(DB.findNode(msgOOB.sCTNode)) end

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

-- Calls updateAurasForActor on each CT node whose token is on the same image supplied as 'window'
function updateAurasForMap(window)
	if not window or window.getClass() ~= 'imagewindow' then return end
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		local _, winImage = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
		if winImage and winImage == window then updateAurasForActor(nodeCT, winImage) end
	end
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

---	Recalculate auras when effect text is changed.
local function onEffectChanged(nodeLabel) updateAurasForActor(DB.getChild(nodeLabel, '....')) end

---	Recalculate auras when effects are removed.
local function onEffectRemoved(nodeEffect) updateAurasForActor(DB.getChild(nodeEffect, '...')) end

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
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*'), 'onDelete', onEffectRemoved)
	end
end
