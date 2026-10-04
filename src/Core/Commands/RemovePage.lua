--!strict
-- Removes a page and everything on it.

local Document = require(script.Parent.Parent.Document)

local RemovePage = {}

function RemovePage.new(pageId: string)
	local page: Document.Page? = nil
	local nodes: { Document.Node } = {}
	local order = 0
	local command = { label = "Delete page" }

	function command.apply(project: Document.Project)
		local p = Document.getPage(project, pageId)
		assert(p, "Page not found")
		page = p
		order = table.find(project.pageOrder, pageId) :: number
		nodes = Document.detach(project, p.rootId)
		project.pages[pageId] = nil
		table.remove(project.pageOrder, order)
	end

	function command.revert(project: Document.Project)
		local p = page :: Document.Page
		project.pages[pageId] = p
		table.insert(project.pageOrder, order, pageId)
		for _, node in nodes do
			project.nodes[node.id] = node
		end
	end

	return command
end

return RemovePage
