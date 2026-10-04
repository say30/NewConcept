--!strict
-- Renames the project (the name shown in the project list).

local Naming = require(script.Parent.Parent.Naming)

local RenameProject = {}

function RenameProject.new(newName: string)
	local before = ""
	local command = { label = "Rename project" }

	function command.apply(project: any)
		before = project.name
		project.name = Naming.sanitize(newName, project.name)
	end

	function command.revert(project: any)
		project.name = before
	end

	return command
end

return RenameProject
