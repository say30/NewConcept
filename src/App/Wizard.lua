--!strict
-- The assistant: one question at a time, each answer picked from pictures. The big preview
-- on the left always shows the window as it will be built, and every tile on the right
-- shows the window (or the icon, colour, pattern) that this answer gives.

local Icons = require(script.Parent.Parent.Visual.Icons)
local Patterns = require(script.Parent.Parent.Visual.Patterns)
local Preview = require(script.Parent.Preview)
local Recipes = require(script.Parent.Parent.Catalog.Recipes)
local Style = require(script.Parent.Parent.Style.Style)
local Packs = require(script.Parent.Parent.Style.Packs)
local Table = require(script.Parent.Parent.Util.Table)
local Ui = require(script.Parent.Ui)

local Wizard = {}
Wizard.__index = Wizard

local HEADER = 70
local FOOTER = 74

function Wizard.new(editor: any, parent: Instance)
	local self = setmetatable({}, Wizard)
	self.editor = editor
	self.recipe = nil :: any
	self.answers = {} :: { [string]: any }
	self.step = 1
	self.frame = Ui.new("Frame", {
		Name = "Wizard",
		BackgroundColor3 = Ui.colors.background,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		Parent = parent,
	})
	Ui.onPropertyChanged(self.frame, "AbsoluteSize", function()
		if self.frame.Visible then
			self:render()
		end
	end)
	return self
end

-- Starts the assistant, on the list of window kinds (recipeId nil) or on a recipe.
function Wizard:start(recipeId: string?)
	self.recipe = if recipeId then Recipes.get(recipeId) else nil
	self.answers = if self.recipe then Recipes.defaults(self.recipe) else {}
	self.step = 1
	self:render()
end

function Wizard:_size(): Vector2
	local size = Ui.absoluteSize(self.frame)
	if size.X < 200 then
		return Vector2.new(1280, 760)
	end
	return size
end

local function icon(id: string, size: number, parent: Instance)
	local holder = Ui.new("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(size, size),
		Parent = parent,
	})
	Icons.build(id, holder, 1)
	return holder
end

function Wizard:render()
	for _, child in self.frame:GetChildren() do
		child:Destroy()
	end
	if not self.recipe then
		self:_renderKinds()
	else
		self:_renderQuestion()
	end
end

function Wizard:_header(title: string, iconId: string?)
	local header = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, HEADER),
		Parent = self.frame,
	})
	local back = Ui.bigButton("Accueil", {
		color = Ui.colors.panelLight,
		size = UDim2.fromOffset(120, 42),
		textSize = 16,
		onClick = function()
			self.editor:showHome()
		end,
	})
	back.Position = UDim2.fromOffset(16, 14)
	back.Parent = header
	if iconId then
		icon(iconId, 48, header).Position = UDim2.fromOffset(176, HEADER / 2)
	end
	Ui.title(title, 26, {
		Position = UDim2.fromOffset(if iconId then 210 else 156, 18),
		Size = UDim2.fromOffset(600, 32),
		Parent = header,
	})
	return header
end

-- Step 0: which kind of window?
function Wizard:_renderKinds()
	self:_header("Que veux-tu créer ?", "LuckyBlock")
	local scroll = Ui.scroll({
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 1, -HEADER),
		Parent = self.frame,
	})
	Ui.padding(24, 32).Parent = scroll
	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(280, 236),
			CellPadding = UDim2.fromOffset(18, 18),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	for i, recipe in Recipes.list() do
		local _, picture = Ui.tile({
			order = i,
			label = recipe.label,
			parent = grid,
			onClick = function()
				self:start(recipe.id)
			end,
		})
		Preview.draw(picture, Recipes.build(recipe, {}), {
			pack = "Studs",
			box = Vector2.new(270, 180),
			backdrop = true,
			lite = true,
		})
		Ui.label(recipe.description, {
			Font = Ui.fontBold,
			TextSize = 13,
			TextColor3 = Ui.colors.muted,
			TextXAlignment = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.fromScale(0, 1),
			Size = UDim2.new(1, 0, 0, 16),
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = picture,
		})
	end
end

-- The answers with `questionId` set to `value`.
function Wizard:_with(questionId: string, value: any): { [string]: any }
	local answers = table.clone(self.answers)
	answers[questionId] = value
	return answers
end

local TILE_SIZES = {
	result = Vector2.new(182, 136),
	icon = Vector2.new(112, 112),
	swatch = Vector2.new(112, 96),
	pattern = Vector2.new(130, 104),
	text = Vector2.new(170, 64),
}

function Wizard:_tilePicture(question: any, option: any, picture: Frame, size: Vector2)
	local show = question.show
	if show == "result" then
		local answers = self:_with(question.id, option.value)
		local templates = Recipes.build(self.recipe, answers)
		Preview.draw(picture, templates, {
			pack = answers.pack,
			box = size,
			backdrop = true,
			lite = true,
			screen = if self.recipe.id == "HUD" then nil else Preview.measure(templates, 24),
		})
	elseif show == "icon" then
		if option.icon then
			icon(option.icon, math.floor(size.Y * 0.85), picture)
		elseif option.swatch then
			Ui.new("Frame", {
				BackgroundColor3 = Style.color(option.swatch),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(size.Y * 0.8, size.Y * 0.8),
				Parent = picture,
			}, { Ui.corner(10) })
			Ui.title("R$", 26, {
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = picture,
			})
		else
			local dash = "-"
			Ui.title(dash, 30, {
				TextXAlignment = Enum.TextXAlignment.Center,
				Size = UDim2.fromScale(1, 1),
				Parent = picture,
			})
		end
	elseif show == "swatch" then
		Ui.new("Frame", {
			BackgroundColor3 = Style.color(option.swatch),
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = picture,
		}, { Ui.corner(8), Ui.stroke(Ui.colors.outline, 2) })
	elseif show == "pattern" then
		local tokens = Packs.get(self.answers.pack).tokens
		local kind = if option.value == false then tokens.bodyPattern else option.value
		local holder = Ui.new("CanvasGroup", {
			BackgroundColor3 = Style.color(tokens.body),
			BorderSizePixel = 0,
			GroupTransparency = 0,
			Size = UDim2.fromScale(1, 1),
			Parent = picture,
		}, { Ui.corner(8) })
		local layer = Ui.new("CanvasGroup", {
			BackgroundTransparency = 1,
			GroupTransparency = Style.number(tokens.patternTransparency, 0.8) - 0.15,
			Size = UDim2.fromScale(1, 1),
			Parent = holder,
		})
		if kind and kind ~= "None" then
			Patterns.build(layer, kind, size.X, size.Y, Style.color(tokens.patternColor), 18)
		end
	else
		Ui.title(tostring(option.label), 20, {
			TextXAlignment = Enum.TextXAlignment.Center,
			Size = UDim2.fromScale(1, 1),
			Parent = picture,
		})
	end
end

function Wizard:_renderQuestion()
	local recipe = self.recipe
	local questions = recipe.questions
	local question = questions[self.step]
	local size = self:_size()

	local header = self:_header("Assistant · " .. recipe.label, recipe.icon)
	-- Progress: "Question 3 / 15" and a bar.
	local progress = Ui.new("Frame", {
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -24, 0.5, 0),
		Size = UDim2.fromOffset(300, 40),
		BackgroundTransparency = 1,
		Parent = header,
	})
	Ui.label(string.format("Question %d / %d", self.step, #questions), {
		Font = Ui.fontTitle,
		TextSize = 16,
		TextColor3 = Ui.colors.muted,
		TextXAlignment = Enum.TextXAlignment.Right,
		Size = UDim2.new(1, 0, 0, 18),
		Parent = progress,
	})
	local track = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.field,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = progress,
	}, { Ui.corner(6) })
	Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.success,
		BorderSizePixel = 0,
		Size = UDim2.fromScale(self.step / #questions, 1),
		Parent = track,
	}, { Ui.corner(6) })

	-- Left: the window as it will be built.
	local bodyH = size.Y - HEADER - FOOTER
	local leftW = math.floor(size.X * 0.52)
	local left = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.fromOffset(leftW, bodyH),
		Parent = self.frame,
	})
	local function drawPreview()
		Ui.clear(left)
		local templates = Recipes.build(recipe, self.answers)
		local preview = Preview.draw(left, templates, {
			pack = self.answers.pack,
			box = Vector2.new(leftW - 40, bodyH - 40),
			backdrop = true,
			screen = if recipe.id == "HUD" then nil else Preview.measure(templates, 30),
		})
		preview.Position = UDim2.fromOffset(20, 20)
	end
	drawPreview()

	-- Right: the question and its answers.
	local right = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(leftW, HEADER),
		Size = UDim2.new(1, -leftW, 0, bodyH),
		Parent = self.frame,
	})
	Ui.title(question.title, 30, {
		Position = UDim2.fromOffset(10, 22),
		Size = UDim2.new(1, -30, 0, 38),
		TextWrapped = true,
		Parent = right,
	})
	local scroll =
		Ui.scroll({ Position = UDim2.fromOffset(0, 72), Size = UDim2.new(1, -10, 1, -72), Parent = right })
	Ui.padding(8, 10).Parent = scroll
	local tileSize = TILE_SIZES[question.show] or TILE_SIZES.text
	local grid = Ui.new("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = scroll,
	}, {
		Ui.new("UIGridLayout", {
			CellSize = UDim2.fromOffset(tileSize.X, tileSize.Y + 24),
			CellPadding = UDim2.fromOffset(14, 14),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	})
	-- A click only moves the highlight and redraws the big preview: the answer
	-- pictures depend on the other questions, which did not change.
	local tiles = {}
	for i, option in question.options do
		local selected = Table.deepEqual(self.answers[question.id], option.value)
		local tile, picture = Ui.tile({
			order = i,
			label = option.label,
			selected = selected,
			parent = grid,
			onClick = function()
				if Table.deepEqual(self.answers[question.id], option.value) then
					return
				end
				self.answers[question.id] = option.value
				for j, other in tiles do
					Ui.setTileSelected(other, j == i)
				end
				drawPreview()
			end,
		})
		tiles[i] = tile
		self:_tilePicture(question, option, picture, Vector2.new(tileSize.X - 10, tileSize.Y - 10))
	end

	-- Footer: back, next, build now.
	local footer = Ui.new("Frame", {
		BackgroundColor3 = Ui.colors.panel,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, FOOTER),
		Parent = self.frame,
	})
	local backButton = Ui.bigButton(if self.step == 1 then "Autre type" else "Précédent", {
		color = Ui.colors.panelLight,
		size = UDim2.fromOffset(170, 48),
		onClick = function()
			if self.step == 1 then
				self:start(nil)
			else
				self.step -= 1
				self:render()
			end
		end,
	})
	backButton.Position = UDim2.fromOffset(20, 13)
	backButton.Parent = footer
	Ui.label("Tout restera modifiable ensuite.", {
		Font = Ui.fontBold,
		TextSize = 15,
		TextColor3 = Ui.colors.muted,
		Position = UDim2.fromOffset(210, 26),
		Size = UDim2.fromOffset(300, 22),
		Parent = footer,
	})
	local isLast = self.step == #questions
	local build = Ui.bigButton("Créer ma fenêtre", {
		color = Ui.colors.success,
		size = UDim2.fromOffset(230, 48),
		textSize = 20,
		onClick = function()
			self.editor:applyRecipe(recipe, self.answers)
		end,
	})
	build.AnchorPoint = Vector2.new(1, 0)
	build.Position = UDim2.new(1, -20, 0, 13)
	build.Parent = footer
	if not isLast then
		local nextButton = Ui.bigButton("Suivant", {
			color = Ui.colors.accent,
			size = UDim2.fromOffset(170, 48),
			textSize = 20,
			onClick = function()
				self.step += 1
				self:render()
			end,
		})
		nextButton.AnchorPoint = Vector2.new(1, 0)
		nextButton.Position = UDim2.new(1, -266, 0, 13)
		nextButton.Parent = footer
	end
end

return Wizard
