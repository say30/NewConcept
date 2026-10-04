--!strict
-- Undo/redo stacks. A group (beginGroup/endGroup) turns everything dispatched in between
-- into a single undo step, for example all the small changes of one slider drag.

local Composite = require(script.Parent.Commands.Composite)

local History = {}
History.__index = History

History.LIMIT = 200

function History.new()
	return setmetatable({
		undoStack = {} :: { any },
		redoStack = {} :: { any },
		groupDepth = 0,
		groupLabel = "",
		groupCommands = {} :: { any },
	}, History)
end

-- Called by the Store after a command was applied successfully.
function History:record(command: any)
	table.clear(self.redoStack)
	if self.groupDepth > 0 then
		table.insert(self.groupCommands, command)
		return
	end
	table.insert(self.undoStack, command)
	if #self.undoStack > History.LIMIT then
		table.remove(self.undoStack, 1)
	end
end

function History:beginGroup(label: string)
	if self.groupDepth == 0 then
		self.groupLabel = label
		self.groupCommands = {}
	end
	self.groupDepth += 1
end

function History:endGroup()
	assert(self.groupDepth > 0, "endGroup without beginGroup")
	self.groupDepth -= 1
	if self.groupDepth > 0 or #self.groupCommands == 0 then
		return
	end
	local commands = self.groupCommands
	self.groupCommands = {}
	if #commands == 1 then
		self:record(commands[1])
	else
		self:record(Composite.new(self.groupLabel, commands))
	end
end

function History:isGrouping(): boolean
	return self.groupDepth > 0
end

function History:canUndo(): boolean
	return #self.undoStack > 0 and self.groupDepth == 0
end

function History:canRedo(): boolean
	return #self.redoStack > 0 and self.groupDepth == 0
end

function History:popUndo(): any
	local command = table.remove(self.undoStack)
	if command then
		table.insert(self.redoStack, command)
	end
	return command
end

function History:popRedo(): any
	local command = table.remove(self.redoStack)
	if command then
		table.insert(self.undoStack, command)
	end
	return command
end

function History:clear()
	table.clear(self.undoStack)
	table.clear(self.redoStack)
	self.groupDepth = 0
	self.groupCommands = {}
end

return History
