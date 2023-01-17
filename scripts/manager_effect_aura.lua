--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals bDebug updateAura addAura removeAura removeAllFromAuras isAuraApplicable AuraFactionConditional

bDebug = false

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'

local fromAuraString = 'FROMAURA;'
local auraString = 'AURA: %d+'

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
	rEffect.sUnits = DB.getValue(nodeEffect, 'unit', '')
	return rEffect
end

-- Search for FROMAURA effects on nodeTarget where aura source matches nodeSource and source_aura is not set
-- If found, set source_aura to nodeEffect. this could be bad for users of older versions.
local function saveAuraSource(nodeEffect, nodeSource, nodeTarget)
	for _, nodeTargetEffect in pairs(DB.getChildren(nodeTarget, 'effects')) do
		local sEffect = DB.getValue(nodeTargetEffect, 'label', '')
		if string.find(sEffect, fromAuraString) and DB.getPath(nodeSource) == DB.getValue(nodeTargetEffect, 'source_name', '') then
			if not DB.getValue(nodeTargetEffect, 'source_aura') then
				DB.setValue(nodeTargetEffect, 'source_aura', 'string', DB.getPath(nodeEffect))
			end
			break
		end
	end
end

-- Check effect nodes of nodeSource to see if they are children of nodeEffect
local function hasFromAura(nodeEffect, nodeSource)
	for _, nodeTargetEffect in pairs(DB.getChildren(DB.getPath(nodeSource) .. '.effects')) do
		if DB.getValue(nodeTargetEffect, 'source_aura', '') == DB.getPath(nodeEffect) then return true end
	end
	return false
end

-- Add AURA in nodeEffect to targetToken actor if not already present.
-- Then call saveAuraSource to keep track of the FROMAURA effect
function addAura(nodeEffect, nodeTarget)
	local nodeSource = DB.getChild(nodeEffect, '...')
	if not nodeSource or not nodeTarget then return end
	if hasFromAura(nodeEffect, nodeTarget) then return end
	EffectManager.notifyApply(buildFromAura(nodeEffect), DB.getPath(nodeTarget))
	saveAuraSource(nodeEffect, nodeSource, nodeTarget)
end

-- Search all effects on target to find matching auras to remove.
-- Skip "off/skip" effects to allow for immunity workaround.
function removeAura(nodeEffect, nodeTarget)
	if not nodeEffect or not nodeTarget then return end
	for _, nodeTargetEffect in pairs(DB.getChildren(nodeTarget, 'effects')) do
		if DB.getValue(nodeTargetEffect, 'isactive', 0) == 1 and DB.getValue(nodeTargetEffect, 'source_aura', '') == DB.getPath(nodeEffect) then
			EffectManager.notifyExpire(nodeTargetEffect)
			break
		end
	end
end

-- Search all effects on target to find matching auras to remove.
function removeAllFromAuras(nodeEffect)
	local sEffect = DB.getValue(nodeEffect, 'label', '')
	if not string.find(sEffect, auraString) then return end
	local tokenSource = CombatManager.getTokenFromCT(DB.getChild(nodeEffect, '...'))
	local _, winSource = ImageManager.getImageControl(tokenSource)
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		local tokenTarget = CombatManager.getTokenFromCT(nodeCT)
		local _, winTarget = ImageManager.getImageControl(tokenTarget)
		if winSource == winTarget then AuraEffect.removeAura(nodeEffect, nodeCT) end
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
			if token ~= tokenSource and (not tSkipTokens or not tSkipTokens[token.getId()]) then tNewTokens[token.getId()] = token end
		end
	end

	compileTokensSkipSource(imageControl.getTokensWithinDistance(tokenSource, nRange), tCloseTokens)
	compileTokensSkipSource(ImageManager.getImageControl(tokenSource).getTokens(), tFarTokens, tCloseTokens)

	return tFarTokens
end

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

-- Should auras in range be added to this target?
function isAuraApplicable(nodeEffect, rSource, token, auraType)
	local rTarget = ActorManager.resolveActor(CombatManager.getCTFromToken(token))
	if
		checkConditionalBeforeAura(nodeEffect, ActorManager.getCTNode(rSource), ActorManager.getCTNode(rTarget))
		and DB.getValue(nodeEffect, 'isactive', 0) == 1
		and AuraFactionConditional.checkFaction(rSource, rTarget, auraType)
	then
		return true
	end
	return false
end

-- Compile sets of tokens on same map as source that should/should not have aura applied.
-- Trigger adding/removing auras as applicable.
function updateAura(tokenSource, nodeEffect, nRange, auraType)
	local imageControl = ImageManager.getImageControl(tokenSource)
	if not imageControl then return end -- only process if effect parent is on an opened map
	local tAdd, tRemove = {}, {}

	-- compile lists
	local rSource = ActorManager.resolveActor(DB.getChild(nodeEffect, '...'))
	for _, token in pairs(imageControl.getTokensWithinDistance(tokenSource, nRange)) do
		local nodeCT = CombatManager.getCTFromToken(token)
		if isAuraApplicable(nodeEffect, rSource, token, auraType) then
			tAdd[token.getId()] = { nodeEffect, nodeCT }
		else
			tRemove[token.getId()] = { nodeEffect, nodeCT }
		end
	end
	for id, token in pairs(getTokensBeyondDistance(tokenSource, nRange)) do
		local nodeCT = CombatManager.getCTFromToken(token)
		tRemove[id] = { nodeEffect, nodeCT }
	end

	-- process add/remove
	for _, v in pairs(tAdd) do
		addAura(v[1], v[2])
	end
	for _, v in pairs(tRemove) do
		removeAura(v[1], v[2])
	end
end
