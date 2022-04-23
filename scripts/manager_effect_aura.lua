--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove';
OOB_MSGTYPE_AURAAPPLYSILENT = 'applyeffsilent';
OOB_MSGTYPE_AURAEXPIRESILENT = 'expireeffsilent';

local fromAuraString = 'FROMAURA;'
local auraString = 'AURA:'

local aEffectVarMap = {
	['nActive'] = { sDBType = 'number', sDBField = 'isactive' },
	['nDuration'] = { sDBType = 'number', sDBField = 'duration', vDBDefault = 1, sDisplay = '[D: %d]' },
	['nGMOnly'] = { sDBType = 'number', sDBField = 'isgmonly' },
	['nInit'] = { sDBType = 'number', sDBField = 'init', sSourceChangeSet = 'initresult', bClearOnUntargetedDrop = true },
	['sName'] = { sDBType = 'string', sDBField = 'label' },
	['sSource'] = { sDBType = 'string', sDBField = 'source_name', bClearOnUntargetedDrop = true },
	['sTarget'] = { sDBType = 'string', bClearOnUntargetedDrop = true },
	['sUnit'] = { sDBType = 'string', sDBField = 'unit' },
};

---	This function checks whether an effect should trigger recalculation.
--	It does this by checking the effect text for a series of three letters followed by a colon (as used in bonuses like CON: 4).
local function checkEffectRecursion(nodeEffect, sEffectComp)
	return string.find(DB.getValue(nodeEffect, aEffectVarMap['sName']['sDBField'], ''), sEffectComp) ~= nil;
end

local function isSourceDisabled(nodeChar)
	local rActor = ActorManager.resolveActor(nodeChar);
	if ActorHealthManager.isDyingOrDead(rActor) then
		return
	elseif ActorHealthManager.getHealthStatus(rActor) == ActorHealthManager.STATUS_UNCONSCIOUS then
		return
	end
end

---	This function is called when effects are removed or effect components are changed.
local function onEffectChanged(nodeEffect)
	if checkEffectRecursion(nodeEffect, auraString) and not checkEffectRecursion(nodeEffect, fromAuraString) then
		local nodeCT = nodeEffect.getChild('...');
		if nodeCT then
			if DB.getValue(nodeEffect, aEffectVarMap['nActive']['sDBField'], 0) ~= 1 then
				checkDeletedAuraEffects(nodeEffect);
			else
				updateAuras(nodeCT);
			end
		end
	end
end

---	This function is called when effect components are changed.
local function onStatusChanged(nodeStatus) updateAuras(nodeStatus.getChild('..')); end

---	This function requests aura processing to be performed on the host FG instance.
local function notifyTokenMove(tokenMap)
	if not tokenMap.getContainerNode or not CombatManager then return; end
	local nodeCT = CombatManager.getCTFromToken(tokenMap)
	if not nodeCT then return; end

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_AURATOKENMOVE;
	msgOOB.sCTNode = nodeCT.getNodeName()

	Comm.deliverOOBMessage(msgOOB, '');
end

local function getAurasEffectingNode(nodeCT)
	local auraEffects = {};
	for _, nodeEffect in pairs(DB.getChildren(nodeCT, 'effects')) do
		if DB.getValue(nodeEffect, aEffectVarMap['nActive']['sDBField'], 0) == 1 then
			local sLabelNodeEffect = DB.getValue(nodeEffect, aEffectVarMap['sName']['sDBField'], '');
			if string.find(sLabelNodeEffect, fromAuraString, 0, true) then table.insert(auraEffects, nodeEffect); end
		end
	end
	return auraEffects;
end

local function checkSilentNotification(auraType)
	local option = OptionsManager.getOption('AURASILENT'):lower();
	auraType = auraType:lower():gsub('enemy', 'foe');
	return option == 'all' or option == auraType;
end

local function removeAuraEffect(auraType, nodeEffect)
	if DB.getValue(nodeEffect, aEffectVarMap['nActive']['sDBField'], 1) ~= 0 then
		if checkSilentNotification(auraType) == true then

			function notifyExpireSilent()
				if type(nodeEffect) == 'databasenode' then
					varEffect = nodeEffect.getNodeName();
				elseif type(nodeEffect) ~= 'string' then
					return false;
				end

				local msgOOB = {};
				msgOOB.type = OOB_MSGTYPE_AURAEXPIRESILENT;
				msgOOB.sEffectNode = varEffect;

				Comm.deliverOOBMessage(msgOOB, '');
			end

			notifyExpireSilent();
		else
			EffectManager.notifyExpire(nodeEffect, nil, false);
		end
	end
end

local function checkAurasEffectingNodeForDelete(nodeCT)
	local aurasEffectingNode = getAurasEffectingNode(nodeCT);
	for _, targetEffect in ipairs(aurasEffectingNode) do
		local targetEffectLabel = DB.getValue(targetEffect, aEffectVarMap['sName']['sDBField'], '');
		local targetEffectLabel = targetEffectLabel:gsub(fromAuraString, '');
		if not string.find(targetEffectLabel, fromAuraString) then
			local sSource = DB.getValue(targetEffect, aEffectVarMap['sSource']['sDBField'], '');
			local sourceNode = DB.findNode(sSource);
			if sourceNode then
				local sourceAuras = getAurasForNode(sourceNode);
				local auraStillExists = false;
				for _, sourceEffect in ipairs(sourceAuras) do
					local sourceEffectLabel = DB.getValue(sourceEffect, aEffectVarMap['sName']['sDBField'], '');
					if string.find(sourceEffectLabel, targetEffectLabel, 0, true) then
						auraStillExists = true;
						break
					end
				end
				if not auraStillExists then removeAuraEffect('all', targetEffect); end
			end
		end
	end
end

-- luacheck: globals checkDeletedAuraEffects
function checkDeletedAuraEffects(nodeFromDelete)
	local ctEntries = CombatManager.getSortedCombatantList();
	for _, nodeCT in pairs(ctEntries) do if nodeCT ~= nodeFromDelete then checkAurasEffectingNodeForDelete(nodeCT); end end
end

function checkAuraAlreadyEffecting(nodeSource, nodeTarget, effect)
	local sLabel = DB.getValue(effect, aEffectVarMap['sName']['sDBField'], '');
	for _, nodeEffect in pairs(DB.getChildren(nodeTarget, 'effects')) do
		-- if DB.getValue(nodeEffect, aEffectVarMap["nActive"]["sDBField"], 0) ~= 2 then
		local sSource = DB.getValue(nodeEffect, aEffectVarMap['sSource']['sDBField']);
		if sSource == nodeSource.getPath() then
			local sEffect = DB.getValue(nodeEffect, aEffectVarMap['sName']['sDBField'], '');
			sEffect = sEffect:gsub(fromAuraString, '');
			if string.find(sLabel, sEffect, 0, true) then return nodeEffect; end
		end
		-- end
	end
end

local function checkFaction(targetActor, nodeEffect, sFactionCheck)
	if not targetActor or not sFactionCheck then return false; end

	local targetFaction = ActorManager.getFaction(targetActor);

	local sourceActor, sourceFaction
	local sEffectSource = DB.getValue(nodeEffect, aEffectVarMap['sSource']['sDBField'], '');
	if sFactionCheck:match('notself') then
		return not (sEffectSource == '');
	elseif sEffectSource ~= '' then
		sourceActor = ActorManager.resolveActor(DB.findNode(sEffectSource));
		sourceFaction = ActorManager.getFaction(sourceActor);
	else
		sourceFaction = targetFaction;
	end

	local bReturn;
	if sFactionCheck:match('friend') then
		bReturn = sourceFaction == targetFaction;
	elseif sFactionCheck:match('foe') then
		if sourceFaction == 'friend' then
			bReturn = targetFaction == 'foe';
		elseif sourceFaction == 'foe' then
			bReturn = targetFaction == 'friend';
		end
	elseif sFactionCheck:match('neutral') then
		bReturn = targetFaction == 'neutral';
	elseif sFactionCheck:match('faction') then
		bReturn = targetFaction == 'faction';
	end

	if sFactionCheck:match('^!') then bReturn = not bReturn; end

	return bReturn;
end

local CheckConditional = nil;
function customCheckConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)
	local bReturn
	if EffectManager4E then
		local rEffectComp = aConditions
		aConditions = aConditions.remainder
		bReturn = checkConditional(rActor, nodeEffect, rEffectComp, rTarget, aIgnore);
	else
		bReturn = checkConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore);
	end
	for _, v in ipairs(aConditions) do
		local sLower = v:lower();
		local sFactionCheck = sLower:match('^faction%s*%(([^)]+)%)$');
		if sFactionCheck then
			if not checkFaction(rActor, nodeEffect, sFactionCheck) then
				bReturn = false
				break
			end
		end
	end
	return bReturn;
end

local onMove = nil;
local function auraOnMove(tokenMap)
	if onMove then onMove(tokenMap); end
	if Session.IsHost then
		-- Debug.chat("onMove aura update", tokenMap)
		notifyTokenMove(tokenMap)
	end
end

local updateAttributesFromToken = nil;
local function auraUpdateAttributesFromToken(tokenMap)
	if updateAttributesFromToken then updateAttributesFromToken(tokenMap); end
	onMove = tokenMap.onMove;
	tokenMap.onMove = auraOnMove;
end

local function getRelationship(sourceNode, targetNode)
	if DB.getValue(sourceNode, 'friendfoe', '') == DB.getValue(targetNode, 'friendfoe', '') then
		return 'friend'
	else
		return 'foe'
	end
end

-- luacheck: globals updateAuras
function updateAuras(sourceNode)
	if not sourceNode then return false end

	local ctEntries = CombatManager.getSortedCombatantList();
	for _, otherNode in pairs(ctEntries) do
		if otherNode ~= sourceNode then
			local nodeInfo = {}
			-- Check if the moved token has auras to apply/remove
			for _, auraEffect in pairs(getAurasForNode(sourceNode)) do
				checkAuraApplicationAndAddOrRemove(sourceNode, otherNode, auraEffect, nodeInfo)
			end
			-- Check if the moved token is subject to other's auras
			for _, auraEffect in pairs(getAurasForNode(otherNode)) do
				checkAuraApplicationAndAddOrRemove(otherNode, sourceNode, auraEffect, nodeInfo)
			end
		end
	end
end

function getAurasForNode(nodeCT)
	if not nodeCT then return false; end
	local auraEffects = {};
	local nodeEffects = DB.getChildren(nodeCT, 'effects');
	for _, nodeEffect in pairs(nodeEffects) do
		if DB.getValue(nodeEffect, aEffectVarMap['nActive']['sDBField'], 0) == 1 then
			local sLabelNodeEffect = DB.getValue(nodeEffect, aEffectVarMap['sName']['sDBField'], '');
			if string.match(sLabelNodeEffect, '%s*' .. auraString) then table.insert(auraEffects, nodeEffect); end
		end
	end
	return auraEffects;
end

function notifyApplySilent(rEffect, vTargets)
	-- Build OOB message to pass effect to host
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_AURAAPPLYSILENT;
	for k, v in pairs(rEffect) do
		if aEffectVarMap[k] then
			if aEffectVarMap[k].sDBType == 'number' then
				msgOOB[k] = rEffect[k] or aEffectVarMap[k].vDBDefault or 0;
			else
				msgOOB[k] = rEffect[k] or aEffectVarMap[k].vDBDefault or '';
			end
		end
	end
	if Session.IsHost then
		msgOOB.user = '';
	else
		msgOOB.user = User.getUsername();
	end
	msgOOB.identity = User.getIdentityLabel();

	-- Send one message for each target
	if type(vTargets) == 'table' then
		for _, v in pairs(vTargets) do
			msgOOB.sTargetNode = v;
			Comm.deliverOOBMessage(msgOOB, '');
		end
	else
		msgOOB.sTargetNode = vTargets;
		Comm.deliverOOBMessage(msgOOB, '');
	end
end

local function addAuraEffect(auraType, effect, targetNode, sourceNode)
	local sLabel = DB.getValue(effect, aEffectVarMap['sName']['sDBField'], '');
	local applyLabel = string.match(sLabel, auraString .. '.-;%s*(.*)$');
	if not applyLabel then
		Debug.console(Interface.getString('aura_console_notext'), sLabel, auraString);
		return false;
	end
	applyLabel = fromAuraString .. applyLabel;

	local rEffect = {};
	rEffect.nDuration = 0;
	rEffect.nGMOnly = DB.getValue(effect, aEffectVarMap['nGMOnly']['sDBField'], 0);
	rEffect.nInit = DB.getValue(effect, aEffectVarMap['nInit']['sDBField'], 0);
	rEffect.sLabel = applyLabel;
	rEffect.sName = applyLabel;
	rEffect.sSource = sourceNode.getPath();
	rEffect.sUnits = DB.getValue(effect, aEffectVarMap['sUnit']['sDBField'], '');

	-- CHECK IF SILENT IS ON
	if checkSilentNotification(auraType) == true then
		notifyApplySilent(rEffect, targetNode.getPath());
	else
		EffectManager.notifyApply(rEffect, targetNode.getPath());
	end
end

-- Get the closest position of token 1 (center of the square contained by token 1 which is closest
-- along a straight line to the center of token 2)
local function getClosestPosition(token1, token2)
	local ctToken1 = CombatManager.getCTFromToken(token1)
	local ctToken2 = CombatManager.getCTFromToken(token2)
	if not ctToken1 or not ctToken2 then return 0, 0, 0, 0 end

	local gridsize = ImageManager.getImageControl(token1).getGridSize() or 0;
	local units = GameSystem.getDistanceUnitsPerGrid();

	local centerPos1x, centerPos1y = token1.getPosition();
	local centerPos2x, centerPos2y = token2.getPosition();
	local dx = centerPos2x - centerPos1x;
	local dy = centerPos2y - centerPos1y;
	local slope = 0
	if dx ~= 0 then slope = (dy) / (dx); end

	local nSpace = DB.getValue(ctToken1, 'space');
	local nHalfSpace = nSpace / 2;
	local nSquares = nSpace / units;
	local center = (nSquares + 1) / 2;
	local minPosX, minPosY;

	local intercept = 0;
	local delta = 0;
	local right = centerPos1x + nHalfSpace;
	local left = centerPos1x - nHalfSpace;
	local top = centerPos1y - nHalfSpace;
	local bottom = centerPos1y + nHalfSpace;

	if math.abs(dx) > math.abs(dy) then
		if dx < 0 then
			-- Look at the left edge
			intercept = centerPos1y - slope * nHalfSpace;
			delta = math.max(1, math.ceil((intercept - top) / units));
			shiftedDelta = delta - center;
			minPosX = centerPos1x + ((center - nSquares) * gridsize);
			minPosY = centerPos1y + (shiftedDelta * gridsize);
		else
			-- Look at the right edge
			intercept = centerPos1y + slope * nHalfSpace;
			delta = math.max(1, math.ceil((intercept - top) / units));
			shiftedDelta = delta - center;
			minPosX = centerPos1x + ((nSquares - center) * gridsize);
			minPosY = centerPos1y + (shiftedDelta * gridsize);
		end
	else
		if dy < 0 then
			-- Look at the top edge
			if slope == 0 then
				minPosX = centerPos1x;
			else
				intercept = centerPos1x - nHalfSpace / slope;
				delta = math.max(1, math.ceil((intercept - left) / units));
				shiftedDelta = delta - center;
				minPosX = centerPos1x + (shiftedDelta * gridsize);
			end
			minPosY = centerPos1y + ((center - nSquares) * gridsize);
		else
			-- Look at the bottom edge
			if slope == 0 then
				minPosX = centerPos1x;
			else
				intercept = centerPos1x + nHalfSpace / slope;
				delta = math.max(1, math.ceil((intercept - left) / units));
				shiftedDelta = delta - center;
				minPosX = centerPos1x + (shiftedDelta * gridsize);
			end
			minPosY = centerPos1y + ((nSquares - center) * gridsize);
		end
	end

	return minPosX, minPosY
end

function checkAuraApplicationAndAddOrRemove(sourceNode, targetNode, auraEffect, nodeInfo)
	if not targetNode or not auraEffect then return false end

	local sLabelNodeEffect = DB.getValue(auraEffect, aEffectVarMap['sName']['sDBField'], '')
	local nRange, auraType = string.match(sLabelNodeEffect, '(%d+) (%w+)')
	if nRange then
		nRange = math.floor(tonumber(nRange))
	else
		Debug.console(Interface.getString('aura_console_norange'));
		return false
	end
	if not auraType then
		auraType = 'all'
	elseif auraType == 'enemy' then
		auraType = 'foe'
	end

	if not nodeInfo.relationship then nodeInfo.relationship = getRelationship(sourceNode, targetNode) end
	if auraType == nodeInfo.relationship or auraType == 'all' then
		if not nodeInfo.distanceBetween then
			local sourceToken = CombatManager.getTokenFromCT(sourceNode)
			local targetToken = CombatManager.getTokenFromCT(targetNode)
			if sourceToken and targetToken then nodeInfo.distanceBetween = Token.getDistanceBetween(sourceToken, targetToken) end
		end
		local existingAuraEffect = checkAuraAlreadyEffecting(sourceNode, targetNode, auraEffect)
		if (nodeInfo.distanceBetween and nodeInfo.distanceBetween <= nRange) and not isSourceDisabled(sourceNode) then
			if not existingAuraEffect then addAuraEffect(auraType, auraEffect, targetNode, sourceNode) end
		elseif existingAuraEffect then
			removeAuraEffect(auraType, existingAuraEffect)
		end
	end
end

function handleTokenMovement(msgOOB) updateAuras(DB.findNode(msgOOB.sCTNode)); end

function handleApplyEffectSilent(msgOOB)
	-- Get the target combat tracker node
	local nodeCTEntry = DB.findNode(msgOOB.sTargetNode);
	if not nodeCTEntry then
		ChatManager.SystemMessage(Interface.getString('ct_error_effectapplyfail') .. ' (' .. msgOOB.sTargetNode .. ')');
		return false;
	end

	-- Reconstitute the effect details
	local rEffect = {};
	for k, v in pairs(msgOOB) do
		if aEffectVarMap[k] then
			if aEffectVarMap[k].sDBType == 'number' then
				rEffect[k] = tonumber(msgOOB[k]) or 0;
			else
				rEffect[k] = msgOOB[k];
			end
		end
	end

	-- Apply the effect
	EffectManager.addEffect(msgOOB.user, msgOOB.identity, nodeCTEntry, rEffect, false);
end

---	This function creates and removes handlers on the effects list
local function manageHandlers(bRemove)
	if bRemove then
		DB.removeHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*'), 'onChildUpdate', onEffectChanged)
		DB.removeHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects'), 'onChildDeleted', onEffectChanged)
		DB.removeHandler(DB.getPath(CombatManager.CT_LIST .. '.*.status'), 'onUpdate', onStatusChanged)
	else
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects.*'), 'onChildUpdate', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.effects'), 'onChildDeleted', onEffectChanged)
		DB.addHandler(DB.getPath(CombatManager.CT_LIST .. '.*.status'), 'onUpdate', onStatusChanged)
	end
end

---	This function removes nodes without triggering recursion
local function removeNode(nodeEffect)
	manageHandlers(true)
	nodeEffect.delete()
	manageHandlers(false)
end

function expireEffectSilent(nodeActor, nodeEffect, nExpireComp)
	if not nodeEffect then
		-- Debug.chat(nodeActor, nodeEffect, nExpireComp)
		return false;
	end

	-- local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);

	-- Check for partial expiration
	if (nExpireComp or 0) > 0 then
		local sEffect = DB.getValue(nodeEffect, aEffectVarMap['sName']['sDBField'], '');
		local aEffectComps = parseEffect(sEffect);
		if #aEffectComps > 1 then
			table.remove(aEffectComps, nExpireComp);
			local sRebuiltEffect = EffectManager.rebuildParsedEffect(aEffectComps)
			if sRebuiltEffect and sRebuiltEffect ~= '' then
				DB.setValue(nodeEffect, aEffectVarMap['sName']['sDBField'], 'string', sRebuiltEffect);
				return;
				-- else
				-- removeNode(nodeEffect)
			end
		end
	end

	-- Process full expiration
	removeNode(nodeEffect)
end

function handleExpireEffectSilent(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		Debug.console(Interface.getString('aura_console_expire_nonode'));
		-- ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sEffectNode .. ")");
		return;
	end
	local nodeActor = nodeEffect.getChild('...');
	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString('ct_error_effectmissingactor') .. ' (' .. msgOOB.sEffectNode .. ')');
		return;
	end

	expireEffectSilent(nodeActor, nodeEffect, tonumber(msgOOB.nExpireClause) or 0);
end

local handleExpireEffect_old
local function PFRPG2handleExpireEffect(msgOOB, ...) if DB.findNode(msgOOB.sEffectNode) then handleExpireEffect_old(msgOOB, ...) end end

function onInit()
	-- register option for silent aura messages
	OptionsManager.registerOption2(
					'AURASILENT', false, 'option_header_aura', 'option_label_AURASILENT', 'option_entry_cycler', {
						labels = 'option_val_friend|option_val_foe|option_val_all',
						values = 'friend|foe|all',
						baselabel = 'option_val_off',
						baseval = 'off',
						default = 'off',
					}
	);

	-- register OOB message handlers to allow player movement
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURATOKENMOVE, handleTokenMovement);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURAAPPLYSILENT, handleApplyEffectSilent);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURAEXPIRESILENT, handleExpireEffectSilent);

	-- set up the effect manager proxy functions for the detected ruleset
	local DetectedEffectManager = nil
	if EffectManager35E then
		DetectedEffectManager = EffectManager35E
	elseif EffectManagerPFRPG2 then
		DetectedEffectManager = EffectManagerPFRPG2
		handleExpireEffect_old = EffectManager.handleExpireEffect
		OOBManager.registerOOBMsgHandler('expireeff', PFRPG2handleExpireEffect);
		EffectManager.handleExpireEffect = PFRPG2handleExpireEffect
	elseif EffectManagerSFRPG then
		DetectedEffectManager = EffectManagerSFRPG
	elseif EffectManager5E then
		DetectedEffectManager = EffectManager5E
	elseif EffectManager4E then
		DetectedEffectManager = EffectManager4E
	end

	-- create proxy function to add FACTION conditional
	checkConditional = DetectedEffectManager.checkConditional;
	DetectedEffectManager.checkConditional = customCheckConditional;

	local onWindowOpened = nil;
	function auraOnWindowOpened(window)
		if onWindowOpened then onWindowOpened(window); end
		if window.getClass() == 'imagewindow' then
			local ctEntries = CombatManager.getSortedCombatantList();
			for _, nodeCT in pairs(ctEntries) do
				local tokenMap = CombatManager.getTokenFromCT(nodeCT);
				local _, winImage = ImageManager.getImageControl(tokenMap);
				if tokenMap and winImage and winImage == window then notifyTokenMove(tokenMap); end
			end
		end
	end

	-- create proxy function to recalculate auras when new windows are opened
	onWindowOpened = Interface.onWindowOpened;
	Interface.onWindowOpened = auraOnWindowOpened;

	-- create the proxy function to trigger aura calculation on token movement.
	onMove = Token.onMove
	Token.onMove = auraOnMove

	-- all handlers should be created on GM machine
	if Session.IsHost then manageHandlers(false) end
end
