--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals bDebug AuraEffect updateAura addAura removeAura removeAllFromAuras isAuraApplicable
-- luacheck: globals auraString getAuraDetails AuraFactionConditional.isNot
-- luacheck: globals AuraFactionConditional.DetectedEffectManager.parseEffectComp AuraFactionConditional.DetectedEffectManager.checkConditional
-- luacheck: globals AuraTracker AuraAPI AuraToken getPathsOncePerTurn isBaseDetail checkDying isCreatureSize isCreatureType isAlignment
bDebug = false

OOB_MSGTYPE_AURATOKENMOVE = 'aurasontokenmove'
-- Tracks rAuraDetails, reserved fields so they don't get overwritten by API. Keep up to date
local aReservedDetails = {
	'bSingle',
	'bCube',
	'bSticky',
	'bOnce',
	'bPoint',
	'bDying',
	'bSelf',
	'bLegacy',
	'nRange',
	'sEffect',
	'sSource',
	'sAuraNode',
	'aFactions',
	'aAlignment',
	'aCreatureType',
	'aCreatureSize',
	'aDefined',
	'aOther'
}

local rBaseDetails = {
	bSingle = false,
	bCube = false,
	bSticky = false,
	bOnce = false,
	bPoint = false,
	bDying =  false,
	bSelf = true,
	bLegacy = true,
	nRange = 0,
	sEffect = '',
	sSource = '',
	sAuraNode = '',
	aFactions = {},
	aAlignment = {},
	aCreatureType = {},
	aCreatureSize = {},
	aDefined = {},
	aOther = {}
}

auraString = 'AURA: %d+'

local aAuraAlignment = {
	'lawful',
	'chaotic',
	'good',
	'evil',
	'l',
	'c',
	'g',
	'e',
	'n',
	'lg',
	'ln',
	'le',
	'ng',
	'ne',
	'cg',
	'cn',
	'ce'
}

local aAuraCreatureType = {}
local aAuraCreatureSize = {}
local aAuraFactions = { 'ally', 'enemy', 'friend', 'foe', 'all', 'neutral', 'none' }
local aDefinedDescriptors = { 'dying', 'self', 'notself' } -- Other descriptors aura uses but don't need to be grouped

-- Checks AURA effect string common needed information
function getAuraDetails(nodeEffect)
	local rAuraDetails = UtilityManager.copyDeep(rBaseDetails)

	if not AuraFactionConditional.DetectedEffectManager.parseEffectComp then
		return rAuraDetails
	end

	rAuraDetails.sEffect = DB.getValue(nodeEffect, 'label', '')
	for _, sEffectComp in ipairs(EffectManager.parseEffect(rAuraDetails.sEffect)) do
		local rEffectComp = AuraFactionConditional.DetectedEffectManager.parseEffectComp(sEffectComp)

		if rEffectComp.type:upper() == 'AURA' then
			rAuraDetails.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
			rAuraDetails.sAuraNode = DB.getPath(nodeEffect)
			AuraTracker.addTrackedAura(rAuraDetails.sSource, rAuraDetails.sAuraNode)
			rAuraDetails.nRange = rEffectComp.mod
			for _, sFilter in ipairs(rEffectComp.remainder) do
				sFilter = sFilter:lower()
				if sFilter == 'single' then
					rAuraDetails.bSingle = true
				elseif sFilter == 'cube' then
					rAuraDetails.bCube = true
				elseif sFilter == 'sticky' then
					rAuraDetails.bSticky = true
				elseif sFilter == 'once' then
					rAuraDetails.bOnce = true
				elseif sFilter == 'point' then
					rAuraDetails.bPoint = true
				else
					local bNot, sFilterCheck = AuraFactionConditional.isNot(sFilter)
					if StringManager.contains(aAuraFactions, sFilterCheck) then
						table.insert(rAuraDetails.aFactions, sFilter)
					elseif StringManager.contains(aDefinedDescriptors, sFilterCheck) then
						table.insert(rAuraDetails.aDefined, sFilter)
						if (sFilterCheck == 'self' and bNot) or (sFilterCheck == 'notself' and not bNot) then
							rAuraDetails.bSelf = false
						end
					elseif StringManager.contains(aAuraAlignment, sFilterCheck) then
						table.insert(rAuraDetails.aAlignment, sFilter)
					elseif StringManager.contains(aAuraCreatureType, sFilterCheck) then
						table.insert(rAuraDetails.aCreatureType, sFilter)
					elseif StringManager.contains(aAuraCreatureSize, sFilterCheck) then
						table.insert(rAuraDetails.aCreatureSize, sFilter)
					else
						local sKey = AuraAPI.processDescriptor(sFilterCheck, bNot)
						if sKey then
							if not rAuraDetails[sKey] then
								rAuraDetails[sKey] = {}
							end
							table.insert(rAuraDetails[sKey], sFilter)
						else
							table.insert(rAuraDetails.aOther, sFilter)
						end
					end
				end
			end
			break
		end
	end
	if not next(rAuraDetails.aFactions) then
		table.insert(rAuraDetails.aFactions, 'all')
	end
	return rAuraDetails
end

-- Sets up FROMAURA rEffect based on supplied AURA nodeEffect.
local function buildFromAura(rAuraDetails, nodeEffect)
	if rAuraDetails.rEffect then
		return rAuraDetails.rEffect;
	end
	local applyLabel = string.match(DB.getValue(nodeEffect, 'label', ''), auraString .. '.-;%s*(.*)$')
	if not applyLabel then
		rAuraDetails.bLegacy = false
		return nil
	end

	rAuraDetails.rEffect = {}
	rAuraDetails.rEffect.nDuration = 0
	rAuraDetails.rEffect.nGMOnly = DB.getValue(nodeEffect, 'isgmonly', 0)
	rAuraDetails.rEffect.nInit = DB.getValue(nodeEffect, 'init', 0)
	rAuraDetails.rEffect.sName = applyLabel
	rAuraDetails.rEffect.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
	rAuraDetails.rEffect.sAuraSource = DB.getPath(nodeEffect)
	rAuraDetails.rEffect.sUnits = DB.getValue(nodeEffect, 'unit', '')
	return rAuraDetails.rEffect
end

local function getAppliedAuraFromCustomEffects(rAuraDetails, nodeEffect)
	-- If we found and search, don't search again
	if rAuraDetails.rEffect then
		return rAuraDetails.rEffect
	end

	-- If we have BCE/BCEG grab the effect from the binary search for efficiency reasons
	local rEffect
	if  BCEManager then
		for _, sEffect in ipairs(rAuraDetails.aOther) do
			rEffect = BCEManager.matchEffect(sEffect)
			if next(rEffect) then
				rEffect.sAuraSource = DB.getPath(nodeEffect)
				rEffect.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
				rAuraDetails.rEffect = rEffect
				break
			end
		end
	else
		for _, nodeSearchEffect in pairs(DB.getChildrenGlobal('effects')) do
			local aEffectComps = EffectManager.parseEffect(DB.getValue(nodeSearchEffect, 'label', ''):lower())
			if next(aEffectComps) then
				if StringManager.contains(rAuraDetails.aOther, aEffectComps[1]) then
					rEffect = EffectManager.getEffect(nodeSearchEffect)
					rEffect.sAuraSource = DB.getPath(nodeEffect)
					rEffect.sSource = DB.getPath(DB.getChild(nodeEffect, '...'))
					rAuraDetails.rEffect = rEffect
					break
				end
			end
		end
	end
	return rAuraDetails.rEffect
end

-- Check effect nodes of nodeSource to see if they are children of nodeEffect
local function hasFromAura(nodeEffect, nodeSource)
	if type(nodeEffect) == 'databasenode' then
		local sEffectPath = DB.getPath(nodeEffect)
		for _, nodeTargetEffect in ipairs(DB.getChildList(nodeSource, 'effects')) do
			if DB.getValue(nodeTargetEffect, 'source_aura', '') == sEffectPath then
				return true
			end
		end
	end
	return false
end

function isBaseDetail(sName)
	local bReturn = false
	if sName and StringManager.contains(aReservedDetails, sName) then
		bReturn = true
	end
	return bReturn
end

-- Add AURA in nodeEffect to targetToken actor if not already present.
-- Then call saveAuraSource to keep track of the FROMAURA effect
function addAura(nodeEffect, nodeTarget, rAuraDetails)
	if type(nodeEffect) == 'databasenode' then
		local nodeSource = DB.findNode(rAuraDetails.sSource)
		if not nodeSource or not nodeTarget or not nodeEffect then
			return
		end
		if hasFromAura(nodeEffect, nodeTarget) then
			return
		end
		local rEffectAura = buildFromAura(rAuraDetails, nodeEffect)
		if not rEffectAura then
			rEffectAura = getAppliedAuraFromCustomEffects(rAuraDetails, nodeEffect)
			if not rEffectAura then
				return -- not found
			end
		end
		local sNodeTarget = DB.getPath(nodeTarget)
		if sNodeTarget ~= rAuraDetails.sSource or (rAuraDetails.bSelf and not rAuraDetails.bLegacy) then
			AuraTracker.addTrackedFromAura(rAuraDetails.sSource, rAuraDetails.sAuraNode, sNodeTarget)
			AuraEffectSilencer.notifyApply(rEffectAura,sNodeTarget)
		end
	end
end

-- Search all effects on target to find matching auras to remove.
-- Skip "off/skip" effects to allow for immunity workaround.
function removeAura(nodeEffect, nodeTarget, rAuraDetails)
	if not nodeEffect or not nodeTarget then
		return
	end
	local sNodeTarget = DB.getPath(nodeTarget)
	if sNodeTarget == '' then
		sNodeTarget = rAuraDetails.sSource
	end
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
	if not string.find(rAuraDetails.sEffect, auraString) then
		return
	end
	local aFromAuraNodes = AuraTracker.getTrackedFromAuras(rAuraDetails.sSource, rAuraDetails.sAuraNode)
	for sNodeCT, _ in pairs(aFromAuraNodes) do
		local nodeCT = DB.findNode(sNodeCT)
		AuraEffect.removeAura(nodeEffect, nodeCT, rAuraDetails)
	end
end

-- Check for IF/IFT conditionals blocking aura effect
local function checkConditionalBeforeAura(nodeEffect, rSource, rTarget)
	if not AuraFactionConditional.DetectedEffectManager.parseEffectComp then
		return true
	end
	for _, sEffectComp in ipairs(EffectManager.parseEffect(DB.getValue(nodeEffect, 'label', ''))) do
		local rEffectComp = AuraFactionConditional.DetectedEffectManager.parseEffectComp(sEffectComp)
		local aCondHelper
		if EffectManager4E then
			aCondHelper = rEffectComp
		else
			aCondHelper = rEffectComp.remainder
		end
		-- Check conditionals
		if rEffectComp.type == 'AURA' then
			if not AuraFactionConditional.DetectedEffectManager.checkConditional(rSource, nodeEffect, aCondHelper) then
				return false
			else
				return true
			end
		elseif rEffectComp.type == 'IF' then
			if not AuraFactionConditional.DetectedEffectManager.checkConditional(rSource, nodeEffect, aCondHelper) then
				return false
			end
		elseif rEffectComp.type == 'IFT' then
			if rTarget and not AuraFactionConditional.DetectedEffectManager.checkConditional(rTarget, nodeEffect, aCondHelper, rSource) then
				return false
			end
		end
	end
	return true
end

function isCreatureSize(rAuraDetails, rTarget)
	local bReturn = true
	if next(rAuraDetails.aCreatureSize) and rTarget then
		local a5Ruleset = {'5E', 'SFRPG', 'DCC', 'MCC'}
		local a3Ruleset = {'PFRPG', '3.5E', '4E', '13A', 'd20Modern'}
		local sRuleset =  User.getRulesetName()
		bReturn = false
		for _,sDescriptor in ipairs(rAuraDetails.aCreatureSize) do
			local bNot, sSize = AuraFactionConditional.isNot(sDescriptor)
			local bSize
			if StringManager.contains(a5Ruleset, sRuleset) then
				bSize = ActorCommonManager.isCreatureSizeDnD5(rTarget, sSize)
			elseif StringManager.contains(a3Ruleset, sRuleset) then
				bSize = ActorCommonManager.isCreatureSizeDnD3(rTarget, sSize)
			elseif sRuleset == 'PFRPG2' then
				bSize = ActorManager2.isSize(rTarget, sSize)
			elseif sRuleset == '2E' then
				bSize = ActorManagerADND.isSize(rTarget, sSize)
			end
			if (not bNot and bSize) or (not bSize and bNot) then
				bReturn = true
			end
		end
	end
	return bReturn
end

function isCreatureType(rAuraDetails, rTarget)
	local bReturn = true
	if next(rAuraDetails.aCreatureType) and rTarget then
		bReturn = false
		for _,sDescriptor in ipairs(rAuraDetails.aCreatureType) do
			local bNot, sType = AuraFactionConditional.isNot(sDescriptor)
			local bType = ActorCommonManager.isCreatureTypeDnD(rTarget, sType)
			if (not bNot and bType) or (not bType and bNot) then
				bReturn = true
			end
		end
	end
	return bReturn
end

function isAlignment(rAuraDetails, rTarget)
	local bReturn = true
	if next(rAuraDetails.aAlignment) and rTarget then
		for _,sDescriptor in ipairs(rAuraDetails.aAlignment) do
			local bNot, sAlignment = AuraFactionConditional.isNot(sDescriptor)
			local bAlign = ActorCommonManager.isCreatureAlignmentDnD(rTarget, sAlignment)
			if (bNot and bAlign) or (not bAlign and not bNot) then
				bReturn = false
				break
			end
		end
	end
	return bReturn
end

function checkDying(rAuraDetails)
	local bReturn = true
	if next(rAuraDetails.aDefined)then
		local bFilterDying = StringManager.contains(rAuraDetails.aDefined, 'dying')
		local bFilterNotDying = StringManager.contains(rAuraDetails.aDefined, '!dying') or StringManager.contains(rAuraDetails.aDefined, '~dying')

		if  bFilterDying or bFilterNotDying then
			if (not rAuraDetails.bDying and bFilterDying) or (rAuraDetails.bDying and bFilterNotDying) then
				bReturn = false
			end
		end
	end
	return bReturn
end

-- Should auras in range be added to this target?
function isAuraApplicable(nodeEffect, rSource, rTarget, rAuraDetails)
	local rAuraSource

	local sSourcePath = DB.getValue(nodeEffect, 'source_name', '')
	if sSourcePath == '' then
		rAuraSource = rSource -- Source is the Source
	else
		rAuraSource = ActorManager.resolveActor(DB.findNode(DB.getPath(DB.getChild(nodeEffect, '...'))))
	end

	local aConditions = { 'FACTION(' .. table.concat(rAuraDetails.aFactions, ',') .. ')' }
	local aCondHelper = {}
	if EffectManager4E then
		aCondHelper.remainder = aConditions
		aCondHelper.original = DB.getValue(nodeEffect, 'label')
	else
		aCondHelper = aConditions
	end

	-- self check moved futher down the pipeline
	if
		DB.getValue(nodeEffect, 'isactive', 0) == 1
		and checkConditionalBeforeAura(nodeEffect, rSource, rTarget)
		and AuraFactionConditional.DetectedEffectManager.checkConditional(rAuraSource, nodeEffect, aCondHelper, rTarget)
		and AuraEffect.checkDying(rAuraDetails)
		and AuraEffect.isAlignment(rAuraDetails, rTarget)
		and AuraEffect.isCreatureSize(rAuraDetails, rTarget)
		and AuraEffect.isCreatureType(rAuraDetails, rTarget)
		and AuraAPI.isAuraApplicable(nodeEffect, rSource, rTarget, rAuraDetails)
	then
		return true
	end
	return false
end

-- Compile sets of tokens on same map as source that should/should not have aura applied.
-- Trigger adding/removing auras as applicable.
function updateAura(tokenSource, nodeEffect, rAuraDetails, rMoved)
	local imageControl = ImageManager.getImageControl(tokenSource)
	if not imageControl then
		return
	end -- only process if effect parent is on an opened map
	local tAdd, tRemove = {}, {}
	-- compile lists
	local rSource = ActorManager.resolveActor(DB.findNode(rAuraDetails.sSource))
	local aTokens
	local aFromAuraNodes = AuraTracker.getTrackedFromAuras(rAuraDetails.sSource, rAuraDetails.sAuraNode)
	rAuraDetails.bDying = ActorHealthManager.isDyingOrDead(rSource)
	if rAuraDetails.bCube then
		aTokens = AuraToken.getTokensWithinCube(tokenSource, rAuraDetails.nRange)
	else
		local nCalcFormat = tonumber(OptionsManager.getOption('AURADISTANCE'))
		if nCalcFormat == 0 or (nCalcFormat > 0 and rAuraDetails.bPoint) then
			aTokens = AuraToken.getTokensWithinSphere(tokenSource, rAuraDetails.nRange, rAuraDetails.bPoint)
		else
			aTokens = imageControl.getTokensWithinDistance(tokenSource, rAuraDetails.nRange)
		end
		table.insert(aTokens,tokenSource)
	end
	for _, token in pairs(aTokens) do
		local nodeCTToken = CombatManager.getCTFromToken(token)
		if nodeCTToken then -- Guard against non-CT linked tokens
			local rTarget = ActorManager.resolveActor(nodeCTToken)
			aFromAuraNodes[rTarget.sCTNode] = nil -- Processed so mark as such
			if AuraEffect.isAuraApplicable(nodeEffect, rSource, rTarget, rAuraDetails) then
				if rAuraDetails.bSingle or rAuraDetails.bOnce then
					if
						not AuraTracker.checkOncePerTurn(rAuraDetails.sSource, rAuraDetails.sAuraNode, rTarget.sCTNode)
						and (rAuraDetails.bOnce or rMoved and rMoved.sCTNode == rTarget.sCTNode)
					then
						tAdd[token.getId()] = { nodeEffect, nodeCTToken }
						AuraTracker.addOncePerTurn(rAuraDetails.sSource, rAuraDetails.sAuraNode, rTarget.sCTNode)
					end
				else
					tAdd[token.getId()] = { nodeEffect, nodeCTToken }
				end
			elseif not rAuraDetails.bSticky then
				table.insert(tRemove, { nodeEffect, nodeCTToken })
			end
		end
	end

	if not rAuraDetails.bSticky then
		-- Anything left in aFromAuraNodes is out of range so remove
		for sNode, _ in pairs(aFromAuraNodes) do
			table.insert(tRemove, { nodeEffect, DB.findNode(sNode) })
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

function onInit()
	-- register option for silent aura messages
	OptionsManager.registerOption2('AURADISTANCE', false, 'option_header_aura', 'option_label_AURADISTANCE', 'option_entry_cycler', {
		labels = 'option_val_aura_ruleset',
		values = '1',
		baselabel = 'option_val_aura_raw',
		baseval = '0',
		default = '0',
	})

	if DataCommon then
		if DataCommon.creaturetype then
			aAuraCreatureType = UtilityManager.copyDeep(DataCommon.creaturetype)
		end
		if DataCommon.creaturesubtype then
			for _,sSubType in ipairs(DataCommon.creaturesubtype) do
				table.insert(aAuraCreatureType, sSubType)
			end
		end
		table.insert(aAuraCreatureType, 'humanoid')
		table.insert(aAuraCreatureType, 'human')
		if DataCommon.creaturesize then
			for sSize,_ in pairs(DataCommon.creaturesize) do
				if sSize:len() > 1 then
					table.insert(aAuraCreatureSize, sSize)
				end
			end
		end
	end
end
