--!strict
-- Chooses whether a page is visible when the game starts.

local SetPageOpen = {}

function SetPageOpen.new(pageId: string, open: boolean)
	local before = false
	local command = { label = "Page visibility" }

	function command.apply(project: any)
		local page = project.pages[pageId]
		assert(page, "Page not found")
		before = page.openByDefault
		page.openByDefault = open
	end

	function command.revert(project: any)
		project.pages[pageId].openByDefault = before
	end

	return command
end

return SetPageOpen
