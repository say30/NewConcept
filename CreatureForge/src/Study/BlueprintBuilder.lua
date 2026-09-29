-- BlueprintBuilder : copie d'étude à côté de l'original.
-- Chaque pièce source -> boîte englobante (taille, position, rotation exactes),
-- couleur approximative, contour et nom visible. Le modèle source n'est pas modifié.

local Root = script.Parent.Parent
local Config = require(Root.Config)

local BlueprintBuilder = {}
local A = Config.ATTR

local function label(text: string, parent: Instance, offsetY: number, size: number, bold: boolean?)
	local gui = Instance.new("BillboardGui")
	gui.Name = "CF_Label"
	gui.Size = UDim2.fromOffset(160, size + 6)
	gui.StudsOffset = Vector3.new(0, offsetY, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = Config.VIZ.LabelMaxDistance
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextSize = size
	t.Font = if bold then Enum.Font.GothamBold else Enum.Font.GothamMedium
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextStrokeTransparency = 0.35
	t.Parent = gui
	gui.Parent = parent
	return gui
end

-- Pivot où poser la copie d'étude : à droite de l'original (axe X monde).
function BlueprintBuilder.placement(report)
	local size = report.boundingSize
	local gap = Config.LAYOUT_GAP + math.max(size.X, size.Z) * 0.25
	return report.pivot + Vector3.new(math.max(size.X, size.Z) + gap, 0, 0)
end

function BlueprintBuilder.build(report, parent: Instance)
	local pivot = BlueprintBuilder.placement(report)
	local model = Instance.new("Model")
	model.Name = report.name .. "_Blueprint"
	model:SetAttribute(A .. "Blueprint", true)
	model:SetAttribute(A .. "Source", report.name)
	model:SetAttribute(A .. "Explode", 0)

	-- Étiquettes : toutes si peu de pièces, sinon seulement les plus grosses.
	local labelled = {}
	local sorted = table.clone(report.parts)
	table.sort(sorted, function(a, b)
		return a.volume > b.volume
	end)
	local n = 0
	for _, p in sorted do
		if p.region ~= "ignore" and n < 80 then
			labelled[p] = true
			n += 1
		end
	end

	local map = {}
	local center, weight = Vector3.zero, 0
	local maxDim = math.max(report.boundingSize.X, report.boundingSize.Y, report.boundingSize.Z)
	for _, p in report.parts do
		local b = Instance.new("Part")
		b.Name = p.name
		b.Size = p.size
		b.CFrame = pivot * p.localCFrame
		b.Color = p.color
		b.Material = Enum.Material.SmoothPlastic
		-- Pièces techniques (HumanoidRootPart, Torso invisible, HatPoint...) : quasi invisibles.
		local helper = p.region == "ignore"
		b.Transparency = if helper then 0.97 else Config.VIZ.BlueprintTransparency
		b.Anchored = true
		b.CanCollide = false
		b.CanTouch = false
		b.CastShadow = false
		b.TopSurface = Enum.SurfaceType.Smooth
		b.BottomSurface = Enum.SurfaceType.Smooth
		b:SetAttribute(A .. "BaseCF", p.localCFrame)
		b:SetAttribute(A .. "SourcePath", p.path)
		b:SetAttribute(A .. "SourceClass", p.className)
		b:SetAttribute(A .. "Region", p.region or "")
		b:SetAttribute(A .. "SourceMaterial", p.material.Name)
		if p.materialVariant ~= "" then
			b:SetAttribute(A .. "SourceVariant", p.materialVariant)
		end
		if p.meshId ~= "" then
			b:SetAttribute(A .. "SourceMeshId", p.meshId) -- information d'étude uniquement
		end

		local box = Instance.new("SelectionBox")
		box.Name = "CF_Outline"
		box.Adornee = b
		box.LineThickness = math.clamp(maxDim * 0.002, 0.01, 0.06)
		box.Color3 = p.color:Lerp(Color3.new(0, 0, 0), 0.45)
		box.SurfaceTransparency = 1
		box.Transparency = if helper then 0.85 else 0
		box.Parent = b

		if labelled[p] then
			label(p.name:match("[^/\\]+$") or p.name, b, p.size.Y * 0.5 + 0.15, 11)
		end
		b.Parent = model
		map[p.inst] = b
		local w = math.max(p.volume, 1e-4)
		center += p.localCFrame.Position * w
		weight += w
	end

	model.WorldPivot = pivot
	model:SetAttribute(A .. "Center", if weight > 0 then center / weight else Vector3.zero)

	-- Titre au-dessus de la plus grosse pièce.
	local biggest = sorted[1] and map[sorted[1].inst]
	if biggest then
		label(report.name .. " — BLUEPRINT", biggest, report.boundingSize.Y * 0.6 + 1, 16, true)
	end

	model.Parent = parent
	return model, map
end

-- Fantôme : copie d'étude transparente de l'original, dans le blueprint uniquement.
-- Jamais publiée ni réutilisée pour une créature générée.
local STRIP = { "LuaSourceContainer", "JointInstance", "WeldConstraint", "Constraint", "Sound", "ProximityPrompt", "ClickDetector" }

function BlueprintBuilder.hasGhost(blueprint: Model)
	for _, d in blueprint:GetChildren() do
		if d:GetAttribute(A .. "Ghost") then
			return true
		end
	end
	return false
end

function BlueprintBuilder.toggleGhost(report, blueprint: Model)
	local pivot = blueprint:GetPivot()
	if BlueprintBuilder.hasGhost(blueprint) then
		for _, d in blueprint:GetChildren() do
			if d:GetAttribute(A .. "Ghost") then
				d:Destroy()
			elseif d:IsA("BasePart") and d.Transparency < 0.95 then
				d.Transparency = Config.VIZ.BlueprintTransparency
			end
		end
		return false
	end
	local explode = blueprint:GetAttribute(A .. "Explode") or 0
	local center = blueprint:GetAttribute(A .. "Center") or Vector3.zero
	local k = 1 + explode * 1.6
	for _, d in blueprint:GetChildren() do
		if d:IsA("BasePart") and d.Transparency < 0.95 then
			d.Transparency = 0.85 -- les boîtes deviennent des contours
		end
	end
	for _, p in report.parts do
		if p.region ~= "ignore" and p.transparency < 0.95 and p.inst.Parent then
			local ok, ghost = pcall(function()
				return p.inst:Clone()
			end)
			if ok and ghost then
				for _, d in ghost:GetDescendants() do
					for _, cls in STRIP do
						if d:IsA(cls) then
							d:Destroy()
							break
						end
					end
				end
				for _, child in ghost:GetChildren() do
					if child:IsA("BasePart") then
						child:Destroy() -- les sous-pièces ont leur propre fantôme
					end
				end
				ghost.Name = "Ghost_" .. (p.name:match("[^/\\]+$") or p.name)
				ghost.Anchored = true
				ghost.CanCollide = false
				ghost.CanTouch = false
				ghost.CanQuery = false
				ghost.CastShadow = false
				ghost.Transparency = math.max(p.transparency, 0.25)
				local base = p.localCFrame
				ghost:SetAttribute(A .. "Ghost", true)
				ghost:SetAttribute(A .. "BaseCF", base)
				local pos = center + (base.Position - center) * k
				ghost.CFrame = pivot * (CFrame.new(pos) * base.Rotation)
				ghost.Parent = blueprint
			end
		end
	end
	return true
end

-- Retrouve la correspondance source -> blueprint (après redémarrage du plugin).
function BlueprintBuilder.rebuildMap(report, blueprint: Model)
	local byPath = {}
	for _, d in blueprint:GetChildren() do
		local path = d:GetAttribute(A .. "SourcePath")
		if path then
			byPath[path] = d
		end
	end
	local map = {}
	for _, p in report.parts do
		map[p.inst] = byPath[p.path]
	end
	return map
end

return BlueprintBuilder
