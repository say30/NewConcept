--!strict
-- Changes one or more properties of a node. Paths are relative to node.props:
-- { path = {"text", "size"}, value = 24 }. A nil value removes the property, which for a
-- theme-linked property means "back to the theme".

local Document = require(script.Parent.Parent.Document)
local Table = require(script.Parent.Parent.Parent.Util.Table)

export type Change = { path: { string }, value: any }

local SetProps = {}

function SetProps.new(nodeId: string, changes: { Change }, label: string?)
	local previous: { any } = {}

	local command = { label = label or "Edit properties" }

	function command.apply(project: Document.Project)
		local node = Document.getNode(project, nodeId)
		assert(node, "Element not found")
		for i, change in changes do
			assert(#change.path > 0, "Empty property path")
			previous[i] = Table.deepCopy(Table.getPath(node.props, change.path))
		end
		for _, change in changes do
			Table.setPath(node.props, change.path, Table.deepCopy(change.value))
		end
	end

	function command.revert(project: Document.Project)
		local node = Document.getNode(project, nodeId) :: Document.Node
		for i = #changes, 1, -1 do
			Table.setPath(node.props, changes[i].path, Table.deepCopy(previous[i]))
		end
	end

	return command
end

return SetProps
