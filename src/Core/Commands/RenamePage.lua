--!strict
-- Renames a page and its root node (the ScreenGui keeps the page name).

local Document = require(script.Parent.Parent.Document)
local Naming = require(script.Parent.Parent.Naming)

local RenamePage = {}

function RenamePage.new(pageId: string, newName: string)
	local before = ""
	local command = { label = "Rename page", result = nil :: string? }

	function command.apply(project: Document.Project)
		local page = Document.getPage(project, pageId)
		assert(page, "Page not found")
		before = page.name
		local name = Naming.unique(Naming.sanitize(newName, page.name), Document.pageNames(project, pageId))
		page.name = name
		project.nodes[page.rootId].name = name
		command.result = name
	end

	function command.revert(project: Document.Project)
		local page = Document.getPage(project, pageId) :: Document.Page
		page.name = before
		project.nodes[page.rootId].name = before
	end

	return command
end

return RenamePage
