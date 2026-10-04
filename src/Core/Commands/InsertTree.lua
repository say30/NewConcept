--!strict
-- Adds a node, or a whole tree of nodes (a preset, a pasted copy), under a parent.
-- Used by "Add a button", presets and paste alike: once inserted, nodes are ordinary
-- nodes with no link to where they came from.

local Document = require(script.Parent.Parent.Document)

local InsertTree = {}

function InsertTree.new(template: Document.NodeTemplate, parentId: string, index: number?)
	local inserted: { Document.Node }? = nil

	local command = {
		label = "Add " .. (template.name or template.type),
		result = nil :: string?,
	}

	function command.apply(project: Document.Project)
		local parent = Document.getNode(project, parentId)
		assert(parent, "Parent not found")
		if inserted == nil then
			inserted = Document.instantiate(project, template, parentId)
		end
		local nodes = inserted :: { Document.Node }
		Document.attach(project, nodes, parentId, index)
		command.result = nodes[1].id
	end

	function command.revert(project: Document.Project)
		local nodes = inserted :: { Document.Node }
		Document.detach(project, nodes[1].id)
	end

	return command
end

return InsertTree
