--
--	Please see the LICENSE.md file included with this distribution for attribution and copyright information.
--
-- luacheck: globals add delete customLinkToken onAdd onDelete isMovedFilter
-- luacheck: globals Image.getGridSize Image.hasGrid Image.getDistanceBaseUnits getTokensWithinSphere

--new functions from SilentRuin
-- luacheck: globals getTokensWithinShape isPointInsideCylinder getBoundingSphereRadius isPointInOrientedRect3D
-- luacheck: globals isPointInSphere sphere_radius_from_cylinder

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

-- luacheck: push ignore 561
function getTokensWithinShape(bPoint, nShape, tokenSource, ngParamA, ngParamBoptional, ngParamCoptional, ngParamDoptional, ngParamEoptional)
--	Debug.console(" Aura Shape ");
	-- values with ng are in grid coords
	local aReturn = {};
	local imageCtl = ImageManager.getImageControl(tokenSource);
	local nodeImage = tokenSource.getContainerNode();
	-- use given token as center point
	local nX, nY = tokenSource.getPosition();
	local nZ = tokenSource.getHeight();
	local ngParamB;
	local ngParamC;
	local ngParamD;

	-- find tokens within max spherical search distance then determine if center point is within ORTHOGONAL (not tilted) 3D shape (sphere, cyclinder, 3Drectangle) based on parameters provided
	-- sphere (nShape = 0 (default); ngParamA = Radius)
	-- cyclinder(nShape = 1; ngParamA = Radius, ngParamB = MinHeight, ngParamC = MaxHeight, ngParamD = additional Radius)
	-- 3Drectangle (nShape = 2; ngParamA = Length, ngParamB = Width, ngParamC = MinHeight, ngParamD = MaxHeight, ngParamE = orientation)

	-- The bPoint flag tells us if the parameter distances emanate from center of the token or if the dimensions of the source token must be considered.
	-- assume token is cube with spacing all around when figuring out edge of token in 3D
	local nTokenWidth, nTokenHeight = tokenSource.getSize();
--	Debug.console(tokenSource.getSize());
--	Debug.console(Image.getGridSize(nodeImage));
--	Debug.console(Image.getDistanceBaseUnits(nodeImage));
	local nConvert = Image.getGridSize(nodeImage) /Image.getDistanceBaseUnits(nodeImage);
--	Debug.console(nConvert);
	local ngConvert = 1/nConvert;
--	Debug.console(ngConvert);
--	Debug.console(TokenManager.getTokenSpace(tokenSource));
	local ngTokenLengthAddition = (nTokenWidth + TokenManager.getTokenSpace(tokenSource)) * ngConvert;
	local ngTokenHeightAddition = (nTokenHeight + TokenManager.getTokenSpace(tokenSource))  * ngConvert;
--	Debug.console(bPoint);
--	Debug.console(nShape);
--	Debug.console(tokenSource);
--	Debug.console(ngParamA);
--	Debug.console(ngParamB);
--	Debug.console(ngParamC);
--	Debug.console(ngParamD);
--	Debug.console(nX);
--	Debug.console(nY);
--	Debug.console(nZ);

--	Debug.console(ngTokenLengthAddition);
--	Debug.console(ngTokenHeightAddition);

	-- cyclinder(nShape = 1; ngParamA = Radius, ngParamB = MinHeight, ngParamC = MaxHeight, ngParamD = additional Radius)
	if nShape == 1 then
--		Debug.console(" Cylinder ");
		-- radius
		local ngRadius = ngParamA;
--		Debug.console(ngRadius);
		-- height of cylinder
		if ngParamBoptional ~= nil and ngParamCoptional ~= nil then
			-- min/max height both must be defined
			ngParamB = ngParamBoptional;
			ngParamC = ngParamCoptional;
		else
			-- default 0 height
			ngParamB = 0;
			ngParamC = 0;
		end
		local ngHeight = ngParamC - ngParamB;
--		Debug.console(ngHeight);
		-- see if we have an outer cylinder (wall of fire as ring - has ring then 10ft in our out from where it is defined)
		local ngRadius2 = 0;
--		Debug.console(ngParamDoptional);
		if ngParamDoptional ~= nil then
			ngParamD = ngParamDoptional;
			ngRadius2 = ngParamD;
		--else
		--	ngParamD = 0;
		end
--		Debug.console(ngRadius2);
		if not bPoint then
			ngRadius = ngRadius + ngTokenLengthAddition/2;
			if ngRadius2 > 0 then
				ngRadius2 = ngRadius2 + ngTokenLengthAddition/2;
			end
			ngHeight = ngHeight + ngTokenHeightAddition;
		end
--		Debug.console(ngRadius);
--		Debug.console(ngHeight);
		local nRadiusPx = nConvert * ngRadius;
--		Debug.console(nRadiusPx);
		local nRadiusPx2 = 0;
		if ngRadius2 > 0 then
			nRadiusPx2 = nConvert * ngRadius2;
		end
--		Debug.console(nRadiusPx2);
		-- find max search distance from source token to limit number of tokens we look at
		local ngMaxSearchDist = sphere_radius_from_cylinder(ngRadius, ngHeight);
		local bParamARadiusIsOuterCylinder = true;
		if ngRadius2 > ngRadius then
			bParamARadiusIsOuterCylinder = false;
			ngMaxSearchDist = sphere_radius_from_cylinder(ngRadius2, ngHeight);
		end
--		Debug.console(ngMaxSearchDist);
--		Debug.console(bParamARadiusIsOuterCylinder);
		for _, token in pairs(imageCtl.getTokensWithinDistance(tokenSource, ngMaxSearchDist)) do
			-- Determine if token is within cyclinder
--			Debug.console(token);
--			Debug.console(DB.getValue(CombatManager.getCTFromToken(token), "name", ""));
			local nTokenX, nTokenY = token.getPosition();
			local nTokenZ = token.getHeight();
--			Debug.console(nTokenX);
--			Debug.console(nTokenY);
--			Debug.console(nTokenZ);
--			Debug.console(nX);
--			Debug.console(nY);
--			Debug.console(nRadiusPx);
--			Debug.console(ngParamB);
--			Debug.console(ngParamC);
			-- Outer cylinder Must be checked first if nRadiusPx2 is present
			-- then outer must contain point and inner must not.
			local nRadiusOuter = nRadiusPx;
			local nRadiusInner = nRadiusPx2;
			if not bParamARadiusIsOuterCylinder then
				nRadiusOuter = nRadiusPx2;
				nRadiusInner = nRadiusPx;
			end
			if isPointInsideCylinder(nTokenX, nTokenY, nTokenZ, nX, nY, nRadiusOuter, nConvert * ngParamB, nConvert * ngParamC) then
				if nRadiusInner > 0 then
					if not isPointInsideCylinder(nTokenX, nTokenY, nTokenZ, nX, nY, nRadiusInner, nConvert * ngParamB, nConvert * ngParamC) then
--						Debug.console("token added between cylinders");
						table.insert(aReturn, token);
					end
				else
--					Debug.console("token added inside cylinder");
					table.insert(aReturn, token);
				end
			end
		end

	-- 3Drectangle (nShape = 2; ngParamA = Length, ngParamB = Width, ngParamC = MinHeight, ngParamD = MaxHeight, ngParamE = orientation)
	elseif nShape == 2 then
--		Debug.console(" 3D Rectangle ");
		-- based on token source find min/max x (length), min/max y (width), and min/max z (min height and max height)
		if ngParamBoptional ~= nil then
			ngParamB = ngParamBoptional;
		else
			-- if width not defined default to length
			ngParamB = ngParamA;
		end
		local length = nConvert * ngParamA;
--		Debug.console(length);
		local width = nConvert * ngParamB;
--		Debug.console(width);
		if ngParamCoptional ~= nil and ngParamDoptional ~= nil then
			-- min/max height both must be defined
			ngParamC = ngParamCoptional;
			ngParamD = ngParamDoptional;
		else
			-- default 0 height
			ngParamC = 0;
			ngParamD = 0;
		end
--		Debug.console(ngParamC);
--		Debug.console(ngParamD);
		local min_x = nX - nConvert * ngParamA/2;
		local max_x = nX + nConvert * ngParamA/2;
		local min_y = nY - nConvert *ngParamB/2;
		local max_y = nY + nConvert * ngParamB/2;
		local min_z = nZ - nConvert * ngParamC;
		local max_z = nZ + nConvert * ngParamD;
		-- Orientation in degrees is either going to be nil (use token orientation)
		-- or an orientation
		local nOrientation = ngParamEoptional;
		if nOrientation == nil then
			-- 0.0 is orient 2 (0 degrees)
			-- 0.785398 is orient 1 (45 degrees)
			-- 1.5708 is orient 0 (Moved Up 90 degrees)
			-- 2.35619 is orient 7 (135 degrees)
			-- 3.14159 is orient 6 (180 degrees)
			-- -2.35619 is orient 5 (225 degrees)
			-- -1.5708 is orient 4 (270 degrees)
			-- -0.785398 is orient 3 (315 degrees)
			-- 6.28319 360 degrees
			local nTokenOrientation = tokenSource.getOrientation();
--			Debug.console(nTokenOrientation);
			if nTokenOrientation == 0 then
				nOrientation = 90;
			elseif nTokenOrientation == 1 then
				nOrientation = 45;
			elseif nTokenOrientation == 2 then
				nOrientation = 0;
			elseif nTokenOrientation == 3 then
				nOrientation = 315;
			elseif nTokenOrientation == 4 then
				nOrientation = 270;
			elseif nTokenOrientation == 5 then
				nOrientation = 225;
			elseif nTokenOrientation == 6 then
				nOrientation = 180;
			else -- 7
				nOrientation = 135;
			end
		end
--		Debug.console(min_x);
--		Debug.console(min_y);
--		Debug.console(min_z);
--		Debug.console(max_x);
--		Debug.console(max_y);
--		Debug.console(max_z);
--		Debug.console(nOrientation);
--		Debug.console(length);
--		Debug.console(width);
		-- height we are searching for our imaginary sphere of max possibles is based on min/max from token source z axis
		--local height = nConvert * ngParamD - nConvert* ngParamC;
--		Debug.console(height);
		if not bPoint then
			length = length + nConvert * ngTokenLengthAddition;
			width = width + nConvert * ngTokenLengthAddition;
			min_x = min_x - nConvert * ngTokenLengthAddition/2;
			min_y = min_y - nConvert * ngTokenLengthAddition/2;
			min_z = min_z - nConvert * ngTokenHeightAddition/2;
			max_x = max_x + nConvert * ngTokenLengthAddition/2;
			max_y = max_y + nConvert * ngTokenLengthAddition/2;
			max_z = max_z + nConvert * ngTokenHeightAddition/2;
			--height = height + nConvert * ngTokenHeightAddition;
		end
		--Debug.console(length);
		--Debug.console(width);
		--Debug.console(min_x);
		--Debug.console(min_y);
		--Debug.console(min_z);
		--Debug.console(max_x);
		--Debug.console(max_y);
		--Debug.console(max_z);
		--Debug.console(height);
		-- we need to find the max length based on base of 3d rect and its height (min/max based on source token can ignore orientation)
		-- find max search distance from source token to limit number of tokens we look at
		local ngMaxSearchDist = ngConvert * getBoundingSphereRadius(min_x, min_y, min_z, max_x, max_y, max_z);
--		Debug.console(ngMaxSearchDist);
		for _, token in pairs(imageCtl.getTokensWithinDistance(tokenSource, ngMaxSearchDist)) do
			-- Determine if token is within cyclinder
--			Debug.console(token);
--			Debug.console(DB.getValue(CombatManager.getCTFromToken(token), "name", ""));
			local nTokenX, nTokenY = token.getPosition()
			local nTokenZ = token.getHeight()
--			Debug.console(nTokenX);
--			Debug.console(nTokenY);
--			Debug.console(nTokenZ);
--			Debug.console(nX);
--			Debug.console(nY);
--			Debug.console(length);
--			Debug.console(width);
--			Debug.console(nOrientation);
--			Debug.console(min_z);
--			Debug.console(max_z);
			if isPointInOrientedRect3D(nTokenX, nTokenY, nTokenZ, nX, nY, length, width, nOrientation, min_z, max_z) then
--				Debug.console(" in 3D rect ");
				table.insert(aReturn, token)
			end
		end

	-- sphere (nShape = 0 (default); ngParamA = Radius)
	else
--		Debug.console(" Sphere ");
		-- radius
		local ngRadius = ngParamA;
--		Debug.console(ngRadius);
		if not bPoint then
			ngRadius = ngRadius + ngTokenLengthAddition/2;
		end
--		Debug.console(ngRadius);
		local nRadiusPx = nConvert * ngRadius;
--		Debug.console(nRadiusPx);
		for _, token in pairs(imageCtl.getTokensWithinDistance(tokenSource, ngRadius)) do
			-- Determine if token is within cyclinder
--			Debug.console(token);
--			Debug.console(DB.getValue(CombatManager.getCTFromToken(token), "name", ""));

			local nTokenX, nTokenY = token.getPosition()
			local nTokenZ = token.getHeight()
--			Debug.console(nTokenX);
--			Debug.console(nTokenY);
--			Debug.console(nTokenZ);
--			Debug.console(nX);
--			Debug.console(nY);
--			Debug.console(nZ);
			if isPointInSphere(nX, nY, nZ, nTokenX, nTokenY, nTokenZ, nRadiusPx) then
--				Debug.console("in sphere");
				table.insert(aReturn, token)
			end
		end
	end
	return aReturn
end
-- luacheck: pop

function isPointInsideCylinder(pointX, pointY, pointZ, centerX, centerY, radius, zMin, zMax)
    -- Check if point is within the circular base (X-Y plane)
    local distanceToCenter = math.sqrt((pointX - centerX)^2 + (pointY - centerY)^2)
    local inBase = distanceToCenter <= radius

    -- Check if point is within the height (Z-axis)
    local inHeight = (pointZ >= zMin) and (pointZ <= zMax)

    -- Point is inside cylinder only if both conditions are true
    return inBase and inHeight
end

-- Helper: rotate point around origin by negative angle (to undo orientation)
local function rotatePoint(px, py, cx, cy, negAngleRad)
    local dx = px - cx
    local dy = py - cy
    local cosA = math.cos(negAngleRad)
    local sinA = -math.sin(negAngleRad) -- negative for inverse rotation
    local rx = dx * cosA - dy * sinA
    local ry = dx * sinA + dy * cosA
    return rx + cx, ry + cy
end

-- Check if a 3D point is inside an oriented 3D rectangle
-- (orientation in deg of XY plane) z_min, z_max: vertical bounds
function isPointInOrientedRect3D(pointX, pointY, pointZ, cX, cY, length, width, orientation, z_min, z_max)
    local x, y, z = pointX, pointY, pointZ
    local cx, cy = cX, cY
    local l, w = length, width
    local angleRad = -math.rad(orientation) -- invert for local space

    -- Step 1: Rotate point around center to align rectangle with axes
    local lx, ly = rotatePoint(x, y, cx, cy, angleRad)

    -- Step 2: Check if in 2D bounds
    local halfL = l / 2
    local halfW = w / 2
    if lx < cx - halfL or lx > cx + halfL then return false end
    if ly < cy - halfW or ly > cy + halfW then return false end

    -- Step 3: Check Z bounds
    if z < z_min or z > z_max then return false end

    return true
end

function isPointInSphere(sphereCenterX, sphereCenterY, sphereCenterZ, pointX, pointY, pointZ, radius)
    local dx = pointX - sphereCenterX
    local dy = pointY - sphereCenterY
    local dz = pointZ - sphereCenterZ
    local distanceSquared = dx*dx + dy*dy + dz*dz
    return distanceSquared < radius*radius
end

function getBoundingSphereRadius(min_x, min_y, min_z, max_x, max_y, max_z)
    local dx = max_x - min_x
    local dy = max_y - min_y
    local dz = max_z - min_z
    local diagonal = math.sqrt(dx*dx + dy*dy + dz*dz)
    return diagonal / 2
end

function sphere_radius_from_cylinder(cylinder_radius, cylinder_height)
    local diagonal = math.sqrt(cylinder_height^2 + (2 * cylinder_radius)^2)
    return diagonal / 2
end