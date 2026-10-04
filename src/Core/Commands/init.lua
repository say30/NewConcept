--!strict
-- Every change to a project goes through a command. A command knows how to apply itself
-- and how to revert exactly what it did, which gives undo/redo everywhere.
--
-- A command must check everything it needs before touching the project and raise an error
-- instead of applying half of a change: the Store relies on that to stay consistent.

export type Command = {
	label: string,
	apply: (project: any) -> (),
	revert: (project: any) -> (),
	-- Optional value for the caller once applied (for example the id of a new node).
	result: any?,
}

return {
	InsertTree = require(script.InsertTree),
	DeleteNodes = require(script.DeleteNodes),
	SetProps = require(script.SetProps),
	SetEditorFlag = require(script.SetEditorFlag),
	Rename = require(script.Rename),
	Move = require(script.Move),
	AddPage = require(script.AddPage),
	RemovePage = require(script.RemovePage),
	RenamePage = require(script.RenamePage),
	SetTheme = require(script.SetTheme),
	RenameProject = require(script.RenameProject),
	SetPageOpen = require(script.SetPageOpen),
	Composite = require(script.Composite),
}
