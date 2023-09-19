--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals bDebug updateAura addAura removeAura removeAllFromAuras isAuraApplicable
-- luacheck: globals fromAuraString auraString getAuraDetails
-- luacheck: globals AuraFactionConditional.DetectedEffectManager.parseEffectComp AuraFactionConditional.DetectedEffectManager.checkConditional
bDebug = false

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'

fromAuraString = 'FROMAURA;'
auraString = 'AURA: %d+'

local aAuraFactions = {'ally', 'enemy', 'friend', 'foe', 'all', 'neutral', 'faction'}

-- Checks AURA effect string common needed information
function getAuraDetails(nodeEffect)
    local rDetails = {nRange = 0, sEffect = '', sSource = '', sAuraNode = '', aFactions = {}}
    if not AuraFactionConditional.DetectedEffectManager.parseEffectComp then return 'all' end

	    rDetails.sEffect = DB.getValue(nodeEffect, 'label', '')
		for _, sEffectComp in ipairs(EffectManager.parseEffect(rDetails.sEffect)) do
		local rEffectComp = AuraFactionConditional.DetectedEffectManager.parseEffectComp(sEffectComp)

        if rEffectComp.type:upper() == 'AURA' then
			rDetails.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
			rDetails.sAuraNode = DB.getPath(nodeEffect)
            rDetails.nRange = rEffectComp.mod
            for _, sFilter in ipairs(rEffectComp.remainder) do
                local sFilterCheck = sFilter:lower();
				if StringManager.startsWith(sFilter, '!') then
					sFilterCheck = sFilter:sub(2);
				end
				if StringManager.contains(aAuraFactions, sFilterCheck) then
					table.insert(rDetails.aFactions, sFilter:lower());
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
    rEffect.sName = fromAuraString .. applyLabel:gsub('IFT*:%s*FACTION%(%s*notself%s*%)%s*;*', '')
    rEffect.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
    rEffect.sAuraNode = DB.getPath(nodeEffect)
    rEffect.sUnits = DB.getValue(nodeEffect, 'unit', '')
    return rEffect
end

-- Checks provided effect node to see whether it's a fromaura matching the actor at the provided string
-- It does this without using source_aura as it's used in the pipeline that sets source_aura
local function isAuraMatchToSaveSource(nodeTargetEffect, sSourcePath)
    local bReturn = DB.getValue(nodeTargetEffect, 'source_name', '') == sSourcePath
    return bReturn and string.find(DB.getValue(nodeTargetEffect, 'label', ''), fromAuraString) ~= nil
end

-- Search for FROMAURA effects on nodeTarget where aura source matches nodeSource and source_aura is not set
-- If found, set source_aura to nodeEffect. this could be bad for users of older versions.
local function saveAuraSource(nodeTarget, rAuraDetails)
    for _, nodeTargetEffect in ipairs(DB.getChildList(nodeTarget, 'effects')) do
        if not DB.getValue(nodeTargetEffect, 'source_aura') and isAuraMatchToSaveSource(nodeTargetEffect, rAuraDetails.sSource) then
            DB.setValue(nodeTargetEffect, 'source_aura', 'string', rAuraDetails.sAuraNode)
            break
        end
    end
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
	if hasFromAura(nodeEffect, nodeTarget) then return end
	AuraEffectSilencer.notifyApply(buildFromAura(nodeEffect), DB.getPath(nodeTarget), rAuraDetails.aFactions)
	saveAuraSource(nodeTarget, rAuraDetails)
end

-- Search all effects on target to find matching auras to remove.
-- Skip "off/skip" effects to allow for immunity workaround.
function removeAura(nodeEffect, nodeTarget, rAuraDetails)
	if not nodeEffect or not nodeTarget then return end
	for _, nodeTargetEffect in ipairs(DB.getChildList(nodeTarget, 'effects')) do
		if DB.getValue(nodeTargetEffect, 'isactive', 0) == 1 and DB.getValue(nodeTargetEffect, 'source_aura', '') == rAuraDetails.sAuraNode then
			AuraEffectSilencer.notifyExpire(nodeTargetEffect, nil, nil, rAuraDetails.aFactions)
			break
		end
	end
end

-- Search all effects on target to find matching auras to remove.
function removeAllFromAuras(nodeEffect)
	local rAuraDetails = AuraEffect.getAuraDetails(nodeEffect)
	if not string.find(rAuraDetails.sEffect, auraString) then return end
	local nodeSource = DB.getChild(nodeEffect, '...')
	local _, winSource = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeSource))
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		if nodeCT ~= nodeSource then -- don't check for FROMAURAs on parent of nodeEffect
			local _, winTarget = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
			if winTarget == winSource then AuraEffect.removeAura(nodeEffect, nodeCT, rAuraDetails) end
		end
	end
end

-- Gets a table of tokens, keyed to their id number, that are further from tokenSource than the distance nRange.
local function getTokensBeyondDistance(tokenSource, nRange)
    local imageControl = ImageManager.getImageControl(tokenSource)
    if not imageControl or not tokenSource or not nRange then return {} end -- only process if token is on map
    local tCloseTokens, tFarTokens = {}, {}

    -- Add tokens from tTokens to tNewTokens if they aren't tokenSource from getTokensBeyondDistance
    -- If provided with tSkipTokens, don't include tokens with key matches in tNewTokens either.
    local function compileTokensSkipSource(tTokens, tNewTokens, tSkipTokens)
        for _, token in pairs(tTokens) do
            if token ~= tokenSource and (not tSkipTokens or not tSkipTokens[token.getId()]) then
                tNewTokens[token.getId()] = token
            end
        end
    end

    compileTokensSkipSource(imageControl.getTokensWithinDistance(tokenSource, nRange), tCloseTokens)
    compileTokensSkipSource(ImageManager.getImageControl(tokenSource).getTokens(), tFarTokens, tCloseTokens)

    return tFarTokens
end

-- Check for IF/IFT conditionals blocking aura effect
local function checkConditionalBeforeAura(nodeEffect, nodeCT, targetNodeCT)
	if not AuraFactionConditional.DetectedEffectManager.parseEffectComp then return true end
	for _, sEffectComp in ipairs(EffectManager.parseEffect(DB.getValue(nodeEffect, 'label', ''))) do
		local rEffectComp = AuraFactionConditional.DetectedEffectManager.parseEffectComp(sEffectComp)
		-- Check conditionals
		if rEffectComp.type == 'AURA' then
            local rActor = ActorManager.resolveActor(nodeCT) -- these are in here for performance reasons
            if not AuraFactionConditional.DetectedEffectManager.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then
				return false
			else
				return true
            end
		elseif rEffectComp.type == 'IF' then
			local rActor = ActorManager.resolveActor(nodeCT) -- these are in here for performance reasons
			if not AuraFactionConditional.DetectedEffectManager.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then return false end
		elseif rEffectComp.type == 'IFT' then
			local rActor = ActorManager.resolveActor(nodeCT) -- these are in here for performance reasons
			local rTarget = ActorManager.resolveActor(targetNodeCT) -- these are in here for performance reasons
			if rTarget and not AuraFactionConditional.DetectedEffectManager.checkConditional(rTarget, nodeEffect, rEffectComp.remainder, rActor) then
				return false
			end
		end
	end
	return true
end

-- Should auras in range be added to this target?
function isAuraApplicable(nodeEffect, rSource, token, aFactions)
	local rTarget = ActorManager.resolveActor(CombatManager.getCTFromToken(token))
	if
		rTarget ~= rSource
		and DB.getValue(nodeEffect, 'isactive', 0) == 1
		and checkConditionalBeforeAura(nodeEffect, ActorManager.getCTNode(rSource), ActorManager.getCTNode(rTarget))
		and AuraFactionConditional.checkFaction(rTarget, rSource, aFactions)
	then
		return true
	end
	return false
end

-- Compile sets of tokens on same map as source that should/should not have aura applied.
-- Trigger adding/removing auras as applicable.
function updateAura(tokenSource, nodeEffect, rAuraDetails)
	local imageControl = ImageManager.getImageControl(tokenSource)
	if not imageControl then return end -- only process if effect parent is on an opened map
	local tAdd, tRemove = {}, {}

	-- compile lists
    local nodeSource = DB.findNode(rAuraDetails.sSource)
 	local rSource = ActorManager.resolveActor(nodeSource)
	for _, token in pairs(imageControl.getTokensWithinDistance(tokenSource, rAuraDetails.nRange)) do
        if isAuraApplicable(nodeEffect, rSource, token, rAuraDetails.aFactions) then
            tAdd[token.getId()] = {nodeEffect, CombatManager.getCTFromToken(token)}
        else
            tRemove[token.getId()] = {nodeEffect, CombatManager.getCTFromToken(token)}
        end
	end
	for id, token in pairs(getTokensBeyondDistance(tokenSource, rAuraDetails.nRange)) do
		tRemove[id] = { nodeEffect, CombatManager.getCTFromToken(token) }
	end

	-- process add/remove
	for _, v in pairs(tAdd) do
		AuraEffect.addAura(v[1], v[2], rAuraDetails)
	end
	for _, v in pairs(tRemove) do
		AuraEffect.removeAura(v[1], v[2], rAuraDetails)
	end
end