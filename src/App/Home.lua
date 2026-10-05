--!strict
-- The first screen: two big choices (let the assistant build a window, or start from an
-- empty page), the kinds of windows the assistant knows, and the current project.

local Icons = require(script.Parent.Parent.Visual.Icons)
local Patterns = require(script.Parent.Parent.Visual.Patterns)
local Preview = require(script.Parent.Preview)
local Recipes = require(script.Parent.Parent.Catalog.Recipes)
local Ui = require(script.Parent.Ui)

local Home = {}
Home.__index = Home

function Home.new(editor: any, parent: Instance)
	local self = setmetatable({}, Home)
	self.editor = editor
	self.frame = Ui.new("Frame", {
		Name = "Home",
		BackgroundColor3 = Ui.colors.background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = parent,
	})
	return self
end

local function icon(id: string, size: number, parent: Instance, props: { [string]: any }?): Frame
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	for key, value in props or {} do
		(holder :: any)[key] = value
	end
	Icons.build(id, holder, 1)
	return holder
end

-- A big choice card: a picture on top, a title and one line of text below.
local function choiceCard(
	parent: Instance,
	order: number,
	color: Color3,
	title: string,
	text: string,
	onClick: () -> ()
): Frame
	local card = Ui.new("TextButton", {
		Text = "",
		AutoButtonColor = true,
		BackgroundColor3 = color:Lerp(Color3.new(0, 0, 0), 0.4),
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(440, 300),
		LayoutOrder = order,
		Parent = parent,
	}, { Ui.corner(18) })
	local face = Ui.new("Frame", {
		BackgroundColor3 = color,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 1, -6),
		Parent = card,
	}, {
		Ui.corner(18),
		Ui.new("UIGradient", {
			Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(200, 200, 200)),
			Rotation = 90,
		}),
	})
	local picture = Ui.new("Frame", {
		Name = "Picture",
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.82,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(14, 14),
		Size = UDim2.new(1, -28, 0, 196),
		ClipsDescendants = true,
		Parent = face,
	}, { Ui.corner(12) })
	Ui.title(title, 28, {
		Position = UDim2.new(0, 18, 1, -78),
		Size = UDim2.new(1, -36, 0, 32),
		TextColor3 = Color3.new(1, 1, 1),
		Parent = face,
	})
	Ui.label(text, {
		Font = Ui.fontBold,
		TextSize = 15,
		TextWrapped = true,
		TextTruncate = Enum.TextTruncate.None,
		TextColor3 = Color3.fromRGB(235, 240, 255),
		Position = UDim2.new(0, 18, 1, -44),
		Size = UDim2.new(1, -36, 0, 36),
		TextYAlignment = Enum.TextYAlignment.Top,
		Parent = face,
	})
	Ui.connect(card, "MouseButton1Click", onClick)
	return picture
end

function Home:render()
	local editor = self.editor
	Ui.clear(self.frame)
	for _, child in self.frame:GetChildren() do
		child:Destroy()
	end

	-- Soft studs behind everything, like a Roblox baseplate.
	local backdrop = Ui.new("CanvasGroup", {
		BackgroundTransparency = 1,
		GroupTransparency = 0.94,
		Size = UDim2.fromScale(1, 1),
		Parent = self.frame,
	})
	Patterns.build(backdrop, "Studs", 1600, 1000, Color3.new(1, 1, 1), 44)

	local scroll = Ui.scroll({ Parent = self.frame })
	Ui.list("Vertical", 18).Parent = scroll
	Ui.padding(28, 40).Parent = scroll
	local list = scroll:FindFirstChildOfClass("UIListLayout") :: UIListLayout
	list.HorizontalAlignment = Enum.HorizontalAlignment.Center

	-- Header: logo and name.
	local header = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 72),
		LayoutOrder = 1,
		Parent = scroll,
	})
	icon("LuckyBlock", 64, header, { Position = UDim2.fromOffset(0, 4) })
	Ui.title(
		"GuiCreator",
		40,
		{ Position = UDim2.fromOffset(78, 2), Size = UDim2.fromOffset(500, 44), Parent = header }
	)
	Ui.label("Crée de belles interfaces Roblox en quelques clics.", {
		Font = Ui.fontBold,
		TextSize = 17,
		TextColor3 = Ui.colors.muted,
		Position = UDim2.fromOffset(80, 46),
		Size = UDim2.fromOffset(600, 22),
		Parent = header,
	})
	local projectButton = Ui.bigButton("Mes projets", {
		color = Ui.colors.panelLight,
		size = UDim2.fromOffset(150, 42),
		textSize = 16,
		onClick = function()
			editor:openProjects()
		end,
	})
	projectButton.AnchorPoint = Vector2.new(1, 0)
	projectButton.Position = UDim2.new(1, 0, 0, 14)
	projectButton.Parent = header

	-- The two big choices.
	local choices = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 300),
		LayoutOrder = 2,
		Parent = scroll,
	}, { Ui.list("Horizontal", 20) })
	local wizardPicture = choiceCard(
		choices,
		1,
		Color3.fromRGB(63, 169, 245),
		"Assistant",
		"Choisis un type de fenêtre, réponds à quelques questions en images : elle se construit toute seule.",
		function()
			editor:showWizard(nil)
		end
	)
	local shop = Recipes.get("Shop") :: any
	Preview.draw(
		wizardPicture,
		Recipes.build(shop, {}),
		{
			pack = "Studs",
			box = Vector2.new(412, 196),
			lite = true,
		} :: any
	)

	local freePicture = choiceCard(
		choices,
		2,
		Color3.fromRGB(183, 107, 255),
		"Je crée moi-même",
		"Une page vide : ajoute fenêtres, cartes, boutons et icônes depuis la galerie.",
		function()
			editor:startBlank()
		end
	)
	icon("Plus", 110, freePicture, {
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
	})

	-- Continue the open project when it has something in it.
	if editor:projectHasContent() then
		local continueButton = Ui.bigButton("Continuer « " .. editor.store.project.name .. " »", {
			color = Ui.colors.success,
			size = UDim2.fromOffset(420, 50),
			order = 3,
			textSize = 20,
			onClick = function()
				editor:showWorkspace()
			end,
		})
		continueButton.Parent = scroll
	end

	-- Every kind of window the assistant knows.
	Ui.title("Ou choisis directement ce que tu veux créer", 22, {
		Size = UDim2.fromOffset(900, 30),
		LayoutOrder = 4,
		Parent = scroll,
	})
	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(900, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 5,
		Parent = scroll,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(166, 128),
			CellPadding = UDim2.fromOffset(17, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, recipe in Recipes.list() do
		local _, picture = Ui.tile({
			order = i,
			label = recipe.label,
			parent = grid,
			onClick = function()
				editor:showWizard(recipe.id)
			end,
		})
		icon(recipe.icon, 72, picture, {
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
		})
	end
end

return Home
