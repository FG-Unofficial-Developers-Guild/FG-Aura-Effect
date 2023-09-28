--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--

-- luacheck: globals getAllTrackedAuras addTrackedAura getTrackedAuras deleteTrackedAuras removeTrackedAura
-- luacheck: globals addTrackedFromAura getTrackedFromAuras removeTrackedFromAura printTrackedAuras

-- Constructed as such [sSourceNode][sAuraNode][sFromAuraNode]
-- [sSourceNode] - Array of nodeCT paths of the token who has an aura effect
-- [sAuraNode] - Array of effect paths of the auras which are on the [sSourceNode]
-- [sFromAuraNode] - Array of nodeCT paths which [sAuraNode] is affecting with FROMAURA
local tActiveAuras = {}

function onInit()
    -- Comm.registerSlashHandler("aura", printTrackedAuras);
end

function getAllTrackedAuras()
    return UtilityManager.copyDeep(tActiveAuras)
end

function addTrackedAura(sSourceNode, sAuraNode)
    if not tActiveAuras[sSourceNode] then
        tActiveAuras[sSourceNode] = {}
    end
    if not tActiveAuras[sSourceNode][sAuraNode] then
        tActiveAuras[sSourceNode][sAuraNode] = {}
    end
end

function getTrackedAuras(sSourceNode)
    local aReturn = {}
    if tActiveAuras[sSourceNode] then
        aReturn = UtilityManager.copyDeep(tActiveAuras[sSourceNode])
    end
    return aReturn
end

function deleteTrackedAuras(sSourceNode)
    tActiveAuras[sSourceNode] = nil
end

function removeTrackedAura(sSourceNode, sAuraNode)
    if tActiveAuras[sSourceNode] and tActiveAuras[sSourceNode][sAuraNode] then
        tActiveAuras[sSourceNode][sAuraNode] = nil
    end
    if tActiveAuras[sSourceNode] and not next(tActiveAuras[sSourceNode]) then
        tActiveAuras[sSourceNode] = nil
    end
end

function addTrackedFromAura(sSourceNode, sAuraNode, sFromAuraNode)
    addTrackedAura(sSourceNode, sAuraNode)
    if not tActiveAuras[sSourceNode][sAuraNode][sFromAuraNode] then
        tActiveAuras[sSourceNode][sAuraNode][sFromAuraNode] = true
    end
end

function getTrackedFromAuras(sSourceNode, sAuraNode)
    local aReturn = {}
    if tActiveAuras[sSourceNode] and tActiveAuras[sSourceNode][sAuraNode] then
        aReturn = UtilityManager.copyDeep(tActiveAuras[sSourceNode][sAuraNode])
    end
    return aReturn
end

function removeTrackedFromAura(sSourceNode, sAuraNode, sFromAuraNode)
    if sFromAuraNode then
        if tActiveAuras[sSourceNode] and tActiveAuras[sSourceNode][sAuraNode] then
            tActiveAuras[sSourceNode][sAuraNode][sFromAuraNode] = nil
        end
    else
        if tActiveAuras[sSourceNode] and tActiveAuras[sSourceNode][sAuraNode] then
            tActiveAuras[sSourceNode][sAuraNode] = {}
        end
    end
end

function printTrackedAuras()
    Debug.chat(tActiveAuras)
end
