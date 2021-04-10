--
-- Add functionality for SAVEO type effects similar to DMGO or REGEN
--
--

local fromAuraString = "FROMAURA:"

---	This function checks whether an effect should trigger recalculation.
--	It does this by checking the effect text for a series of three letters followed by a colon (as used in bonuses like CON: 4).
local function checkEffectRecursion(nodeEffect, sEffectComp)
	if string.find(DB.getValue(nodeEffect, 'label', ''), sEffectComp) then
		return true
	end
end

---	This function is called when effect components are changed.
local function onEffectChanged(node)
	local nodeEffect = node.getChild('..')
	if checkEffectRecursion(nodeEffect, 'AURA:') and not checkEffectRecursion(nodeEffect, fromAuraString) then
		local nodeCT = node.getChild('....')
		local tokenCT = CombatManager.getTokenFromCT(nodeCT);
		if tokenCT then
			updateAuras(tokenCT);
		end
	end
end

local updateAttributesFromToken = nil;
local checkConditional = nil
local onMove = nil;
local onWindowOpened = nil;
local onTokenAdd = nil;

local auraTokens = {};

local updateEffectsHelper = nil
OOB_MSGTYPE_APPLYEFFSILENT = "applyeffsilent";
OOB_MSGTYPE_EXPIREEFFSILENT = "expireeffsilent";

function auraOnTokenAdd(tokenMap)
	if onTokenAdd then
		onTokenAdd(tokenMap);
	end
	--Debug.chat("updating from onTokenAdd");
	if not Session.IsHost then
		return;
	end
	--Debug.chat(tokenMap)
	updateAuras(tokenMap);
end

function auraOnWindowOpened(window)
	if onWindowOpened then
		onWindowOpened(window);
	end
	if not Session.IsHost then
		return;
	end
	if window.getClass() == "imagewindow" then
		local ctEntries = CombatManager.getSortedCombatantList();
		for _, nodeCT in pairs(ctEntries) do
			local tokenCT = CombatManager.getTokenFromCT(nodeCT);
			local ctrlImage, winImage = ImageManager.getImageControl(tokenCT);
			--Debug.chat("ctrlImage = ",ctrlImage,"winImage =", winImage,"window =",window);
			if tokenCT and winImage and winImage == window then
				updateAuras(tokenCT);
			end
		end
	end
end

local function getAurasEffectingNode(nodeCT)
	local auraEffects = {};

	for _, nodeEffect in pairs(DB.getChildren(nodeCT, "effects")) do
		if DB.getValue(nodeEffect, "isactive", 0) == 1 then
			local sLabelNodeEffect = DB.getValue(nodeEffect, "label", "");
			if string.find(sLabelNodeEffect, fromAuraString, 0, true) then
				table.insert(auraEffects, nodeEffect);
			end
		end
	end
	return auraEffects;
end

local function checkAurasEffectingNodeForDelete(nodeCT)
	local aurasEffectingNode = getAurasEffectingNode(nodeCT);
	for _, targetEffect in ipairs(aurasEffectingNode) do
		local targetEffectLabel = DB.getValue(targetEffect, "label", ""):gsub(fromAuraString,"");
		if not string.find(targetEffectLabel, fromAuraString) then
			local sSource = DB.getValue(targetEffect, "source_name", "");
			local sourceNode = DB.findNode(sSource);
			if sourceNode then
				local sourceAuras = getAurasForNode(sourceNode);
				local auraStillExists = nil;
				for _, sourceEffect in ipairs(sourceAuras) do
					local sourceEffectLabel = DB.getValue(sourceEffect, "label", "");
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
	local sLabel = DB.getValue(effect, "label", "");
	local nodeEffects = DB.getChildren(nodeTarget, "effects");
	local sourcePath = nodeSource.getPath();
	for _, nodeEffect in pairs(nodeEffects) do
		local sSource = DB.getValue(nodeEffect, "source_name");
		if sSource == sourcePath then
			local sEffect = DB.getValue(nodeEffect, "label", ""):gsub(fromAuraString,"");
			if string.find(sLabel, sEffect, 0, true) then
				return nodeEffect;
			end
		end
	end
end

local function checkFaction(rActor, nodeEffect, sFactionCheck)
	if not nodeEffect then
		return true;
	end

	local effectSource = DB.getValue(nodeEffect, "source_name");
	if not effectSource then 
		return false; 
	end

	local sourceNode = CombatManager.getCTFromNode(effectSource);
	local sourceFaction = DB.getValue(sourceNode, "friendfoe", "");
	local targetFaction = ActorManager.getFaction(rActor);
	
	local bReturn = true;

	if sFactionCheck:match("friend") then
		bReturn = sourceFaction == targetFaction;
	elseif sFactionCheck:match("foe") then
		bReturn = sourceFaction ~= targetFaction;
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

function customCheckConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)
	local bReturn = checkConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore);
	for _,v in ipairs(aConditions) do
		local sLower = v:lower();
		local sFactionCheck = sLower:match("^faction%s*%(([^)]+)%)$");
		if sFactionCheck then
			if not checkFaction(rActor, nodeEffect, sFactionCheck) then
				bReturn = false;
				break;
			end
		end
	end
	return bReturn;
end

function auraUpdateAttributesFromToken(tokenMap)
	if updateAttributesFromToken then
		updateAttributesFromToken(tokenMap);
	end

	onMove = tokenMap.onMove;
	tokenMap.onMove = auraOnMove;
end

function updateAuras(tokenMap)
	--Debug.printstack();
	--Debug.chat("updating Auras");
	local nodeCT = CombatManager.getCTFromToken(tokenMap);
	if not nodeCT or not nodeCT.isOwner() then
		--Debug.chat("no nodeCT");
		return;
	end

	local ctEntries = CombatManager.getSortedCombatantList();
	for _, node in pairs(ctEntries) do
		if node ~= nodeCT then
			-- Check if the moved token has auras to apply/remove
			local nodeCTAuras = getAurasForNode(nodeCT);
			for _, sourceAuraEffect in pairs(nodeCTAuras) do
				checkAuraApplicationAndAddOrRemove(node, nodeCT, sourceAuraEffect);
			end

			-- Check if the moved token is subject to other's auras
			local nodeAuras = getAurasForNode(node);
			for _, auraEffect in pairs(nodeAuras) do
				checkAuraApplicationAndAddOrRemove(nodeCT, node, auraEffect);
			end
		end
	end
	--checkAurasEffectingNodeForDelete(nodeCT);
end

function auraOnMove(tokenMap)
	--Debug.chat("in aura on move");
	if onMove then
		onMove(tokenMap);
	end
	updateAuras(tokenMap);

	--Debug.chat("finishing aura on move");
end

function getAurasForNode(nodeCT)
	if not nodeCT then 
		return nil; 
	end
	local auraEffects = {};
	local nodeEffects = DB.getChildren(nodeCT, "effects");
	for _, nodeEffect in pairs(nodeEffects) do
		if DB.getValue(nodeEffect, "isactive", 0) == 1 then
			local sLabelNodeEffect = DB.getValue(nodeEffect, "label", "");
			if string.match(sLabelNodeEffect, "%s*AURA:") then
				--Debug.console(nodeEffect);
				table.insert(auraEffects, nodeEffect);
			end
		end
	end
	return auraEffects;
end

function checkAuraApplicationAndAddOrRemove(targetNode, sourceNode, auraEffect)
	if not targetNode 
	or not auraEffect 
	then
		return;
	end

	if not sourceNode then
		local sSource = DB.getValue(auraEffect, "source_name", "");
		sourceNode = DB.findNode(sSource);
		if not sourceNode then
			return;
		end
	end

	local sLabelNodeEffect = DB.getValue(auraEffect, "label", "");
	local nRange, auraType = string.match(sLabelNodeEffect, "(%d+) (%w+)");
	if not nRange then
		return;
	end
	if not auraType then
		auraType = "all";
	end
	nRange = math.floor(nRange);
	local sourceFaction = DB.getValue(sourceNode, "friendfoe", "");
	local targetFaction = DB.getValue(targetNode, "friendfoe", "");
	if (auraType == "friend" and sourceFaction == targetFaction) 
	or ((auraType == "enemy" or auraType == "foe") and sourceFaction ~= targetFaction) 
	or (auraType == "all") then
		addOrRemoveAura(nRange, auraType, targetNode, sourceNode, auraEffect);
	end
end

function addOrRemoveAura(nRange, auraType, targetNode, sourceNode, nodeEffect)
	local existingAuraEffect = checkAuraAlreadyEffecting(sourceNode, targetNode, nodeEffect);
	if checkRange(nRange, targetNode, sourceNode) then
		if not existingAuraEffect then
			addAuraEffect(auraType, nodeEffect, targetNode, sourceNode);
		end
	else
		if existingAuraEffect then
			removeAuraEffect(auraType, existingAuraEffect);
		end
	end
end

function checkRange(nRange, nodeSource, nodeTarget)
	local sourceToken = CombatManager.getTokenFromCT(nodeSource);
	local targetToken = CombatManager.getTokenFromCT(nodeTarget);
	if not sourceToken or not targetToken or not nRange then
		return false;
	end;
	local nDistanceBetweenTokens = Token.getDistanceBetween(sourceToken, targetToken)

	return nDistanceBetweenTokens <= nRange;
end

function checkSilentNotification(auraType)
	local option = OptionsManager.getOption("AURASILENT"):lower();
	auraType = auraType:lower():gsub("enemy", "foe");
	return option == "all" or option == auraType;
end

function removeAuraEffect(auraType, effect)
	if checkSilentNotification(auraType) == true then
		notifyExpireSilent(effect, nil, false);
	else
		EffectManager.notifyExpire(effect, nil, false);
	end
end

local aEffectVarMap = {
	["sName"] = { sDBType = "string", sDBField = "label" },
	["nGMOnly"] = { sDBType = "number", sDBField = "isgmonly" },
	["sSource"] = { sDBType = "string", sDBField = "source_name", bClearOnUntargetedDrop = true },
	["sTarget"] = { sDBType = "string", bClearOnUntargetedDrop = true },
	["nDuration"] = { sDBType = "number", sDBField = "duration", vDBDefault = 1, sDisplay = "[D: %d]" },
	["nInit"] = { sDBType = "number", sDBField = "init", sSourceChangeSet = "initresult", bClearOnUntargetedDrop = true },
};

local function notifyApplySilent(rEffect, vTargets)
	-- Build OOB message to pass effect to host
	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_APPLYEFFSILENT;
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

function addAuraEffect(auraType, effect, targetNode, sourceNode)
	local sLabel = DB.getValue(effect, "label", "");
	local applyLabel = string.match(sLabel, "AURA:.-;%s*(.*)$");
	if not applyLabel then
		return;
	end
	applyLabel = fromAuraString..applyLabel;
	
	local rEffect = {};
	rEffect.nDuration = DB.getValue(effect, "duration", 0);
	rEffect.sUnits = DB.getValue(effect, "unit", "");
	rEffect.nInit = DB.getValue(effect, "init", 0);
	rEffect.sSource = sourceNode.getPath();
	rEffect.nGMOnly = DB.getValue(effect, "isgmonly", 0);
	rEffect.sLabel = applyLabel;
	rEffect.sName = applyLabel;
	
	-- CHECK IF SILENT IS ON
	if checkSilentNotification(auraType) == true then
		notifyApplySilent(rEffect, targetNode.getPath());
	else
		EffectManager.notifyApply(rEffect, targetNode.getPath());
	end
end

function handleApplyEffectSilent(msgOOB)
	-- Get the target combat tracker node
	local nodeCTEntry = DB.findNode(msgOOB.sTargetNode);
	if not nodeCTEntry then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectapplyfail") .. " (" .. msgOOB.sTargetNode .. ")");
		return;
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

function handleExpireEffect(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sEffectNode .. ")");
		return;
	end
	local nodeActor = nodeEffect.getChild("...");
	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sEffectNode .. ")");
		return;
	end

	EffectManager.expireEffect(nodeActor, nodeEffect, tonumber(msgOOB.nExpireClause) or 0);
end

function expireEffectSilent(nodeActor, nodeEffect, nExpireComp)
	if not nodeEffect then
		return false;
	end

	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
	local sEffect = DB.getValue(nodeEffect, "label", "");

	-- Check for partial expiration
	if (nExpireComp or 0) > 0 then
		local aEffectComps = parseEffect(sEffect);
		if #aEffectComps > 1 then
			table.remove(aEffectComps, nExpireComp);
			DB.setValue(nodeEffect, "label", "string", rebuildParsedEffect(aEffectComps));
			--EffectManager.message("Effect ['" .. sEffect .. "'] -> [SINGLE MOD USED]", nodeActor, bGMOnly);
			return true;
		end
	end

	-- Process full expiration
	nodeEffect.delete();
end

function notifyExpireSilent(varEffect, nMatch)
	if type(varEffect) == "databasenode" then
		varEffect = varEffect.getNodeName();
	elseif type(varEffect) ~= "string" then
		return;
	end

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_EXPIREEFFSILENT;
	msgOOB.sEffectNode = varEffect;
	msgOOB.nExpireClause = nMatch;

	Comm.deliverOOBMessage(msgOOB, "");
end

local function handleExpireEffectSilent(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectdeletefail") .. " (" .. msgOOB.sEffectNode .. ")");
		return;
	end
	local nodeActor = nodeEffect.getChild("...");
	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sEffectNode .. ")");
		return;
	end

	expireEffectSilent(nodeActor, nodeEffect, tonumber(msgOOB.nExpireClause) or 0);
end

function onInit()
	updateAttributesFromToken = TokenManager.updateAttributesFromToken;
	TokenManager.updateAttributesFromToken = auraUpdateAttributesFromToken;

	local DetectedEffectManager
	if EffectManager35E then
		DetectedEffectManager = EffectManager35E
	end
	if EffectManager5E then
		DetectedEffectManager = EffectManager5E
	end
	if EffectManager4E then
		DetectedEffectManager = EffectManager4E
	end
	checkConditional = DetectedEffectManager.checkConditional;
	DetectedEffectManager.checkConditional = customCheckConditional;

	CombatManager.setCustomDeleteCombatantEffectHandler(checkDeletedAuraEffects);
	if Session.IsHost then
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.label'), 'onUpdate', onEffectChanged)
		DB.addHandler(DB.getPath('combattracker.list.*.effects.*.isactive'), 'onUpdate', onEffectChanged)
	end

	onWindowOpened = Interface.onWindowOpened;
	Interface.onWindowOpened = auraOnWindowOpened;

	onTokenAdd = ImageManager.onTokenAdd;
	ImageManager.onTokenAdd = auraOnTokenAdd;

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYEFFSILENT, handleApplyEffectSilent);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_EXPIREEFFSILENT, handleExpireEffectSilent);
	
	OptionsManager.registerOption2("AURASILENT", false, "option_header_aura", "option_label_AURASILENT", "option_entry_cycler", { labels = "option_val_friend|option_val_foe|option_val_all", values="friend|foe|all", baselabel = "option_val_off", baseval="off", default="friend"});
end