-- Scenes for scene.luau: lists of { title?, pack, width?, height?, template | templates }.
return function(loader)
	local Kit = loader.require(loader.src.Catalog.Kit)
	local Packs = loader.require(loader.src.Style.Packs)

	local function shop()
		local cards = {}
		local items = {
			{ "Server Luck", "Coin", "$accent1" },
			{ "Gold Luck", "Gem", "$accent2" },
			{ "Void Luck", "Potion", "$accent3" },
			{ "Mega Pack", "Gift", "$accent4" },
		}
		for i, item in items do
			table.insert(
				cards,
				Kit.card({
					name = "Item" .. i,
					style = "Wide",
					title = item[1],
					subtitle = "(10 mins)",
					icon = item[2],
					color = item[3],
					textColor = "#FFFFFF",
					price = "500",
					currency = "Coin",
				})
			)
		end
		return Kit.window({
			title = "Store",
			icon = "Basket",
			tabs = { "Seeds", "Gears" },
			width = 640,
			height = 440,
			content = {
				Kit.grid("Items", 2, 96, cards),
			},
		})
	end

	local function tall()
		local cards = {}
		local icons = { "Egg", "Potion", "Backpack", "Chest", "Gem", "Trophy" }
		for i, icon in icons do
			table.insert(
				cards,
				Kit.card({
					name = "Item" .. i,
					title = icon,
					icon = icon,
					price = tostring(i * 150),
					badge = if i == 1 then "NEW" else nil,
				})
			)
		end
		return Kit.window({
			title = "Shop",
			titleStyle = "Tab",
			width = 620,
			height = 450,
			content = { Kit.grid("Items", 3, 190, cards) },
		})
	end

	local function banner()
		local cards = {}
		for i = 1, 6 do
			table.insert(
				cards,
				Kit.card({
					name = "Day" .. i,
					title = "Jour " .. i,
					icon = if i == 6 then "Chest" else "Gift",
					subtitle = "x" .. (i * 100),
				})
			)
		end
		return Kit.window({
			title = "Récompenses",
			icon = "Calendar",
			titleStyle = "Banner",
			width = 620,
			height = 450,
			content = { Kit.grid("Days", 3, 170, cards) },
		})
	end

	local scenes = {}
	local function each(make, w, h)
		local list = {}
		for _, pack in Packs.list() do
			table.insert(list, { pack = pack.name, template = make(), width = w or 760, height = h or 520 })
		end
		return list
	end
	scenes.shop = each(shop)
	scenes.tall = each(tall)
	scenes.banner = each(banner)
	scenes.hud = {
		{
			pack = "Studs",
			width = 900,
			height = 500,
			templates = {
				Kit.currencyBar("Coins", "Coin", "12,500", { position = { 0, 140, 0, 40 } }),
				Kit.currencyBar("Gems", "Gem", "350", { position = { 0, 380, 0, 40 } }),
				Kit.hudButton("ShopButton", "Shop", "SHOP", "$warning"),
			},
		},
	}
	local Recipes = loader.require(loader.src.Catalog.Recipes)
	local function recipeScenes(pack, overrides)
		local list = {}
		for _, recipe in Recipes.list() do
			local answers = table.clone(overrides or {})
			answers.pack = pack
			table.insert(list, {
				title = recipe.label .. " · " .. pack,
				pack = pack,
				templates = Recipes.build(recipe, answers),
				width = 900,
				height = 620,
			})
		end
		return list
	end
	scenes.recipes = recipeScenes("Studs")
	scenes.recipesGarden =
		recipeScenes("Garden", { titleStyle = "Banner", cardStyle = "Wide", sections = 2, colors = "Plain" })
	scenes.recipesCandy =
		recipeScenes("Candy", { titleStyle = "Tab", cardStyle = "Slot", columns = 4, count = 8 })
	return scenes
end
