-- RigVisualizer : affiche Motor6D, Welds, Bones et Attachments sous forme de
-- lignes (Beams) et de petits marqueurs toujours visibles.
-- Ne dessine QUE dans nos propres modèles (blueprint ou créature générée).

local Config = require(script.Parent.Parent.Config)

local RigVisualizer = {}
local A = Config.ATTR
local VIZ = Config.VIZ

local TAG = A .. "Viz"

function RigVisualizer.isShown(model: Instance)
	return model:GetAttribute(A .. "RigShown") == true
end

function RigVisualizer.clear(model: Instance)
	for _, d in model:GetDescendants() do
		if d:GetAttribute(TAG) then
			d:Destroy()
		end
	end
	local folder = model:FindFirstChild("CF_RigView")
	if folder then
		folder:Destroy()
	end
	if model:GetAttribute(A .. "Blueprint") then
		local base = Config.VIZ.BlueprintTransparency
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d.Transparency < 0.9 then
				d.Transparency = base
			end
		end
	end
	model:SetAttribute(A .. "RigShown", false)
end

local function attach(part: BasePart, cf: CFrame, name: string)
	local a = Instance.new("Attachment")
	a.Name = name
	a.CFrame = cf
	a:SetAttribute(TAG, true)
	a.Parent = part
	return a
end

local function beam(a0: Attachment, a1: Attachment, color: Color3, width: number, transparency: number?)
	local b = Instance.new("Beam")
	b.Name = "CF_VizBeam"
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(color)
	b.Width0 = width
	b.Width1 = width
	b.FaceCamera = true
	b.LightEmission = 1
	b.LightInfluence = 0
	b.Segments = 1
	b.Transparency = NumberSequence.new(transparency or 0)
	b:SetAttribute(TAG, true)
	b.Parent = a0.Parent
	return b
end

local function marker(folder: Instance, adornee: BasePart, cf: CFrame, radius: number, color: Color3)
	local s = Instance.new("SphereHandleAdornment")
	s.Adornee = adornee
	s.CFrame = cf
	s.Radius = radius
	s.Color3 = color
	s.AlwaysOnTop = true
	s.ZIndex = 5
	s.Transparency = 0.05
	s.Parent = folder
	return s
end

local function tag(folder: Instance, adornee: Instance, text: string, color: Color3)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = adornee
	gui.Size = UDim2.fromOffset(110, 16)
	gui.StudsOffset = Vector3.new(0, 0.35, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = VIZ.LabelMaxDistance
	local t = Instance.new("TextLabel")
	t.BackgroundTransparency = 1
	t.Size = UDim2.fromScale(1, 1)
	t.Text = text
	t.TextSize = 10
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = color
	t.TextStrokeTransparency = 0.2
	t.Parent = gui
	gui.Parent = folder
end

-- data = {
--   joints = { { part0, part1, c0?, c1?, kind, name } },   -- parts = pièces du modèle cible
--   bones = { { part, cframe, parent? (index) , name } },
--   attachments = { { part, cframe } },
-- }
function RigVisualizer.show(model: Model, data)
	RigVisualizer.clear(model)
	local _, size = model:GetBoundingBox()
	local s = math.max(size.X, size.Y, size.Z)
	local width = math.clamp(s * 0.008, 0.04, 0.4)
	local radius = math.clamp(s * 0.012, 0.06, 0.6)

	local folder = Instance.new("Folder")
	folder.Name = "CF_RigView"
	folder.Parent = model

	local counts = { joints = 0, bones = 0, attachments = 0 }
	for _, j in data.joints do
		local p0, p1 = j.part0, j.part1
		if p0 and p1 and p0:IsA("BasePart") and p1:IsA("BasePart") then
			local color = VIZ.Colors[j.kind] or VIZ.Colors.Weld
			local c0 = j.c0 or p0.CFrame:ToObjectSpace(CFrame.new(p1.Position))
			local c1 = j.c1 or CFrame.new()
			local center0 = attach(p0, CFrame.new(), "CF_VizCenter")
			local center1 = attach(p1, CFrame.new(), "CF_VizCenter")
			local j0 = attach(p0, c0, "CF_VizJoint")
			local j1 = attach(p1, c1, "CF_VizJoint")
			beam(center0, j0, color, width)
			beam(j1, center1, color, width)
			beam(j0, j1, Color3.new(1, 1, 1), width * 0.6, 0.3) -- visible en vue éclatée
			marker(folder, p0, c0, radius, color)
			if j.kind == "Motor6D" then
				tag(folder, j0, j.name, color)
			end
			counts.joints += 1
		end
	end

	local boneAttachments = {}
	for i, b in data.bones do
		if b.part then
			boneAttachments[i] = attach(b.part, b.cframe, "CF_VizBone")
			marker(folder, b.part, b.cframe, radius * 0.8, VIZ.Colors.Bone)
			counts.bones += 1
		end
	end
	for i, b in data.bones do
		if b.parent and boneAttachments[i] and boneAttachments[b.parent] then
			beam(boneAttachments[b.parent], boneAttachments[i], VIZ.Colors.Bone, width)
		end
	end

	for i, a in data.attachments do
		if i > VIZ.MaxAttachmentMarkers then
			break
		end
		if a.part then
			marker(folder, a.part, a.cframe, radius * 0.45, VIZ.Colors.Attachment)
			counts.attachments += 1
		end
	end

	if model:GetAttribute(A .. "Blueprint") then
		for _, d in model:GetChildren() do
			if d:IsA("BasePart") and d.Transparency < 0.9 then
				d.Transparency = VIZ.BlueprintTransparencyRig
			end
		end
	end
	model:SetAttribute(A .. "RigShown", true)
	return counts
end

return RigVisualizer
