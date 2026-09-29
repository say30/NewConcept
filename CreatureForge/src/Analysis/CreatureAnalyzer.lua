-- CreatureAnalyzer : point d'entrée de l'analyse d'une créature (lecture seule).
-- Ne modifie JAMAIS le modèle source.

local Analysis = script.Parent
local Util = require(Analysis.Parent.Core.Util)
local RigAnalyzer = require(Analysis.RigAnalyzer)
local PaletteAnalyzer = require(Analysis.PaletteAnalyzer)
local MorphologyAnalyzer = require(Analysis.MorphologyAnalyzer)

local CreatureAnalyzer = {}

local function meshInfo(part: BasePart)
	if part:IsA("MeshPart") then
		local tex = ""
		pcall(function()
			tex = part.TextureID
		end)
		return part.MeshId, tex
	end
	local special = part:FindFirstChildWhichIsA("SpecialMesh")
	if special then
		return special.MeshId, special.TextureId
	end
	return "", ""
end

function CreatureAnalyzer.analyze(model: Instance)
	assert(model and model:IsA("Model"), "Sélectionnez un Model")

	local pivot = model:GetPivot()
	local rig = RigAnalyzer.analyze(model)

	-- Nom d'articulation associé à chaque Part1 (aide à nommer les pièces anonymes).
	local jointNameOf = {}
	for _, j in rig.joints do
		if j.part1 then
			jointNameOf[j.part1] = j.name
		end
	end

	local parts = {}
	local counts = {
		parts = 0,
		meshParts = 0,
		plainParts = 0,
		surfaceAppearances = 0,
		textured = 0,
		materialVariants = 0,
	}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			counts.parts += 1
			if d:IsA("MeshPart") then
				counts.meshParts += 1
			elseif d:IsA("Part") then
				counts.plainParts += 1
			end
			local meshId, textureId = meshInfo(d)
			local hasSA = d:FindFirstChildWhichIsA("SurfaceAppearance") ~= nil
			if hasSA then
				counts.surfaceAppearances += 1
			end
			if textureId ~= "" then
				counts.textured += 1
			end
			if d.MaterialVariant ~= "" then
				counts.materialVariants += 1
			end
			table.insert(parts, {
				inst = d,
				name = d.Name,
				className = d.ClassName,
				path = Util.pathOf(d, model),
				size = d.Size,
				cframe = d.CFrame,
				localCFrame = pivot:ToObjectSpace(d.CFrame),
				volume = d.Size.X * d.Size.Y * d.Size.Z,
				color = d.Color,
				material = d.Material,
				materialVariant = d.MaterialVariant,
				transparency = d.Transparency,
				meshId = meshId,
				textureId = textureId,
				surfaceAppearance = hasSA,
				jointName = jointNameOf[d],
			})
		end
	end
	assert(#parts > 0, "Aucune BasePart dans « " .. model.Name .. " »")

	local traits, frame = MorphologyAnalyzer.analyze(parts, pivot, model.Name)

	local visible = {}
	for _, p in parts do
		if p.region ~= "ignore" and p.transparency < 0.95 then
			table.insert(visible, p)
		end
	end
	local palette = PaletteAnalyzer.analyze(if #visible > 0 then visible else parts)
	traits.palette = palette.slots
	traits.material = palette.dominantMaterial
	traits.materialVariant = palette.dominantVariant

	counts.colors = palette.uniqueCount
	counts.motor6D = rig.counts.Motor6D
	counts.bones = rig.counts.Bone
	counts.attachments = rig.counts.Attachment
	counts.welds = rig.counts.Weld
	counts.weldConstraints = rig.counts.WeldConstraint

	local cf, size = model:GetBoundingBox()

	return {
		model = model,
		name = model.Name,
		pivot = pivot,
		frame = frame,
		boundingCFrame = cf,
		boundingSize = size,
		parts = parts,
		counts = counts,
		rig = rig,
		palette = palette,
		traits = traits,
		morphology = MorphologyAnalyzer.describe(traits),
		time = os.time(),
	}
end

-- Texte pour « Détails avancés ».
function CreatureAnalyzer.details(report)
	local c, t = report.counts, report.traits
	local lines = {}
	local function add(s)
		table.insert(lines, s)
	end
	add(string.format("Taille : %.1f × %.1f × %.1f studs", report.boundingSize.X, report.boundingSize.Y, report.boundingSize.Z))
	add(string.format("Parts simples : %d · SurfaceAppearance : %d · Texturées : %d", c.plainParts, c.surfaceAppearances, c.textured))
	add(string.format("Attachments : %d · Welds : %d · WeldConstraints : %d", c.attachments, c.welds, c.weldConstraints))
	add(string.format("MaterialVariants utilisés : %d · Matériau dominant : %s", c.materialVariants, t.material or "?"))
	add("")
	add("Morphologie : " .. report.morphology)
	add(string.format("Corps : L %.2f · l %.2f · h %.2f (×H)", t.body.length, t.body.width, t.body.height))
	add(string.format("Tête/corps : %.2f · Cou : %.2f", t.headRatio, t.neckLength))
	if t.legLength then
		add(string.format("Pattes : longueur %.2f · épaisseur %.2f", t.legLength, t.legThickness or 0))
	end
	if t.tail.has then
		add(string.format("Queue : longueur %.2f · %d segments", t.tail.length, t.tail.segments))
	end
	if t.wings.count > 0 then
		add(string.format("Ailes : envergure %.2f · corde %.2f", t.wings.span, t.wings.chord))
	end
	add(string.format("Yeux %d · Oreilles %d · Cornes %d · Pics %d", t.eyes.count, t.ears.count, t.horns.count, t.spikes.count))
	add("")
	add("Régions détectées :")
	local regions = {}
	for r, n in t.regionCounts do
		table.insert(regions, r .. " " .. n)
	end
	table.sort(regions)
	add("  " .. table.concat(regions, " · "))
	add("")
	add("Palette :")
	for _, slot in { "Primary", "Secondary", "Accent", "Eyes", "Special" } do
		local col = t.palette[slot]
		add(string.format("  %s : #%s", slot, col:ToHex()))
	end
	if report.rig.treeText ~= "" then
		add("")
		add("Hiérarchie Motor6D :")
		add(report.rig.treeText)
	end
	return table.concat(lines, "\n")
end

return CreatureAnalyzer
