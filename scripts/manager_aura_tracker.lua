--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals getAllTrackedAuras addTrackedAura getTrackedAuras deleteTrackedAuras removeTrackedAura
-- luacheck: globals addTrackedFromAura getTrackedFromAuras removeTrackedFromAura printTrackedAuras getAuraTrackerPaths
-- luacheck: globals addOncePerTurn clearOncePerTurn getAuraEffects checkOncePerTurn

-- Constructed as such [sSource][sAura][sTarget]
-- [sSource] - Array of nodeCT paths of the token who has an aura effect
-- [sAura] - Array of effect paths of the auras which are on the [sSource]
-- [sTarget] - Array of nodeCT paths which [sAura] is affecting with FROMAURA
local tActiveAuras = {}
local tAuraOncePerTurn = {}

--Convience. Converts nodes to paths if needed
function getAuraTrackerPaths(nodeSource, nodeEffect, nodeTarget)
	local sSource, sEffect, sTarget
	if type(nodeSource) == 'databasenode' then
		sSource = DB.getPath(nodeSource)
	else
		sSource = nodeSource
	end
	if type(nodeTarget) == 'databasenode' then
		sTarget = DB.getPath(nodeTarget)
	else
		sTarget = nodeTarget
	end
	if type(nodeEffect) == 'databasenode' then
		sEffect = DB.getPath(nodeEffect)
	else
		sEffect = nodeEffect
	end
	return sSource, sEffect, sTarget
end

--Get a copy of the aura tracker table
function getAllTrackedAuras()
	return UtilityManager.copyDeep(tActiveAuras)
end

-- Add an aura to be tracked
function addTrackedAura(nodeSource, nodeEffect)
	local sSource, sAura = AuraTracker.getAuraTrackerPaths(nodeSource, nodeEffect)
	if not tActiveAuras[sSource] then
		tActiveAuras[sSource] = {}
	end
	if not tActiveAuras[sSource][sAura] then
		tActiveAuras[sSource][sAura] = {}
	end
end

-- get tracked aura paths for a node
function getTrackedAuras(nodeSource)
	local sSource = AuraTracker.getAuraTrackerPaths(nodeSource)
	local aReturn = {}
	if tActiveAuras[sSource] then
		aReturn = UtilityManager.copyDeep(tActiveAuras[sSource])
	end
	return aReturn
end

-- delete tracked aura paths for a node
function deleteTrackedAuras(nodeSource)
	local sSource = AuraTracker.getAuraTrackerPaths(nodeSource)
	tActiveAuras[sSource] = nil
end

-- remove a specific tracked aura for a node
function removeTrackedAura(nodeSource, nodeEffect)
	local sSource, sAura = AuraTracker.getAuraTrackerPaths(nodeSource, nodeEffect)
	if tActiveAuras[sSource] and tActiveAuras[sSource][sAura] then
		tActiveAuras[sSource][sAura] = nil
	end
	if tActiveAuras[sSource] and not next(tActiveAuras[sSource]) then
		tActiveAuras[sSource] = nil
	end
end

-- add a fromaura to track
function addTrackedFromAura(nodeSource, nodeEffect, nodeTarget)
	local sSource, sAura, sTarget = AuraTracker.getAuraTrackerPaths(nodeSource, nodeEffect, nodeTarget)
	AuraTracker.addTrackedAura(sSource, sAura)
	if not tActiveAuras[sSource][sAura][sTarget] then
		tActiveAuras[sSource][sAura][sTarget] = true
	end
end

-- get fromauras that are a result of nodeEffect
function getTrackedFromAuras(nodeSource, nodeEffect)
	local sSource, sAura = AuraTracker.getAuraTrackerPaths(nodeSource, nodeEffect)
	local aReturn = {}
	if tActiveAuras[sSource] and tActiveAuras[sSource][sAura] then
		aReturn = UtilityManager.copyDeep(tActiveAuras[sSource][sAura])
	end
	return aReturn
end

-- delete specific tracked fromauras
function removeTrackedFromAura(nodeSource, nodeEffect, nodeTarget)
	local sSource, sAura, sTarget = AuraTracker.getAuraTrackerPaths(nodeSource, nodeEffect, nodeTarget)
	if sTarget then
		if tActiveAuras[sSource] and tActiveAuras[sSource][sAura] then
			tActiveAuras[sSource][sAura][sTarget] = nil
		end
	else
		if tActiveAuras[sSource] and tActiveAuras[sSource][sAura] then
			tActiveAuras[sSource][sAura] = {}
		end
	end
end

-- Return a table of all aura effects for a CT node
function getAuraEffects(nodeCT)
	local sPath = DB.getPath(nodeCT)
	local aReturn = {}
	if sPath and tActiveAuras[sPath] then
		for sEffectPath, _ in pairs(tActiveAuras[sPath]) do
			table.insert(aReturn, DB.findNode(sEffectPath))
		end
	end
	return aReturn
end

------- Once Per Turn Tracking -------

-- SINGLE/ONCE  aura type clear once per turn tracking
function clearOncePerTurn()
	tAuraOncePerTurn = {}
end

-- SINGLE/ONCE  aura type aura effected target this turn
function addOncePerTurn(nodeSource, nodeEffect, nodeTarget)
	local sSource, sEffect, sTarget = AuraTracker.getAuraTrackerPaths(nodeSource, nodeEffect, nodeTarget)
	if not tAuraOncePerTurn[sTarget] then
		tAuraOncePerTurn[sTarget] = {}
	end
	if not tAuraOncePerTurn[sTarget][sSource] then
		tAuraOncePerTurn[sTarget][sSource] = {}
	end
	tAuraOncePerTurn[sTarget][sSource][sEffect] = true
end

-- SINGLE/ONCE aura type check if aura effected target this turn
function checkOncePerTurn(nodeSource, nodeEffect, nodeTarget)
	local sSource, sEffect, sTarget = AuraTracker.getAuraTrackerPaths(nodeSource, nodeEffect, nodeTarget)
	local bReturn = false
	if tAuraOncePerTurn[sTarget] and tAuraOncePerTurn[sTarget][sSource] and tAuraOncePerTurn[sTarget][sSource][sEffect] then
		bReturn = true
	end
	return bReturn
end

function onInit()
	-- Comm.registerSlashHandler("aura", printTrackedAuras);
end

--Debugging to see the tracker table
function printTrackedAuras()
	Debug.chat(tActiveAuras)
end
