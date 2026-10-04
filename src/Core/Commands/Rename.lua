--!strict
-- Renames a node. The name is cleaned up and made unique among its siblings, because it
-- becomes the Instance name in the generated interface.

local Document = require(script.Parent.Parent.Document)
local Naming = require(script.Parent.Parent.Naming)

local Rename = {}

function Rename.new(nodeId: string, newName: string)
	local before = ""
	local command = { label = "Rename", result = nil :: string? }

	function command.apply(project: Document.Project)
		local node = Document.getNode(project, nodeId)
		assert(node, "Element not found")
		before = node.name
		local clean = Naming.sanitize(newName, node.name)
		local taken = if node.parent then Document.childNames(project, node.parent, nodeId) else {}
		node.name = Naming.unique(clean, taken)
		command.result = node.name
	end

	function command.revert(project: Document.Project)
		local node = Document.getNode(project, nodeId) :: Document.Node
		node.name = before
	end

	return command
end

return Rename
