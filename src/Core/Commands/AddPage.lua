--!strict
-- Adds a page (HUD, Shop, Inventory...). Each page has a root node that becomes a ScreenGui.

local Document = require(script.Parent.Parent.Document)
local Ids = require(script.Parent.Parent.Ids)
local Naming = require(script.Parent.Parent.Naming)

local AddPage = {}

function AddPage.new(name: string, openByDefault: boolean?)
	local page: Document.Page? = nil
	local root: Document.Node? = nil
	local command = { label = "Add page", result = nil :: string? }

	function command.apply(project: Document.Project)
		if page == nil then
			local pageName = Naming.unique(Naming.sanitize(name, "Page"), Document.pageNames(project))
			local pageId = Ids.newUnique(project.pages)
			local rootNode = Document.newNode(Ids.newUnique(project.nodes), Document.PAGE_TYPE, pageName)
			rootNode.pageId = pageId
			root = rootNode
			page = {
				id = pageId,
				name = pageName,
				rootId = rootNode.id,
				openByDefault = if openByDefault == nil then #project.pageOrder == 0 else openByDefault,
			}
		end
		local p = page :: Document.Page
		project.pages[p.id] = p
		project.nodes[p.rootId] = root :: Document.Node
		table.insert(project.pageOrder, p.id)
		command.result = p.id
	end

	function command.revert(project: Document.Project)
		local p = page :: Document.Page
		project.pages[p.id] = nil
		project.nodes[p.rootId] = nil
		table.remove(project.pageOrder, table.find(project.pageOrder, p.id) :: number)
	end

	return command
end

return AddPage
