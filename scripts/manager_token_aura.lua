--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals add delete customLinkToken onAdd onDelete isMovedFilter getTokensWithinCube
-- luacheck: globals Image.getGridSize Image.hasGrid Image.getDistanceBaseUnits getTokensWithinSphere
local tImages = {}
local linkToken = nil

function add(nodeCT)
	AuraToken.onAdd(CombatManager.getTokenFromCT(nodeCT))
end

function delete(nodeCT)
	AuraToken.onDelete(CombatManager.getTokenFromCT(nodeCT))
end

-- Workaround because Token.onAdd, the token isn't linked to the CT node yet via FG.
-- Let FG do its thing they we can track things properly
function customLinkToken(nodeCT, newTokenInstance)
	linkToken(nodeCT, newTokenInstance)
	AuraToken.onAdd(CombatManager.getTokenFromCT(nodeCT))
end

function onAdd(token)
	if token then
		local nodeImage = token.getContainerNode()
		local sImagePath = DB.getPath(nodeImage)
		if not tImages[sImagePath] then
			tImages[sImagePath] = { nGridSize = Image.getGridSize(nodeImage), tTokens = {} }
		end
		local nodeCT = CombatManager.getCTFromToken(token)
		if nodeCT then
			local sNodePath = DB.getPath(nodeCT)
			local nX, nY = token.getPosition()
			local nZ = token.getHeight()
			tImages[sImagePath].tTokens[sNodePath] = { nX = nX, nY = nY, nZ = nZ }
		end
	end
end

function onDelete(token)
	if token then
		local nodeImage = token.getContainerNode()
		local sImagePath = DB.getPath(nodeImage)
		if tImages[sImagePath] then
			local nodeCT = CombatManager.getCTFromToken(token)
			if nodeCT and tImages[sImagePath].tTokens[nodeCT] then
				tImages[sImagePath].tTokens[nodeCT] = nil
				if not next(tImages[sImagePath].tTokens) then
					tImages[sImagePath] = nil
				end
			end
		end
	end
end

-- Although the token is marked as moved, for performance reasons it needs to move more than the
-- threshold distance (at least half of grid size rounded down) to count as moved
function isMovedFilter(sNodeCT, token)
	local bReturn = false
	local nodeImage = token.getContainerNode()
	local sImagePath = DB.getPath(nodeImage)
	if not tImages[sImagePath] or not tImages[sImagePath].tTokens[sNodeCT] then
		AuraToken.onAdd(token)
	end

	if tImages[sImagePath] and sNodeCT then
		local nThreshold = (math.floor(tImages[sImagePath].nGridSize - 1) / 2)
		local nX, nY = token.getPosition()
		local nZ = token.getHeight()

		if tImages[sImagePath].tTokens[sNodeCT] then
			if
				math.abs(tImages[sImagePath].tTokens[sNodeCT].nX - nX) > nThreshold
				or math.abs(tImages[sImagePath].tTokens[sNodeCT].nY - nY) > nThreshold
				or tImages[sImagePath].tTokens[sNodeCT].nZ ~= nZ
			then
				tImages[sImagePath].tTokens[sNodeCT].nX = nX
				tImages[sImagePath].tTokens[sNodeCT].nY = nY
				tImages[sImagePath].tTokens[sNodeCT].nZ = nZ
				bReturn = true
			end
		else
			tImages[sImagePath].tTokens[sNodeCT].nX = nX
			tImages[sImagePath].tTokens[sNodeCT].nY = nY
			tImages[sImagePath].tTokens[sNodeCT].nZ = nZ
			bReturn = true
		end
	end
	return bReturn
end

function getTokensWithinCube(tokenSource, nSideLength)
	local aReturn = {}
	local imageCtl = ImageManager.getImageControl(tokenSource)
	local nodeImage = tokenSource.getContainerNode()
	local nX, nY = tokenSource.getPosition()
	local nZ = tokenSource.getHeight()
	local nSideLengthPx = math.max(Image.getGridSize(nodeImage) / Image.getDistanceBaseUnits(nodeImage)) * math.max(nSideLength / 2)
	local aX = { nX1 = nX + nSideLengthPx, nX2 = nX - nSideLengthPx }
	local aY = { nY1 = nY + nSideLengthPx, nY2 = nY - nSideLengthPx }
	local aZ = { nZ1 = nZ + nSideLengthPx, nZ2 = nZ - nSideLengthPx }
	for _, token in pairs(imageCtl.getTokensWithinDistance(tokenSource, nSideLength)) do
		local nTokenX, nTokenY = token.getPosition()
		local nTokenZ = token.getHeight()

		if nTokenX <= aX.nX1 and nTokenX >= aX.nX2 and nTokenY <= aY.nY1 and nTokenY >= aY.nY2 and nTokenZ <= aZ.nZ1 and nTokenZ >= aZ.nZ2 then
			table.insert(aReturn, token)
		end
	end
	return aReturn
end

-- Need because depending on what the diagDistance is set at, imageCtl.getTokensWithinDistance may not return tokens as expected.
-- If the diagDistance is set to 1, then we will really be getting a cube. This is mostly needed for 5E but is also useful for other
-- rulesets where one wants to sphere to calculate raw rather than based on whatever diagDistance is set to.
function getTokensWithinSphere(tokenSource, nRadius, bPoint)
	local aReturn = {}
	local imageCtl = ImageManager.getImageControl(tokenSource)
	local nodeImage = tokenSource.getContainerNode()
	local nRadiusPx = Image.getGridSize(nodeImage) / Image.getDistanceBaseUnits(nodeImage) * nRadius
	local aTokens
	local nX, nY = tokenSource.getPosition()
	local nZ = tokenSource.getHeight()
	if bPoint then
		aTokens = imageCtl.getTokensWithinDistance({ nX, nY, nZ }, nRadius)
	else
		aTokens = imageCtl.getTokensWithinDistance(tokenSource, nRadius)
		local nTokenSize, _ = tokenSource.getSize()
		nRadiusPx = nRadiusPx + nTokenSize / 2
	end
	for _, token in pairs(aTokens) do
		if token.getId() ~= tokenSource.getId() then
			local nTokenX, nTokenY = token.getPosition()
			local nTokenZ = token.getHeight()
			local nDistanceVector = math.sqrt((nX - nTokenX) * (nX - nTokenX) + (nY - nTokenY) * (nY - nTokenY) + (nZ - nTokenZ) * (nZ - nTokenZ))
			if nDistanceVector <= nRadiusPx then
				table.insert(aReturn, token)
			end
		end
	end
	return aReturn
end

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
