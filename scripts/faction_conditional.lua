--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals bDebug getRelationship checkFaction DetectedEffectManager

bDebug = false

DetectedEffectManager = nil

function getRelationship(rActor, rTarget)
	if bDebug then Debug.chat('getRelationship:args', rActor, rTarget) end
	local sourceFaction = ActorManager.getFaction(rActor)
	local targetFaction = ActorManager.getFaction(rTarget)
	if bDebug then Debug.chat('getRelationship:factions', sourceFaction, targetFaction) end
	if sourceFaction == targetFaction then
		return 'ally' -- actors are allies when their factions match
	elseif sourceFaction == 'friend' and targetFaction == 'foe' then
		return 'enemy' -- actors are enemies when one is a friend and one is a foe
	elseif sourceFaction == 'foe' and targetFaction == 'friend' then
		return 'enemy' -- actors are enemies when one is a friend and one is a foe
	else
		return ''
	end
end

function checkFaction(rActor, rTarget, sFactionFilter)
	if bDebug then Debug.chat('checkFaction', rActor, rTarget, sFactionFilter) end
	if not rActor or not rTarget or not sFactionFilter then return false end

	local bNegate = sFactionFilter:match('[~%!]') ~= nil
	if bNegate then sFactionFilter = sFactionFilter:gsub('[~%!]', '') end

	local bReturn
	if sFactionFilter == 'notself' or (sFactionFilter == 'self' and bNegate) then
		bReturn = rActor == rTarget
	elseif sFactionFilter == 'all' then
		bReturn = true
	end

	bReturn = bReturn or StringManager.contains({ ActorManager.getFaction(rActor), getRelationship(rActor, rTarget) }, sFactionFilter:lower())
	if bNegate then bReturn = not bReturn end

	return bReturn
end

local checkConditional_old
local function checkConditional_new(rActor, nodeEffect, aConditions, rTarget, aIgnore, ...)
	if bDebug then Debug.chat('checkConditional_new', rActor, nodeEffect, aConditions, rTarget, aIgnore, ...) end
	local bReturn = checkConditional_old(rActor, nodeEffect, aConditions, rTarget, aIgnore, ...)

	-- skip faction check if conditions already aren't passing
	if bReturn == false then return bReturn end

	if aConditions and aConditions.remainder then aConditions = aConditions.remainder end
	for _, v in ipairs(aConditions) do
		local sFactionCheck = v:lower():match('^faction%s*%(([^)]+)%)$')
		if sFactionCheck then
			local rAuraSource = ActorManager.resolveActor(DB.findNode(DB.getValue(nodeEffect, 'source_name', '')))
			if not checkFaction(rActor, rAuraSource, sFactionCheck) then
				bReturn = false
				break
			end
		end
	end

	return bReturn
end

function onInit()
	-- Set up the effect manager proxy functions for the detected ruleset
	if EffectManager35E then
		DetectedEffectManager = EffectManager35E
	elseif EffectManagerPFRPG2 then
		DetectedEffectManager = EffectManagerPFRPG2
	elseif EffectManagerSFRPG then
		DetectedEffectManager = EffectManagerSFRPG
	elseif EffectManager5E then
		DetectedEffectManager = EffectManager5E
	elseif EffectManager4E then
		DetectedEffectManager = EffectManager4E
	end

	-- create proxy function to add FACTION conditional
	checkConditional_old = DetectedEffectManager.checkConditional
	DetectedEffectManager.checkConditional = checkConditional_new
end