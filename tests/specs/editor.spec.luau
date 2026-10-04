return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Instance = t.roblox.Instance
	local serde = require("@lune/serde")

	local Ui = t.require(t.src.App.Ui)
	local noop = { Disconnect = function() end }
	Ui.connect = function()
		return noop
	end
	Ui.onPropertyChanged = function()
		return noop
	end

	local Editor = t.require(t.src.App.Editor)
	local ProjectStore = t.require(t.src.Persistence.ProjectStore)
	local Variants = t.require(t.src.Catalog.Variants)
	local Presets = t.require(t.src.Catalog.Presets)
	local NodeTypes = t.require(t.src.Schema.NodeTypes)

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
		it("opens with one page and draws every panel", function()
			local editor = newEditor()
			expect(#editor.store.project.pageOrder).toBe(1)
			expect(editor:currentPage().name).toBe("Main")
		end)

		it("inserts every preset and selects it", function()
			local editor = newEditor()
			local page = editor:currentPage()
			for _, preset in Presets.list() do
				editor:insertTemplate(preset.template, page.rootId, preset.id)
				local id = editor.store.selection:primary()
				assert(id, preset.id .. " was not inserted: " .. editor.statusLabel.Text)
			end
		end)

		it("shows the inspector with every section open for every variant", function()
			local editor = newEditor()
			for name in pairs(editor.openSections) do
				editor.openSections[name] = true
			end
			for _, section in { "Transform", "Stroke", "Corner", "Display" } do
				editor.openSections[section] = true
			end
			local page = editor:currentPage()
			for typeName in NodeTypes.types do
				for _, variant in Variants.list(typeName) do
					if typeName ~= "Page" then
						editor:insertTemplate(variant.template, page.rootId, variant.id)
						assert(editor.store.selection:primary(), variant.id)
						editor.inspector:render()
					end
				end
			end
		end)

		it("duplicates, moves, deletes and undoes", function()
			local editor = newEditor()
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

		it("opens every picker", function()
			local editor = newEditor()
			local page = editor:currentPage()
			for typeName in NodeTypes.types do
				editor.picker:openVariants(typeName, page.rootId)
			end
			editor.picker:openPresets(page.rootId)
			editor.picker:openProjects(editor.services.projectStore:list(), function() end, function() end)
			editor.picker:close()
		end)

		it("switches pages, screens and themes", function()
			local editor = newEditor()
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
			local shop = Presets.get("Shop")
			editor:insertTemplate(shop.template, editor:currentPage().rootId)
			editor:generate()
			local screen = target:FindFirstChild("Main")
			expect(screen ~= nil).toBe(true)
			expect(screen:FindFirstChild("ShopWindow") ~= nil).toBe(true)
			services.projectStore:save(editor.store.project)
			local loaded = services.projectStore:load(editor.store.project.id)
			expect(loaded.name).toBe(editor.store.project.name)
		end)
	end)
end
