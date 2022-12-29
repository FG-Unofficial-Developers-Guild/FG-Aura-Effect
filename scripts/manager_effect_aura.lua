--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals updateAuras handleTokenMovement handleApplyEffectSilent handleExpireEffectSilent

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'
OOB_MSGTYPE_AURAAPPLYSILENT = 'applyeffsilent'
OOB_MSGTYPE_AURAEXPIRESILENT = 'expireeffsilent'

local fromAuraString = 'FROMAURA;'
local auraString = 'AURA: %d+'

local bDebug = false

local aEffectVarMap = {
	['nActive'] = { sDBType = 'number', sDBField = 'isactive' },
	['nDuration'] = { sDBType = 'number', sDBField = 'duration', vDBDefault = 1, sDisplay = '[D: %d]' },
	['nGMOnly'] = { sDBType = 'number', sDBField = 'isgmonly' },
	['nInit'] = { sDBType = 'number', sDBField = 'init', sSourceChangeSet = 'initresult', bClearOnUntargetedDrop = true },
	['sName'] = { sDBType = 'string', sDBField = 'label' },
	['sSource'] = { sDBType = 'string', sDBField = 'source_name', bClearOnUntargetedDrop = true },
	['sTarget'] = { sDBType = 'string', bClearOnUntargetedDrop = true },
	['sUnit'] = { sDBType = 'string', sDBField = 'unit' },
	['sAuraSource'] = { sDBType = 'string', sDBField = 'source_aura' },
}

local DetectedEffectManager = nil

local function getEffectString(nodeEffect)
	local sLabel = DB.getValue(nodeEffect, 'label', '')

	local aEffectComps = EffectManager.parseEffect(sLabel)

	if EffectManager.isTargetedEffect(nodeEffect) then
		local sTargets = table.concat(EffectManager.getEffectTargets(nodeEffect, true), ',')
		table.insert(aEffectComps, 1, '[TRGT: ' .. sTargets .. ']')
	end

	for _, v in pairs(aEffectVarMap) do
		if v.fDisplay then
			local vValue = v.fDisplay(nodeEffect)
			if vValue then table.insert(aEffectComps, vValue) end
		elseif v.sDisplay and v.sDBField then
			local vDBValue
			if v.sDBType == 'number' then
				vDBValue = DB.getValue(nodeEffect, v.sDBField, v.vDBDefault or 0)
				if vDBValue == 0 then vDBValue = nil end
			else
				vDBValue = DB.getValue(nodeEffect, v.sDBField, v.vDBDefault or '')
				if vDBValue == '' then vDBValue = nil end
			end
			if vDBValue then table.insert(aEffectComps, string.format(v.sDisplay, tostring(vDBValue):upper())) end
		end
	end

	return EffectManager.rebuildParsedEffect(aEffectComps):gsub('%s*%(C%)', ''):gsub('%s*%[D: %d+%]', '')
end

local function getAurasForNode(nodeCT, searchString, targetNodeCT)
	local auraEffects = {}
	for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
		if DB.getValue(nodeEffect, 'isactive', 0) == 1 then
			local sLabelNodeEffect = getEffectString(nodeEffect)
			if sLabelNodeEffect:match(searchString) then
				local bSkipAura = false
				if DetectedEffectManager.parseEffectComp then -- check conditionals if supported
					for _, sEffectComp in ipairs(EffectManager.parseEffect(sLabelNodeEffect)) do
						local rEffectComp = DetectedEffectManager.parseEffectComp(sEffectComp)
						local rActor = ActorManager.resolveActor(nodeCT)
						-- Check conditionals
						if rEffectComp.type == 'IF' then
							if not DetectedEffectManager.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
								bSkipAura = true
								break
							end
						elseif rEffectComp.type == 'IFT' then
							local rTarget = ActorManager.resolveActor(targetNodeCT)
							if rTarget and not DetectedEffectManager.checkConditional(rTarget, nodeEffect, rEffectComp.remainder, rActor) then
								bSkipAura = true
								break
							end
						elseif rEffectComp.type == 'AURA' then
							break
						end
					end
				end
				if bSkipAura == false then
					table.insert(auraEffects, nodeEffect)
				elseif bDebug then
					Debug.console(
						'Skipping aura for ' .. DB.getValue(nodeCT, 'name', '') .. ' which targets ' .. DB.getValue(targetNodeCT, 'name', '')
					)
				end
			end
		end
	end

	return auraEffects
end

local function checkSilentNotification(auraType)
	local option = OptionsManager.getOption('AURASILENT'):lower()
	return option == 'all' or option == auraType:lower():gsub('[~%!]', '')
end

local function getAuraDetails(sEffect)
	if not sEffect:match(fromAuraString) then return sEffect:match('AURA:%s*([%d%.]*)%s*([~%!]*%a*);') end
end

-- luacheck: globals notifyExpireSilent
function notifyExpireSilent(nodeEffect)
	local varEffect
	if type(nodeEffect) == 'databasenode' then
		varEffect = nodeEffect.getPath()
	elseif type(nodeEffect) ~= 'string' then
		return false
	end

	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_AURAEXPIRESILENT
	msgOOB.sEffectNode = varEffect

	Comm.deliverOOBMessage(msgOOB, '')
end

local function removeAuraEffect(nodeEffect, auraType)
	if not nodeEffect or type(nodeEffect) ~= 'databasenode' then return end

	-- don't remove effects if they're set to off
	if DB.getValue(nodeEffect, 'isactive', 1) == 0 then return end

	if checkSilentNotification(auraType) then
		notifyExpireSilent(nodeEffect)
	else
		EffectManager.notifyExpire(nodeEffect, nil, false)
	end
end

local function checkDeletedAuraEffects(nodeAuraSource, sEffect)
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		for _, targetEffect in ipairs(getAurasForNode(nodeCT, fromAuraString, nodeAuraSource)) do
			local sourceNode = DB.findNode(DB.getValue(targetEffect, 'source_name', ''))
			if not sourceNode then return end
			local auraStillExists = false
			for _, sourceEffect in ipairs(getAurasForNode(sourceNode.getChild('...'), auraString)) do
				local sEffectTrim = sEffect:gsub(fromAuraString, '')
				if getEffectString(sourceEffect):find(sEffectTrim:gsub('IFT*:%s*FACTION%(%s*notself%s*%)%s*;*', ''), 0, true) then
					auraStillExists = true
					break
				end
			end
			if auraStillExists == false then removeAuraEffect(targetEffect, 'all') end
		end
	end
end

---	This function is called when effects are removed or effect components are changed.
local function onEffectChanged(nodeEffect)
	local sEffect = getEffectString(nodeEffect)
	if sEffect == '' or sEffect:match(fromAuraString) then return end -- if changed effect is empty or a FROMAURA effect

	local nodeAuraSource = nodeEffect.getChild('...')
	if DB.getValue(nodeEffect, 'isactive', 0) ~= 1 then
		checkDeletedAuraEffects(nodeAuraSource, sEffect)
	else
		updateAuras(nodeAuraSource)
	end
end

---	This function is called when effect components are changed.
local function onStatusChanged(nodeStatus) updateAuras(nodeStatus.getChild('..')) end

-- luacheck: globals notifyTokenMove
---	This function requests aura processing to be performed on the host FG instance.
function notifyTokenMove(tokenMap)
	if not tokenMap.getContainerNode or not CombatManager then return end
	local nodeCT = CombatManager.getCTFromToken(tokenMap)
	if not nodeCT then return end

	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_AURATOKENMOVE
	msgOOB.sCTNode = nodeCT.getPath()

	Comm.deliverOOBMessage(msgOOB, '')
end

local function getRelationship(sourceNode, targetNode)
	if ActorManager.getFaction(sourceNode) == ActorManager.getFaction(targetNode) then
		return 'ally'
	elseif ActorManager.getFaction(sourceNode) == 'friend' and ActorManager.getFaction(targetNode) == 'foe' then
		return 'enemy'
	elseif ActorManager.getFaction(sourceNode) == 'foe' and ActorManager.getFaction(targetNode) == 'friend' then
		return 'enemy'
	else
		return ''
	end
end

local function checkFaction(rActor, rSource, sFactionFilter)
	if not rActor or not sFactionFilter then return false end
	local bNegate = sFactionFilter:match('[~%!]') ~= nil
	sFactionFilter = sFactionFilter:gsub('[~%!]', '')

	local nodeSource = ActorManager.getCTNode(rActor)
	local nodeTarget = ActorManager.getCTNode(rSource)

	-- if not nodeTarget then Debug.console(Interface.getString('aura_console_nosource')) end

	local bReturn = false
	if sFactionFilter == 'notself' or (sFactionFilter == 'self' and bNegate) then
		bReturn = nodeTarget == nodeSource
	elseif sFactionFilter == 'all' then
		bReturn = true
	end

	bReturn = bReturn or StringManager.contains({ ActorManager.getFaction(rActor), getRelationship(nodeTarget, nodeSource) }, sFactionFilter)
	if bNegate then bReturn = not bReturn end

	return bReturn
end

local TokenMoveArray = {}
local function tokenMovedEnough(token)
	-- cleanup after every 20 tokens received - we are not looking for perfect just trimming down processing time
	if #TokenMoveArray >= 20 then TokenMoveArray = {} end
	local imageControl = ImageManager.getImageControl(token, false)
	if not imageControl then return false end

	local x, y = token.getPosition()
	for i = 1, #TokenMoveArray, 1 do
		if token == TokenMoveArray[i].token and imageControl == TokenMoveArray[i].imageControl then
			-- Determine if moved more than 1/2 the grid unit
			local nGridSize = imageControl.getGridSize() * 0.5
			if (x - TokenMoveArray[i].x) ^ 2 + (y - TokenMoveArray[i].y) ^ 2 < nGridSize * nGridSize then return false end
			table.remove(TokenMoveArray, i)
			break
		end
	end
	table.insert(TokenMoveArray, { token = token, imageControl = imageControl, x = x, y = y })
	return true
end

local function auraOnMove(tokenMap)
	if not Session.IsHost or not ActorManager.resolveActor(CombatManager.getCTFromToken(tokenMap)) then return end
	if tokenMovedEnough(tokenMap) then notifyTokenMove(tokenMap) end
end

-- luacheck: globals notifyApplySilent
function notifyApplySilent(rEffect, node2)
	-- Build OOB message to pass effect to host
	local msgOOB = {}
	msgOOB.type = OOB_MSGTYPE_AURAAPPLYSILENT
	for k, _ in pairs(rEffect) do
		if aEffectVarMap[k] then
			if aEffectVarMap[k].sDBType == 'number' then
				msgOOB[k] = rEffect[k] or aEffectVarMap[k].vDBDefault or 0
			else
				msgOOB[k] = rEffect[k] or aEffectVarMap[k].vDBDefault or ''
			end
		end
	end
	if Session.IsHost then
		msgOOB.user = ''
	else
		msgOOB.user = User.getUsername()
	end
	msgOOB.identity = User.getIdentityLabel()

	-- Send one message for each target
	if type(node2.getPath()) == 'table' then
		for _, v in pairs(node2.getPath()) do
			msgOOB.sTargetNode = v
			Comm.deliverOOBMessage(msgOOB, '')
		end
	else
		msgOOB.sTargetNode = node2.getPath()
		Comm.deliverOOBMessage(msgOOB, '')
	end
end

local function addAuraEffect(auraEffect, sourceNode, targetNode, auraType)
	local sLabel = getEffectString(auraEffect)
	local applyLabel = sLabel:match(auraString .. '.-;%s*(.*)$')
	if not applyLabel then
		Debug.console(Interface.getString('aura_console_notext'), sLabel, auraString)
		return false
	end
	applyLabel = fromAuraString .. applyLabel:gsub('IFT*:%s*FACTION%(%s*notself%s*%)%s*;*', '')

	local rEffect = {}
	rEffect.nDuration = 0
	rEffect.nGMOnly = DB.getValue(auraEffect, 'isgmonly', 0)
	rEffect.nInit = DB.getValue(auraEffect, 'init', 0)
	rEffect.sLabel = applyLabel
	rEffect.sName = applyLabel
	rEffect.sSource = sourceNode.getPath()
	rEffect.sUnits = DB.getValue(auraEffect, 'unit', '')
	--rEffect.sAuraSource = auraEffect.getPath()

	if bDebug then
		Debug.console('Apply FROMAURA effect on ' .. DB.getValue(targetNode, 'name', '') .. ' due to AURA on ' .. DB.getValue(sourceNode, 'name', ''))
	end

	-- CHECK IF SILENT IS ON
	if checkSilentNotification(auraType) then
		notifyApplySilent(rEffect, targetNode)
	else
		EffectManager.notifyApply(rEffect, targetNode.getPath())
	end

	for _, nodeTargetEffect in pairs(DB.getChildren(targetNode, 'effects')) do
		if sourceNode.getPath() == DB.getValue(nodeTargetEffect, 'source_name', '') and not DB.getValue(nodeTargetEffect, 'source_aura') then
			DB.setValue(nodeTargetEffect, 'source_aura', 'string', auraEffect.getPath())
		end
	end
end

local function checkAuraAlreadyEffecting(auraPath, sourcePath, nodeTarget)
	for _, nodeTargetEffect in pairs(DB.getChildren(nodeTarget, 'effects')) do
		if sourcePath == DB.getValue(nodeTargetEffect, 'source_name', '') and auraPath == DB.getValue(nodeTargetEffect, 'source_aura', '') then
			if bDebug then Debug.console('Effect already on ' .. DB.getValue(nodeTarget, 'name', '')) end
			return nodeTargetEffect
		end
	end
end

local function checkAuraApplicationAndAddOrRemove(nodeSource, nodeTarget, auraEffect, nodeInfo)
	if not auraEffect then return false end

	local sLabelNodeEffect = getEffectString(auraEffect)
	if sLabelNodeEffect:match(fromAuraString) then return false end

	local nRange, auraType = getAuraDetails(sLabelNodeEffect)
	if nRange then
		nRange = tonumber(nRange)
	else
		Debug.console(Interface.getString('aura_console_norange'))
		return false
	end
	if not auraType or auraType == '' then
		if bDebug then Debug.console(Interface.getString('aura_console_nofaction')) end
		auraType = 'all'
	end

	if not nodeInfo.distanceBetween then
		local sourceToken = CombatManager.getTokenFromCT(nodeSource)
		local targetToken = CombatManager.getTokenFromCT(nodeTarget)
		if sourceToken and targetToken then nodeInfo.distanceBetween = Token.getDistanceBetween(sourceToken, targetToken) end
	end

	local existingAuraEffect = checkAuraAlreadyEffecting(auraEffect.getPath(), nodeSource.getPath(), nodeTarget)
	if
		(nodeInfo.distanceBetween and (nodeInfo.distanceBetween <= nRange))
		and checkFaction(ActorManager.resolveActor(nodeTarget), ActorManager.resolveActor(nodeSource), auraType)
	then
		if not existingAuraEffect then addAuraEffect(auraEffect, nodeSource, nodeTarget, auraType) end
	elseif existingAuraEffect then
		if bDebug then
			Debug.console(
				'Remove FROMAURA effect on ' .. DB.getValue(nodeTarget, 'name', '') .. ' due to AURA on ' .. DB.getValue(nodeSource, 'name', '')
			)
		end
		removeAuraEffect(existingAuraEffect, auraType)
	end
end

function updateAuras(sourceNode)
	if not sourceNode then return end
	local tokenSource = CombatManager.getTokenFromCT(sourceNode)
	if not tokenSource then
		if bDebug then Debug.console('No tokenSource for ' .. DB.getValue(sourceNode, 'name', '')) end
		return
	end
	local imageCtrSource = ImageManager.getImageControl(tokenSource, false)
	if not imageCtrSource then
		if bDebug then Debug.console('No imageCtrSource for ' .. DB.getValue(sourceNode, 'name', '')) end
		return
	end
	for _, otherNode in pairs(CombatManager.getCombatantNodes()) do
		if sourceNode ~= otherNode then
			local bSameImage = true
			if bDebug then Debug.console('Comparing ' .. DB.getValue(sourceNode, 'name', '') .. ' and ' .. DB.getValue(otherNode, 'name', '')) end
			local tokenOther = CombatManager.getTokenFromCT(otherNode)
			if tokenOther then
				local imageCtrOther = ImageManager.getImageControl(tokenOther, false)
				if not imageCtrOther or imageCtrSource ~= imageCtrOther then
					if bDebug then Debug.console('No imageCtrOther for ' .. DB.getValue(otherNode, 'name', '')) end
					bSameImage = false
				end
			else
				if bDebug then Debug.console('No tokenOther for ' .. DB.getValue(otherNode, 'name', '')) end
				bSameImage = false
			end

			if bSameImage then
				local nodeInfo = {}
				-- Check if the moved token has auras to apply/remove
				for _, auraEffect in pairs(getAurasForNode(sourceNode, auraString, otherNode)) do
					checkAuraApplicationAndAddOrRemove(sourceNode, otherNode, auraEffect, nodeInfo)
				end
				-- Check if the moved token is subject to other's auras
				for _, auraEffect in pairs(getAurasForNode(otherNode, auraString, sourceNode)) do
					checkAuraApplicationAndAddOrRemove(otherNode, sourceNode, auraEffect, nodeInfo)
				end
			end
		end
	end
end

---	This function creates and removes handlers on the effects list
local function manageHandlers(bRemove)
	if bRemove then
		DB.removeHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*'), 'onChildUpdate', onEffectChanged)
		DB.removeHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects'), 'onChildDeleted', onEffectChanged)
		DB.removeHandler(DB.getPath(CombatManager.CT_LIST .. '.*.status'), 'onUpdate', onStatusChanged)
		DB.removeHandler(DB.getPath(CombatManager.CT_LIST .. '.*.friendfoe'), 'onUpdate', onStatusChanged)
	else
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*'), 'onChildUpdate', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects'), 'onChildDeleted', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.status'), 'onUpdate', onStatusChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.friendfoe'), 'onUpdate', onStatusChanged)
	end
end

local checkConditional
local function customCheckConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)
	local bReturn = checkConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)

	-- skip faction check if conditions already aren't passing
	if bReturn == false then return bReturn end

	if aConditions and aConditions.remainder then aConditions = aConditions.remainder end
	for _, v in ipairs(aConditions) do
		local sFactionCheck = v:lower():match('^faction%s*%(([^)]+)%)$')
		if sFactionCheck then
			local sEffect = DB.getValue(nodeEffect, 'label', '')
			-- remove IF:FACTION(notself) from FROMAURA effects (this should only be needed temporarily to upgrade existing users)
			if sEffect:match(fromAuraString) and sEffect:match('IFT*:%s*FACTION%(%s*notself%s*%)%s*;*') then
				local sEffectTrim = sEffect:gsub('IFT*:%s*FACTION%(%s*notself%s*%)%s*;*', '')
				manageHandlers(true)
				DB.setValue(nodeEffect, 'label', 'string', sEffectTrim)
				manageHandlers(false)
			end

			local rSource = ActorManager.resolveActor(DB.findNode(DB.getValue(nodeEffect, 'source_name', '')))
			if not checkFaction(rActor, rSource, sFactionCheck) then
				bReturn = false
				break
			end
		end
	end

	return bReturn
end

local onWindowOpened
local function auraOnWindowOpened(window, ...)
	if onWindowOpened then onWindowOpened(window, ...) end
	if window.getClass() == 'imagewindow' then
		for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
			local tokenMap = CombatManager.getTokenFromCT(nodeCT)
			local _, winImage = ImageManager.getImageControl(tokenMap)
			if tokenMap and winImage == window then notifyTokenMove(tokenMap) end
		end
	end
end

local handleStandardCombatAddPlacement
local function auraHandleStandardCombatAddPlacement(tCustom, ...)
	if handleStandardCombatAddPlacement then handleStandardCombatAddPlacement(tCustom, ...) end
	updateAuras(tCustom.nodeCT)
end

function handleTokenMovement(msgOOB) updateAuras(DB.findNode(msgOOB.sCTNode)) end

function handleApplyEffectSilent(msgOOB)
	-- Get the target combat tracker node
	local nodeCTEntry = DB.findNode(msgOOB.sTargetNode)
	if not nodeCTEntry then
		ChatManager.SystemMessage(Interface.getString('ct_error_effectapplyfail') .. ' (' .. msgOOB.sTargetNode .. ')')
		return false
	end

	-- Reconstitute the effect details
	local rEffect = {}
	for k, _ in pairs(msgOOB) do
		if aEffectVarMap[k] then
			if aEffectVarMap[k].sDBType == 'number' then
				rEffect[k] = tonumber(msgOOB[k]) or 0
			else
				rEffect[k] = msgOOB[k]
			end
		end
	end

	-- Apply the effect
	EffectManager.addEffect(msgOOB.user, msgOOB.identity, nodeCTEntry, rEffect, false)
end

local function expireEffectSilent(nodeEffect)
	if not nodeEffect then return false end

	---	This function removes nodes without triggering recursion
	local function removeNode()
		manageHandlers(true)
		nodeEffect.delete()
		manageHandlers(false)
	end

	-- Process full expiration
	removeNode()
end

function handleExpireEffectSilent(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode)
	if not nodeEffect then
		Debug.console(Interface.getString('aura_console_expire_nonode'))
		-- ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sEffectNode .. ")");
		return
	end
	local nodeActor = nodeEffect.getChild('...')
	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString('ct_error_effectmissingactor') .. ' (' .. msgOOB.sEffectNode .. ')')
		return
	end

	expireEffectSilent(nodeEffect)
end

local handleExpireEffect_old
local function PFRPG2handleExpireEffect(msgOOB, ...)
	if DB.findNode(msgOOB.sEffectNode) then handleExpireEffect_old(msgOOB, ...) end
end

function onInit()
	-- register option for silent aura messages
	OptionsManager.registerOption2('AURASILENT', false, 'option_header_aura', 'option_label_AURASILENT', 'option_entry_cycler', {
		labels = 'option_val_aura_ally|option_val_aura_enemy|ct_tooltip_factionempty|'
			.. 'ct_tooltip_factionfriend|ct_tooltip_factionneutral|ct_tooltip_factionfoe|option_val_aura_all',
		values = 'ally|enemy|faction|friend|neutral|foe|all',
		baselabel = 'option_val_off',
		baseval = 'off',
		default = 'off',
	})

	-- register OOB message handlers to allow player movement
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURATOKENMOVE, handleTokenMovement)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURAAPPLYSILENT, handleApplyEffectSilent)
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURAEXPIRESILENT, handleExpireEffectSilent)

	-- set up the effect manager proxy functions for the detected ruleset
	if EffectManager35E then
		DetectedEffectManager = EffectManager35E
	elseif EffectManagerPFRPG2 then
		DetectedEffectManager = EffectManagerPFRPG2
		handleExpireEffect_old = EffectManager.handleExpireEffect
		OOBManager.registerOOBMsgHandler('expireeff', PFRPG2handleExpireEffect)
		EffectManager.handleExpireEffect = PFRPG2handleExpireEffect
	elseif EffectManagerSFRPG then
		DetectedEffectManager = EffectManagerSFRPG
	elseif EffectManager5E then
		DetectedEffectManager = EffectManager5E
	elseif EffectManager4E then
		DetectedEffectManager = EffectManager4E

	-- create proxy function to recalculate auras when new windows are opened
	handleStandardCombatAddPlacement = CombatRecordManager.handleStandardCombatAddPlacement
	CombatRecordManager.handleStandardCombatAddPlacement = auraHandleStandardCombatAddPlacement

	-- create proxy function to add FACTION conditional
	checkConditional = DetectedEffectManager.checkConditional
	DetectedEffectManager.checkConditional = customCheckConditional

	-- create proxy function to recalculate auras when new windows are opened
	onWindowOpened = Interface.onWindowOpened
	Interface.onWindowOpened = auraOnWindowOpened

	-- create the proxy function to trigger aura calculation on token movement.
	Token.addEventHandler('onMove', auraOnMove)

	-- all handlers should be created on GM machine
	if Session.IsHost then manageHandlers(false) end
end
