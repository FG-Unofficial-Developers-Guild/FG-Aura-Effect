--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals bDebug updateAura addAura removeAura removeAllFromAuras isAuraApplicable
-- luacheck: globals fromAuraString auraString getAuraDetails getAuraFaction getAuraRange

bDebug = false

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'

fromAuraString = 'FROMAURA;'
auraString = 'AURA: %d+'

function getAuraFaction(sEffect)
	local auraFaction = string.match(sEffect, 'AURA:%s*[%d%.]*%s*([~%!]*%a*);')
	if not auraFaction or auraFaction == '' then auraFaction = 'all' end
	return auraFaction
end

function getAuraRange(sEffect)
	local nRange = string.match(sEffect, 'AURA:%s*([%d%.]*)%s*[~%!]*%a*;')
	nRange = tonumber(nRange or 0)
	return nRange
end

function getAuraDetails(sEffect)
	if not sEffect then return 0, 'all' end
	return getAuraRange(sEffect), getAuraFaction(sEffect)
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

-- Search for FROMAURA effects on nodeTarget where aura source matches nodeSource and source_aura is not set
-- If found, set source_aura to nodeEffect. this could be bad for users of older versions.
local function saveAuraSource(nodeEffect, nodeSource, nodeTarget)
	local sSourcePath = DB.getPath(nodeSource)
	local sEffectPath = DB.getPath(nodeEffect)
	for _, nodeTargetEffect in pairs(DB.getChildren(nodeTarget, 'effects')) do
		local sEffect = DB.getValue(nodeTargetEffect, 'label', '')
		if string.find(sEffect, fromAuraString) and DB.getValue(nodeTargetEffect, 'source_name', '') == sSourcePath then
			if not DB.getValue(nodeTargetEffect, 'source_aura') then
				DB.setValue(nodeTargetEffect, 'source_aura', 'string', sEffectPath)
			end
			break
		end
	end
end

-- Check effect nodes of nodeSource to see if they are children of nodeEffect
local function hasFromAura(nodeEffect, nodeSource)
	local sEffectPath = DB.getPath(nodeEffect)
	for _, nodeTargetEffect in pairs(DB.getChildren(DB.getPath(nodeSource) .. '.effects')) do
		if DB.getValue(nodeTargetEffect, 'source_aura', '') == sEffectPath then return true end
	end
	return false
end

-- Add AURA in nodeEffect to targetToken actor if not already present.
-- Then call saveAuraSource to keep track of the FROMAURA effect
function addAura(nodeEffect, nodeTarget)
	local auraType = getAuraFaction(DB.getValue(nodeEffect, 'label', ''))
	local nodeSource = DB.getChild(nodeEffect, '...')
	if not nodeSource or not nodeTarget then return end
	if hasFromAura(nodeEffect, nodeTarget) then return end
	AuraEffectSilencer.notifyApply(buildFromAura(nodeEffect), DB.getPath(nodeTarget), auraType)
	saveAuraSource(nodeEffect, nodeSource, nodeTarget)
end

-- Search all effects on target to find matching auras to remove.
-- Skip "off/skip" effects to allow for immunity workaround.
function removeAura(nodeEffect, nodeTarget)
	if not nodeEffect or not nodeTarget then return end
	local auraType = getAuraFaction(DB.getValue(nodeEffect, 'label', ''))
	local sEffectPath = DB.getPath(nodeEffect)
	for _, nodeTargetEffect in pairs(DB.getChildren(nodeTarget, 'effects')) do
		if DB.getValue(nodeTargetEffect, 'isactive', 0) == 1 and DB.getValue(nodeTargetEffect, 'source_aura', '') == sEffectPath then
			AuraEffectSilencer.notifyExpire(nodeTargetEffect, nil, nil, auraType)
			break
		end
	end
end

-- Search all effects on target to find matching auras to remove.
function removeAllFromAuras(nodeEffect)
	local sEffect = DB.getValue(nodeEffect, 'label', '')
	if not string.find(sEffect, auraString) then return end
	local nodeSource = DB.getChild(nodeEffect, '...')
	local _, winSource = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeSource))
	for _, nodeCT in pairs(CombatManager.getCombatantNodes()) do
		if nodeCT ~= nodeSource then -- don't check for FROMAURAs on parent of nodeEffect
			local _, winTarget = ImageManager.getImageControl(CombatManager.getTokenFromCT(nodeCT))
			if winTarget == winSource then AuraEffect.removeAura(nodeEffect, nodeCT) end
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
			-- Check conditionals
			if rEffectComp.type == 'AURA' then
				return true
			elseif rEffectComp.type == 'IF' then
				local rActor = ActorManager.resolveActor(nodeCT) -- these are in here for performance reasons
				if not AuraFactionConditional.DetectedEffectManager.checkConditional(rActor, nodeEffect, rEffectComp.remainder) then return false end
			elseif rEffectComp.type == 'IFT' then
				local rActor = ActorManager.resolveActor(nodeCT) -- these are in here for performance reasons
				local rTarget = ActorManager.resolveActor(targetNodeCT) -- these are in here for performance reasons
				if
					rTarget and not AuraFactionConditional.DetectedEffectManager.checkConditional(rTarget, nodeEffect, rEffectComp.remainder, rActor)
				then
					return false
				end
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
function updateAura(tokenSource, nodeEffect, nRange)
	local sAuraFaction = getAuraFaction(DB.getValue(nodeEffect, 'label', ''))
	local imageControl = ImageManager.getImageControl(tokenSource)
	if not imageControl then return end -- only process if effect parent is on an opened map
	local tAdd, tRemove = {}, {}

	-- compile lists
	local rSource = ActorManager.resolveActor(DB.getChild(nodeEffect, '...'))
	for _, token in pairs(imageControl.getTokensWithinDistance(tokenSource, nRange)) do
		local nodeCT = CombatManager.getCTFromToken(token)
		if isAuraApplicable(nodeEffect, rSource, token, sAuraFaction) then
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
