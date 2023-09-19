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


function checkFaction(rActor, rTarget, aFactions)
	local bReturn = false
	if bDebug then Debug.chat('checkFaction:args', rActor, rTarget, aFactions) end
	if not rActor or not next(aFactions) then return false end
	local bNegate
	for _, sFaction in ipairs(aFactions) do
		bNegate = false
		if StringManager.startsWith(sFaction, '!') or StringManager.startsWith(sFaction, '~') then
			sFaction = sFaction:sub(2);
			bNegate = true
		end

		if not bNegate and sFaction == 'all' then
			bReturn = true
			break
		elseif not bNegate and StringManager.contains({ ActorManager.getFaction(rActor), getRelationship(rActor, rTarget) }, sFaction) then
			bReturn = true
			break
		elseif bNegate and not StringManager.contains({ ActorManager.getFaction(rActor), getRelationship(rActor, rTarget) }, sFaction) then
			bReturn = true
			break
		end
	end
	if bDebug then Debug.chat('checkFaction:results', bReturn, 'negation:', bNegate) end

	return bReturn
end

local function checkFactionConditional(rActor, nodeEffect, aConditions)
	if aConditions and aConditions.remainder then aConditions = aConditions.remainder end
	local rAuraSource = ActorManager.resolveActor(DB.getValue(nodeEffect, 'source_name', ''))
	for _, v in ipairs(aConditions) do
		local sFactionCheck = v:lower():match('^faction%s*%(([^)]+)%)$')
		if sFactionCheck then
			if not checkFaction(rActor, rAuraSource, {sFactionCheck}) then return false end
		end
	end
	return true
end

local checkConditional_old
local function checkConditional_new(rActor, nodeEffect, aConditions, rTarget, aIgnore, ...)
	if bDebug then Debug.chat('checkConditional_new:args', rActor, nodeEffect, aConditions, rTarget, aIgnore, ...) end

	local bReturn = checkConditional_old(rActor, nodeEffect, aConditions, rTarget, aIgnore, ...)
	if not bReturn then return bReturn end -- skip faction check if conditions already aren't passing

	return checkFactionConditional(rActor, nodeEffect, aConditions)
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
