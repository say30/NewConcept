--!strict
-- The assistant: for each kind of window (shop, rewards, pets...), a list of visual
-- questions and a function that builds the window from the answers. Every option is shown
-- as a picture in the assistant (a live preview, an icon, a colour or a pattern).

local Kit = require(script.Parent.Kit)
local Packs = require(script.Parent.Parent.Style.Packs)

export type Option = {
	value: any,
	label: string,
	icon: string?, -- icon id shown on the tile
	swatch: string?, -- colour shown on the tile
}
export type Question = {
	id: string,
	title: string,
	-- How tiles are drawn: "result" = the window built with this option, "icon", "swatch",
	-- "pattern", "text".
	show: string,
	options: { Option },
	default: any,
}
export type Recipe = {
	id: string,
	label: string,
	icon: string,
	description: string,
	pageName: string,
	questions: { Question },
	build: (answers: { [string]: any }) -> { any },
}

local Recipes = {}

local function opt(value: any, label: string, extra: { [string]: any }?): Option
	local o: any = { value = value, label = label }
	for key, v in extra or {} do
		o[key] = v
	end
	return o
end

local function choices(list: { any }, labelOf: ((any) -> string)?): { Option }
	local out = {}
	for _, value in list do
		table.insert(out, opt(value, if labelOf then labelOf(value) else tostring(value)))
	end
	return out
end

--------------------------------------------------------------------------------
-- Questions shared by every window
--------------------------------------------------------------------------------

local function packQuestion(): Question
	local options = {}
	for _, pack in Packs.list() do
		table.insert(options, opt(pack.name, pack.label))
	end
	return {
		id = "pack",
		title = "Quel style te plaît ?",
		show = "result",
		options = options,
		default = "Studs",
	}
end

local function titleQuestion(values: { string }): Question
	return {
		id = "title",
		title = "Quel titre ?",
		show = "text",
		options = choices(values),
		default = values[1],
	}
end

local function iconQuestion(icons: { string }): Question
	local options = { opt(false, "Sans icône") }
	for _, id in icons do
		table.insert(options, opt(id, id, { icon = id }))
	end
	return {
		id = "icon",
		title = "Quelle icône à côté du titre ?",
		show = "icon",
		options = options,
		default = icons[1],
	}
end

local function titleStyleQuestion(): Question
	return {
		id = "titleStyle",
		title = "Comment afficher le titre ?",
		show = "result",
		options = {
			opt("Bar", "Dans le cadre"),
			opt("Tab", "Onglet au-dessus"),
			opt("Banner", "Bandeau coloré"),
		},
		default = "Bar",
	}
end

local function sizeQuestion(): Question
	return {
		id = "size",
		title = "Quelle taille de fenêtre ?",
		show = "result",
		options = { opt("S", "Petite"), opt("M", "Moyenne"), opt("L", "Grande") },
		default = "M",
	}
end

local function closeQuestion(): Question
	return {
		id = "close",
		title = "Quel bouton pour fermer ?",
		show = "result",
		options = { opt("Square", "Carré rouge"), opt("Round", "Rond rouge"), opt("None", "Aucun") },
		default = "Square",
	}
end

local function patternQuestion(): Question
	return {
		id = "pattern",
		title = "Quel motif pour le fond ?",
		show = "pattern",
		options = {
			opt(false, "Celui du style"),
			opt("Studs", "Studs"),
			opt("Dots", "Pois"),
			opt("Diamonds", "Losanges"),
			opt("Checker", "Damier"),
			opt("Stripes", "Rayures"),
			opt("Grid", "Quadrillage"),
			opt("None", "Uni"),
		},
		default = false,
	}
end

local function colorsQuestion(): Question
	return {
		id = "colors",
		title = "Quelles couleurs pour les cartes ?",
		show = "result",
		options = {
			opt("Plain", "Toutes pareilles"),
			opt("Rainbow", "Multicolores"),
			opt("Accent", "Couleur du style"),
		},
		default = "Rainbow",
	}
end

local function currencyQuestion(): Question
	return {
		id = "currency",
		title = "Quelle monnaie ?",
		show = "icon",
		options = {
			opt("Coin", "Pièces", { icon = "Coin" }),
			opt("Gem", "Gemmes", { icon = "Gem" }),
			opt("Cash", "Billets", { icon = "Cash" }),
			opt("Ticket", "Tickets", { icon = "Ticket" }),
			opt("Robux", "Robux (R$)", { swatch = "#00B06F" }),
		},
		default = "Coin",
	}
end

local SIZES = { S = { 540, 400 }, M = { 660, 470 }, L = { 800, 560 } }
local CARD_COLORS = { "$accent1", "$accent2", "$accent3", "$accent4" }

local function windowSize(answers): (number, number)
	local s = SIZES[answers.size or "M"] or SIZES.M
	return s[1], s[2]
end

-- Room left for content inside the window body.
local function bodySize(answers): (number, number)
	local w, h = windowSize(answers)
	local style = answers.titleStyle or "Bar"
	local top = if style == "Tab" then 40 elseif style == "Banner" then 70 else 64
	return w - 24 - 28, h - top - 24 - 28
end

local function cardColor(answers, index: number): (string, string?)
	if answers.colors == "Rainbow" then
		return CARD_COLORS[(index - 1) % #CARD_COLORS + 1], "#FFFFFF"
	elseif answers.colors == "Accent" then
		return "$primary", "#FFFFFF"
	end
	return "$card", nil
end

local function priceText(answers, value: number): (string, string)
	if answers.currency == "Robux" then
		return value .. " R$", ""
	end
	return tostring(value), answers.currency or "Coin"
end

-- A grid of `cards` that fits in the window body, scrolling when it is too tall.
local function cardArea(answers, cards, columns: number, cellHeight: number, reserved: number?)
	local _, h = bodySize(answers)
	h -= reserved or 0
	local rows = math.ceil(#cards / columns)
	-- Shrink the cards a little to fit without scrolling; scroll when that is not enough.
	local fit = math.floor((h - (rows - 1) * 12) / rows)
	local cell = math.min(cellHeight, fit)
	local area
	if cell < cellHeight * 0.7 then
		area = Kit.scroll("Items", columns, cellHeight, cards)
	else
		area = Kit.grid("Items", columns, cell, cards)
	end
	if reserved then
		-- Leave room under the cards for buttons.
		area.props.size = { 1, -28, 1, -28 - reserved }
		area.props.anchor = { 0.5, 0 }
		area.props.position = { 0.5, 0, 0, 14 }
	end
	return area
end

local function window(answers, content, extra: { [string]: any }?)
	local w, h = windowSize(answers)
	local options: any = {
		name = answers.windowName or "Window",
		title = answers.title,
		icon = answers.icon or nil,
		titleStyle = answers.titleStyle,
		close = answers.close,
		width = w,
		height = h,
		content = content,
		bodyPattern = answers.pattern or nil,
	}
	for key, value in extra or {} do
		options[key] = value
	end
	return Kit.window(options)
end

local function cellFor(answers, style: string, columns: number): number
	if style == "Wide" then
		return 96
	elseif style == "Slot" then
		local w = bodySize(answers)
		return math.floor((w - 12 * (columns - 1)) / columns)
	end
	return 196
end

--------------------------------------------------------------------------------
-- Recipes
--------------------------------------------------------------------------------

local SHOP_ITEMS = {
	{ "Potion", "Potion" },
	{ "Œuf", "Egg" },
	{ "Coffre", "Chest" },
	{ "Gemmes", "Gem" },
	{ "Sac à dos", "Backpack" },
	{ "Épée", "Sword" },
	{ "Bouclier", "Shield" },
	{ "Bloc chance", "LuckyBlock" },
	{ "Cadeau", "Gift" },
	{ "Couronne", "Crown" },
	{ "Billets", "Cash" },
	{ "Énergie", "Lightning" },
}

local function shopCards(answers, count: number, offset: number?)
	local cards = {}
	for i = 1, count do
		local item = SHOP_ITEMS[((i + (offset or 0)) - 1) % #SHOP_ITEMS + 1]
		local color, textColor = cardColor(answers, i)
		local price, currency = priceText(answers, i * 100 + 150)
		table.insert(
			cards,
			Kit.card({
				name = "Item" .. (i + (offset or 0)),
				style = answers.cardStyle,
				title = item[1],
				subtitle = if answers.cardStyle == "Wide" then "Dure 10 min" else nil,
				icon = item[2],
				color = color,
				textColor = textColor,
				price = price,
				currency = currency,
				priceColor = answers.priceColor,
				badge = if answers.badge and i == 1 then "NEW" else nil,
			})
		)
	end
	return cards
end

table.insert(Recipes, {
	id = "Shop",
	label = "Boutique",
	icon = "Shop",
	description = "Objets à acheter avec un prix",
	pageName = "Shop",
	questions = {
		packQuestion(),
		titleQuestion({ "Boutique", "Shop", "Store", "Marché" }),
		iconQuestion({ "Basket", "Shop", "Bag", "Cash", "Coin", "Gem" }),
		titleStyleQuestion(),
		{
			id = "cardStyle",
			title = "Comment présenter les objets ?",
			show = "result",
			options = { opt("Tall", "Cartes hautes"), opt("Wide", "Lignes larges"), opt("Slot", "Cases") },
			default = "Tall",
		},
		{
			id = "count",
			title = "Combien d'objets ?",
			show = "result",
			options = choices({ 3, 4, 6, 8, 9, 12 }),
			default = 6,
		},
		{
			id = "columns",
			title = "Combien par ligne ?",
			show = "result",
			options = choices({ 2, 3, 4 }),
			default = 3,
		},
		{
			id = "sections",
			title = "Ranger les objets en catégories ?",
			show = "result",
			options = { opt(1, "Une seule liste"), opt(2, "Deux catégories") },
			default = 1,
		},
		{
			id = "tabs",
			title = "Des onglets en haut ?",
			show = "result",
			options = { opt(0, "Aucun"), opt(2, "Deux onglets"), opt(3, "Trois onglets") },
			default = 2,
		},
		colorsQuestion(),
		currencyQuestion(),
		{
			id = "priceColor",
			title = "Couleur des boutons d'achat ?",
			show = "swatch",
			options = {
				opt("$warning", "Jaune", { swatch = "#FFC531" }),
				opt("$success", "Vert", { swatch = "#5ED65A" }),
				opt("$primary", "Couleur du style", { swatch = "#3FA9F5" }),
				opt("$danger", "Rouge", { swatch = "#FF4D4D" }),
			},
			default = "$warning",
		},
		{
			id = "badge",
			title = "Mettre en avant le premier objet ?",
			show = "result",
			options = { opt(true, "Badge NEW"), opt(false, "Non") },
			default = true,
		},
		patternQuestion(),
		closeQuestion(),
		sizeQuestion(),
	},
	build = function(answers)
		local columns = if answers.cardStyle == "Wide" then math.min(answers.columns, 2) else answers.columns
		local cell = cellFor(answers, answers.cardStyle, columns)
		local tabs = ({ [0] = nil, [2] = { "Objets", "Boosts" }, [3] = { "Objets", "Boosts", "Pass" } })[answers.tabs]
		local content
		if answers.sections == 2 then
			local half = math.ceil(answers.count / 2)
			local parts = {}
			for s, label in { "Populaire", "Boosts" } do
				local cards = shopCards(
					answers,
					if s == 1 then half else answers.count - half,
					if s == 1 then 0 else half
				)
				local rows = math.ceil(#cards / columns)
				local grid = Kit.grid(label .. "Items", columns, cell, cards, {
					size = { 1, 0, 0, rows * cell + (rows - 1) * 12 + 4 },
				})
				table.insert(parts, Kit.sectionBar(label, if s == 1 then "$header" else "$accent3"))
				table.insert(parts, grid)
			end
			content = {
				Kit.node("ScrollArea", "Sections", {
					size = { 1, -28, 1, -28 },
					layout = { kind = "Vertical", spacing = 10, padding = 4, align = "Start" },
				}, parts),
			}
		else
			content = { cardArea(answers, shopCards(answers, answers.count), columns, cell) }
		end
		return { window(answers, content, { tabs = tabs, name = "Shop" }) }
	end,
})

table.insert(Recipes, {
	id = "Rewards",
	label = "Récompenses",
	icon = "Calendar",
	description = "Cadeaux quotidiens à réclamer",
	pageName = "DailyRewards",
	questions = {
		packQuestion(),
		titleQuestion({ "Récompenses", "Cadeaux du jour", "Daily Rewards" }),
		iconQuestion({ "Calendar", "Gift", "Clock", "Chest" }),
		titleStyleQuestion(),
		{
			id = "days",
			title = "Combien de jours ?",
			show = "result",
			options = choices({ 5, 6, 7, 9 }),
			default = 7,
		},
		{
			id = "columns",
			title = "Combien par ligne ?",
			show = "result",
			options = choices({ 3, 4, 5 }),
			default = 4,
		},
		{
			id = "reward",
			title = "Quel cadeau dans les cases ?",
			show = "icon",
			options = {
				opt("Gift", "Cadeau", { icon = "Gift" }),
				opt("Chest", "Coffre", { icon = "Chest" }),
				opt("Coins", "Pièces", { icon = "Coins" }),
				opt("Gem", "Gemmes", { icon = "Gem" }),
			},
			default = "Gift",
		},
		{
			id = "bigLast",
			title = "Un gros cadeau pour le dernier jour ?",
			show = "result",
			options = { opt(true, "Oui, un coffre"), opt(false, "Non") },
			default = true,
		},
		colorsQuestion(),
		{
			id = "claim",
			title = "Un bouton « Récupérer » en bas ?",
			show = "result",
			options = { opt(true, "Oui"), opt(false, "Non") },
			default = true,
		},
		patternQuestion(),
		closeQuestion(),
		sizeQuestion(),
	},
	build = function(answers)
		local cards = {}
		for i = 1, answers.days do
			local color, textColor = cardColor(answers, i)
			local last = i == answers.days and answers.bigLast
			table.insert(
				cards,
				Kit.card({
					name = "Day" .. i,
					title = "Jour " .. i,
					subtitle = "x" .. (i * 100),
					icon = if last then "Chest" else answers.reward,
					color = if last then "$warning" else color,
					textColor = if last then "#FFFFFF" else textColor,
					badge = if last then "MEGA" else nil,
				})
			)
		end
		local _, bodyH = bodySize(answers)
		local content = {}
		if answers.claim then
			table.insert(content, cardArea(answers, cards, answers.columns, 170, 70))
			table.insert(
				content,
				Kit.button({
					name = "ClaimButton",
					text = "Récupérer",
					icon = "Check",
					color = "$success",
					size = { 0, 240, 0, 56 },
					anchor = { 0.5, 1 },
					position = { 0.5, 0, 1, -14 },
				})
			)
		else
			table.insert(content, cardArea(answers, cards, answers.columns, 170))
		end
		local _ = bodyH
		return { window(answers, content, { name = "DailyRewards" }) }
	end,
})

table.insert(Recipes, {
	id = "Pets",
	label = "Animaux",
	icon = "Paw",
	description = "Inventaire d'animaux à équiper",
	pageName = "Pets",
	questions = {
		packQuestion(),
		titleQuestion({ "Animaux", "Pets", "Mes compagnons" }),
		iconQuestion({ "Paw", "Egg", "Heart" }),
		titleStyleQuestion(),
		{
			id = "count",
			title = "Combien de cases ?",
			show = "result",
			options = choices({ 8, 12, 15, 20, 24 }),
			default = 12,
		},
		{
			id = "columns",
			title = "Combien par ligne ?",
			show = "result",
			options = choices({ 4, 5, 6 }),
			default = 5,
		},
		{
			id = "rarity",
			title = "Des couleurs de rareté ?",
			show = "result",
			options = { opt(true, "Oui, par rareté"), opt(false, "Non, toutes pareilles") },
			default = true,
		},
		{
			id = "actions",
			title = "Des boutons en bas ?",
			show = "result",
			options = { opt("EquipBest", "Équiper + Supprimer"), opt("None", "Aucun") },
			default = "EquipBest",
		},
		{
			id = "tabs",
			title = "Des onglets en haut ?",
			show = "result",
			options = { opt(0, "Aucun"), opt(2, "Animaux / Œufs") },
			default = 0,
		},
		patternQuestion(),
		closeQuestion(),
		sizeQuestion(),
	},
	build = function(answers)
		local rarity = { "$accent4", "$accent1", "$accent3", "$warning", "$danger" }
		local icons = { "Paw", "Egg", "Heart", "Egg" }
		local cards = {}
		for i = 1, answers.count do
			table.insert(
				cards,
				Kit.card({
					name = "Slot" .. i,
					style = "Slot",
					icon = icons[(i - 1) % #icons + 1],
					subtitle = "x" .. i,
					color = if answers.rarity then rarity[(i - 1) % #rarity + 1] else "$card",
					textColor = if answers.rarity then "#FFFFFF" else nil,
				})
			)
		end
		local cell = cellFor(answers, "Slot", answers.columns)
		local content = {}
		if answers.actions == "EquipBest" then
			table.insert(content, cardArea(answers, cards, answers.columns, cell, 70))
			table.insert(
				content,
				Kit.button({
					name = "EquipBestButton",
					text = "Équiper",
					icon = "Check",
					color = "$success",
					size = { 0, 200, 0, 54 },
					anchor = { 1, 1 },
					position = { 0.5, -8, 1, -14 },
				})
			)
			table.insert(
				content,
				Kit.button({
					name = "DeleteButton",
					text = "Supprimer",
					icon = "Close",
					color = "$danger",
					size = { 0, 200, 0, 54 },
					anchor = { 0, 1 },
					position = { 0.5, 8, 1, -14 },
				})
			)
		else
			table.insert(content, cardArea(answers, cards, answers.columns, cell))
		end
		return {
			window(answers, content, {
				name = "Pets",
				tabs = if answers.tabs == 2 then { "Animaux", "Œufs" } else nil,
			}),
		}
	end,
})

table.insert(Recipes, {
	id = "Codes",
	label = "Codes",
	icon = "Ticket",
	description = "Champ pour entrer un code promo",
	pageName = "Codes",
	questions = {
		packQuestion(),
		titleQuestion({ "Codes", "Codes promo", "Redeem" }),
		iconQuestion({ "Ticket", "Gift", "Lock" }),
		titleStyleQuestion(),
		{
			id = "hint",
			title = "Un message d'aide ?",
			show = "result",
			options = { opt(true, "Oui"), opt(false, "Non") },
			default = true,
		},
		patternQuestion(),
		closeQuestion(),
	},
	build = function(answers)
		local content = {}
		if answers.hint then
			table.insert(
				content,
				Kit.text("Hint", "Suis le jeu pour recevoir des codes !", 24, {
					anchor = { 0.5, 0 },
					position = { 0.5, 0, 0, 24 },
					size = { 1, -40, 0, 30 },
				})
			)
		end
		local row = Kit.inputRow("Entre ton code...", "Valider")
		row.props.position = { 0.5, 0, 0.5, if answers.hint then 16 else 0 }
		table.insert(content, row)
		local a = table.clone(answers)
		a.size = "S"
		local w = windowSize(a)
		return { window(a, content, { name = "Codes", width = w, height = 280 }) }
	end,
})

local SETTINGS =
	{ "Musique", "Effets sonores", "Ombres", "Notifications", "Mode économie", "Afficher les dégâts" }

table.insert(Recipes, {
	id = "Settings",
	label = "Paramètres",
	icon = "Gear",
	description = "Options à activer ou désactiver",
	pageName = "Settings",
	questions = {
		packQuestion(),
		titleQuestion({ "Paramètres", "Settings", "Options" }),
		iconQuestion({ "Gear", "Person" }),
		titleStyleQuestion(),
		{
			id = "count",
			title = "Combien d'options ?",
			show = "result",
			options = choices({ 3, 4, 5, 6 }),
			default = 4,
		},
		patternQuestion(),
		closeQuestion(),
		sizeQuestion(),
	},
	build = function(answers)
		local rows = {}
		for i = 1, answers.count do
			table.insert(rows, Kit.toggleRow(SETTINGS[(i - 1) % #SETTINGS + 1], i % 3 ~= 0))
		end
		return {
			window(answers, {
				Kit.node("ScrollArea", "Options", {
					size = { 1, -28, 1, -28 },
					layout = { kind = "Vertical", spacing = 10, padding = 6, align = "Start" },
				}, rows),
			}, { name = "Settings" }),
		}
	end,
})

table.insert(Recipes, {
	id = "Rebirth",
	label = "Renaissance",
	icon = "Boost",
	description = "Recommencer contre un bonus",
	pageName = "Rebirth",
	questions = {
		packQuestion(),
		titleQuestion({ "Renaissance", "Rebirth", "Prestige" }),
		iconQuestion({ "Boost", "Crown", "Trophy" }),
		titleStyleQuestion(),
		{
			id = "progress",
			title = "Une barre de progression ?",
			show = "result",
			options = { opt(true, "Oui"), opt(false, "Non") },
			default = true,
		},
		currencyQuestion(),
		patternQuestion(),
		closeQuestion(),
	},
	build = function(answers)
		local price, currency = priceText(answers, 10000)
		local content = {
			Kit.node(
				"Icon",
				"BonusIcon",
				{ size = { 0, 96, 0, 96 }, position = { 0.25, 0, 0, 74 }, icon = { id = "Boost" } }
			),
			Kit.text("Bonus", "x2 gains", 40, {
				anchor = { 0, 0.5 },
				position = { 0.25, 60, 0, 74 },
				size = { 0.5, 0, 0, 50 },
				text = { font = "$fontTitle", alignX = "Left", stroke = { thickness = 3 } },
			}),
			Kit.priceButton(price, if currency == "" then nil else currency, "$warning", {
				size = { 0, 180, 0, 44 },
				anchor = { 0.5, 0 },
				position = { 0.5, 0, 0, 140 },
				name = "Cost",
			}),
			Kit.button({
				name = "RebirthButton",
				text = "Renaître",
				icon = "Boost",
				color = "$accent3",
				size = { 0, 260, 0, 60 },
				anchor = { 0.5, 1 },
				position = { 0.5, 0, 1, -18 },
			}),
		}
		if answers.progress then
			local bar = Kit.progressBar("Progress", 0.65, "65 %")
			bar.props.anchor = { 0.5, 0 }
			bar.props.position = { 0.5, 0, 0, 200 }
			bar.props.size = { 0.8, 0, 0, 34 }
			table.insert(content, bar)
		end
		local a = table.clone(answers)
		a.size = "S"
		return { window(a, content, { name = "Rebirth" }) }
	end,
})

table.insert(Recipes, {
	id = "Quests",
	label = "Quêtes",
	icon = "Medal",
	description = "Missions avec progression",
	pageName = "Quests",
	questions = {
		packQuestion(),
		titleQuestion({ "Quêtes", "Missions", "Quests" }),
		iconQuestion({ "Medal", "Pin", "Trophy" }),
		titleStyleQuestion(),
		{
			id = "count",
			title = "Combien de quêtes ?",
			show = "result",
			options = choices({ 3, 4, 5 }),
			default = 3,
		},
		colorsQuestion(),
		patternQuestion(),
		closeQuestion(),
		sizeQuestion(),
	},
	build = function(answers)
		local names =
			{ "Ramasse 100 pièces", "Ouvre 3 œufs", "Gagne 5 combats", "Joue 30 minutes", "Invite un ami" }
		local rows = {}
		for i = 1, answers.count do
			local color, textColor = cardColor(answers, i)
			local k = (i - 1) % #names + 1
			local ratio = ({ 0.8, 0.4, 1, 0.2, 0.6 })[k]
			local bar = Kit.progressBar("Progress", ratio, math.floor(ratio * 100) .. " %")
			bar.props.anchor = { 0, 1 }
			bar.props.position = { 0, 92, 1, -12 }
			bar.props.size = { 1, -250, 0, 26 }
			table.insert(
				rows,
				Kit.node("Card", "Quest" .. i, { size = { 1, 0, 0, 92 }, fill = { color = color } }, {
					Kit.node("Panel", "Slot", {
						anchor = { 0, 0.5 },
						position = { 0, 10, 0.5, 0 },
						size = { 1, 0, 1, -20 },
						aspect = 1,
						fill = { kind = "Color", color = "$slot", transparency = 0.15 },
						stroke = { enabled = false },
						pattern = { kind = "None" },
					}, {
						Kit.node(
							"Icon",
							"QuestIcon",
							{ size = { 0.78, 0, 0.78, 0 }, icon = { id = answers.icon or "Medal" } }
						),
					}),
					Kit.text("QuestName", names[k], 22, {
						anchor = { 0, 0 },
						position = { 0, 92, 0, 10 },
						size = { 1, -250, 0, 28 },
						text = { alignX = "Left", color = textColor or "$cardText" },
					}),
					bar,
					Kit.button({
						name = "ClaimButton",
						text = "Récupérer",
						color = "$success",
						size = { 0, 136, 0, 44 },
						anchor = { 1, 0.5 },
						position = { 1, -12, 0.5, 0 },
						textSize = 20,
					}),
				})
			)
		end
		return {
			window(answers, {
				Kit.node("ScrollArea", "QuestList", {
					size = { 1, -28, 1, -28 },
					layout = { kind = "Vertical", spacing = 10, padding = 6, align = "Start" },
				}, rows),
			}, { name = "Quests" }),
		}
	end,
})

table.insert(Recipes, {
	id = "Popup",
	label = "Message",
	icon = "Check",
	description = "Petite fenêtre de confirmation",
	pageName = "Popup",
	questions = {
		packQuestion(),
		titleQuestion({ "Confirmer", "Attention", "Bravo !" }),
		iconQuestion({ "Check", "Lock", "Trophy", "Heart" }),
		titleStyleQuestion(),
		{
			id = "buttons",
			title = "Quels boutons ?",
			show = "result",
			options = { opt("YesNo", "Oui + Non"), opt("Ok", "OK seul") },
			default = "YesNo",
		},
		patternQuestion(),
		closeQuestion(),
	},
	build = function(answers)
		local content = {
			Kit.text("Message", "Veux-tu vraiment faire ça ?", 28, {
				anchor = { 0.5, 0 },
				position = { 0.5, 0, 0, 26 },
				size = { 1, -40, 0, 70 },
				text = { wrap = true },
			}),
		}
		if answers.buttons == "YesNo" then
			table.insert(
				content,
				Kit.button({
					name = "YesButton",
					text = "Oui",
					color = "$success",
					size = { 0, 170, 0, 56 },
					anchor = { 1, 1 },
					position = { 0.5, -8, 1, -18 },
				})
			)
			table.insert(
				content,
				Kit.button({
					name = "NoButton",
					text = "Non",
					color = "$danger",
					size = { 0, 170, 0, 56 },
					anchor = { 0, 1 },
					position = { 0.5, 8, 1, -18 },
				})
			)
		else
			table.insert(
				content,
				Kit.button({
					name = "OkButton",
					text = "OK",
					color = "$success",
					size = { 0, 200, 0, 56 },
					anchor = { 0.5, 1 },
					position = { 0.5, 0, 1, -18 },
				})
			)
		end
		local a = table.clone(answers)
		return { window(a, content, { name = "Popup", width = 460, height = 300 }) }
	end,
})

local HUD_BUTTONS = {
	{ "Shop", "Shop", "SHOP", "$warning" },
	{ "Pets", "Paw", "PETS", "$accent1" },
	{ "Rewards", "Gift", "CADEAUX", "$accent3" },
	{ "Codes", "Ticket", "CODES", "$accent4" },
	{ "Settings", "Gear", "OPTIONS", "$primary" },
	{ "Rebirth", "Boost", "REBIRTH", "$accent2" },
}

table.insert(Recipes, {
	id = "HUD",
	label = "HUD",
	icon = "Coins",
	description = "Monnaies et boutons sur l'écran de jeu",
	pageName = "HUD",
	questions = {
		packQuestion(),
		{
			id = "currencies",
			title = "Quelles monnaies afficher ?",
			show = "icon",
			options = {
				opt("Coin", "Pièces", { icon = "Coin" }),
				opt("CoinGem", "Pièces + Gemmes", { icon = "Gem" }),
				opt("CoinGemCash", "Les trois", { icon = "Cash" }),
			},
			default = "CoinGem",
		},
		{
			id = "buttons",
			title = "Combien de boutons de menu ?",
			show = "result",
			options = choices({ 2, 3, 4, 5, 6 }),
			default = 4,
		},
		{
			id = "side",
			title = "Où placer les boutons ?",
			show = "result",
			options = { opt("Left", "À gauche"), opt("Right", "À droite"), opt("Bottom", "En bas") },
			default = "Left",
		},
	},
	build = function(answers)
		local templates = {}
		local currencies = ({
			Coin = { "Coin" },
			CoinGem = { "Coin", "Gem" },
			CoinGemCash = { "Coin", "Gem", "Cash" },
		})[answers.currencies]
		local amounts = { Coin = "12,500", Gem = "350", Cash = "$1.2K" }
		local bars = {}
		for _, id in currencies do
			table.insert(bars, Kit.currencyBar(id .. "Bar", id, amounts[id]))
		end
		table.insert(
			templates,
			Kit.node("List", "Currencies", {
				anchor = { 0.5, 0 },
				position = { 0.5, 0, 0, 16 },
				size = { 0, #bars * 240, 0, 62 },
				layout = { kind = "Horizontal", spacing = 20, padding = 0, align = "Center" },
			}, bars)
		)
		local buttons = {}
		for i = 1, answers.buttons do
			local b = HUD_BUTTONS[i]
			table.insert(buttons, Kit.hudButton(b[1] .. "Button", b[2], b[3], b[4]))
		end
		local side = answers.side
		local columns = if side == "Bottom" then answers.buttons else 2
		local rows = math.ceil(answers.buttons / columns)
		local menuW = columns * 86 + (columns - 1) * 18
		local menuH = rows * 104 + (rows - 1) * 6
		local position = if side == "Left"
			then { 0, 20, 0.5, 0 }
			elseif side == "Right" then { 1, -20, 0.5, 0 }
			else { 0.5, 0, 1, -24 }
		local anchor = if side == "Left" then { 0, 0.5 } elseif side == "Right" then { 1, 0.5 } else { 0.5, 1 }
		table.insert(
			templates,
			Kit.node("Grid", "Menu", {
				anchor = anchor,
				position = position,
				size = { 0, menuW, 0, menuH },
				layout = { kind = "Grid", columns = columns, cellHeight = 104, spacing = 18 },
			}, buttons)
		)
		return templates
	end,
})

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

local BY_ID: { [string]: Recipe } = {}
for _, recipe in Recipes do
	BY_ID[recipe.id] = recipe
end

local Api = {}

function Api.list(): { Recipe }
	return Recipes :: any
end

function Api.get(id: string): Recipe?
	return BY_ID[id]
end

function Api.defaults(recipe: Recipe): { [string]: any }
	local answers = {}
	for _, q in recipe.questions do
		answers[q.id] = q.default
	end
	return answers
end

-- Builds the templates for `answers` (missing answers take their default).
function Api.build(recipe: Recipe, answers: { [string]: any }): { any }
	local full = Api.defaults(recipe)
	for key, value in answers do
		full[key] = value
	end
	return recipe.build(full)
end

return Api
