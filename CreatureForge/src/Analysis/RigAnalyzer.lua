-- RigAnalyzer : inventaire des articulations (Motor6D, Weld, WeldConstraint),
-- des Bones et des Attachments, + arbre hiérarchique lisible.

local RigAnalyzer = {}

function RigAnalyzer.analyze(model: Instance)
	local rig = {
		joints = {}, -- { inst, kind, name, part0, part1, c0, c1 }
		bones = {}, -- { inst, name, part, parentBone, worldCFrame }
		attachments = {}, -- { inst, name, part, cframe }
		counts = { Motor6D = 0, Weld = 0, WeldConstraint = 0, Bone = 0, Attachment = 0, Other = 0 },
	}

	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") then
			rig.counts.Motor6D += 1
			table.insert(rig.joints, {
				inst = d,
				kind = "Motor6D",
				name = d.Name,
				part0 = d.Part0,
				part1 = d.Part1,
				c0 = d.C0,
				c1 = d.C1,
			})
		elseif d:IsA("Weld") or d:IsA("ManualWeld") or d:IsA("Snap") then
			rig.counts.Weld += 1
			table.insert(rig.joints, {
				inst = d,
				kind = "Weld",
				name = d.Name,
				part0 = d.Part0,
				part1 = d.Part1,
				c0 = d.C0,
				c1 = d.C1,
			})
		elseif d:IsA("WeldConstraint") then
			rig.counts.WeldConstraint += 1
			table.insert(rig.joints, {
				inst = d,
				kind = "WeldConstraint",
				name = d.Name,
				part0 = d.Part0,
				part1 = d.Part1,
			})
		elseif d:IsA("Bone") then
			rig.counts.Bone += 1
			local part = d:FindFirstAncestorWhichIsA("BasePart")
			local parentBone = if d.Parent and d.Parent:IsA("Bone") then d.Parent else nil
			local ok, world = pcall(function()
				return d.WorldCFrame
			end)
			table.insert(rig.bones, {
				inst = d,
				name = d.Name,
				part = part,
				parentBone = parentBone,
				worldCFrame = if ok then world else nil,
			})
		elseif d:IsA("Attachment") then
			rig.counts.Attachment += 1
			local part = d.Parent
			if part and part:IsA("BasePart") then
				table.insert(rig.attachments, { inst = d, name = d.Name, part = part, cframe = d.CFrame })
			end
		elseif d:IsA("JointInstance") then
			rig.counts.Other += 1
		end
	end

	-- Hiérarchie Motor6D : racines = Part0 jamais Part1.
	local children, isChild = {}, {}
	for _, j in rig.joints do
		if j.kind == "Motor6D" and j.part0 and j.part1 then
			children[j.part0] = children[j.part0] or {}
			table.insert(children[j.part0], j)
			isChild[j.part1] = true
		end
	end
	local roots = {}
	for part in children do
		if not isChild[part] then
			table.insert(roots, part)
		end
	end
	table.sort(roots, function(a, b)
		return a.Name < b.Name
	end)
	rig.roots = roots

	local lines, visited = {}, {}
	local function walk(part, depth)
		if visited[part] or depth > 40 then
			return
		end
		visited[part] = true
		local list = children[part] or {}
		table.sort(list, function(a, b)
			return a.part1.Name < b.part1.Name
		end)
		for _, j in list do
			table.insert(lines, string.rep("  ", depth) .. "└ " .. j.part1.Name .. "  (" .. j.name .. ")")
			walk(j.part1, depth + 1)
		end
	end
	for _, root in roots do
		table.insert(lines, root.Name)
		walk(root, 1)
	end
	rig.treeText = table.concat(lines, "\n")
	return rig
end

return RigAnalyzer
