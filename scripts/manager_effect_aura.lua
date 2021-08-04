--
-- Add functionality for SAVEO type effects similar to DMGO or REGEN
--
--

OOB_MSGTYPE_AURATOKENMOVE = "aurasontokenmove";
OOB_MSGTYPE_AURAAPPLYSILENT = "applyeffsilent";
OOB_MSGTYPE_AURAEXPIRESILENT = "expireeffsilent";

local fromAuraString = "FROMAURA;"
local auraString = "AURA:"

local aEffectVarMap = {
	["nActive"] = { sDBType = "number", sDBField = "isactive" },
	["nDuration"] = { sDBType = "number", sDBField = "duration", vDBDefault = 1, sDisplay = "[D: %d]" },
	["nGMOnly"] = { sDBType = "number", sDBField = "isgmonly" },
	["nInit"] = { sDBType = "number", sDBField = "init", sSourceChangeSet = "initresult", bClearOnUntargetedDrop = true },
	["sName"] = { sDBType = "string", sDBField = "label" },
	["sSource"] = { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true },
	["sTarget"] = { sDBType = "string", bClearOnUntargetedDrop = true },
	["sUnit"] = { sDBType = "string", sDBField = "unit" },
};

---	This function checks whether an effect should trigger recalculation.
--	It does this by checking the effect text for a series of three letters followed by a colon (as used in bonuses like CON: 4).
local function checkEffectRecursion(nodeEffect, sEffectComp)
	return string.find(DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], ""), sEffectComp) ~= nil
end

---	This function is called when effect components are changed.
local function onEffectChanged(nodeEffect)
	if checkEffectRecursion(nodeEffect, auraString) and not checkEffectRecursion(nodeEffect, fromAuraString) then
		local nodeCT = nodeEffect.getChild("...")
		local tokenCT = CombatManager.getTokenFromCT(nodeCT);
		if tokenCT then
			if DB.getValue(nodeEffect, aEffectVarMap["nActive"]["sDBField"], 0) ~= 1 then
				checkDeletedAuraEffects(nodeEffect)
			else
				updateAuras(tokenCT);
			end
		end
	end
end

---	This function requests aura processing to be performed on the host FG instance.
function notifyTokenMove(tokenMap)
	if not tokenMap.getContainerNode or not CombatManager then
		return;
	end
	local nodeCT = CombatManager.getCTFromToken(tokenMap)
	if not nodeCT then
		return;
	end

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_AURATOKENMOVE;
	msgOOB.sCTNode = nodeCT.getNodeName()

	Comm.deliverOOBMessage(msgOOB, "");
end

local onWindowOpened = nil;
function auraOnWindowOpened(window)
	if onWindowOpened then
		onWindowOpened(window);
	end
	if window.getClass() == "imagewindow" then
		local ctEntries = CombatManager.getSortedCombatantList();
		for _, nodeCT in pairs(ctEntries) do
			local tokenMap = CombatManager.getTokenFromCT(nodeCT);
			local ctrlImage, winImage = ImageManager.getImageControl(tokenMap);
			if tokenMap and winImage and winImage == window then
				notifyTokenMove(tokenMap);
			end
		end
	end
end

local function getAurasEffectingNode(nodeCT)
	local auraEffects = {};

	for _, nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		if DB.getValue(nodeEffect, aEffectVarMap["nActive"]["sDBField"], 0) == 1 then
			local sLabelNodeEffect = DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "");
			if string.find(sLabelNodeEffect, fromAuraString, 0, true) then
				table.insert(auraEffects, nodeEffect);
			end
		end
	end
	return auraEffects;
end

local function checkSilentNotification(auraType)
	local option = OptionsManager.getOption("AURASILENT"):lower();
	auraType = auraType:lower():gsub("enemy", "foe");
	return option == "all" or option == auraType;
end

function notifyExpireSilent(varEffect, nMatch)
	if type(varEffect) == "databasenode" then
		varEffect = varEffect.getNodeName();
	elseif type(varEffect) ~= "string" then
		return false;
	end

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_AURAEXPIRESILENT;
	msgOOB.sEffectNode = varEffect;
	msgOOB.nExpireClause = nMatch;

	Comm.deliverOOBMessage(msgOOB, "");
end

local function removeAuraEffect(auraType, nodeEffect)
	if DB.getValue(nodeEffect, aEffectVarMap["nActive"]["sDBField"], 1) ~= 0 then
		if checkSilentNotification(auraType) == true then
			notifyExpireSilent(nodeEffect, nil, false);
		else
			EffectManager.notifyExpire(nodeEffect, nil, false);
		end
	end
end

local function checkAurasEffectingNodeForDelete(nodeCT)
	local aurasEffectingNode = getAurasEffectingNode(nodeCT);
	for _, targetEffect in ipairs(aurasEffectingNode) do
		local targetEffectLabel = DB.getValue(targetEffect, aEffectVarMap["sName"]["sDBField"], ""):gsub(fromAuraString,"");
		if not string.find(targetEffectLabel, fromAuraString) then
			local sSource = DB.getValue(targetEffect, aEffectVarMap["sSource"]["sDBField"], "");
			local sourceNode = DB.findNode(sSource);
			if sourceNode then
				local sourceAuras = getAurasForNode(sourceNode);
				local auraStillExists = nil;
				for _, sourceEffect in ipairs(sourceAuras) do
					local sourceEffectLabel = DB.getValue(sourceEffect, aEffectVarMap["sName"]["sDBField"], "");
					if string.find(sourceEffectLabel, targetEffectLabel, 0, true) then
						auraStillExists = true;
					end
				end
				if not auraStillExists then
					removeAuraEffect("all", targetEffect);
				end
			end
		end
	end
end

function checkDeletedAuraEffects(nodeFromDelete)
	local ctEntries = CombatManager.getSortedCombatantList();
	for _, nodeCT in pairs(ctEntries) do
		if nodeCT ~= nodeFromDelete then
			checkAurasEffectingNodeForDelete(nodeCT);
		end
	end
end

function checkAuraAlreadyEffecting(nodeSource, nodeTarget, effect)
	local sLabel = DB.getValue(effect, aEffectVarMap["sName"]["sDBField"], "");
	for _, nodeEffect in pairs(DB.getChildren(nodeTarget, "effects")) do
		-- if DB.getValue(nodeEffect, aEffectVarMap["nActive"]["sDBField"], 0) ~= 2 then
		local sSource = DB.getValue(nodeEffect, aEffectVarMap["sSource"]["sDBField"]);
		if sSource == nodeSource.getPath() then
			local sEffect = DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], ""):gsub(fromAuraString,"");
			if string.find(sLabel, sEffect, 0, true) then
				return nodeEffect;
			end
		end
		-- end
	end
end

local function checkFaction(targetActor, nodeEffect, sFactionCheck)
	if not targetActor or not sFactionCheck then
		return false;
	end

	local targetFaction = ActorManager.getFaction(targetActor);

	local sourceActor, sourceFaction
	local sEffectSource = DB.getValue(nodeEffect, aEffectVarMap["sSource"]["sDBField"], "");
	if sFactionCheck:match("notself") then
		return not (sEffectSource == "");
	elseif sEffectSource ~= "" then
		sourceActor = ActorManager.resolveActor(DB.findNode(sEffectSource));
		sourceFaction = ActorManager.getFaction(sourceActor);
	else
		sourceFaction = targetFaction;
	end

	local bReturn;
	if sFactionCheck:match("friend") then
		bReturn = sourceFaction == targetFaction;
	elseif sFactionCheck:match("foe") then
		if sourceFaction == "friend" then
			bReturn = targetFaction == "foe";
		elseif sourceFaction == "foe" then
			bReturn = targetFaction == "friend";
		end
	elseif sFactionCheck:match("neutral") then
		bReturn = targetFaction == "neutral";
	elseif sFactionCheck:match("faction") then
		bReturn = targetFaction == "faction";
	end

	if sFactionCheck:match("^!") then
		bReturn = not bReturn;
	end

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
	for _,v in ipairs(aConditions) do
		local sLower = v:lower();
		local sFactionCheck = sLower:match("^faction%s*%(([^)]+)%)$");
		if sFactionCheck then
			if not checkFaction(rActor, nodeEffect, sFactionCheck) then
				bReturn = false
				break;
			end
		end
	end
	return bReturn;
end

local onMove = nil;
local function auraOnMove(tokenInstance)
	if onMove then
		onMove(tokenInstance);
	end
	if Session.IsHost then
		-- Debug.chat("onMove aura update")
		notifyTokenMove(tokenInstance)
	end
end

local onDragEnd = nil;
local function auraOnDragEnd(tokenInstance)
	if onDragEnd then
		onDragEnd(tokenInstance);
	end
	if Session.IsHost then
		-- Debug.chat("onDragEnd aura update")
		notifyTokenMove(tokenInstance)
	end
end

local function getRelationship(sourceNode, targetNode)
	if DB.getValue(sourceNode, "friendfoe", "") == DB.getValue(targetNode, "friendfoe", "") then
		return "friend"
	else
		return "foe"
	end
end

function updateAuras(tokenMap)
	if not tokenMap.getContainerNode or not CombatManager then
		return;
	end
	local sourceNode = CombatManager.getCTFromToken(tokenMap)
	if not sourceNode then
		return false
	end

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
	if not nodeCT then 
		return false; 
	end
	local auraEffects = {};
	local nodeEffects = DB.getChildren(nodeCT, "effects");
	for _, nodeEffect in pairs(nodeEffects) do
		if DB.getValue(nodeEffect, aEffectVarMap["nActive"]["sDBField"], 0) == 1 then
			local sLabelNodeEffect = DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "");
			if string.match(sLabelNodeEffect, "%s*" .. auraString) then
				table.insert(auraEffects, nodeEffect);
			end
		end
	end
	return auraEffects;
end

function notifyApplySilent(rEffect, vTargets)
	-- Build OOB message to pass effect to host
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_AURAAPPLYSILENT;
	for k,v in pairs(rEffect) do
		if aEffectVarMap[k] then
			if aEffectVarMap[k].sDBType == "number" then
				msgOOB[k] = rEffect[k] or aEffectVarMap[k].vDBDefault or 0;
			else
				msgOOB[k] = rEffect[k] or aEffectVarMap[k].vDBDefault or "";
			end
		end
	end
	if Session.IsHost then
		msgOOB.user = "";
	else
		msgOOB.user = User.getUsername();
	end
	msgOOB.identity = User.getIdentityLabel();

	-- Send one message for each target
	if type(vTargets) == "table" then
		for _, v in pairs(vTargets) do
			msgOOB.sTargetNode = v;
			Comm.deliverOOBMessage(msgOOB, "");
		end
	else
		msgOOB.sTargetNode = vTargets;
		Comm.deliverOOBMessage(msgOOB, "");
	end
end

local function addAuraEffect(auraType, effect, targetNode, sourceNode)
	local sLabel = DB.getValue(effect, aEffectVarMap["sName"]["sDBField"], "");
	local applyLabel = string.match(sLabel, auraString .. ".-;%s*(.*)$");
	if not applyLabel then
		return false;
	end
	applyLabel = fromAuraString .. applyLabel;
	
	local rEffect = {};
	rEffect.nDuration = DB.getValue(effect, aEffectVarMap["nDuration"]["sDBField"], 0);
	rEffect.nGMOnly = DB.getValue(effect, aEffectVarMap["nGMOnly"]["sDBField"], 0);
	rEffect.nInit = DB.getValue(effect, aEffectVarMap["nInit"]["sDBField"], 0);
	rEffect.sLabel = applyLabel;
	rEffect.sName = applyLabel;
	rEffect.sSource = sourceNode.getPath();
	rEffect.sUnits = DB.getValue(effect, aEffectVarMap["sUnit"]["sDBField"], "");
	
	-- CHECK IF SILENT IS ON
	if checkSilentNotification(auraType) == true then
		notifyApplySilent(rEffect, targetNode.getPath());
	else
		EffectManager.notifyApply(rEffect, targetNode.getPath());
	end
end

-- compute distance between targets
-- this is not as good as Unity's getDistanceBetween
local function checkDistance(targetToken, sourceToken)
	if not targetToken or not sourceToken then
		return false;
	end;
	local ctrlImage = ImageManager.getImageControl(targetToken);
	local srcCtrlImage = ImageManager.getImageControl(sourceToken);
	if ctrlImage and srcCtrlImage and (ctrlImage == srcCtrlImage) then
		local gridSize = ctrlImage.getGridSize() or 0;
		local gridOffsetX = 0;
		local gridOffsetY = 0;
		if ctrlImage.hasGrid() then	
			gridOffsetX, gridOffsetY = ctrlImage.getGridOffset();
		end
		local sourceX, sourceY = sourceToken.getPosition();
		local targetX, targetY = targetToken.getPosition();

		local targetGridX = (tonumber(targetX) + tonumber(gridOffsetX)) / gridSize;
		local targetGridY = (tonumber(targetY) + tonumber(gridOffsetY)) / gridSize;
		local sourceGridX = (tonumber(sourceX) + tonumber(gridOffsetX)) / gridSize;
		local sourceGridY = (tonumber(sourceY) + tonumber(gridOffsetY)) / gridSize;
		local xDiff = math.abs(targetGridX - sourceGridX);
		local yDiff = math.abs(targetGridY - sourceGridY);
		local totalDiff = math.floor(math.sqrt((xDiff*xDiff)+(yDiff*yDiff)));	
		local nNotchScale = 5
		if User.getRulesetName() == "4E" then
			nNotchScale = 1
		end
		
		return totalDiff * nNotchScale;
	end
end

-- check FG version. if unity, use Token.getDistanceBetween.
-- if classic, call checkDistance function above
local function anyGetDistanceBetween(sourceToken, targetToken)
	if UtilityManager.isClientFGU() then
		return Token.getDistanceBetween(sourceToken, targetToken)
	else
		return checkDistance(sourceToken, targetToken)
	end
end

function checkAuraApplicationAndAddOrRemove(sourceNode, targetNode, auraEffect, nodeInfo)
	if not targetNode or not auraEffect then
		return false
	end

	if not sourceNode then
		local sSource = DB.getValue(auraEffect, aEffectVarMap["sSource"]["sDBField"], "")
		sourceNode = DB.findNode(sSource)
		if not sourceNode then
			return false
		end
	end

	local sLabelNodeEffect = DB.getValue(auraEffect, aEffectVarMap["sName"]["sDBField"], "")
	local nRange, auraType = string.match(sLabelNodeEffect, "(%d+) (%w+)")
	if nRange then
		nRange = math.floor(tonumber(nRange))
	else
		return false
	end
	if not auraType then
		auraType = "all"
	elseif auraType == "enemy" then
		auraType = "foe"
	end

	if not nodeInfo.relationship then
		nodeInfo.relationship = getRelationship(sourceNode, targetNode)
	end
	if auraType == nodeInfo.relationship or auraType == "all" then
		if not nodeInfo.distanceBetween then
			local sourceToken = CombatManager.getTokenFromCT(sourceNode)
			local targetToken = CombatManager.getTokenFromCT(targetNode)
			if sourceToken and targetToken then
				nodeInfo.distanceBetween = anyGetDistanceBetween(sourceToken, targetToken)
			end
		end
		local existingAuraEffect = checkAuraAlreadyEffecting(sourceNode, targetNode, auraEffect)
		if nodeInfo.distanceBetween and nodeInfo.distanceBetween <= nRange then
			if not existingAuraEffect then
				addAuraEffect(auraType, auraEffect, targetNode, sourceNode)
			end
		else
			if existingAuraEffect then
				removeAuraEffect(auraType, existingAuraEffect)
			end
		end
	end
end

function handleTokenMovement(msgOOB)
	local tokenCT = CombatManager.getTokenFromCT(DB.findNode(msgOOB.sCTNode));
	updateAuras(tokenCT);
end

function handleApplyEffectSilent(msgOOB)
	-- Get the target combat tracker node
	local nodeCTEntry = DB.findNode(msgOOB.sTargetNode);
	if not nodeCTEntry then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectapplyfail") .. " (" .. msgOOB.sTargetNode .. ")");
		return false;
	end

	-- Reconstitute the effect details
	local rEffect = {};
	for k,v in pairs(msgOOB) do
		if aEffectVarMap[k] then
			if aEffectVarMap[k].sDBType == "number" then
				rEffect[k] = tonumber(msgOOB[k]) or 0;
			else
				rEffect[k] = msgOOB[k];
			end
		end
	end

	-- Apply the effect
	EffectManager.addEffect(msgOOB.user, msgOOB.identity, nodeCTEntry, rEffect, false);
end

local function manageHandlers(bRemove)
	if bRemove then
		DB.removeHandler(DB.getPath("combattracker.list.*.effects.*"), "onChildUpdate", onEffectChanged)
	else
		DB.addHandler(DB.getPath("combattracker.list.*.effects.*"), "onChildUpdate", onEffectChanged)
	end
end

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
		local sEffect = DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "");
		local aEffectComps = parseEffect(sEffect);
		if #aEffectComps > 1 then
			table.remove(aEffectComps, nExpireComp);
			local sRebuiltEffect = EffectManager.rebuildParsedEffect(aEffectComps)
			if sRebuiltEffect and sRebuiltEffect ~= "" then
				DB.setValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "string", sRebuiltEffect);
				return;
			else
				removeNode(nodeEffect)
			end
		end
	end

	-- Process full expiration
	removeNode(nodeEffect)
end

function handleExpireEffectSilent(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		-- Debug.chat(msgOOB, nodeEffect)
		return false;
	end
	
	local nodeActor = nodeEffect.getChild("...");
	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sEffectNode .. ")");
		return false;
	end

	expireEffectSilent(nodeActor, nodeEffect, tonumber(msgOOB.nExpireClause) or 0);
end

-- This shouldn't remain long term
local function replaceOldFromAuraString()
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		for _, nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
			local sLabelNodeEffect = DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "")
			local index = string.find(sLabelNodeEffect, "FROMAURA:", 0, true)
			if index and index == 1 then
				local sFromAuraEffect = fromAuraString .. sLabelNodeEffect:sub(10)
				if sFromAuraEffect and sFromAuraEffect ~= "" then
					-- Debug.console(sLabelNodeEffect, index)
					DB.setValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "string", sFromAuraEffect)
				else
					removeNode(nodeEffect)
				end
			end
		end
	end
end

function onInit()
	OptionsManager.registerOption2("AURASILENT", false, "option_header_aura", "option_label_AURASILENT", "option_entry_cycler", { labels = "option_val_friend|option_val_foe|option_val_all", values="friend|foe|all", baselabel = "option_val_off", baseval="off", default="off"});

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURATOKENMOVE, handleTokenMovement);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURAAPPLYSILENT, handleApplyEffectSilent);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_AURAEXPIRESILENT, handleExpireEffectSilent);

	CombatManager.setCustomDeleteCombatantEffectHandler(checkDeletedAuraEffects);

	local DetectedEffectManager
	if EffectManager35E then
		DetectedEffectManager = EffectManager35E
	elseif EffectManagerPFRPG2 then
		DetectedEffectManager = EffectManagerPFRPG2
	elseif EffectManager5E then
		DetectedEffectManager = EffectManager5E
	elseif EffectManager4E then
		DetectedEffectManager = EffectManager4E
	end

	checkConditional = DetectedEffectManager.checkConditional;
	DetectedEffectManager.checkConditional = customCheckConditional;

	onWindowOpened = Interface.onWindowOpened;
	Interface.onWindowOpened = auraOnWindowOpened;

	if UtilityManager.isClientFGU() then
		onMove = Token.onMove
		Token.onMove = auraOnMove
	else
		onDragEnd = Token.onDragEnd
		Token.onDragEnd = auraOnDragEnd
	end

	if Session.IsHost then
		manageHandlers(false)
		replaceOldFromAuraString()
	end
end
