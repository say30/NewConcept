--!strict
-- The project model and the low-level operations on it.
--
-- A project is plain data (tables, strings, numbers, booleans) so it can be saved as JSON
-- as-is. Nodes live in a flat table keyed by GuiCreatorId; each node lists its children in
-- order. Every page owns one root node of type "Page", which becomes a ScreenGui.
--
-- Only commands (Core/Commands) should call the mutating functions below, so that every
-- change can be undone.

local Ids = require(script.Parent.Ids)
local Naming = require(script.Parent.Naming)
local Table = require(script.Parent.Parent.Util.Table)

export type Node = {
	id: string,
	name: string,
	type: string,
	parent: string?,
	children: { string },
	variant: string?,
	props: { [string]: any },
	states: { [string]: any },
	actions: { any },
	editor: { hidden: boolean, locked: boolean },
	pageId: string?, -- only set on page roots
}

export type Page = {
	id: string,
	name: string,
	rootId: string,
	openByDefault: boolean,
}

export type Project = {
	formatVersion: number,
	id: string,
	name: string,
	theme: { base: string, overrides: { [string]: any } },
	pages: { [string]: Page },
	pageOrder: { string },
	nodes: { [string]: Node },
	userAssets: { any },
	generation: { target: string },
}

-- Template used to insert nodes: a nested description without ids.
export type NodeTemplate = {
	type: string,
	name: string?,
	variant: string?,
	props: { [string]: any }?,
	states: { [string]: any }?,
	actions: { any }?,
	children: { NodeTemplate }?,
}

local Document = {}

Document.FORMAT_VERSION = 1
Document.PAGE_TYPE = "Page"
Document.DEFAULT_THEME = "Studs"

--------------------------------------------------------------------------------
-- Creation
--------------------------------------------------------------------------------

function Document.newNode(id: string, nodeType: string, name: string): Node
	return {
		id = id,
		name = name,
		type = nodeType,
		parent = nil,
		children = {},
		variant = nil,
		props = {},
		states = {},
		actions = {},
		editor = { hidden = false, locked = false },
	}
end

function Document.newProject(name: string?): Project
	return {
		formatVersion = Document.FORMAT_VERSION,
		id = Ids.new(),
		name = Naming.sanitize(name or "", "MyInterface"),
		theme = { base = Document.DEFAULT_THEME, overrides = {} },
		pages = {},
		pageOrder = {},
		nodes = {},
		userAssets = {},
		generation = { target = "StarterGui" },
	}
end

--------------------------------------------------------------------------------
-- Queries
--------------------------------------------------------------------------------

function Document.getNode(project: Project, id: string): Node?
	return project.nodes[id]
end

function Document.getPage(project: Project, pageId: string): Page?
	return project.pages[pageId]
end

function Document.getPages(project: Project): { Page }
	local pages = {}
	for _, pageId in project.pageOrder do
		table.insert(pages, project.pages[pageId])
	end
	return pages
end

function Document.findPageByName(project: Project, name: string): Page?
	for _, page in project.pages do
		if page.name == name then
			return page
		end
	end
	return nil
end

function Document.isPageRoot(node: Node): boolean
	return node.type == Document.PAGE_TYPE
end

-- True if `ancestorId` is `id` itself or one of its ancestors.
function Document.isAncestorOrSelf(project: Project, ancestorId: string, id: string): boolean
	local current: string? = id
	while current do
		if current == ancestorId then
			return true
		end
		local node = project.nodes[current]
		current = node and node.parent
	end
	return false
end

-- The page root above a node (or the node itself if it is a root).
function Document.getRoot(project: Project, id: string): Node?
	local node = project.nodes[id]
	while node and node.parent do
		node = project.nodes[node.parent]
	end
	return node
end

-- Ids of a node and all its descendants, parents before children.
function Document.subtreeIds(project: Project, id: string): { string }
	local result = {}
	local function visit(nodeId: string)
		table.insert(result, nodeId)
		local node = project.nodes[nodeId]
		if node then
			for _, childId in node.children do
				visit(childId)
			end
		end
	end
	visit(id)
	return result
end

function Document.childNames(project: Project, parentId: string, exceptId: string?): { [string]: boolean }
	local names = {}
	local parent = project.nodes[parentId]
	if parent then
		for _, childId in parent.children do
			if childId ~= exceptId then
				names[project.nodes[childId].name] = true
			end
		end
	end
	return names
end

function Document.pageNames(project: Project, exceptId: string?): { [string]: boolean }
	local names = {}
	for pageId, page in project.pages do
		if pageId ~= exceptId then
			names[page.name] = true
		end
	end
	return names
end

-- Describes an existing node and its subtree as a template (used by duplicate and copy).
function Document.toTemplate(project: Project, id: string): NodeTemplate
	local node = project.nodes[id]
	local children = {}
	for _, childId in node.children do
		table.insert(children, Document.toTemplate(project, childId))
	end
	return {
		type = node.type,
		name = node.name,
		variant = node.variant,
		props = Table.deepCopy(node.props),
		states = Table.deepCopy(node.states),
		actions = Table.deepCopy(node.actions),
		children = children,
	}
end

--------------------------------------------------------------------------------
-- Low-level mutations (commands only)
--------------------------------------------------------------------------------

local function clampIndex(index: number?, length: number): number
	if index == nil then
		return length + 1
	end
	return math.clamp(index, 1, length + 1)
end

-- Builds nodes from a template with fresh ids and names unique among their siblings.
-- Returns the nodes, root first, without attaching them to the project.
function Document.instantiate(project: Project, template: NodeTemplate, parentId: string?): { Node }
	local created: { Node } = {}
	local taken: { [string]: any } = table.clone(project.nodes)

	local function build(tpl: NodeTemplate, parent: string?, siblingNames: { [string]: boolean }): Node
		local id = Ids.newUnique(taken)
		taken[id] = true
		local name = Naming.unique(Naming.sanitize(tpl.name or tpl.type, tpl.type), siblingNames)
		siblingNames[name] = true

		local node = Document.newNode(id, tpl.type, name)
		node.parent = parent
		node.variant = tpl.variant
		node.props = Table.deepCopy(tpl.props or {})
		node.states = Table.deepCopy(tpl.states or {})
		node.actions = Table.deepCopy(tpl.actions or {})
		table.insert(created, node)

		local names = {}
		for _, childTpl in tpl.children or {} do
			local child = build(childTpl, id, names)
			table.insert(node.children, child.id)
		end
		return node
	end

	local rootNames = if parentId then Document.childNames(project, parentId) else {}
	build(template, parentId, rootNames)
	return created
end

-- Adds already-built nodes (root first) under `parentId` at `index`.
function Document.attach(project: Project, nodes: { Node }, parentId: string, index: number?): number
	local parent = project.nodes[parentId]
	assert(parent, "unknown parent " .. parentId)
	local root = nodes[1]
	for _, node in nodes do
		project.nodes[node.id] = node
	end
	root.parent = parentId
	local at = clampIndex(index, #parent.children)
	table.insert(parent.children, at, root.id)
	return at
end

-- Removes a node and its subtree. Returns what is needed to put it back.
function Document.detach(project: Project, id: string): ({ Node }, string?, number?)
	local node = project.nodes[id]
	assert(node, "unknown node " .. id)
	local removed = {}
	for _, nodeId in Document.subtreeIds(project, id) do
		table.insert(removed, project.nodes[nodeId])
		project.nodes[nodeId] = nil
	end

	local parentId = node.parent
	local index = nil
	if parentId then
		local parent = project.nodes[parentId]
		index = table.find(parent.children, id)
		if index then
			table.remove(parent.children, index)
		end
	end
	return removed, parentId, index
end

-- Moves a node to a new parent and position. Returns the old parent and index.
function Document.move(project: Project, id: string, newParentId: string, index: number?): (string, number)
	local node = project.nodes[id]
	assert(node and node.parent, "cannot move a page root")
	local oldParentId = node.parent :: string
	local oldParent = project.nodes[oldParentId]
	local oldIndex = table.find(oldParent.children, id) :: number
	table.remove(oldParent.children, oldIndex)

	local newParent = project.nodes[newParentId]
	table.insert(newParent.children, clampIndex(index, #newParent.children), id)
	node.parent = newParentId
	return oldParentId, oldIndex
end

return Document
