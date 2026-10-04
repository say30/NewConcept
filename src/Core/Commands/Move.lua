--!strict
-- Moves a node in the hierarchy (drag and drop in the Layers panel).

local Document = require(script.Parent.Parent.Document)
local Naming = require(script.Parent.Parent.Naming)

local Move = {}

function Move.new(nodeId: string, newParentId: string, index: number?)
	local oldParentId, oldIndex = "", 0
	local oldName = ""
	local command = { label = "Move" }

	function command.apply(project: Document.Project)
		local node = Document.getNode(project, nodeId)
		assert(node, "Element not found")
		assert(node.parent, "A page cannot be moved")
		assert(Document.getNode(project, newParentId), "Destination not found")
		assert(
			not Document.isAncestorOrSelf(project, nodeId, newParentId),
			"An element cannot be moved inside itself"
		)

		oldName = node.name
		if newParentId ~= node.parent then
			node.name = Naming.unique(node.name, Document.childNames(project, newParentId))
		end
		oldParentId, oldIndex = Document.move(project, nodeId, newParentId, index)
	end

	function command.revert(project: Document.Project)
		Document.move(project, nodeId, oldParentId, oldIndex)
		local node = Document.getNode(project, nodeId) :: Document.Node
		node.name = oldName
	end

	return command
end

return Move
