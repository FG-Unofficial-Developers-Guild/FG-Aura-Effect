--
-- Add functionality for SAVEO type effects similar to DMGO or REGEN
--
--

OOB_MSGTYPE_ONPLAYERMOVE = "aurasonplayermove";
OOB_MSGTYPE_APPLYEFFSILENT = "applyeffsilent";
OOB_MSGTYPE_EXPIREEFFSILENT = "expireeffsilent";

local fromAuraString = "FROMAURA:"
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
local function onEffectChanged(node)
	local nodeEffect = node.getChild("..")
	if checkEffectRecursion(nodeEffect, auraString) and not checkEffectRecursion(nodeEffect, fromAuraString) then
		local nodeCT = node.getChild("....")
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

local function notifyPlayerMove(tokenMap)
	local nodeCT = CombatManager.getCTFromToken(tokenMap)
	if not nodeCT then
		return;
	end
	

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_ONPLAYERMOVE;
	msgOOB.sCTNode = nodeCT.getNodeName()

	Comm.deliverOOBMessage(msgOOB, "");
end

local onTokenAdd = nil;
function auraOnTokenAdd(tokenMap)
	if onTokenAdd then
		onTokenAdd(tokenMap);
	end
	notifyPlayerMove(tokenMap);
end

local onWindowOpened = nil;
function auraOnWindowOpened(window)
	if onWindowOpened then
		onWindowOpened(window);
	end
	if window.getClass() == "imagewindow" then
		local ctEntries = CombatManager.getSortedCombatantList();
		for _, nodeCT in pairs(ctEntries) do
			local tokenCT = CombatManager.getTokenFromCT(nodeCT);
			local ctrlImage, winImage = ImageManager.getImageControl(tokenCT);
			if tokenCT and winImage and winImage == window then
				notifyPlayerMove(tokenMap);
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

local function notifyExpireSilent(varEffect, nMatch)
	if type(varEffect) == "databasenode" then
		varEffect = varEffect.getNodeName();
	elseif type(varEffect) ~= "string" then
		return false;
	end

	local msgOOB = {};
	msgOOB.type = OOB_MSGTYPE_EXPIREEFFSILENT;
	msgOOB.sEffectNode = varEffect;
	msgOOB.nExpireClause = nMatch;

	Comm.deliverOOBMessage(msgOOB, "");
end

local function removeAuraEffect(auraType, effect)
	if checkSilentNotification(auraType) == true then
		notifyExpireSilent(effect, nil, false);
	else
		EffectManager.notifyExpire(effect, nil, false);
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
		if DB.getValue(nodeEffect, aEffectVarMap["nActive"]["sDBField"], 0) == 1 then
			local sSource = DB.getValue(nodeEffect, aEffectVarMap["sSource"]["sDBField"]);
			if sSource == nodeSource.getPath() then
				local sEffect = DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], ""):gsub(fromAuraString,"");
				if string.find(sLabel, sEffect, 0, true) then
					return nodeEffect;
				end
			end
		end
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
local function auraOnMove(tokenMap)
	if onMove then
		onMove(tokenMap);
	end
	notifyPlayerMove(tokenMap)
end

local function getDistanceBetweenCT(ctNodeSource, ctNodeTarget)
	local sourceToken = CombatManager.getTokenFromCT(ctNodeSource)
	local targetToken = CombatManager.getTokenFromCT(ctNodeTarget)
	if sourceToken and targetToken then
		return Token.getDistanceBetween(sourceToken, targetToken)
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
			nodeInfo.distanceBetween = getDistanceBetweenCT(sourceNode, targetNode)
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

local function handlePlayerMove(msgOOB)
	local tokenCT = CombatManager.getTokenFromCT(DB.findNode(msgOOB.sCTNode));
	updateAuras(tokenCT);
end

local function handleApplyEffectSilent(msgOOB)
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

function expireEffectSilent(nodeActor, nodeEffect, nExpireComp)
	if not nodeEffect then
		return false;
	end

	local bGMOnly = EffectManager.isGMEffect(nodeActor, nodeEffect);
	local sEffect = DB.getValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "");

	-- Check for partial expiration
	if (nExpireComp or 0) > 0 then
		local aEffectComps = parseEffect(sEffect);
		if #aEffectComps > 1 then
			table.remove(aEffectComps, nExpireComp);
			DB.setValue(nodeEffect, aEffectVarMap["sName"]["sDBField"], "string", rebuildParsedEffect(aEffectComps));
			return;
		end
	end

	-- Process full expiration
	nodeEffect.delete();
end

local function handleExpireEffectSilent(msgOOB)
	local nodeEffect = DB.findNode(msgOOB.sEffectNode);
	if not nodeEffect then
		return false;
	end
	
	local nodeActor = nodeEffect.getChild("...");
	if not nodeActor then
		ChatManager.SystemMessage(Interface.getString("ct_error_effectmissingactor") .. " (" .. msgOOB.sEffectNode .. ")");
		return false;
	end

	expireEffectSilent(nodeActor, nodeEffect, tonumber(msgOOB.nExpireClause) or 0);
end

function onInit()
	CombatManager.setCustomDeleteCombatantEffectHandler(checkDeletedAuraEffects);
	if Session.IsHost then
		DB.addHandler(DB.getPath("combattracker.list.*.effects.*.label"), "onUpdate", onEffectChanged)
		DB.addHandler(DB.getPath("combattracker.list.*.effects.*.isactive"), "onUpdate", onEffectChanged)
		DB.addHandler(DB.getPath("combattracker.list.*.effects.*.isgmonly"), "onUpdate", onEffectChanged)
	end
	
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

	onWindowOpened = Interface.onWindowOpened;
	Interface.onWindowOpened = auraOnWindowOpened;

	onMove = Token.onMove
	Token.onMove = auraOnMove

	onTokenAdd = ImageManager.onTokenAdd;
	ImageManager.onTokenAdd = auraOnTokenAdd;

	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_ONPLAYERMOVE, handlePlayerMove);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_APPLYEFFSILENT, handleApplyEffectSilent);
	OOBManager.registerOOBMsgHandler(OOB_MSGTYPE_EXPIREEFFSILENT, handleExpireEffectSilent);
	
	OptionsManager.registerOption2("AURASILENT", false, "option_header_aura", "option_label_AURASILENT", "option_entry_cycler", { labels = "option_val_friend|option_val_foe|option_val_all", values="friend|foe|all", baselabel = "option_val_off", baseval="off", default="friend"});
end