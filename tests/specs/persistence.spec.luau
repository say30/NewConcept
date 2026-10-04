return function(t)
	local describe, it, expect = t.describe, t.it, t.expect
	local serde = require("@lune/serde")
	local Document = t.require(t.src.Core.Document)
	local Store = t.require(t.src.Core.Store)
	local Commands = t.require(t.src.Core.Commands)
	local Serializer = t.require(t.src.Persistence.Serializer)
	local ProjectStore = t.require(t.src.Persistence.ProjectStore)

	local codec = {
		encode = function(value)
			return serde.encode("json", value)
		end,
		decode = function(text)
			return serde.decode("json", text)
		end,
	}

	local function sampleProject()
		local store = Store.new(Document.newProject("Pet Sim"))
		local _, pageId = store:dispatch(Commands.AddPage.new("Shop"))
		local page = store.project.pages[pageId]
		store:dispatch(Commands.InsertTree.new({
			type = "Window",
			name = "ShopWindow",
			props = {
				corner = "$radius.md",
				background = { kind = "Gradient", stops = { "$primary", "$accent" } },
			},
			children = { { type = "Button", name = "Buy" }, { type = "Grid" } },
		}, page.rootId))
		return store.project
	end

	describe("Serializer", function()
		it("round-trips a project", function()
			local project = sampleProject()
			local copy = Serializer.decode(Serializer.encode(project, codec), codec)
			expect(copy.name).toBe("PetSim")
			expect(#Serializer.validate(copy)).toBe(0)
			local window
			for _, node in copy.nodes do
				if node.name == "ShopWindow" then
					window = node
				end
			end
			expect(window.props.background.stops[2]).toBe("$accent")
			expect(#window.children).toBe(2)
		end)
		it("restores empty tables JSON turned into arrays", function()
			local project = sampleProject()
			local copy = Serializer.decode(Serializer.encode(project, codec), codec)
			for _, node in copy.nodes do
				expect(type(node.props)).toBe("table")
				expect(type(node.editor)).toBe("table")
			end
		end)
		it("rejects damaged data", function()
			local project = sampleProject()
			for _, node in project.nodes do
				if node.parent then
					node.parent = "gc_000000000000"
					break
				end
			end
			local text = Serializer.encode(project, codec)
			expect(function()
				Serializer.decode(text, codec)
			end).toThrow("damaged")
		end)
		it("refuses projects from a newer plugin", function()
			local project = sampleProject()
			project.formatVersion = Document.FORMAT_VERSION + 1
			local text = Serializer.encode(project, codec)
			expect(function()
				Serializer.decode(text, codec)
			end).toThrow("newer version")
		end)
	end)

	describe("ProjectStore", function()
		local Instance = t.roblox.Instance

		it("saves into the place and loads back", function()
			local storage = Instance.new("Folder")
			local projects = ProjectStore.new(storage, codec)
			local project = sampleProject()
			projects:save(project, 100)
			local list = projects:list()
			expect(#list).toBe(1)
			expect(list[1].name).toBe("PetSim")
			expect(storage:FindFirstChild("GuiCreator"):FindFirstChild("Projects") ~= nil).toBe(true)
			local loaded = projects:load(project.id)
			expect(loaded.id).toBe(project.id)
			expect(#loaded.pageOrder).toBe(1)
		end)
		it("splits big projects into chunks and cleans old chunks", function()
			local storage = Instance.new("Folder")
			local projects = ProjectStore.new(storage, codec)
			local project = sampleProject()
			local oldSize = ProjectStore.CHUNK_SIZE
			ProjectStore.CHUNK_SIZE = 200
			projects:save(project)
			local entry = storage.GuiCreator.Projects:GetChildren()[1]
			local many = #entry:GetChildren()
			expect(many > 2).toBe(true)
			ProjectStore.CHUNK_SIZE = 100000
			projects:save(project)
			expect(#entry:GetChildren()).toBe(1)
			ProjectStore.CHUNK_SIZE = 200
			expect(projects:load(project.id).name).toBe("PetSim")
			ProjectStore.CHUNK_SIZE = oldSize
		end)
		it("keeps the same folder when the project is renamed", function()
			local storage = Instance.new("Folder")
			local projects = ProjectStore.new(storage, codec)
			local project = sampleProject()
			projects:save(project, 1)
			project.name = "RenamedSim"
			projects:save(project, 2)
			local list = projects:list()
			expect(#list).toBe(1)
			expect(list[1].name).toBe("RenamedSim")
		end)
		it("deletes a project", function()
			local storage = Instance.new("Folder")
			local projects = ProjectStore.new(storage, codec)
			local project = sampleProject()
			projects:save(project)
			projects:delete(project.id)
			expect(#projects:list()).toBe(0)
		end)
	end)
end
