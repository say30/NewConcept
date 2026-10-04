--!strict
-- Deletes nodes and everything inside them. Page roots are removed with RemovePage.

local Document = require(script.Parent.Parent.Document)

local DeleteNodes = {}

function DeleteNodes.new(ids: { string })
	type Removed = { nodes: { Document.Node }, parentId: string, index: number }
	local removed: { Removed } = {}

	local command = { label = if #ids == 1 then "Delete" else "Delete " .. #ids .. " elements" }

	function command.apply(project: Document.Project)
		-- Skip ids already inside another deleted node.
		local targets = {}
		for _, id in ids do
			local node = Document.getNode(project, id)
			assert(node, "Element not found")
			assert(not Document.isPageRoot(node), "Use RemovePage to delete a page")
			local covered = false
			for _, other in ids do
				if other ~= id and Document.isAncestorOrSelf(project, other, id) then
					covered = true
					break
				end
			end
			if not covered then
				table.insert(targets, id)
			end
		end

		table.clear(removed)
		for _, id in targets do
			local nodes, parentId, index = Document.detach(project, id)
			table.insert(removed, { nodes = nodes, parentId = parentId :: string, index = index :: number })
		end
	end

	function command.revert(project: Document.Project)
		for i = #removed, 1, -1 do
			local entry = removed[i]
			Document.attach(project, entry.nodes, entry.parentId, entry.index)
		end
	end

	return command
end

return DeleteNodes
