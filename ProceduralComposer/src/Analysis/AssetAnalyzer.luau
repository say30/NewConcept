--[[
	AssetAnalyzer
	Mesure précisément un asset (Model, Part, assemblage...) sans jamais le
	modifier, et produit une fiche AssetData.

	Repère de référence (RefFrame) :
	  - origine = position du pivot (Model:ScaleTo met à l'échelle autour de ce point) ;
	  - orientation = lacet du pivot, axe Y = haut du monde tel que l'asset est
	    rangé dans la bibliothèque (les assets sont stockés debout).
	  Un pivot décalé ou basculé n'a donc aucune influence : toutes les
	  positions sont calculées à partir de la boîte réelle mesurée dans ce repère.
	  L'avant canonique de l'asset est -Z (LookVector), modifiable par
	  l'Attachment "Facing" ou l'attribut FacingYaw.

	Toutes les mesures (boîte, sous-boîtes de collision, attachments) sont
	exprimées dans ce repère, à l'échelle 1.
]]

local CollectionService = game:GetService("CollectionService")

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local MathUtil = require(Core.MathUtil)
local Utilities = require(Core.Utilities)

local AssetAnalyzer = {}

local A = Config.Assets

local ATTACHMENT_NAMES = {
	Placement_Base = "PlacementBase",
	Placement_Back = "PlacementBack",
	Snap_Left = "SnapLeft",
	Snap_Right = "SnapRight",
	Snap_Top = "SnapTop",
	Snap_Bottom = "SnapBottom",
	Facing = "Facing",
}

local ROLE_ALIASES = {
	large = "LargeStructure",
	largestructure = "LargeStructure",
	hero = "LargeStructure",
	module = "WallModule",
	wallmodule = "WallModule",
	section = "WallModule",
	pillar = "Pillar",
	column = "Pillar",
	arch = "Arch",
	top = "WallTop",
	walltop = "WallTop",
	trim = "WallTop",
	cornice = "WallTop",
	base = "WallBase",
	wallbase = "WallBase",
	baseboard = "WallBase",
	relief = "Relief",
	filler = "Filler",
	floor = "Floor",
	wall = "Wall",
	corner = "Corner",
	ceiling = "Ceiling",
}

function AssetAnalyzer.normalizeRoleName(name)
	if type(name) ~= "string" then
		return nil
	end
	local key = string.lower((string.gsub(name, "%s", "")))
	return ROLE_ALIASES[key]
end

local function parseRoles(instance, stopAt)
	local roles = {}
	local found = false
	local value = Utilities.getInheritedAttribute(instance, "PlacementType", "string", stopAt)
	if value then
		for token in string.gmatch(value, "[^,;|]+") do
			local role = AssetAnalyzer.normalizeRoleName(token)
			if role then
				roles[role] = true
				found = true
			end
		end
	end
	local ok, tags = pcall(CollectionService.GetTags, CollectionService, instance)
	if ok then
		for _, tag in ipairs(tags) do
			if string.sub(tag, 1, #Config.Tags.ROLE_PREFIX) == Config.Tags.ROLE_PREFIX then
				local role = AssetAnalyzer.normalizeRoleName(string.sub(tag, #Config.Tags.ROLE_PREFIX + 1))
				if role then
					roles[role] = true
					found = true
				end
			end
		end
	end
	return roles, found
end

-- Lecture des métadonnées optionnelles (attributs hérités des dossiers parents).
function AssetAnalyzer.readMetadata(instance, stopAt)
	local function num(name)
		return Utilities.getInheritedAttribute(instance, name, "number", stopAt)
	end
	local function bool(name)
		return Utilities.getInheritedAttribute(instance, name, "boolean", stopAt)
	end
	local function str(name)
		return Utilities.getInheritedAttribute(instance, name, "string", stopAt)
	end
	local roles, explicit = parseRoles(instance, stopAt)
	local minScale = num("MinScale")
	local maxScale = num("MaxScale")
	if minScale and maxScale and minScale > maxScale then
		minScale, maxScale = maxScale, minScale
	end
	local sizeClass = str("SizeClass")
	if sizeClass and not table.find(A.SIZE_CLASS_ORDER, sizeClass) then
		sizeClass = nil
	end
	local allowRotation = bool("AllowRotation")
	local allowMirror = bool("AllowMirror")
	local allowScale = bool("AllowScale")
	local canTouchWall = bool("CanTouchWall")
	return {
		Roles = roles,
		ExplicitRoles = explicit,
		Weight = math.max(0, num("Weight") or A.DEFAULT_WEIGHT),
		MinScale = if minScale then math.max(0.05, minScale) else nil,
		MaxScale = if maxScale then math.max(0.05, maxScale) else nil,
		AllowRotation = if allowRotation == nil then true else allowRotation,
		AllowMirror = if allowMirror == nil then true else allowMirror,
		AllowScale = if allowScale == nil then true else allowScale,
		WallOffset = num("WallOffset") or 0,
		FloorOffset = num("FloorOffset") or 0,
		Category = str("Category"),
		Importance = num("Importance"),
		RepeatLimit = num("RepeatLimit"),
		MinSpacing = num("MinSpacing"),
		PreferredHeight = num("PreferredHeight"),
		CanTouchWall = if canTouchWall == nil then true else canTouchWall,
		CanOverlapDecoration = bool("CanOverlapDecoration") == true,
		UniqueAsset = bool("UniqueAsset") == true,
		SizeClass = sizeClass,
		Stretchable = bool("Stretchable") == true,
		CeilingFlip = bool("CeilingFlip") == true,
		WallYaw = num("WallYaw"),
		FacingYaw = num("FacingYaw"),
		AlignToSurface = bool("AlignToSurface"),
		UsePivotOrientation = bool("UsePivotOrientation") == true,
	}
end

local function isVisible(part)
	return part.Transparency < 0.999
end

-- Grille d'occupation : réduit un asset de centaines de parts à quelques boîtes.
local function occupancyBoxes(localBoxes, bmin, bmax, n)
	local size = bmax - bmin
	local cell = Vector3.new(math.max(size.X / n, 1e-3), math.max(size.Y / n, 1e-3), math.max(size.Z / n, 1e-3))
	local occupied = {}
	local function index(x, y, z)
		return x + (y - 1) * n + (z - 1) * n * n
	end
	local function cellRange(lo, hi, origin, step)
		local a = math.clamp(math.floor((lo - origin) / step) + 1, 1, n)
		local b = math.clamp(math.floor((hi - origin) / step - 1e-6) + 1, 1, n)
		return a, math.max(a, b)
	end
	for _, box in ipairs(localBoxes) do
		local x0, x1 = cellRange(box.Min.X, box.Max.X, bmin.X, cell.X)
		local y0, y1 = cellRange(box.Min.Y, box.Max.Y, bmin.Y, cell.Y)
		local z0, z1 = cellRange(box.Min.Z, box.Max.Z, bmin.Z, cell.Z)
		for z = z0, z1 do
			for y = y0, y1 do
				for x = x0, x1 do
					occupied[index(x, y, z)] = true
				end
			end
		end
	end
	local boxes = {}
	for z = 1, n do
		for y = 1, n do
			local x = 1
			while x <= n do
				if occupied[index(x, y, z)] then
					local startX = x
					while x + 1 <= n and occupied[index(x + 1, y, z)] do
						x += 1
					end
					local lo = bmin + Vector3.new((startX - 1) * cell.X, (y - 1) * cell.Y, (z - 1) * cell.Z)
					local hi = bmin + Vector3.new(x * cell.X, y * cell.Y, z * cell.Z)
					table.insert(boxes, { CFrame = CFrame.new((lo + hi) * 0.5), Size = hi - lo })
				end
				x += 1
			end
		end
	end
	return boxes
end

local function findAttachments(instance)
	local found = {}
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("Attachment") and ATTACHMENT_NAMES[d.Name] and not found[d.Name] then
			found[d.Name] = d
		end
	end
	return found
end

local function clamp01(x)
	return math.clamp(x, 0, 1)
end

--[[
	Classification automatique par la forme.
	Renvoie les scores de rôle (0..1), le lacet mural conseillé et une étiquette de forme.
]]
function AssetAnalyzer.classifyShape(size, fillRatio)
	local sx, sy, sz = size.X, size.Y, size.Z
	local hmax = math.max(sx, sz)
	local hmin = math.min(sx, sz)
	local eps = 1e-4

	-- Orientation murale : l'axe horizontal le plus fin doit faire face au mur
	-- (et l'axe le plus long suit le mur).
	local wallYaw = if sx + eps < sz * 0.8 then math.pi / 2 else 0
	local wx = if wallYaw == 0 then sx else sz
	local wd = if wallYaw == 0 then sz else sx
	local wh = sy

	local depthToWidth = wd / math.max(wx, eps)
	local depthToHeight = wd / math.max(wh, eps)
	local heightRatio = wh / math.max(wx, eps)
	local slenderness = sy / math.max(hmax, eps)
	local sectionRatio = hmin / math.max(hmax, eps)
	local elongation = hmax / math.max(sy, hmin, eps)
	local flatH = sy / math.max(hmax, eps)

	local scores = {}
	local shape = "Blocky"

	local isRelief = depthToWidth <= A.RELIEF_MAX_DEPTH_RATIO and depthToHeight <= A.RELIEF_MAX_DEPTH_RATIO and wh >= A.RELIEF_MIN_HEIGHT_RATIO * wx
	local isShallow = depthToWidth <= A.WALL_PROP_MAX_DEPTH_RATIO and depthToHeight <= A.WALL_PROP_MAX_DEPTH_RATIO
	local isPanel = depthToWidth <= A.PANEL_MAX_DEPTH_RATIO and depthToHeight <= A.PANEL_MAX_DEPTH_RATIO
		and heightRatio >= A.PANEL_MIN_HEIGHT_RATIO and heightRatio <= A.PANEL_MAX_HEIGHT_RATIO
	local isPillar = slenderness >= A.PILLAR_MIN_SLENDERNESS and sectionRatio >= A.PILLAR_MIN_SECTION_RATIO
	local isTrim = elongation >= A.TRIM_MIN_ELONGATION and hmax >= 3 * hmin
	local isFlatFloor = flatH <= A.FLAT_FLOOR_MAX_RATIO and not isTrim

	scores.Floor = 0.8
	scores.Wall = if isRelief then 1 elseif isShallow and not isPillar and not isTrim then 0.45 else 0.05
	scores.Relief = if isRelief then 1 else 0
	scores.WallModule = if isPanel and not isPillar then (if isRelief then 0.6 else 0.9) else 0
	scores.Arch = if scores.WallModule > 0 and fillRatio <= A.ARCH_MAX_FILL_RATIO then 0.8 else 0
	scores.Pillar = if isPillar then 1 elseif slenderness >= 1.6 and sectionRatio >= A.PILLAR_MIN_SECTION_RATIO then 0.5 else 0
	scores.WallTop = if isTrim then 1 else 0
	scores.WallBase = if isTrim then 1 else 0
	scores.Corner = if isPillar then 0.9 elseif sy >= 0.8 * hmax and sectionRatio >= 0.6 then 0.6 else 0
	scores.Ceiling = if slenderness >= 1.5 and hmax <= 6 then 0.5 elseif isFlatFloor then 0.45 else 0
	scores.LargeStructure = 0
	scores.Filler = 0

	if isRelief then
		shape = "Relief"
		scores.Floor = 0.15
	elseif isPillar then
		shape = "Vertical"
		scores.Floor = 0.7
	elseif isTrim then
		shape = "Trim"
		scores.Floor = 0.5
	elseif isPanel then
		shape = "Panel"
		scores.Floor = 0.35
	elseif isFlatFloor then
		shape = "FlatHorizontal"
		scores.Floor = 0.7
		scores.Wall = 0.05
	end
	for k, v in pairs(scores) do
		scores[k] = clamp01(v)
	end
	return scores, wallYaw, shape
end

--[[
	Analyse d'un asset.
	context = { LibraryRoot = Instance, Key = string, Order = number }
	Renvoie AssetData ou (nil, raison).
]]
function AssetAnalyzer.analyze(instance, context)
	context = context or {}
	local ok, result, reason = pcall(function()
		local parts = Utilities.collectBaseParts(instance, Config.Performance.MAX_ANALYZE_PARTS_PER_ASSET)
		if #parts == 0 then
			return nil, "contains no BasePart"
		end
		local meta = AssetAnalyzer.readMetadata(instance, context.LibraryRoot)
		local pivot = (instance :: any):GetPivot()
		local attachments = findAttachments(instance)

		-- Repère de référence : position du pivot + lacet (haut = haut du monde).
		local rotation = if meta.UsePivotOrientation then pivot.Rotation else MathUtil.yawOnly(pivot)
		local ref = CFrame.new(pivot.Position) * rotation

		-- Avant de l'asset : Attachment "Facing" puis attribut FacingYaw.
		local facingAtt = attachments.Facing
		if facingAtt then
			local front = ref:VectorToObjectSpace(facingAtt.WorldCFrame.LookVector)
			front = Vector3.new(front.X, 0, front.Z)
			if front.Magnitude > 0.2 then
				front = front.Unit
				local theta = math.atan2(front.X, -front.Z)
				ref = ref * CFrame.Angles(0, -theta, 0)
			end
		end
		if meta.FacingYaw then
			ref = ref * CFrame.Angles(0, -math.rad(meta.FacingYaw), 0)
		end

		-- Boîte visuelle réelle dans le repère de référence.
		local useParts = parts
		if A.IGNORE_INVISIBLE_PARTS_IN_BOUNDS then
			local visible = {}
			for _, p in ipairs(parts) do
				if isVisible(p) then
					table.insert(visible, p)
				end
			end
			if #visible > 0 then
				useParts = visible
			end
		end
		local bmin = Vector3.new(math.huge, math.huge, math.huge)
		local bmax = Vector3.new(-math.huge, -math.huge, -math.huge)
		local localBoxes = table.create(#useParts)
		local partsVolume = 0
		for _, p in ipairs(useParts) do
			local lo, hi = MathUtil.obbBoundsInFrame(ref, p.CFrame, p.Size)
			bmin = MathUtil.componentMin(bmin, lo)
			bmax = MathUtil.componentMax(bmax, hi)
			table.insert(localBoxes, { Min = lo, Max = hi, CFrame = ref:ToObjectSpace(p.CFrame), Size = p.Size })
			partsVolume += p.Size.X * p.Size.Y * p.Size.Z
		end
		local size = bmax - bmin
		if size.X <= 1e-4 or size.Y <= 1e-4 or size.Z <= 1e-4 then
			-- Asset "plat" (decal sur une part d'épaisseur nulle) : on impose une épaisseur minimale.
			local fix = Vector3.new(math.max(size.X, 0.01), math.max(size.Y, 0.01), math.max(size.Z, 0.01))
			local c = (bmin + bmax) * 0.5
			bmin, bmax = c - fix * 0.5, c + fix * 0.5
			size = fix
		end
		local boundsVolume = size.X * size.Y * size.Z
		local fillRatio = math.clamp(partsVolume / math.max(boundsVolume, 1e-6), 0, 1)

		-- Sous-boîtes pour la collision précise.
		local subBoxes = {}
		if #localBoxes <= A.MAX_EXACT_SUB_BOXES then
			for _, b in ipairs(localBoxes) do
				table.insert(subBoxes, { CFrame = b.CFrame, Size = b.Size })
			end
		else
			subBoxes = occupancyBoxes(localBoxes, bmin, bmax, A.OCCUPANCY_GRID)
		end

		-- Attachments exprimés dans le repère de référence.
		local localAttachments = {}
		for name, att in pairs(attachments) do
			localAttachments[ATTACHMENT_NAMES[name]] = ref:ToObjectSpace(att.WorldCFrame)
		end

		local scriptCount = 0
		for _, d in ipairs(instance:GetDescendants()) do
			if d:IsA("LuaSourceContainer") then
				scriptCount += 1
			end
		end

		local roleScores, wallYaw, shape = AssetAnalyzer.classifyShape(size, fillRatio)
		if meta.WallYaw then
			wallYaw = math.rad(meta.WallYaw)
		elseif facingAtt or meta.FacingYaw then
			-- L'avant est explicitement défini : il fait face à l'espace libre.
			wallYaw = 0
		end

		local isModel = instance:IsA("Model")
		local isPart = instance:IsA("BasePart")
		local singleStretchPart = nil
		if isPart and meta.Stretchable then
			singleStretchPart = instance
		elseif isModel and meta.Stretchable and #parts == 1 then
			singleStretchPart = parts[1]
		end

		local characteristic = 0.5 * math.max(size.X, size.Y, size.Z) + 0.5 * boundsVolume ^ (1 / 3)

		return {
			Key = context.Key or instance.Name,
			Order = context.Order or 0,
			Name = instance.Name,
			Instance = instance,
			FullName = Utilities.fullName(instance),
			LibraryRoot = context.LibraryRoot,
			Category = meta.Category or context.Category or "Default",
			IsModel = isModel,
			IsBasePart = isPart,
			PartCount = #parts,
			ScriptCount = scriptCount,
			RefFrame = ref,
			PivotFromRef = ref:ToObjectSpace(pivot),
			BoundsMin = bmin,
			BoundsMax = bmax,
			Size = size,
			Center = (bmin + bmax) * 0.5,
			FootprintRadius = 0.5 * math.sqrt(size.X * size.X + size.Z * size.Z),
			CharacteristicSize = characteristic,
			FillRatio = fillRatio,
			SubBoxes = subBoxes,
			Attachments = localAttachments,
			Meta = meta,
			AutoRoleScores = roleScores,
			RoleScores = roleScores,
			WallYaw = wallYaw,
			Shape = shape,
			IsFlat = size.Y <= Config.Precision.FLAT_ASSET_THICKNESS or shape == "FlatHorizontal",
			StretchPart = singleStretchPart,
			SizeClass = meta.SizeClass or "Medium",
		}, nil
	end)
	if not ok then
		return nil, "analysis error: " .. tostring(result)
	end
	return result, reason
end

return AssetAnalyzer
