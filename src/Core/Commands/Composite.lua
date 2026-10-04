--!strict
-- Several commands applied as one undo step (a slider drag, align, a generated preset...).
-- If one of them fails, the ones already applied are reverted.

local Composite = {}

function Composite.new(label: string, commands: { any })
	local command = { label = label, commands = commands }

	function command.apply(project: any)
		for i, child in commands do
			local ok, err = pcall(child.apply, project)
			if not ok then
				for j = i - 1, 1, -1 do
					commands[j].revert(project)
				end
				error(err, 0)
			end
		end
	end

	function command.revert(project: any)
		for i = #commands, 1, -1 do
			commands[i].revert(project)
		end
	end

	return command
end

return Composite
