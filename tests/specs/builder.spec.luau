return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Instance = t.roblox.Instance
	local Document = t.require(t.src.Core.Document)
	local Store = t.require(t.src.Core.Store)
	local Commands = t.require(t.src.Core.Commands)
	local Builder = t.require(t.src.Generator.Builder)
	local Generator = t.require(t.src.Generator.Generator)
	local Variants = t.require(t.src.Catalog.Variants)
	local Presets = t.require(t.src.Catalog.Presets)
	local NodeTypes = t.require(t.src.Schema.NodeTypes)

	local function newStore(theme)
		local store = Store.new(Document.newProject("Test"))
		store.project.theme.base = theme or "Cartoon"
		local _, pageId = store:dispatch(Commands.AddPage.new("Shop"))
		return store, store.project.pages[pageId]
	end

	local function find(root, name)
		for _, d in root:GetDescendants() do
			if d.Name == name then
				return d
			end
		end
		return nil
	end

	describe("Builder", function()
		it("builds every variant of every type, in every theme and mode", function()
			for typeName in NodeTypes.types do
				for _, variant in Variants.list(typeName) do
					for _, theme in { "Cartoon", "Flat", "Studs" } do
						for _, mode in { "preview", "game" } do
							local store, page = newStore(theme)
							local ok, err =
								store:dispatch(Commands.InsertTree.new(variant.template, page.rootId))
							assert(ok, tostring(err))
							local parent = Instance.new("Folder")
							local ctx =
								Builder.newContext(store.project, mode, t.roblox.Vector2.new(800, 600))
							local built, buildErr = pcall(Builder.syncNode, ctx, page.rootId, parent)
							assert(
								built,
								variant.id .. " / " .. theme .. " / " .. mode .. ": " .. tostring(buildErr)
							)
						end
					end
				end
			end
		end)

		it("builds every preset", function()
			for _, preset in Presets.list() do
				local store, page = newStore()
				local ok, err = store:dispatch(Commands.InsertTree.new(preset.template, page.rootId))
				assert(ok, preset.id .. ": " .. tostring(err))
				local ctx = Builder.newContext(store.project, "game")
				local built, buildErr = pcall(Builder.syncNode, ctx, page.rootId, Instance.new("Folder"))
				assert(built, preset.id .. ": " .. tostring(buildErr))
			end
		end)

		it("translates visual settings into Roblox objects", function()
			local store, page = newStore()
			local _, id = store:dispatch(Commands.InsertTree.new({
				type = "Window",
				name = "ShopWindow",
				props = {
					fill = { kind = "Gradient", color = "#FF0000", color2 = "#0000FF" },
					corner = 12,
					layout = { kind = "Grid", cellWidth = 90, cellHeight = 110 },
				},
				children = { { type = "Button", name = "Buy button", props = { text = { value = "Buy" } } } },
			}, page.rootId))
			local folder = Instance.new("Folder")
			local ctx = Builder.newContext(store.project, "game")
			Builder.syncNode(ctx, page.rootId, folder)

			local screen = folder:GetChildren()[1]
			expect(screen.ClassName).toBe("ScreenGui")
			expect(screen.Name).toBe("Shop")
			local window = screen:FindFirstChild("ShopWindow")
			expect(window.ClassName).toBe("Frame")
			expect(window:GetAttribute("GuiCreatorId")).toBe(id)
			expect(window:FindFirstChild("GC_Corner").CornerRadius.Offset).toBe(12)
			expect(window:FindFirstChild("GC_Gradient").ClassName).toBe("UIGradient")
			expect(window:FindFirstChild("GC_Layout").CellSize.X.Offset).toBe(90)
			expect(window:FindFirstChild("GC_Stroke").Thickness).toBe(3) -- Cartoon theme
			local buy = window:FindFirstChild("BuyButton")
			expect(buy.ClassName).toBe("TextButton")
			expect(buy:FindFirstChild("GC_Label").Text).toBe("Buy")
		end)

		it("follows the theme", function()
			local store, page = newStore("Flat")
			local _, id = store:dispatch(Commands.InsertTree.new({ type = "Button" }, page.rootId))
			local ctx = Builder.newContext(store.project, "game")
			local folder = Instance.new("Folder")
			Builder.syncNode(ctx, page.rootId, folder)
			local fill = ctx.instances[id]:FindFirstChild("GC_Fill")
			expect(fill.BackgroundColor3.R > 0.2 and fill.BackgroundColor3.B > 0.9).toBe(true) -- Flat blue
			store:dispatch(Commands.SetTheme.new("Studs"))
			ctx = Builder.newContext(store.project, "game")
			Builder.syncNode(ctx, page.rootId, folder)
			fill = ctx.instances[id]:FindFirstChild("GC_Fill")
			expect(fill.BackgroundColor3.R > 0.85).toBe(true) -- Studs red
		end)
	end)

	describe("Generator", function()
		it("updates in place, keeps hand-made objects and removes deleted elements", function()
			local store, page = newStore()
			local _, windowId = store:dispatch(Commands.InsertTree.new({
				type = "Window",
				name = "Store",
				children = { { type = "Button", name = "Buy" }, { type = "Text", name = "Title" } },
			}, page.rootId))
			local target = Instance.new("Folder")
			local report = Generator.generate(store.project, target)
			expect(report.pages).toBe(1)
			expect(report.elements).toBe(4)

			local window = find(target, "Store")
			local manual = Instance.new("Frame")
			manual.Name = "MyOwnFrame"
			manual.Parent = window

			local title = store.project.nodes[windowId].children[2]
			store:dispatch(Commands.DeleteNodes.new({ title }))
			store:dispatch(Commands.Rename.new(windowId, "ShopWindow"))
			Generator.generate(store.project, target)

			local again = find(target, "ShopWindow")
			expect(again).toBe(window) -- same Instance, renamed
			expect(again:FindFirstChild("MyOwnFrame")).toBe(manual)
			expect(again:FindFirstChild("Title")).toBeNil()
			expect(again:FindFirstChild("Buy") ~= nil).toBe(true)
		end)

		it("keeps children when an element changes kind", function()
			local store, page = newStore()
			local _, windowId = store:dispatch(Commands.InsertTree.new({
				type = "Window",
				children = { { type = "Button", name = "Buy" } },
			}, page.rootId))
			local target = Instance.new("Folder")
			Generator.generate(store.project, target)
			local buy = find(target, "Buy")
			store:dispatch(
				Commands.SetProps.new(windowId, { { path = { "fill", "kind" }, value = "Image" } })
			)
			Generator.generate(store.project, target)
			local window = find(target, "Window")
			expect(window.ClassName).toBe("ImageLabel")
			expect(window:FindFirstChild("Buy")).toBe(buy)
		end)

		it("removes the ScreenGui of a deleted page only", function()
			local store, page = newStore()
			local _, secondId = store:dispatch(Commands.AddPage.new("HUD"))
			local target = Instance.new("Folder")
			local other = Instance.new("ScreenGui")
			other.Name = "NotOurs"
			other.Parent = target
			Generator.generate(store.project, target)
			expect(#target:GetChildren()).toBe(3)
			store:dispatch(Commands.RemovePage.new(secondId))
			local report = Generator.generate(store.project, target)
			expect(report.removed).toBe(1)
			expect(target:FindFirstChild("NotOurs")).toBe(other)
			expect(target:FindFirstChild("Shop") ~= nil).toBe(true)
			expect(page.openByDefault).toBe(true)
		end)
	end)
end
