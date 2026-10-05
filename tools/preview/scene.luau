-- Dev tool: builds node templates with the real Builder and exports them for render.js.
--   lune run tools/preview/scene.luau <out.json> <scene> [columns]
-- Scenes are listed in tools/preview/scenes.luau.
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local loader = require("../../tests/loader")
local export = require("./export")
local roblox = loader.roblox
local R = loader.require
local src = loader.src

local Document = R(src.Core.Document)
local Store = R(src.Core.Store)
local Commands = R(src.Core.Commands)
local Builder = R(src.Generator.Builder)
local Packs = R(src.Style.Packs)

local scenes = require("./scenes")(loader)
local wanted = process.args[2] or "shop"
local list = scenes[wanted]
assert(list, "unknown scene " .. wanted)

local out = { columns = tonumber(process.args[3]) or 2, scenes = {} }
for _, s in list do
	local store = Store.new(Document.newProject("Preview"))
	store.project.theme.base = s.pack or "Studs"
	local _, pageId = store:dispatch(Commands.AddPage.new("Page"))
	local page = store.project.pages[pageId]
	for _, template in (if s.templates then s.templates else { s.template }) do
		local ok, err = store:dispatch(Commands.InsertTree.new(template, page.rootId))
		assert(ok, tostring(err))
	end
	local size = roblox.Vector2.new(s.width or 800, s.height or 520)
	local ctx = Builder.newContext(store.project, "preview", size)
	local root = Builder.syncNode(ctx, page.rootId, roblox.Instance.new("Folder"))
	table.insert(out.scenes, {
		title = s.title or Packs.get(s.pack).label,
		width = size.X,
		height = size.Y,
		background = s.background or Packs.get(s.pack).tokens.backdrop,
		root = export.serialize(root),
		fillRoot = true,
	})
end
fs.writeFile(process.args[1], serde.encode("json", out))
