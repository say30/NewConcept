--!strict
-- Live miniatures: draws node templates with the real Builder in a throwaway project, then
-- scales the result down to fit a tile. Used by the assistant, the "Ajouter" gallery and
-- the style picker, so every choice shows exactly what it will create.

local Builder = require(script.Parent.Parent.Generator.Builder)
local Commands = require(script.Parent.Parent.Core.Commands)
local Document = require(script.Parent.Parent.Core.Document)
local Packs = require(script.Parent.Parent.Style.Packs)
local Store = require(script.Parent.Parent.Core.Store)
local Style = require(script.Parent.Parent.Style.Style)
local Ui = require(script.Parent.Ui)

local Preview = {}

-- The screen size a list of templates needs: their own pixel size plus a margin, or a
-- whole screen when they are placed relative to it (HUD).
function Preview.measure(templates: { any }, margin: number?): Vector2
	local m = margin or 40
	if #templates == 1 then
		local size = templates[1].props and templates[1].props.size
		if type(size) == "table" and size[1] == 0 and size[3] == 0 then
			return Vector2.new(size[2] + m * 2, size[4] + m * 2)
		end
	end
	return Vector2.new(1000, 560)
end

export type Options = {
	pack: string?,
	screen: Vector2?, -- simulated screen size (defaults to Preview.measure)
	box: Vector2, -- pixel size of the area to fill
	backdrop: boolean?, -- paint the pack's backdrop colour behind
	project: any?, -- copy the theme (pack and overrides) of this project
	lite: boolean?, -- coarser patterns, for small tiles drawn in numbers
}

-- Draws `templates` scaled into a new frame of size `box` inside `parent`.
function Preview.draw(parent: Instance, templates: { any }, options: Options): Frame
	local store = Store.new(Document.newProject("Preview"))
	if options.project then
		store.project.theme = table.clone(options.project.theme)
		store.project.theme.overrides = table.clone(options.project.theme.overrides or {})
	end
	if options.pack then
		store.project.theme.base = options.pack
	end
	if options.lite then
		store.project.theme.overrides.patternSize = 56
	end
	local _, pageId = store:dispatch(Commands.AddPage.new("Preview"))
	local page = store.project.pages[pageId]
	for _, template in templates do
		store:dispatch(Commands.InsertTree.new(template, page.rootId))
	end

	local screen = options.screen or Preview.measure(templates)
	local box = options.box
	local scale = math.min(box.X / screen.X, box.Y / screen.Y)
	local holder = Ui.new("Frame", {
		Name = "Preview",
		BackgroundTransparency = if options.backdrop then 0 else 1,
		BackgroundColor3 = Style.color(Packs.get(store.project.theme.base).tokens.backdrop),
		BorderSizePixel = 0,
		ClipsDescendants = true,
		Size = UDim2.fromOffset(box.X, box.Y),
		Parent = parent,
	}, { Ui.corner(8) })
	local stage = Ui.new("Frame", {
		Name = "Stage",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(screen.X, screen.Y),
		Parent = holder,
	}, { Ui.new("UIScale", { Scale = scale }) })
	local ctx = Builder.newContext(store.project, "preview", screen)
	Builder.syncNode(ctx, page.rootId, stage)
	return holder
end

return Preview
