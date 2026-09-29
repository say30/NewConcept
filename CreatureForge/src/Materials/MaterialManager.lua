-- MaterialManager : Original / Studs (MaterialVariant) / SmoothPlastic.
-- Les yeux restent en SmoothPlastic pour garder un regard net.

local MaterialService = game:GetService("MaterialService")

local Config = require(script.Parent.Parent.Config)

local MaterialManager = {}
local A = Config.ATTR

MaterialManager.MODES = { "Original", "Studs", "SmoothPlastic" }

-- Cherche un MaterialVariant par nom dans MaterialService (seul endroit où il s'applique).
function MaterialManager.findVariant(name: string)
	if not name or name == "" then
		return nil
	end
	for _, d in MaterialService:GetDescendants() do
		if d:IsA("MaterialVariant") and d.Name == name then
			return d
		end
	end
	return nil
end

local function materialFromName(name: string?)
	local ok, m = pcall(function()
		return Enum.Material[name]
	end)
	return if ok and m then m else Enum.Material.SmoothPlastic
end

-- Retourne { applied, missingVariant (string?) }.
function MaterialManager.apply(model: Instance, mode: string, variantName: string?)
	local variant = nil
	local missing = nil
	if mode == "Studs" then
		variant = MaterialManager.findVariant(variantName or Config.DEFAULT_VARIANT)
		if not variant then
			missing = variantName or Config.DEFAULT_VARIANT
		end
	end
	local refMaterial = materialFromName(tostring(model:GetAttribute(A .. "RefMaterial") or "SmoothPlastic"))
	local refVariantName = tostring(model:GetAttribute(A .. "RefVariant") or "")
	local refVariant = if refVariantName ~= "" then MaterialManager.findVariant(refVariantName) else nil

	local applied = 0
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute(A .. "Slot") then
			local slot = d:GetAttribute(A .. "Slot")
			if slot == "Eyes" or slot == "Pupil" then
				d.Material = Enum.Material.SmoothPlastic
				d.MaterialVariant = ""
			elseif mode == "Studs" and variant then
				d.Material = variant.BaseMaterial
				d.MaterialVariant = variant.Name
			elseif mode == "Original" and d:GetAttribute(A .. "SourceMaterial") then
				-- Reconstruction fidèle : matière d'origine de CETTE pièce.
				d.Material = materialFromName(tostring(d:GetAttribute(A .. "SourceMaterial")))
				local v = MaterialManager.findVariant(tostring(d:GetAttribute(A .. "SourceVariant") or ""))
				d.MaterialVariant = if v then v.Name else ""
			elseif mode == "Original" then
				if refVariant then
					d.Material = refVariant.BaseMaterial
					d.MaterialVariant = refVariant.Name
				else
					d.Material = refMaterial
					d.MaterialVariant = ""
				end
			else
				d.Material = Enum.Material.SmoothPlastic
				d.MaterialVariant = ""
			end
			applied += 1
		end
	end
	model:SetAttribute(A .. "Material", mode)
	model:SetAttribute(A .. "Variant", if mode == "Studs" then (variantName or "") else "")
	return { applied = applied, missingVariant = missing }
end

return MaterialManager
