--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals bDebug getRelationship DetectedEffectManager hasFaction customCheckConditional customParseWords
bDebug = false

DetectedEffectManager = nil

function getRelationship(rActor, rTarget)
	if bDebug then
		Debug.chat('getRelationship:args', rActor, rTarget)
	end
	local sourceFaction = ActorManager.getFaction(rActor)
	local targetFaction = ActorManager.getFaction(rTarget)
	if bDebug then
		Debug.chat('getRelationship:factions', sourceFaction, targetFaction)
	end
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

function hasFaction(rActor, sFaction, rTarget, nodeEffect)
	local bReturn = false
	local bNegate = false
	local sTargetFaction
	local sTargetNode
	local aFactions = StringManager.splitByPattern(sFaction, '%s*,%s*', true)
	local sNodeEffectSource = DB.getValue(nodeEffect, 'source_name', '')
	if sNodeEffectSource == '' then
		sNodeEffectSource = DB.getPath(DB.getChild(nodeEffect, '...'))
	end
	-- If there is a target IFT. No Target IF
	if rTarget then
		sTargetNode = rTarget.sCTNode
		sTargetFaction = ActorManager.getFaction(rTarget)
	else
		sTargetNode = rActor.sCTNode
		sTargetFaction = ActorManager.getFaction(rActor)
	end
	for _, sFactionElement in ipairs(aFactions) do
		if StringManager.startsWith(sFactionElement, '!') or StringManager.startsWith(sFactionElement, '~') then
			sFactionElement = sFactionElement:sub(2)
			bNegate = true
		end
		if sFactionElement == 'all' then
			bReturn = true
			break
		end
		if
			sFactionElement == 'notself' and ((not bNegate and sTargetNode ~= sNodeEffectSource) or (bNegate and sTargetNode == sNodeEffectSource))
		then
			bReturn = true
			break
		end
		if sFactionElement == 'self' and ((not bNegate and sTargetNode == sNodeEffectSource) or (bNegate and sTargetNode ~= sNodeEffectSource)) then
			bReturn = true
			break
		end
		if sFactionElement == 'ally' or sFactionElement == 'enemy' then
			local sFactionRelationship = getRelationship(rActor, rTarget)
			if (not bNegate and sFactionElement == sFactionRelationship) or (bNegate and sFactionElement ~= sFactionRelationship) then
				bReturn = true
				break
			end
		end
		if
			(sFactionElement == 'foe' or sFactionElement == 'friend' or sFactionElement == 'neutral')
			and ((not bNegate and sFactionElement == sTargetFaction) or (bNegate and sFactionElement ~= sTargetFaction))
		then
			bReturn = true
			break
		end
		if sFactionElement == 'none' and ((not bNegate and sTargetFaction == '') or (bNegate and sTargetFaction ~= '')) then
			bReturn = true
			break
		end
	end
	return bReturn
end

local checkConditional_old
-- NOTE: 4E aConditions is a rEffectComp
function customCheckConditional(rActor, nodeEffect, aConditions, rTarget, aIgnore)
	local bReturn = checkConditional_old(rActor, nodeEffect, aConditions, rTarget, aIgnore)
	if bReturn then
		local aCondHelper
		if EffectManager4E then
			aCondHelper = aConditions.remainder
		else
			aCondHelper = aConditions
		end

		for _, v in ipairs(aCondHelper) do
			local sLower = v:lower()
			local bNegate = false
			if StringManager.startsWith(sLower, '!') or StringManager.startsWith(sLower, '~') then
				sLower = sLower:sub(2)
				bNegate = true
			end
			local sFaction = sLower:match('^faction%s*%(([^)]+)%)$')

			if sFaction then
				local bHasFaction = hasFaction(rActor, sFaction, rTarget, nodeEffect)
				if (not bNegate and not bHasFaction) or (bNegate and bHasFaction) then
					bReturn = false
					break
				end
			end
		end
	end
	return bReturn
end

local parseWordsOriginal
function customParseWords(s, extra_delimiters)
	local sDelim = ''
	if extra_delimiters then
		if not extra_delimiters:match('!') then
			sDelim = sDelim .. '!'
		end
		if not extra_delimiters:match('~') then
			sDelim = sDelim .. '~'
		end
		sDelim = sDelim .. extra_delimiters
	else
		sDelim = '!~'
	end
	return parseWordsOriginal(s, sDelim)
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
		DetectedEffectManager.parseEffectComp = EffectManager.parseEffectCompSimple
	end

	parseWordsOriginal = StringManager.parseWords
	StringManager.parseWords = customParseWords

	-- create proxy function to add FACTION conditional
	checkConditional_old = DetectedEffectManager.checkConditional
	DetectedEffectManager.checkConditional = customCheckConditional
end
