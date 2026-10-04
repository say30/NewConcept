--!strict
-- Hides or locks a node in the editor. Hidden nodes are still generated, just not shown
-- while editing; locked nodes cannot be selected on the canvas.

local Document = require(script.Parent.Parent.Document)

local SetEditorFlag = {}

function SetEditorFlag.new(nodeId: string, flag: "hidden" | "locked", value: boolean)
	local before = false
	local command = { label = if flag == "hidden" then "Hide" else "Lock" }

	function command.apply(project: Document.Project)
		local node = Document.getNode(project, nodeId)
		assert(node, "Element not found")
		before = node.editor[flag]
		node.editor[flag] = value
	end

	function command.revert(project: Document.Project)
		local node = Document.getNode(project, nodeId) :: Document.Node
		node.editor[flag] = before
	end

	return command
end

return SetEditorFlag
