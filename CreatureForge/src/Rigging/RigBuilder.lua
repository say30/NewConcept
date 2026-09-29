-- RigBuilder : crée automatiquement le rig d'une créature générée.
-- Root (ancré, invisible) -> Body -> Neck -> Head -> Jaw ... via Motor6D ;
-- détails décoratifs (yeux, cornes, pics) via WeldConstraint.
-- Aucune hypothèse humanoïde : la hiérarchie vient des attributs CF_RigParent
-- posés par le planificateur (ou, à défaut, de la pièce la plus proche).

local Config = require(script.Parent.Parent.Config)

local RigBuilder = {}
local A = Config.ATTR

local function isRigJoint(inst: Instance)
	return inst:GetAttribute(A .. "Rig") == true
end

function RigBuilder.clear(model: Model)
	for _, d in model:GetDescendants() do
		if (d:IsA("Motor6D") or d:IsA("WeldConstraint") or d:IsA("Weld")) and isRigJoint(d) then
			d:Destroy()
		end
	end
end

local function ensureRoot(model: Model)
	local root = model:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		return root
	end
	local pivot = model:GetPivot()
	-- Placée sous le centre du corps, à hauteur de la jointure du corps.
	local body = model:FindFirstChild("Body") or model:FindFirstChild("Pelvis")
	local y = 1
	if body then
		local jp = body:GetAttribute(A .. "JointPos")
		if typeof(jp) == "Vector3" then
			y = jp.Y
		end
	end
	root = Instance.new("Part")
	root.Name = "Root"
	root.Size = Vector3.new(1, 1, 1)
	root.Transparency = 1
	root.CanCollide = false
	root.CanTouch = false
	root.CanQuery = false
	root.Anchored = true
	root.CFrame = pivot * CFrame.new(0, y, 0)
	-- Le pivot du modèle reste au sol, même quand Root devient PrimaryPart.
	root.PivotOffset = CFrame.new(0, -y, 0)
	root:SetAttribute(A .. "Rig", true)
	root.Parent = model
	return root
end

-- Construit / reconstruit le rig. Retourne { motors, welds, root }.
function RigBuilder.build(model: Model)
	RigBuilder.clear(model)
	local pivot = model:GetPivot()
	local root = ensureRoot(model)
	model.PrimaryPart = root

	local parts = {}
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") and d ~= root then
			table.insert(parts, d)
		end
	end

	local motors, welds = 0, 0
	for _, part in parts do
		local parentName = part:GetAttribute(A .. "RigParent")
		local parentPart = nil
		if parentName == "Root" then
			parentPart = root
		elseif parentName then
			parentPart = model:FindFirstChild(parentName)
		end
		local kind = part:GetAttribute(A .. "JointKind") or "Weld"
		local jointLocal = part:GetAttribute(A .. "JointPos")

		if not parentPart or not parentPart:IsA("BasePart") then
			-- Pièce ajoutée à la main : soudée à la pièce générée la plus proche.
			local best, bestD = root, math.huge
			for _, other in parts do
				if other ~= part and other:GetAttribute(A .. "RigParent") then
					local dist = (other.Position - part.Position).Magnitude
					if dist < bestD then
						best, bestD = other, dist
					end
				end
			end
			parentPart, kind = best, "Weld"
		end

		if kind == "Motor6D" then
			local jointWorld = if typeof(jointLocal) == "Vector3"
				then pivot * CFrame.new(jointLocal)
				else CFrame.new(part.Position) * pivot.Rotation
			local m = Instance.new("Motor6D")
			m.Name = part.Name
			m.Part0 = parentPart
			m.Part1 = part
			m.C0 = parentPart.CFrame:ToObjectSpace(jointWorld)
			m.C1 = part.CFrame:ToObjectSpace(jointWorld)
			m:SetAttribute(A .. "Rig", true)
			m.Parent = part
			motors += 1
		else
			local w = Instance.new("WeldConstraint")
			w.Name = "Weld_" .. part.Name
			w.Part0 = parentPart
			w.Part1 = part
			w:SetAttribute(A .. "Rig", true)
			w.Parent = part
			welds += 1
		end
	end

	-- Tout est tenu par les joints : seule la racine reste ancrée.
	for _, part in parts do
		part.Anchored = false
	end
	root.Anchored = true

	local controller = model:FindFirstChildWhichIsA("AnimationController")
	if not controller then
		controller = Instance.new("AnimationController")
		controller.Parent = model
	end
	if not controller:FindFirstChildWhichIsA("Animator") then
		Instance.new("Animator").Parent = controller
	end

	model:SetAttribute(A .. "RigMotors", motors)
	model:SetAttribute(A .. "RigWelds", welds)
	return { motors = motors, welds = welds, root = root }
end

-- Arbre texte du rig (pour « Détails avancés »).
function RigBuilder.describe(model: Model)
	local children = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			children[d.Part0] = children[d.Part0] or {}
			table.insert(children[d.Part0], d.Part1)
		end
	end
	local lines = {}
	local function walk(part, depth)
		if depth > 30 then
			return
		end
		local list = children[part] or {}
		table.sort(list, function(a, b)
			return a.Name < b.Name
		end)
		for _, child in list do
			table.insert(lines, string.rep("  ", depth) .. "└ " .. child.Name)
			walk(child, depth + 1)
		end
	end
	local root = model:FindFirstChild("Root")
	if root then
		table.insert(lines, "Root")
		walk(root, 1)
	end
	return table.concat(lines, "\n")
end

return RigBuilder
