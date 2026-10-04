--!strict
-- Switches the project theme. Every property linked to the theme ("$primary"...) follows.

local SetTheme = {}

function SetTheme.new(themeName: string)
	local before = ""
	local command = { label = "Change theme" }

	function command.apply(project: any)
		before = project.theme.base
		project.theme.base = themeName
	end

	function command.revert(project: any)
		project.theme.base = before
	end

	return command
end

return SetTheme
