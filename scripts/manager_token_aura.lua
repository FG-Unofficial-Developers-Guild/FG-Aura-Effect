local tImages = {}

local linkToken = nil

function onInit()
    if Session.IsHost then
        Token.addEventHandler('onDelete', onDelete)

        linkToken = TokenManager.linkToken
        TokenManager.linkToken = customLinkToken
    end
end

function onClose()
    if Session.IsHost then
        TokenManager.linkToken = linkToken
    end
end

function add(nodeCT)
    onAdd(CombatManager.getTokenFromCT(nodeCT))
end

function delete(nodeCT)
    onDelete(CombatManager.getTokenFromCT(nodeCT))
end

-- Workaround because Token.onAdd, the token isn't linked to the CT node yet via FG.
-- Let FG do its thing they we can track things properly
function customLinkToken(nodeCT, newTokenInstance)
    linkToken(nodeCT, newTokenInstance)
    onAdd(CombatManager.getTokenFromCT(nodeCT))
end

function onAdd(token)
    if token then
        local nodeImage = token.getContainerNode()
        local sImagePath = DB.getPath(nodeImage)
        if not tImages[sImagePath] then
            tImages[sImagePath] = {nGridSize = Image.getGridSize(nodeImage), tTokens = {}}
        end
        local nodeCT = CombatManager.getCTFromToken(token)
        if nodeCT then
            local sNodePath = DB.getPath(nodeCT)
            local nX, nY = token.getPosition()
            local nZ = token.getHeight()
            tImages[sImagePath].tTokens[sNodePath] = {nX = nX, nY = nY, nZ = nZ}
        end
    end
end

function onDelete(token)
    if token then
        local nodeImage = token.getContainerNode()
        local sImagePath = DB.getPath(nodeImage)
        if tImages[sImagePath] then
            local nodeCT = CombatManager.getCTFromToken(token)
            if nodeCT then
                if tImages[sImagePath].tTokens[nodeCT] then
                    tImages[sImagePath].tTokens[nodeCT] = nil
                    if not next(tImages[sImagePath].tTokens) then
                        tImages[sImagePath] = nil
                    end
                end
            end
        end
    end
end

-- Although the token is marked as moved, for performance reasons it needs to move more than the
-- threshold distance (at least half of grid size rounded down) to count as moved
function isMovedFilter(nodeCT, token)
    local bReturn = false
    local nodeImage = token.getContainerNode()
    local sImagePath = DB.getPath(nodeImage)

    if tImages[sImagePath] and nodeCT and Image.hasGrid(sImagePath) then
        local sNodePath = DB.getPath(nodeCT)
        local nThreshold = (math.floor(tImages[sImagePath].nGridSize - 1) / 2)
        local nX, nY = token.getPosition()
        local nZ = token.getHeight()

        if tImages[sImagePath].tTokens[sNodePath] then
            if math.abs(tImages[sImagePath].tTokens[sNodePath].nX - nX) > nThreshold or
               math.abs(tImages[sImagePath].tTokens[sNodePath].nY - nY) > nThreshold then
                tImages[sImagePath].tTokens[sNodePath].nX = nX
                tImages[sImagePath].tTokens[sNodePath].nY = nY
                tImages[sImagePath].tTokens[sNodePath].nZ = nZ
                bReturn = true
            end
        else
            tImages[sImagePath].tTokens[sNodePath].nX = nX
            tImages[sImagePath].tTokens[sNodePath].nY = nY
            tImages[sImagePath].tTokens[sNodePath].nZ = nZ
            bReturn = true
        end
    end
    return bReturn
end
