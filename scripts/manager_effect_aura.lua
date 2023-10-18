--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals bDebug updateAura addAura removeAura removeAllFromAuras isAuraApplicable
-- luacheck: globals auraString getAuraDetails
-- luacheck: globals AuraFactionConditional.DetectedEffectManager.parseEffectComp AuraFactionConditional.DetectedEffectManager.checkConditional
-- luacheck: globals AuraTracker AuraToken getPathsOncePerTurn
bDebug = false

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'

auraString = 'AURA: %d+'

local aAuraFactions = {'ally', 'enemy', 'friend', 'foe', 'all', 'neutral', 'none'}

-- Checks AURA effect string common needed information
function getAuraDetails(nodeEffect)
	local rDetails = {
		bSingle = false, bCube = false, bSticky = false, bOnce = false,
		nRange = 0, sEffect = '', sSource = '', sAuraNode = '', aFactions = {}
	}
	if not AuraFactionConditional.DetectedEffectManager.parseEffectComp then return rDetails end

	rDetails.sEffect = DB.getValue(nodeEffect, 'label', '')
	for _, sEffectComp in ipairs(EffectManager.parseEffect(rDetails.sEffect)) do
		local rEffectComp = AuraFactionConditional.DetectedEffectManager.parseEffectComp(sEffectComp)

		if rEffectComp.type:upper() == 'AURA' then
			rDetails.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
			rDetails.sAuraNode = DB.getPath(nodeEffect)
			AuraTracker.addTrackedAura(rDetails.sSource, rDetails.sAuraNode)
			rDetails.nRange = rEffectComp.mod
			for _, sFilter in ipairs(rEffectComp.remainder) do
				local sFilterCheck = sFilter:lower()
				if sFilterCheck == 'single' then
					rDetails.bSingle = true
				elseif sFilterCheck == 'cube' then
					rDetails.bCube = true
				elseif sFilterCheck == 'sticky' then
					rDetails.bSticky = true
				elseif sFilterCheck == 'once' then
					rDetails.bOnce = true
				else
					if StringManager.startsWith(sFilter, '!') or StringManager.startsWith(sFilter, '~') then
						sFilterCheck = sFilter:sub(2)
					end
					if StringManager.contains(aAuraFactions, sFilterCheck) then
						table.insert(rDetails.aFactions, sFilter:lower())
					end
				end
			end
			break
		end
	end
	if not next(rDetails.aFactions) then
		table.insert(rDetails.aFactions, 'all')
	end
	return rDetails
end

-- Sets up FROMAURA rEffect based on supplied AURA nodeEffect.
local function buildFromAura(nodeEffect)
	local applyLabel = string.match(DB.getValue(nodeEffect, 'label', ''), auraString .. '.-;%s*(.*)$')
	if not applyLabel then return nil end

	local rEffect = {}
	rEffect.nDuration = 0
	rEffect.nGMOnly = DB.getValue(nodeEffect, 'isgmonly', 0)
	rEffect.nInit = DB.getValue(nodeEffect, 'init', 0)
	rEffect.sName =  applyLabel
	rEffect.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
	rEffect.sAuraSource = DB.getPath(nodeEffect)
	rEffect.sUnits = DB.getValue(nodeEffect, 'unit', '')
	return rEffect
end

-- Check effect nodes of nodeSource to see if they are children of nodeEffect
local function hasFromAura(nodeEffect, nodeSource)
	local sEffectPath = DB.getPath(nodeEffect)
	for _, nodeTargetEffect in ipairs(DB.getChildList(nodeSource, 'effects')) do
		if DB.getValue(nodeTargetEffect, 'source_aura', '') == sEffectPath then return true end
	end
	return false
end

-- Add AURA in nodeEffect to targetToken actor if not already present.
-- Then call saveAuraSource to keep track of the FROMAURA effect
function addAura(nodeEffect, nodeTarget, rAuraDetails)
	local nodeSource = DB.findNode(rAuraDetails.sSource)
	if not nodeSource or not nodeTarget or not nodeEffect then return end
	AuraTracker.addTrackedFromAura(rAuraDetails.sSource, rAuraDetails.sAuraNode, DB.getPath(nodeTarget))
	if hasFromAura(nodeEffect, nodeTarget) then return end
	AuraEffectSilencer.notifyApply(buildFromAura(nodeEffect), DB.getPath(nodeTarget))
end

-- Search all effects on target to find matching auras to remove.
-- Skip "off/skip" effects to allow for immunity workaround.
function removeAura(nodeEffect, nodeTarget, rAuraDetails)
	if not nodeEffect or not nodeTarget then return end
	local sNodeTarget = DB.getPath(nodeTarget)
	for _, nodeTargetEffect in ipairs(DB.getChildList(nodeTarget, 'effects')) do
		if DB.getValue(nodeTargetEffect, 'isactive', 0) == 1 and DB.getValue(nodeTargetEffect, 'source_aura', '') == rAuraDetails.sAuraNode then
			if not rAuraDetails.bSticky then
				AuraEffectSilencer.notifyExpire(nodeTargetEffect)
				AuraTracker.removeTrackedFromAura(rAuraDetails.sSource, rAuraDetails.sAuraNode, sNodeTarget)
			end
			break
		end
	end
end

-- Search all effects on target to find matching auras to remove.
function removeAllFromAuras(nodeEffect)
	local rAuraDetails = AuraEffect.getAuraDetails(nodeEffect)
	if not string.find(rAuraDetails.sEffect, auraString) then return end
	local aFromAuraNodes = AuraTracker.getTrackedFromAuras(rAuraDetails.sSource, rAuraDetails.sAuraNode)
	for sNodeCT, _ in pairs(aFromAuraNodes) do
		local nodeCT = DB.findNode(sNodeCT)
		AuraEffect.removeAura(nodeEffect, nodeCT, rAuraDetails)
	end
end

-- Check for IF/IFT conditionals blocking aura effect
local function checkConditionalBeforeAura(nodeEffect, rSource, rTarget)
	if not AuraFactionConditional.DetectedEffectManager.parseEffectComp then return true end
	for _, sEffectComp in ipairs(EffectManager.parseEffect(DB.getValue(nodeEffect, 'label', ''))) do
		local rEffectComp = AuraFactionConditional.DetectedEffectManager.parseEffectComp(sEffectComp)
		-- Check conditionals
		if rEffectComp.type == 'AURA' then
			if not AuraFactionConditional.DetectedEffectManager.checkConditional(rSource, nodeEffect, rEffectComp.remainder) then
				return false
			else
				return true
			end
		elseif rEffectComp.type == 'IF' then
			if not AuraFactionConditional.DetectedEffectManager.checkConditional(rSource, nodeEffect, rEffectComp.remainder) then return false end
		elseif rEffectComp.type == 'IFT' then
			if rTarget and not AuraFactionConditional.DetectedEffectManager.checkConditional(rTarget, nodeEffect, rEffectComp.remainder, rSource) then
				return false
			end
		end
	end
	return true
end

-- Should auras in range be added to this target?
function isAuraApplicable(nodeEffect, rSource, rTarget, aFactions)
	local rAuraSource

	-- If the source token is set to faction is set to none, use the faction of the source of the aura to get the relationship
	if ActorManager.getFaction(rSource) == '' then
		local sSourcePath = DB.getValue(nodeEffect, 'source_name', '')
		if sSourcePath == '' then
			rAuraSource = rSource -- Source is the Source
		else
			rAuraSource = ActorManager.resolveActor(DB.findNode(DB.getPath(DB.getChild(nodeEffect, '...'))))
		end
	else
		rAuraSource = rSource
	end
	if
		rTarget ~= rSource
		and DB.getValue(nodeEffect, 'isactive', 0) == 1
		and checkConditionalBeforeAura(nodeEffect, rSource, rTarget)
		and AuraFactionConditional.DetectedEffectManager.checkConditional(rAuraSource,
			nodeEffect, {'FACTION(' .. table.concat(aFactions, ',') .. ')'}, rTarget)
	then
		return true
	end
	return false
end

-- Compile sets of tokens on same map as source that should/should not have aura applied.
-- Trigger adding/removing auras as applicable.
function updateAura(tokenSource, nodeEffect, rAuraDetails, rMoved)
	local imageControl = ImageManager.getImageControl(tokenSource)
	if not imageControl then return end -- only process if effect parent is on an opened map
	local tAdd, tRemove = {}, {}
	-- compile lists
	local rSource = ActorManager.resolveActor(DB.findNode(rAuraDetails.sSource))
	local aTokens;
	local aFromAuraNodes = AuraTracker.getTrackedFromAuras(rAuraDetails.sSource,rAuraDetails.sAuraNode)
	if rAuraDetails.bCube then
		aTokens = AuraToken.getTokensWithinCube(tokenSource, rAuraDetails.nRange)
	else
		aTokens = imageControl.getTokensWithinDistance(tokenSource, rAuraDetails.nRange)
	end
	for _, token in pairs(aTokens) do
		local nodeCTToken = CombatManager.getCTFromToken(token)
		if nodeCTToken then -- Guard against non-CT linked tokens
			local rTarget = ActorManager.resolveActor(nodeCTToken)
			aFromAuraNodes[rTarget.sCTNode] = nil -- Processed so mark as such
			if isAuraApplicable(nodeEffect, rSource, rTarget, rAuraDetails.aFactions) then

				if rAuraDetails.bSingle or rAuraDetails.bOnce then
					if not AuraTracker.checkOncePerTurn(rAuraDetails.sSource, rAuraDetails.sAuraNode, rTarget.sCTNode)
					   and (rAuraDetails.bOnce or rMoved and rMoved.sCTNode == rTarget.sCTNode) then
						tAdd[token.getId()] = {nodeEffect, nodeCTToken}
						AuraTracker.addOncePerTurn(rAuraDetails.sSource, rAuraDetails.sAuraNode,rTarget.sCTNode)
					end
				else
					tAdd[token.getId()] = {nodeEffect, nodeCTToken}
				end
			end
		end
	end

	if not rAuraDetails.bSticky then
		-- Anything left in aFromAuraNodes is out of range so remove
		for sNode, _ in pairs(aFromAuraNodes) do
			table.insert(tRemove, { nodeEffect, DB.findNode(sNode) } )
			 -- Leaving SINGLE/ONCE aura. Track as Once per turn only if the target is the one moving
			if rAuraDetails.bOnce or (rAuraDetails.bSingle and rMoved and rMoved.sCTNode == sNode) then
				AuraTracker.addOncePerTurn(rAuraDetails.sSource, rAuraDetails.sAuraNode, sNode)
			end
		end
	end

	-- process add/remove
	for _, v in pairs(tAdd) do
		AuraEffect.addAura(v[1], v[2], rAuraDetails)
	end
	for _, v in pairs(tRemove) do
		AuraEffect.removeAura(v[1], v[2], rAuraDetails)
	end
end
