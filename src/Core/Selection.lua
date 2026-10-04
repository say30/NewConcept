--!strict
-- The selected elements, shared by the canvas, the Layers panel and the inspector.

local Signal = require(script.Parent.Parent.Util.Signal)

local Selection = {}
Selection.__index = Selection

function Selection.new()
	return setmetatable({
		ids = {} :: { string },
		changed = Signal.new(),
	}, Selection)
end

function Selection:get(): { string }
	return table.clone(self.ids)
end

function Selection:primary(): string?
	return self.ids[#self.ids]
end

function Selection:isSelected(id: string): boolean
	return table.find(self.ids, id) ~= nil
end

function Selection:set(ids: { string })
	local unique = {}
	for _, id in ids do
		if not table.find(unique, id) then
			table.insert(unique, id)
		end
	end
	self.ids = unique
	self.changed:Fire(self:get())
end

function Selection:toggle(id: string)
	local ids = self:get()
	local index = table.find(ids, id)
	if index then
		table.remove(ids, index)
	else
		table.insert(ids, id)
	end
	self:set(ids)
end

function Selection:clear()
	if #self.ids > 0 then
		self:set({})
	end
end

-- Drops ids that no longer exist in the project (after a delete or an undo).
function Selection:prune(nodes: { [string]: any })
	local kept = {}
	for _, id in self.ids do
		if nodes[id] then
			table.insert(kept, id)
		end
	end
	if #kept ~= #self.ids then
		self:set(kept)
	end
end

return Selection
