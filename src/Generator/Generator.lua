--!strict
-- Writes the project into the game as real ScreenGuis, Frames, TextButtons, UICorners...
-- Running it again updates what it built before (matched by GuiCreatorId) instead of
-- deleting everything, so objects added by hand inside the generated interface survive.

local Builder = require(script.Parent.Builder)
local Ids = require(script.Parent.Parent.Core.Ids)

local Generator = {}

export type Report = { pages: number, elements: number, removed: number }

function Generator.generate(project: any, target: Instance): Report
	local ctx = Builder.newContext(project, "game")
	local keep = {}
	for _, pageId in project.pageOrder do
		local page = project.pages[pageId]
		keep[page.rootId] = true
		Builder.syncNode(ctx, page.rootId, target)
	end

	local removed = 0
	for _, child in target:GetChildren() do
		local id = child:GetAttribute(Ids.ATTRIBUTE)
		if id and child:GetAttribute(Builder.PROJECT_ATTRIBUTE) == project.id and not keep[id] then
			child:Destroy()
			removed += 1
		end
	end

	local elements = 0
	for _ in ctx.instances do
		elements += 1
	end
	return { pages = #project.pageOrder, elements = elements, removed = removed }
end

return Generator
