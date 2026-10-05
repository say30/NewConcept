--!strict
-- What the "Ajouter" gallery offers, by category. Each entry makes a fresh template from
-- Kit, so everything inserted follows the project's style pack.

local Icons = require(script.Parent.Parent.Visual.Icons)
local Kit = require(script.Parent.Kit)

export type Entry = { id: string, label: string, make: () -> any }
export type Category = { id: string, label: string, icon: string, entries: { Entry } }

local function entry(id: string, label: string, make: () -> any): Entry
	return { id = id, label = label, make = make }
end

local function sampleCards(count: number, style: string?)
	local icons = { "Potion", "Egg", "Chest", "Gem", "Gift", "Sword" }
	local cards = {}
	for i = 1, count do
		table.insert(
			cards,
			Kit.card({
				name = "Item" .. i,
				style = style,
				title = "Objet " .. i,
				icon = icons[(i - 1) % #icons + 1],
				price = tostring(i * 100),
			})
		)
	end
	return cards
end

local categories: { Category } = {
	{
		id = "Windows",
		label = "Fenêtres",
		icon = "Shop",
		entries = {
			entry("WindowBar", "Titre dans le cadre", function()
				return Kit.window({ title = "Titre", icon = "Shop" })
			end),
			entry("WindowTab", "Titre en onglet", function()
				return Kit.window({ title = "Titre", titleStyle = "Tab" })
			end),
			entry("WindowBanner", "Bandeau coloré", function()
				return Kit.window({ title = "Titre", titleStyle = "Banner", icon = "Gift" })
			end),
			entry("WindowTabs", "Avec onglets", function()
				return Kit.window({ title = "Titre", icon = "Bag", tabs = { "Un", "Deux", "Trois" } })
			end),
			entry("Popup", "Petite fenêtre", function()
				return Kit.window({
					name = "Popup",
					title = "Message",
					width = 420,
					height = 260,
					icon = "Check",
				})
			end),
			entry("Panel", "Panneau simple", function()
				return Kit.node("Panel", "Panel", { size = { 0, 300, 0, 200 } })
			end),
		},
	},
	{
		id = "Cards",
		label = "Cartes",
		icon = "Gift",
		entries = {
			entry("CardTall", "Carte avec prix", function()
				return Kit.card({ title = "Objet", icon = "Potion", price = "500" })
			end),
			entry("CardWide", "Ligne avec prix", function()
				local card = Kit.card({
					style = "Wide",
					title = "Objet",
					subtitle = "Dure 10 min",
					icon = "Chest",
					price = "500",
					color = "$accent1",
					textColor = "#FFFFFF",
				})
				card.props.size = { 0, 380, 0, 96 }
				return card
			end),
			entry("CardSlot", "Case d'inventaire", function()
				local card = Kit.card({
					style = "Slot",
					icon = "Egg",
					subtitle = "x3",
					color = "$accent4",
					textColor = "#FFFFFF",
				})
				card.props.size = { 0, 110, 0, 110 }
				return card
			end),
			entry("CardBadge", "Carte en promo", function()
				return Kit.card({
					title = "Pack",
					icon = "Gift",
					price = "99 R$",
					currency = "",
					badge = "-50%",
					color = "$accent3",
					textColor = "#FFFFFF",
				})
			end),
			entry("CardReward", "Jour de cadeau", function()
				return Kit.card({
					title = "Jour 1",
					subtitle = "x100",
					icon = "Gift",
					color = "$accent2",
					textColor = "#FFFFFF",
				})
			end),
			entry("ToggleRow", "Ligne d'option", function()
				local row = Kit.toggleRow("Musique", true)
				row.props.size = { 0, 380, 0, 58 }
				return row
			end),
		},
	},
	{
		id = "Buttons",
		label = "Boutons",
		icon = "ArrowRight",
		entries = {
			entry("ButtonPlay", "Bouton principal", function()
				return Kit.button({ name = "PlayButton", text = "Jouer", color = "$success" })
			end),
			entry("ButtonBuy", "Bouton d'achat", function()
				return Kit.priceButton("500", "Coin")
			end),
			entry("ButtonRobux", "Bouton Robux", function()
				return Kit.button({ name = "RobuxButton", text = "99 R$", color = "$success" })
			end),
			entry("ButtonClose", "Fermer", function()
				local b = Kit.closeButton("Square")
				b.props.position = { 0.5, 0, 0.5, 0 }
				b.props.anchor = { 0.5, 0.5 }
				return b
			end),
			entry("ButtonIcon", "Bouton icône", function()
				return Kit.button({
					name = "IconButton",
					icon = "Gear",
					color = "$primary",
					size = { 0, 64, 0, 64 },
				})
			end),
			entry("ButtonHud", "Bouton de menu", function()
				return Kit.hudButton("ShopButton", "Shop", "SHOP", "$warning")
			end),
			entry("ButtonClaim", "Récupérer", function()
				return Kit.button({
					name = "ClaimButton",
					text = "Récupérer",
					icon = "Check",
					color = "$success",
					size = { 0, 220, 0, 56 },
				})
			end),
			entry("ButtonTab", "Onglet", function()
				return Kit.button({
					name = "Tab",
					text = "Onglet",
					color = "$accent3",
					size = { 0, 120, 0, 42 },
					textSize = 20,
				})
			end),
		},
	},
	{
		id = "Texts",
		label = "Textes",
		icon = "Ticket",
		entries = {
			entry("Title", "Grand titre", function()
				return Kit.title("Titre", 44, { size = { 0, 360, 0, 56 } })
			end),
			entry("Subtitle", "Sous-titre", function()
				return Kit.text("Subtitle", "Sous-titre", 30, { size = { 0, 300, 0, 40 } })
			end),
			entry("Body", "Paragraphe", function()
				return Kit.text("Body", "Un petit texte pour expliquer quelque chose au joueur.", 20, {
					size = { 0, 320, 0, 60 },
					text = { wrap = true, stroke = { enabled = false } },
				})
			end),
			entry("Amount", "Montant", function()
				return Kit.text("Amount", "x2 gains", 38, {
					size = { 0, 240, 0, 50 },
					text = { color = "$warning", font = "$fontTitle", stroke = { thickness = 3 } },
				})
			end),
			entry("Input", "Zone de saisie", function()
				return Kit.node("Input", "TextInput", { text = { placeholder = "Écris ici..." } })
			end),
		},
	},
	{
		id = "Bars",
		label = "Barres",
		icon = "Coins",
		entries = {
			entry("Section", "Barre de section", function()
				local bar = Kit.sectionBar("Section")
				bar.props.size = { 0, 400, 0, 40 }
				return bar
			end),
			entry("Currency", "Monnaie", function()
				return Kit.currencyBar("CoinsBar", "Coin", "12,500")
			end),
			entry("CurrencyGem", "Gemmes", function()
				return Kit.currencyBar("GemsBar", "Gem", "350")
			end),
			entry("Progress", "Progression", function()
				local bar = Kit.progressBar("Progress", 0.6, "60 %")
				bar.props.size = { 0, 360, 0, 34 }
				return bar
			end),
			entry("CodeRow", "Code + bouton", function()
				local row = Kit.inputRow("Entre ton code...", "Valider")
				row.props.size = { 0, 460, 0, 64 }
				return row
			end),
		},
	},
	{
		id = "Layouts",
		label = "Rangements",
		icon = "Podium",
		entries = {
			entry("Grid3", "Grille de cartes", function()
				return Kit.grid("Items", 3, 196, sampleCards(6), { size = { 0, 520, 0, 410 } })
			end),
			entry("Scroll", "Liste défilante", function()
				return Kit.scroll("Items", 2, 96, sampleCards(6, "Wide"), { size = { 0, 560, 0, 320 } })
			end),
			entry("GridEmpty", "Grille vide", function()
				return Kit.node("Grid", "Grid", { size = { 0, 400, 0, 300 } })
			end),
			entry("ListEmpty", "Colonne vide", function()
				return Kit.node("List", "List", {})
			end),
		},
	},
}

-- Every icon as its own entry.
local iconEntries = {}
for _, def in Icons.list do
	table.insert(
		iconEntries,
		entry("Icon" .. def.id, def.label, function()
			return Kit.node("Icon", def.id .. "Icon", { size = { 0, 72, 0, 72 }, icon = { id = def.id } })
		end)
	)
end
table.insert(categories, 5, { id = "Icons", label = "Icônes", icon = "Coin", entries = iconEntries })

local Elements = {}

function Elements.categories(): { Category }
	return categories
end

return Elements
