return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Instance = t.roblox.Instance
	local Document = t.require(t.src.Core.Document)
	local Store = t.require(t.src.Core.Store)
	local Commands = t.require(t.src.Core.Commands)
	local Builder = t.require(t.src.Generator.Builder)
	local Generator = t.require(t.src.Generator.Generator)
	local Recipes = t.require(t.src.Catalog.Recipes)
	local Elements = t.require(t.src.Catalog.Elements)
	local Packs = t.require(t.src.Style.Packs)

	local function newStore(theme)
		local store = Store.new(Document.newProject("Test"))
		store.project.theme.base = theme or "Studs"
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
		it("builds every gallery element in every pack and mode", function()
			for _, category in Elements.categories() do
				for _, entry in category.entries do
					for _, pack in Packs.list() do
						for _, mode in { "preview", "game" } do
							local store, page = newStore(pack.name)
							local ok, err = store:dispatch(Commands.InsertTree.new(entry.make(), page.rootId))
							assert(ok, tostring(err))
							local ctx =
								Builder.newContext(store.project, mode, t.roblox.Vector2.new(800, 600))
							local built, buildErr =
								pcall(Builder.syncNode, ctx, page.rootId, Instance.new("Folder"))
							assert(
								built,
								entry.id .. " / " .. pack.name .. " / " .. mode .. ": " .. tostring(buildErr)
							)
						end
					end
				end
			end
		end)

		it("builds every assistant answer", function()
			for _, recipe in Recipes.list() do
				for _, question in recipe.questions do
					for _, option in question.options do
						local store, page = newStore()
						local answers = { [question.id] = option.value }
						for _, template in Recipes.build(recipe, answers) do
							local ok, err = store:dispatch(Commands.InsertTree.new(template, page.rootId))
							assert(ok, recipe.id .. ": " .. tostring(err))
						end
						store.project.theme.base = if question.id == "pack" then option.value else "Studs"
						local ctx = Builder.newContext(store.project, "game")
						local built, buildErr =
							pcall(Builder.syncNode, ctx, page.rootId, Instance.new("Folder"))
						assert(
							built,
							recipe.id
								.. " / "
								.. question.id
								.. " = "
								.. tostring(option.value)
								.. ": "
								.. tostring(buildErr)
						)
					end
				end
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
					pattern = { kind = "Studs" },
				},
				children = {
					{
						type = "Button",
						name = "Buy button",
						props = { text = { value = "Buy" }, icon = { id = "Coin" } },
					},
					{
						type = "Grid",
						name = "Items",
						props = { layout = { kind = "Grid", columns = 4, cellHeight = 110 } },
					},
				},
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
			expect(window.BackgroundTransparency).toBe(1)
			local fill = window:FindFirstChild("GC_Fill")
			expect(fill:FindFirstChild("GC_Corner").CornerRadius.Offset).toBe(12)
			expect(fill:FindFirstChild("GC_Gradient").ClassName).toBe("UIGradient")
			expect(fill:FindFirstChild("GC_Stroke").Thickness).toBe(3) -- Studs pack
			expect(fill.ZIndex < 0).toBe(true) -- drawn under the children
			local pattern = window:FindFirstChild("GC_Pattern")
			expect(pattern.ClassName).toBe("CanvasGroup")
			expect(pattern:FindFirstChild("GC_Corner").CornerRadius.Offset).toBe(12) -- follows the corners
			expect(#pattern:GetDescendants() > 50).toBe(true)
			expect(window:FindFirstChild("GC_Shadow") ~= nil).toBe(true)
			local grid = window:FindFirstChild("Items")
			expect(grid:FindFirstChild("GC_Layout").CellSize.X.Scale).toBe(0.25)
			local buy = window:FindFirstChild("BuyButton")
			expect(buy.ClassName).toBe("TextButton")
			expect(buy:FindFirstChild("GC_Label").Text).toBe("Buy")
			expect(#buy:FindFirstChild("GC_Icon"):GetDescendants() > 5).toBe(true)
		end)

		it("follows the style pack", function()
			local store, page = newStore("Studs")
			local _, id = store:dispatch(Commands.InsertTree.new({ type = "Window" }, page.rootId))
			local ctx = Builder.newContext(store.project, "game")
			local folder = Instance.new("Folder")
			Builder.syncNode(ctx, page.rootId, folder)
			local gradient = ctx.instances[id]:FindFirstChild("GC_Fill"):FindFirstChild("GC_Gradient")
			local blue = gradient.Color.Keypoints[1].Value
			expect(blue.B > blue.R).toBe(true) -- Studs blue frame
			store:dispatch(Commands.SetTheme.new("Garden"))
			ctx = Builder.newContext(store.project, "game")
			Builder.syncNode(ctx, page.rootId, folder)
			gradient = ctx.instances[id]:FindFirstChild("GC_Fill"):FindFirstChild("GC_Gradient")
			local wood = gradient.Color.Keypoints[1].Value
			expect(wood.R > wood.B).toBe(true) -- Garden wooden frame
		end)

		it("does not rebuild a pattern or an icon that did not change", function()
			local store, page = newStore()
			local _, id = store:dispatch(
				Commands.InsertTree.new(
					{ type = "Panel", props = { pattern = { kind = "Dots" } } },
					page.rootId
				)
			)
			local folder = Instance.new("Folder")
			local ctx = Builder.newContext(store.project, "preview", t.roblox.Vector2.new(800, 600))
			Builder.syncNode(ctx, page.rootId, folder)
			local first = ctx.instances[id]:FindFirstChild("GC_Pattern"):FindFirstChild("Area")
			store:dispatch(Commands.SetProps.new(id, { { path = { "fill", "color" }, value = "#FF0000" } }))
			ctx = Builder.newContext(store.project, "preview", t.roblox.Vector2.new(800, 600), ctx.instances)
			Builder.syncNode(ctx, page.rootId, folder)
			expect(ctx.instances[id]:FindFirstChild("GC_Pattern"):FindFirstChild("Area")).toBe(first)
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
			local _, iconId =
				store:dispatch(Commands.InsertTree.new({ type = "Icon", name = "Logo" }, windowId))
			Generator.generate(store.project, target)
			local icon = find(target, "Logo")
			expect(icon.ClassName).toBe("Frame")
			store:dispatch(
				Commands.SetProps.new(iconId, { { path = { "icon", "image" }, value = "rbxassetid://123" } })
			)
			Generator.generate(store.project, target)
			expect(find(target, "Logo").ClassName).toBe("ImageLabel")
			expect(find(target, "Buy")).toBe(buy)
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
