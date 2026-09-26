--[[
	OutputBuilder
	Transforme un plan en instances :

	  ProceduralAssetPlacement_Generated
	      Generation_001
	          Architecture / CornerDecor / WallDecor / FloorDecor / CeilingDecor
	              AssetName_001, AssetName_002...

	  - Toujours Clone() : les assets sources ne sont jamais modifiés.
	  - Mise à l'échelle : Model:ScaleTo (autour du pivot, cohérent avec le
	    repère de mesure) ; pour une Part isolée, taille + PivotOffset +
	    attachments + SpecialMesh.
	  - Étirement (modules étirables d'une seule Part) : taille et CFrame
	    calculés directement depuis la boîte planifiée.
	  - Attributs : GeneratedBy, Seed, SourceAsset, PlacementType,
	    TargetSurface, GenerationId...
	  - Les clones sont construits dans un dossier non parenté, puis le dossier
	    est parenté en une fois : rapide et un seul changement d'historique.
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)
local Utilities = require(Core.Utilities)

local OutputBuilder = {}

local OUT = Config.Output
local ATTR = Config.Attr

function OutputBuilder.getRoot(create)
	local root = workspace:FindFirstChild(OUT.ROOT_NAME)
	if root == nil and create then
		root = Instance.new("Folder")
		root.Name = OUT.ROOT_NAME
		root:SetAttribute(ATTR.GeneratedBy, OUT.GENERATED_BY)
		root.Parent = workspace
	end
	return root
end

function OutputBuilder.nextGenerationIndex(root)
	local maxIndex = 0
	if root then
		for _, child in ipairs(root:GetChildren()) do
			local idx = child:GetAttribute(ATTR.GenerationIndex)
			if type(idx) == "number" then
				maxIndex = math.max(maxIndex, idx)
			else
				local n = tonumber((string.match(child.Name, "^" .. OUT.GENERATION_PREFIX .. "(%d+)$")))
				if n then
					maxIndex = math.max(maxIndex, n)
				end
			end
		end
	end
	return maxIndex + 1
end

function OutputBuilder.generationName(index)
	return OUT.GENERATION_PREFIX .. Utilities.padNumber(index, OUT.GENERATION_DIGITS)
end

-- Dossier de génération (non parenté) + sous-dossiers.
function OutputBuilder.createGenerationFolder(name, meta)
	local folder = Instance.new("Folder")
	folder.Name = name
	folder:SetAttribute(ATTR.GeneratedBy, OUT.GENERATED_BY)
	folder:SetAttribute(ATTR.GenerationId, meta.GenerationId)
	folder:SetAttribute(ATTR.Seed, meta.Seed)
	if meta.SettingsJson then
		folder:SetAttribute(ATTR.Settings, meta.SettingsJson)
	end
	local subfolders = {}
	for _, key in ipairs(OUT.SUBFOLDER_ORDER) do
		local sub = Instance.new("Folder")
		sub.Name = OUT.Subfolders[key]
		sub.Parent = folder
		subfolders[key] = sub
	end
	return folder, subfolders
end

-- Mise à l'échelle d'une Part isolée autour de son pivot.
local function scaleBasePart(part, s)
	local offset = part.PivotOffset
	part.Size = part.Size * s
	part.PivotOffset = CFrame.new(offset.Position * s) * offset.Rotation
	for _, d in ipairs(part:GetDescendants()) do
		if d:IsA("Attachment") then
			d.Position = d.Position * s
		elseif d:IsA("SpecialMesh") then
			if d.MeshType == Enum.MeshType.FileMesh then
				d.Scale = d.Scale * s
			end
			d.Offset = d.Offset * s
		end
	end
end

-- Étirement d'une Part : taille et CFrame issus de la boîte planifiée.
local function applyStretch(clone, asset, item)
	local part = if clone:IsA("BasePart") then clone else nil
	if not part then
		for _, d in ipairs(clone:GetDescendants()) do
			if d:IsA("BasePart") then
				part = d
				break
			end
		end
	end
	if not part then
		return false
	end
	-- Rotation de la Part dans le repère de référence (sans échelle) : doit être une permutation d'axes.
	local source = asset.StretchPart
	local rel = asset.RefFrame:ToObjectSpace(source.CFrame).Rotation
	local sizeRef = Vector3.new(
		math.abs(rel.XVector.X) * source.Size.X + math.abs(rel.YVector.X) * source.Size.Y + math.abs(rel.ZVector.X) * source.Size.Z,
		math.abs(rel.XVector.Y) * source.Size.X + math.abs(rel.YVector.Y) * source.Size.Y + math.abs(rel.ZVector.Y) * source.Size.Z,
		math.abs(rel.XVector.Z) * source.Size.X + math.abs(rel.YVector.Z) * source.Size.Y + math.abs(rel.ZVector.Z) * source.Size.Z
	)
	local aligned = math.max(math.abs(rel.XVector.X), math.abs(rel.XVector.Y), math.abs(rel.XVector.Z)) > 0.999
		and math.max(math.abs(rel.YVector.X), math.abs(rel.YVector.Y), math.abs(rel.YVector.Z)) > 0.999
	if not aligned or sizeRef.Magnitude < 1e-6 then
		return false
	end
	local target = item.BoxSize
	local k = Vector3.new(target.X / math.max(sizeRef.X, 1e-6), target.Y / math.max(sizeRef.Y, 1e-6), target.Z / math.max(sizeRef.Z, 1e-6))
	-- Facteur exprimé dans les axes propres de la Part.
	local function axisFactor(axisVector)
		local ax = math.abs(axisVector.X)
		local ay = math.abs(axisVector.Y)
		if ax >= ay and ax >= math.abs(axisVector.Z) then
			return k.X
		elseif ay >= math.abs(axisVector.Z) then
			return k.Y
		end
		return k.Z
	end
	part.Size = Vector3.new(
		source.Size.X * axisFactor(rel.XVector),
		source.Size.Y * axisFactor(rel.YVector),
		source.Size.Z * axisFactor(rel.ZVector)
	)
	part.CFrame = CFrame.new(item.BoxCFrame.Position) * item.RefCFrame.Rotation * rel
	return true
end

local function stripScripts(instance)
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("LuaSourceContainer") then
			d:Destroy()
		end
	end
end

local function anchorAll(instance)
	if instance:IsA("BasePart") then
		instance.Anchored = true
	end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end
end

--[[
	Instancie les objets du plan.
	options = { Seed, GenerationId, AnchorClones, StripScripts, OnProgress(f, text) }
	Renvoie (nombre créé, erreurs)
]]
function OutputBuilder.instantiate(items, subfolders, options)
	local counters = {}
	local created = 0
	local errors = {}
	local onProgress = options.OnProgress or function() end
	for index, item in ipairs(items) do
		local asset = item.Asset
		local ok, err = pcall(function()
			if not Utilities.isAlive(asset.Instance) then
				error("source asset no longer exists")
			end
			local clone = asset.Instance:Clone()
			if not clone then
				error("asset is not Archivable (Clone returned nil)")
			end
			if options.StripScripts then
				stripScripts(clone)
			end
			local s = item.Scale or 1
			local stretched = false
			if item.Stretch and math.abs((item.Stretch.Factor or 1) - 1) > 1e-9 and asset.StretchPart then
				if math.abs(s - 1) > 1e-9 then
					if clone:IsA("Model") then
						clone:ScaleTo(clone:GetScale() * s)
					elseif clone:IsA("BasePart") then
						scaleBasePart(clone, s)
					end
				end
				clone:PivotTo(item.Pivot)
				stretched = applyStretch(clone, asset, item)
			end
			if not stretched then
				if math.abs(s - 1) > 1e-9 then
					if clone:IsA("Model") then
						clone:ScaleTo(clone:GetScale() * s)
					elseif clone:IsA("BasePart") then
						scaleBasePart(clone, s)
					end
				end
				clone:PivotTo(item.Pivot)
			end
			if options.AnchorClones then
				anchorAll(clone)
			end
			local n = (counters[asset.Name] or 0) + 1
			counters[asset.Name] = n
			clone.Name = asset.Name .. "_" .. Utilities.padNumber(n, Config.Output.ITEM_DIGITS)
			clone:SetAttribute(ATTR.GeneratedBy, Config.Output.GENERATED_BY)
			clone:SetAttribute(ATTR.Seed, options.Seed)
			clone:SetAttribute(ATTR.SourceAsset, asset.FullName)
			clone:SetAttribute(ATTR.PlacementType, item.PlacementType)
			clone:SetAttribute(ATTR.TargetSurface, if item.Surface then (item.Surface.PartName .. " [" .. item.Surface.Role .. " " .. item.Surface.FaceName .. " " .. item.Surface.Id .. "]") else "Corner")
			clone:SetAttribute(ATTR.GenerationId, options.GenerationId)
			clone:SetAttribute(ATTR.SizeClass, asset.SizeClass)
			clone:SetAttribute(ATTR.Scale, s)
			clone:SetAttribute(ATTR.Layer, item.Layer or 0)
			local folder = subfolders[item.Folder] or subfolders.Floor
			clone.Parent = folder
			created += 1
		end)
		if not ok then
			table.insert(errors, string.format("%s: %s", asset.Name, tostring(err)))
		end
		if index % Config.Performance.INSTANTIATE_BATCH == 0 then
			onProgress(index / #items, string.format("Building %d/%d", index, #items))
			task.wait()
		end
	end
	-- Suppression des sous-dossiers vides pour une hiérarchie propre.
	for _, sub in pairs(subfolders) do
		if #sub:GetChildren() == 0 then
			sub:Destroy()
		end
	end
	return created, errors
end

-- Masque des murs d'origine de façon réversible (ObjectValue + transparence d'origine).
function OutputBuilder.hideWalls(folder, parts)
	if #parts == 0 then
		return
	end
	local store = Instance.new("Folder")
	store.Name = OUT.HIDDEN_WALLS_FOLDER
	for _, part in ipairs(parts) do
		if Utilities.isAlive(part) then
			local ref = Instance.new("ObjectValue")
			ref.Name = part.Name
			ref.Value = part
			ref:SetAttribute(ATTR.OriginalTransparency, part.Transparency)
			ref.Parent = store
			part.Transparency = 1
		end
	end
	store.Parent = folder
end

function OutputBuilder.restoreWalls(folder)
	local store = folder:FindFirstChild(OUT.HIDDEN_WALLS_FOLDER)
	if not store then
		return 0
	end
	local restored = 0
	for _, ref in ipairs(store:GetChildren()) do
		if ref:IsA("ObjectValue") and ref.Value and ref.Value:IsA("BasePart") then
			local original = ref:GetAttribute(ATTR.OriginalTransparency)
			if type(original) == "number" then
				ref.Value.Transparency = original
				restored += 1
			end
		end
	end
	return restored
end

return OutputBuilder
