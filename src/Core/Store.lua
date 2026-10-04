--!strict
-- Holds the open project. Panels never edit the project directly: they dispatch commands
-- and listen to `changed` to redraw.

local Document = require(script.Parent.Document)
local History = require(script.Parent.History)
local Selection = require(script.Parent.Selection)
local Signal = require(script.Parent.Parent.Util.Signal)

local Store = {}
Store.__index = Store

function Store.new(project: Document.Project?)
	local self = setmetatable({
		project = project or Document.newProject(),
		history = History.new(),
		selection = Selection.new(),
		-- Fired after every successful change: (reason: "dispatch" | "undo" | "redo" | "load", command?)
		changed = Signal.new(),
		-- Increases on every change; persistence uses it to know when to save.
		revision = 0,
	}, Store)
	return self
end

function Store:_changed(reason: string, command: any?)
	self.revision += 1
	self.selection:prune(self.project.nodes)
	self.changed:Fire(reason, command)
end

-- Applies a command. Returns true and the command's result, or false and an error message.
-- A failing command leaves the project untouched.
function Store:dispatch(command: any): (boolean, any)
	local ok, err = pcall(command.apply, self.project)
	if not ok then
		return false, err
	end
	self.history:record(command)
	self:_changed("dispatch", command)
	return true, command.result
end

function Store:undo(): boolean
	if not self.history:canUndo() then
		return false
	end
	local command = self.history:popUndo()
	command.revert(self.project)
	self:_changed("undo", command)
	return true
end

function Store:redo(): boolean
	if not self.history:canRedo() then
		return false
	end
	local command = self.history:popRedo()
	command.apply(self.project)
	self:_changed("redo", command)
	return true
end

function Store:beginGroup(label: string)
	self.history:beginGroup(label)
end

function Store:endGroup()
	self.history:endGroup()
end

-- Replaces the whole project (opening another project). History is reset.
function Store:load(project: Document.Project)
	self.project = project
	self.history:clear()
	self.selection:clear()
	self:_changed("load", nil)
end

return Store
