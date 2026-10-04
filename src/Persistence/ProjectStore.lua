--!strict
-- Saves projects inside the place, under ServerStorage/GuiCreator/Projects.
-- ServerStorage is never sent to players, and it is saved with the place: close Studio,
-- reopen, and the project is still there.
--
-- Each project is a Folder holding its JSON split across StringValues, because a single
-- StringValue has a size limit.

local Serializer = require(script.Parent.Serializer)

local ProjectStore = {}
ProjectStore.__index = ProjectStore

ProjectStore.ROOT_NAME = "GuiCreator"
ProjectStore.PROJECTS_NAME = "Projects"
ProjectStore.CHUNK_SIZE = 100000

export type Summary = { id: string, name: string, savedAt: number }

-- `container` is ServerStorage in Studio; `codec` encodes and decodes JSON.
function ProjectStore.new(container: Instance, codec: Serializer.Codec)
	return setmetatable({ container = container, codec = codec }, ProjectStore)
end

function ProjectStore:_folder(create: boolean): Instance?
	local root = self.container:FindFirstChild(ProjectStore.ROOT_NAME)
	if not root then
		if not create then
			return nil
		end
		root = Instance.new("Folder")
		root.Name = ProjectStore.ROOT_NAME
		root.Parent = self.container
	end
	local projects = root:FindFirstChild(ProjectStore.PROJECTS_NAME)
	if not projects and create then
		projects = Instance.new("Folder")
		projects.Name = ProjectStore.PROJECTS_NAME
		projects.Parent = root
	end
	return projects
end

function ProjectStore:_find(projectId: string): Instance?
	local folder = self:_folder(false)
	if not folder then
		return nil
	end
	for _, child in folder:GetChildren() do
		if child:GetAttribute("ProjectId") == projectId then
			return child
		end
	end
	return nil
end

function ProjectStore:list(): { Summary }
	local result = {}
	local folder = self:_folder(false)
	if folder then
		for _, child in folder:GetChildren() do
			local id = child:GetAttribute("ProjectId")
			if type(id) == "string" then
				table.insert(result, {
					id = id,
					name = child.Name,
					savedAt = child:GetAttribute("SavedAt") or 0,
				})
			end
		end
	end
	table.sort(result, function(a, b)
		return a.savedAt > b.savedAt
	end)
	return result
end

function ProjectStore:save(project: any, now: number?)
	local text = Serializer.encode(project, self.codec)
	local entry = self:_find(project.id)
	if not entry then
		entry = Instance.new("Folder")
		entry:SetAttribute("ProjectId", project.id)
		entry.Parent = self:_folder(true)
	end
	local target = entry :: Instance
	target.Name = project.name
	target:SetAttribute("FormatVersion", project.formatVersion)
	target:SetAttribute("SavedAt", now or os.time())

	-- Write the new chunks, then remove the extra old ones.
	local count = math.max(1, math.ceil(#text / ProjectStore.CHUNK_SIZE))
	for i = 1, count do
		local name = string.format("Chunk%03d", i)
		local value = target:FindFirstChild(name) :: StringValue?
		if not value then
			local created = Instance.new("StringValue")
			created.Name = name
			created.Parent = target
			value = created
		end
		(value :: StringValue).Value =
			string.sub(text, (i - 1) * ProjectStore.CHUNK_SIZE + 1, i * ProjectStore.CHUNK_SIZE)
	end
	for _, child in target:GetChildren() do
		local index = tonumber(string.match(child.Name, "^Chunk(%d+)$"))
		if index and index > count then
			child:Destroy()
		end
	end
end

function ProjectStore:load(projectId: string): any
	local entry = self:_find(projectId)
	assert(entry, "Project not found in this place")
	local chunks = {}
	for _, child in entry:GetChildren() do
		local index = tonumber(string.match(child.Name, "^Chunk(%d+)$"))
		if index and child:IsA("StringValue") then
			chunks[index] = child.Value
		end
	end
	return Serializer.decode(table.concat(chunks), self.codec)
end

function ProjectStore:delete(projectId: string)
	local entry = self:_find(projectId)
	if entry then
		entry:Destroy()
	end
end

return ProjectStore
