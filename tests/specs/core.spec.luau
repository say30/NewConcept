return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local Core = t.src.Core
	local Ids = t.require(Core.Ids)
	local Naming = t.require(Core.Naming)
	local Document = t.require(Core.Document)
	local Store = t.require(Core.Store)
	local Commands = t.require(Core.Commands)

	local function newStoreWithPage()
		Ids.setSeed(42)
		local store = Store.new(Document.newProject("Test"))
		local _, pageId = store:dispatch(Commands.AddPage.new("Shop"))
		return store, store.project.pages[pageId]
	end

	local function count(map)
		local n = 0
		for _ in map do
			n += 1
		end
		return n
	end

	describe("Ids", function()
		it("creates GuiCreatorIds", function()
			local id = Ids.new()
			expect(Ids.isValid(id)).toBe(true)
			expect(string.sub(id, 1, 3)).toBe("gc_")
		end)
		it("never returns a taken id", function()
			Ids.setSeed(1)
			local first = Ids.new()
			Ids.setSeed(1)
			expect(Ids.newUnique({ [first] = true }) ~= first).toBe(true)
		end)
	end)

	describe("Naming", function()
		it("cleans user input into PascalCase", function()
			expect(Naming.sanitize("buy button!")).toBe("BuyButton")
			expect(Naming.sanitize("  ")).toBe("Element")
			expect(Naming.sanitize("3 coins")).toBe("_3Coins")
		end)
		it("adds a number when the name is taken", function()
			expect(Naming.unique("BuyButton", { BuyButton = true })).toBe("BuyButton2")
			expect(Naming.unique("BuyButton2", { BuyButton = true, BuyButton2 = true })).toBe("BuyButton3")
			expect(Naming.unique("Free", {})).toBe("Free")
		end)
	end)

	describe("Pages", function()
		it("adds a page with a root node", function()
			local store, page = newStoreWithPage()
			expect(page.name).toBe("Shop")
			expect(page.openByDefault).toBe(true)
			expect(store.project.nodes[page.rootId].type).toBe("Page")
		end)
		it("keeps page names unique", function()
			local store = newStoreWithPage()
			local _, secondId = store:dispatch(Commands.AddPage.new("Shop"))
			expect(store.project.pages[secondId].name).toBe("Shop2")
			expect(store.project.pages[secondId].openByDefault).toBe(false)
		end)
		it("renames a page and its root", function()
			local store, page = newStoreWithPage()
			store:dispatch(Commands.RenamePage.new(page.id, "pet shop"))
			expect(page.name).toBe("PetShop")
			expect(store.project.nodes[page.rootId].name).toBe("PetShop")
		end)
		it("removes a page with its content and undoes it", function()
			local store, page = newStoreWithPage()
			store:dispatch(
				Commands.InsertTree.new({ type = "Window", children = { { type = "Button" } } }, page.rootId)
			)
			expect(count(store.project.nodes)).toBe(3)
			store:dispatch(Commands.RemovePage.new(page.id))
			expect(count(store.project.nodes)).toBe(0)
			expect(#store.project.pageOrder).toBe(0)
			store:undo()
			expect(count(store.project.nodes)).toBe(3)
			expect(store.project.pageOrder[1]).toBe(page.id)
		end)
	end)

	describe("InsertTree", function()
		it("inserts a whole preset with readable unique names", function()
			local store, page = newStoreWithPage()
			local ok, windowId = store:dispatch(Commands.InsertTree.new({
				type = "Window",
				name = "ShopWindow",
				children = {
					{ type = "Button", name = "Buy button" },
					{ type = "Button", name = "Buy button" },
					{ type = "Text" },
				},
			}, page.rootId))
			expect(ok).toBe(true)
			local window = store.project.nodes[windowId]
			expect(window.name).toBe("ShopWindow")
			expect(window.parent).toBe(page.rootId)
			local names = {}
			for _, childId in window.children do
				table.insert(names, store.project.nodes[childId].name)
			end
			expect(table.concat(names, ",")).toBe("BuyButton,BuyButton2,Text")
		end)
		it("copies template values so the template stays untouched", function()
			local store, page = newStoreWithPage()
			local template = { type = "Button", props = { text = { value = "Buy" } } }
			local _, id = store:dispatch(Commands.InsertTree.new(template, page.rootId))
			store.project.nodes[id].props.text.value = "Changed"
			expect(template.props.text.value).toBe("Buy")
		end)
		it("inserts at a given position", function()
			local store, page = newStoreWithPage()
			store:dispatch(Commands.InsertTree.new({ type = "Text", name = "A" }, page.rootId))
			store:dispatch(Commands.InsertTree.new({ type = "Text", name = "B" }, page.rootId))
			local _, id =
				store:dispatch(Commands.InsertTree.new({ type = "Text", name = "C" }, page.rootId, 1))
			expect(store.project.nodes[page.rootId].children[1]).toBe(id)
		end)
		it("fails cleanly on an unknown parent", function()
			local store = newStoreWithPage()
			local before = store.revision
			local ok, err = store:dispatch(Commands.InsertTree.new({ type = "Button" }, "gc_missing"))
			expect(ok).toBe(false)
			expect(string.find(tostring(err), "Parent not found", 1, true) ~= nil).toBe(true)
			expect(store.revision).toBe(before)
			expect(store.history:canUndo()).toBe(true) -- only the AddPage
		end)
	end)

	describe("Undo / redo", function()
		it("undoes and redoes an insert", function()
			local store, page = newStoreWithPage()
			local _, id = store:dispatch(Commands.InsertTree.new({ type = "Button" }, page.rootId))
			store:undo()
			expect(store.project.nodes[id]).toBeNil()
			expect(#store.project.nodes[page.rootId].children).toBe(0)
			store:redo()
			expect(store.project.nodes[id].type).toBe("Button")
			expect(store.project.nodes[page.rootId].children[1]).toBe(id)
		end)
		it("clears redo after a new change", function()
			local store, page = newStoreWithPage()
			store:dispatch(Commands.InsertTree.new({ type = "Button" }, page.rootId))
			store:undo()
			store:dispatch(Commands.InsertTree.new({ type = "Text" }, page.rootId))
			expect(store.history:canRedo()).toBe(false)
		end)
		it("groups a slider drag into one step", function()
			local store, page = newStoreWithPage()
			local _, id = store:dispatch(Commands.InsertTree.new({ type = "Button" }, page.rootId))
			store:beginGroup("Corner radius")
			for radius = 1, 10 do
				store:dispatch(Commands.SetProps.new(id, { { path = { "corner" }, value = radius } }))
			end
			store:endGroup()
			expect(store.project.nodes[id].props.corner).toBe(10)
			store:undo()
			expect(store.project.nodes[id].props.corner).toBeNil()
			expect(store.project.nodes[id]).toBeTruthy()
			store:redo()
			expect(store.project.nodes[id].props.corner).toBe(10)
		end)
		it("survives a long chain of mixed commands", function()
			local store, page = newStoreWithPage()
			local _, a = store:dispatch(Commands.InsertTree.new({ type = "Window", name = "A" }, page.rootId))
			local _, b = store:dispatch(Commands.InsertTree.new({ type = "Button", name = "B" }, page.rootId))
			store:dispatch(Commands.Move.new(b, a))
			store:dispatch(Commands.Rename.new(b, "Buy"))
			store:dispatch(
				Commands.SetProps.new(b, { { path = { "background", "color" }, value = "#00FF00" } })
			)
			store:dispatch(Commands.DeleteNodes.new({ a }))
			for _ = 1, 6 do
				store:undo()
			end
			expect(count(store.project.nodes)).toBe(1)
			for _ = 1, 6 do
				store:redo()
			end
			expect(store.project.nodes[a]).toBeNil()
			expect(store.project.nodes[b]).toBeNil()
			store:undo()
			expect(store.project.nodes[b].name).toBe("Buy")
			expect(store.project.nodes[b].parent).toBe(a)
			expect(store.project.nodes[b].props.background.color).toBe("#00FF00")
		end)
	end)

	describe("SetProps", function()
		it("sets nested values and restores them", function()
			local store, page = newStoreWithPage()
			local _, id = store:dispatch(Commands.InsertTree.new({
				type = "Button",
				props = { text = { value = "Buy", size = 18 } },
			}, page.rootId))
			store:dispatch(Commands.SetProps.new(id, {
				{ path = { "text", "size" }, value = 24 },
				{ path = { "stroke", "thickness" }, value = 3 },
			}))
			local props = store.project.nodes[id].props
			expect(props.text.size).toBe(24)
			expect(props.text.value).toBe("Buy")
			expect(props.stroke.thickness).toBe(3)
			store:undo()
			expect(props.text.size).toBe(18)
			expect(props.stroke and props.stroke.thickness).toBeNil()
		end)
		it("a nil value puts a property back to the theme", function()
			local store, page = newStoreWithPage()
			local _, id = store:dispatch(
				Commands.InsertTree.new({ type = "Button", props = { corner = 12 } }, page.rootId)
			)
			store:dispatch(Commands.SetProps.new(id, { { path = { "corner" }, value = nil } }))
			expect(store.project.nodes[id].props.corner).toBeNil()
			store:undo()
			expect(store.project.nodes[id].props.corner).toBe(12)
		end)
	end)

	describe("Move", function()
		it("refuses to move an element inside itself", function()
			local store, page = newStoreWithPage()
			local _, windowId = store:dispatch(Commands.InsertTree.new({
				type = "Window",
				children = { { type = "Panel" } },
			}, page.rootId))
			local panelId = store.project.nodes[windowId].children[1]
			local ok = store:dispatch(Commands.Move.new(windowId, panelId))
			expect(ok).toBe(false)
			expect(store.project.nodes[windowId].parent).toBe(page.rootId)
		end)
		it("renames on conflict and restores the name on undo", function()
			local store, page = newStoreWithPage()
			local _, windowId = store:dispatch(Commands.InsertTree.new({
				type = "Window",
				children = { { type = "Button", name = "Close" } },
			}, page.rootId))
			local _, loose =
				store:dispatch(Commands.InsertTree.new({ type = "Button", name = "Close" }, page.rootId))
			store:dispatch(Commands.Move.new(loose, windowId))
			expect(store.project.nodes[loose].name).toBe("Close2")
			store:undo()
			expect(store.project.nodes[loose].name).toBe("Close")
			expect(store.project.nodes[loose].parent).toBe(page.rootId)
		end)
		it("reorders inside the same parent", function()
			local store, page = newStoreWithPage()
			local _, a = store:dispatch(Commands.InsertTree.new({ type = "Text", name = "A" }, page.rootId))
			local _, b = store:dispatch(Commands.InsertTree.new({ type = "Text", name = "B" }, page.rootId))
			store:dispatch(Commands.Move.new(b, page.rootId, 1))
			local children = store.project.nodes[page.rootId].children
			expect(children[1]).toBe(b)
			expect(children[2]).toBe(a)
			store:undo()
			expect(children[1]).toBe(a)
		end)
	end)

	describe("DeleteNodes", function()
		it("deletes nested selections once and restores order", function()
			local store, page = newStoreWithPage()
			local _, a = store:dispatch(Commands.InsertTree.new({ type = "Text", name = "A" }, page.rootId))
			local _, w = store:dispatch(Commands.InsertTree.new({
				type = "Window",
				children = { { type = "Button" } },
			}, page.rootId))
			local _, c = store:dispatch(Commands.InsertTree.new({ type = "Text", name = "C" }, page.rootId))
			local inner = store.project.nodes[w].children[1]
			store.selection:set({ w, inner })
			expect(store:dispatch(Commands.DeleteNodes.new({ inner, w }))).toBe(true)
			expect(count(store.project.nodes)).toBe(3)
			expect(#store.selection:get()).toBe(0)
			store:undo()
			local children = store.project.nodes[page.rootId].children
			expect(table.concat(children, ",")).toBe(table.concat({ a, w, c }, ","))
			expect(store.project.nodes[inner].parent).toBe(w)
		end)
		it("refuses to delete a page root", function()
			local store, page = newStoreWithPage()
			expect(store:dispatch(Commands.DeleteNodes.new({ page.rootId }))).toBe(false)
		end)
	end)

	describe("Editor flags", function()
		it("hides and locks", function()
			local store, page = newStoreWithPage()
			local _, id = store:dispatch(Commands.InsertTree.new({ type = "Button" }, page.rootId))
			store:dispatch(Commands.SetEditorFlag.new(id, "hidden", true))
			store:dispatch(Commands.SetEditorFlag.new(id, "locked", true))
			expect(store.project.nodes[id].editor.hidden).toBe(true)
			store:undo()
			expect(store.project.nodes[id].editor.locked).toBe(false)
			expect(store.project.nodes[id].editor.hidden).toBe(true)
		end)
	end)

	describe("Composite", function()
		it("reverts applied parts when one part fails", function()
			local store, page = newStoreWithPage()
			local ok = store:dispatch(Commands.Composite.new("Two things", {
				Commands.InsertTree.new({ type = "Button" }, page.rootId),
				Commands.InsertTree.new({ type = "Button" }, "gc_missing"),
			}))
			expect(ok).toBe(false)
			expect(#store.project.nodes[page.rootId].children).toBe(0)
		end)
	end)
end
