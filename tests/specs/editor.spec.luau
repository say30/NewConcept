return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Instance = t.roblox.Instance
	local serde = require("@lune/serde")

	local Ui = t.require(t.src.App.Ui)
	local noop = { Disconnect = function() end }
	local clicks = {}
	Ui.connect = function(instance, event, fn)
		if event == "MouseButton1Click" then
			clicks[instance] = fn
		end
		return noop
	end
	Ui.onPropertyChanged = function()
		return noop
	end

	local Editor = t.require(t.src.App.Editor)
	local ProjectStore = t.require(t.src.Persistence.ProjectStore)
	local Elements = t.require(t.src.Catalog.Elements)
	local Recipes = t.require(t.src.Catalog.Recipes)
	local Packs = t.require(t.src.Style.Packs)

	local codec = {
		encode = function(v)
			return serde.encode("json", v)
		end,
		decode = function(s)
			return serde.decode("json", s)
		end,
	}

	local function newEditor()
		local storage = Instance.new("Folder")
		local target = Instance.new("Folder")
		target.Name = "StarterGui"
		local services = {
			projectStore = ProjectStore.new(storage, codec),
			generateTarget = function()
				return target
			end,
			recordChange = function(_, fn)
				fn()
			end,
		}
		local root = Instance.new("Frame")
		return Editor.new(root, services), target, services
	end

	describe("Editor", function()
		it("opens on the home screen", function()
			local editor = newEditor()
			expect(editor.screen).toBe("home")
			expect(#editor.store.project.pageOrder).toBe(1)
			expect(editor:projectHasContent()).toBe(false)
		end)

		it("walks through every question of every assistant and builds the window", function()
			for _, recipe in Recipes.list() do
				local editor = newEditor()
				editor:showWizard(nil)
				editor:showWizard(recipe.id)
				for step = 1, #recipe.questions do
					editor.wizard.step = step
					editor.wizard:render()
				end
				editor:applyRecipe(recipe, { pack = "Garden" })
				expect(editor.screen).toBe("workspace")
				expect(editor.store.project.theme.base).toBe("Garden")
				expect(editor:currentPage().name).toBe(recipe.pageName)
				assert(editor.store.selection:primary(), recipe.id .. " selected nothing")
				expect(editor:projectHasContent()).toBe(true)
			end
		end)

		it("updates the assistant in place when an answer is clicked", function()
			local editor = newEditor()
			editor:showWizard("Shop")
			editor.wizard.step = 1
			editor.wizard:render()
			local tiles = {}
			for _, d in editor.wizard.frame:GetDescendants() do
				if d:IsA("TextButton") and d:FindFirstChild("Picture") and clicks[d] then
					table.insert(tiles, d)
				end
			end
			assert(#tiles >= 2, "no answer tiles")
			table.sort(tiles, function(a, b)
				return a.LayoutOrder < b.LayoutOrder
			end)
			clicks[tiles[2]]()
			expect(tiles[2].Parent ~= nil).toBe(true)
			expect(tiles[2]:FindFirstChildOfClass("UIStroke").Thickness).toBe(3)
			expect(tiles[1]:FindFirstChildOfClass("UIStroke").Thickness).toBe(1)
			local question = Recipes.get("Shop").questions[1]
			expect(editor.wizard.answers[question.id]).toBe(question.options[2].value)
		end)

		it("adds every gallery element and shows its inspector", function()
			local editor = newEditor()
			editor:startBlank()
			editor.inspector.advanced = true
			for _, category in Elements.categories() do
				editor.palette.category = category.id
				editor.palette:render()
				for _, entry in category.entries do
					editor.store.selection:clear()
					editor:insertElement(entry.make(), category.id)
					assert(editor.store.selection:primary(), entry.id .. ": " .. editor.statusLabel.Text)
					editor.inspector:render()
				end
			end
		end)

		it("changes the look of the selection with one undo step", function()
			local editor = newEditor()
			editor:startBlank()
			editor:insertElement(Elements.categories()[1].entries[1].make(), "Windows")
			local id = editor.store.selection:primary()
			editor:setProps({
				{ path = { "pattern", "kind" }, value = "Stripes" },
				{ path = { "corner" }, value = -1 },
			})
			expect(editor.store.project.nodes[id].props.pattern.kind).toBe("Stripes")
			editor.store:undo()
			expect(editor.store.project.nodes[id].props.corner).toBeNil()
		end)

		it("duplicates, moves, deletes and undoes", function()
			local editor = newEditor()
			editor:startBlank()
			local page = editor:currentPage()
			editor:insertTemplate({ type = "Window", children = { { type = "Button" } } }, page.rootId)
			local windowId = editor.store.selection:primary()
			editor:duplicateSelection()
			expect(#editor.store.project.nodes[page.rootId].children).toBe(2)
			editor:moveSelection(-1)
			local copyId = editor.store.selection:primary()
			expect(editor.store.project.nodes[page.rootId].children[1]).toBe(copyId)
			editor:deleteSelection()
			expect(#editor.store.project.nodes[page.rootId].children).toBe(1)
			editor.store:undo()
			expect(#editor.store.project.nodes[page.rootId].children).toBe(2)

			local buttonId = editor.store.project.nodes[windowId].children[1]
			editor.store.selection:set({ buttonId })
			editor:moveSelectionOut()
			expect(editor.store.project.nodes[buttonId].parent).toBe(page.rootId)
		end)

		it("opens every popup and every style", function()
			local editor = newEditor()
			editor:startBlank()
			editor.popup:openPacks()
			editor.popup:openNewPage()
			editor.popup:openProjects(editor.services.projectStore:list(), function() end, function() end)
			editor.popup:close()
			for _, pack in Packs.list() do
				editor:setPack(pack.name)
				expect(editor.store.project.theme.base).toBe(pack.name)
			end
			editor:showHome()
			expect(editor.screen).toBe("home")
		end)

		it("switches pages and screens", function()
			local editor = newEditor()
			editor:startBlank()
			editor:addPage()
			expect(#editor.store.project.pageOrder).toBe(2)
			expect(editor:currentPage().name).toBe("Page")
			editor:setDevice("Mobile")
			editor:setDevice("Console")
			editor:deletePage(editor.pageId)
			expect(#editor.store.project.pageOrder).toBe(1)
			editor:deletePage(editor.pageId)
			expect(#editor.store.project.pageOrder).toBe(1)
		end)

		it("generates into StarterGui and saves the project", function()
			local editor, target, services = newEditor()
			editor:applyRecipe(Recipes.get("Shop"), {})
			editor:generate()
			local screen = target:FindFirstChild("Shop")
			expect(screen ~= nil).toBe(true)
			expect(screen:FindFirstChild("Shop") ~= nil).toBe(true)
			services.projectStore:save(editor.store.project)
			local loaded = services.projectStore:load(editor.store.project.id)
			expect(loaded.name).toBe(editor.store.project.name)
		end)
	end)
end
