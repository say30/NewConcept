--!strict
-- Turns a project into text and back. The JSON codec is injected so the same code runs in
-- Studio (HttpService) and in the test runner.

local Document = require(script.Parent.Parent.Core.Document)
local Migrations = require(script.Parent.Migrations)

export type Codec = {
	encode: (value: any) -> string,
	decode: (text: string) -> any,
}

local Serializer = {}

function Serializer.encode(project: Document.Project, codec: Codec): string
	return codec.encode(project)
end

-- JSON turns empty tables into [] and drops nil fields; put back what the model expects.
local function normalize(project: any)
	project.pages = project.pages or {}
	project.pageOrder = project.pageOrder or {}
	project.nodes = project.nodes or {}
	project.userAssets = project.userAssets or {}
	project.theme = project.theme or { base = Document.DEFAULT_THEME, overrides = {} }
	project.theme.overrides = project.theme.overrides or {}
	project.generation = project.generation or { target = "StarterGui" }
	for _, node in project.nodes do
		node.children = node.children or {}
		node.props = node.props or {}
		node.states = node.states or {}
		node.actions = node.actions or {}
		node.editor = node.editor or { hidden = false, locked = false }
	end
end

-- Returns a list of problems; an empty list means the project is consistent.
function Serializer.validate(project: any): { string }
	local problems = {}
	local function problem(text: string)
		table.insert(problems, text)
	end

	if type(project) ~= "table" or type(project.nodes) ~= "table" then
		return { "Not a project" }
	end
	for id, node in project.nodes do
		if node.id ~= id then
			problem("Node key and id differ: " .. tostring(id))
		end
		if node.parent then
			local parent = project.nodes[node.parent]
			if not parent then
				problem(id .. " has a missing parent")
			elseif not table.find(parent.children, id) then
				problem(id .. " is not listed by its parent")
			end
		elseif node.type ~= Document.PAGE_TYPE then
			problem(id .. " has no parent and is not a page")
		end
		for _, childId in node.children do
			local child = project.nodes[childId]
			if not child or child.parent ~= id then
				problem(id .. " lists a wrong child " .. tostring(childId))
			end
		end
	end
	for _, pageId in project.pageOrder do
		local page = project.pages[pageId]
		if not page then
			problem("Unknown page in order: " .. tostring(pageId))
		elseif not project.nodes[page.rootId] then
			problem("Page " .. page.name .. " has no root")
		end
	end
	return problems
end

function Serializer.decode(text: string, codec: Codec): Document.Project
	local ok, data = pcall(codec.decode, text)
	assert(ok and type(data) == "table", "The saved project could not be read")
	normalize(data)
	Migrations.run(data, Document.FORMAT_VERSION)
	local problems = Serializer.validate(data)
	assert(#problems == 0, "The saved project is damaged: " .. table.concat(problems, "; "))
	return data
end

return Serializer
