--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals AuraEffect registerHelper registerDescriptorMatch registerIsApplicable processDescriptor
-- luacheck: globals isAuraApplicable isHex
local aCustomDescriptors = {}
local rCustomTable = {aDescriptors = {}, fCustomMatch = nil, fCustomApplicable = nil}

local function registerHelper(sIdentifier)
    if not sIdentifier or AuraEffect.isBaseDetail(sIdentifier) then
        return false
    end
    if not aCustomDescriptors[sIdentifier] then
        aCustomDescriptors[sIdentifier] = UtilityManager.copyDeep(rCustomTable)
    end
    return true
end

-- Register custom descriptor match function. This is only needed if you need to do a partial name match
-- or for something like Aura Visualized, to match the hex string. There is a hex string match in this file
-- that is available
--
-- fCustomMatch(sDescriptorClean, bNot)
--     sDescriptorClean - the descriptor sanitized, lowered and stripped of any not
--     bNot - indicates if this descriptor has a NOT if for some reason you need that information here
--     Return true if you would like to process/use this descriptor later else return false
function registerDescriptorMatch(sIdentifier, fCustomMatch)
    if not registerHelper(sIdentifier) or not fCustomMatch then
        return
    end
    aCustomDescriptors[sIdentifier].fCustomMatch = fCustomMatch
end

-- Register custom isApplicable function. Used to determine if an applied aura should be applied
-- to rTarget. Descriptors that match what was registered for are available in rAuraDetails.<sIdentifier>
-- where <sIdentifier> is the identifier used to register custom descriptors

-- fCustomApplicable(nodeEffect, rSource, rTarget, rAuraDetails)
--    nodeEffect - DB node of the AURA effect
--    rSource -- Actor nodeEffect is on
--    rTarget -- Actor to determine if an applied effect should be added
--    rAuraDetails - Metadata about the AURA. Descriptors that match what was registered for are available in rAuraDetails.<sIdentifier>
--               where <sIdentifier> is the identifier used to register custom descriptors
--     Return false if the applied aura should NOT be applied to rTarget else return true
function registerIsApplicable(sIdentifier, fCustomApplicable)
    if not registerHelper(sIdentifier) or not fCustomApplicable then
        return
    end
    aCustomDescriptors[sIdentifier].fCustomApplicable = fCustomApplicable
end

-- Register custom descriptors that you are interested in and can be processed later. Only register
-- non-not descriptors, the NOT version will match automaticlly. These are exact matches. If you need
-- a non-exact match, you'll need to write your own match function and register it with AuraAPI.registerDescriptorMatch

-- sIdentifier - is your custom identifier used to register custom descriptors. This can be anything except
--               what is defined in AuraEffect.rBaseDetails
-- sDescriptor - is a descriptor to register, or an array of descriptors to register
function registerDescriptors(sIdentifier, sDescriptor)
    if not registerHelper(sIdentifier) or not sDescriptor then
        return
    end

    if type(sDescriptor) == 'table' then
        for _, sTableDescriptor in ipairs(sDescriptor) do
            sTableDescriptor = StringManager.trim(sTableDescriptor:lower())
            table.insert(aCustomDescriptors[sIdentifier].aDescriptors, sTableDescriptor)
        end
    else
        local sCleanDescriptor = StringManager.trim(sDescriptor:lower())
        table.insert(aCustomDescriptors[sIdentifier].aDescriptors, sCleanDescriptor)
    end
end

-- Internal. Used  to process custom descriptor match
function processDescriptor(sDescriptorClean, bNot)
    local sReturn = false
    for sIdentifier, rCustom in pairs(aCustomDescriptors) do
        if (StringManager.contains(rCustom.aDescriptors, sDescriptorClean) or
                (rCustom.fCustomMatch and rCustom.fCustomMatch(sDescriptorClean, bNot))) then
            sReturn = sIdentifier
            break
        end
    end
    return sReturn
end


-- Internal. Used  to process custom isApplicable
function isAuraApplicable(nodeEffect, rSource, rTarget, rAuraDetails)
    local bReturn = true
    for _, rTable in pairs(aCustomDescriptors) do
        if rTable.fCustomApplicable and not rTable.fCustomApplicable(nodeEffect, rSource, rTarget, rAuraDetails) then
            bReturn = false
            break
        end
    end
    return bReturn
end

-- match on 8 char hex string
function isHex(sDescriptor)
    local bReturn
    if sDescriptor:match('^%x%x%x%x%x%x%x%x$') then
        bReturn = true
    end
    return bReturn
end
