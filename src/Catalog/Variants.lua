--!strict
-- Ready-made starting points for each kind of element ("Add a button" -> pick a design).
-- A variant only fills in starting values: once inserted, the element is a normal element
-- that can be changed completely.

export type Variant = { id: string, label: string, template: any }

local function at(x: number, y: number, ax: number?, ay: number?)
	return { position = { 0, x, 0, y }, anchor = { ax or 0, ay or 0 } }
end

local function merge(...: any): any
	local result = {}
	for _, part in { ... } do
		for key, value in part do
			result[key] = value
		end
	end
	return result
end

local function button(label: string, props: any, children: any?)
	return { type = "Button", name = label .. "Button", props = props, children = children }
end

local CLOSE_BUTTON = {
	type = "Button",
	name = "CloseButton",
	props = {
		size = { 0, 44, 0, 44 },
		position = { 1, -12, 0, 12 },
		anchor = { 1, 0 },
		fill = { kind = "Color", color = "$danger" },
		text = { value = "X", size = 26 },
		corner = "$radiusSmall",
	},
}

local Variants: { [string]: { Variant } } = {}

Variants.Button = {
	{ id = "Button.Simple", label = "Simple", template = button("Simple", { text = { value = "Bouton" } }) },
	{
		id = "Button.Secondary",
		label = "Secondaire",
		template = button(
			"Secondary",
			{ fill = { kind = "Color", color = "$secondary" }, text = { value = "Options" } }
		),
	},
	{
		id = "Button.Buy",
		label = "Acheter",
		template = button(
			"Buy",
			{ fill = { kind = "Color", color = "$success" }, text = { value = "Acheter" } }
		),
	},
	{
		id = "Button.Danger",
		label = "Danger",
		template = button(
			"Danger",
			{ fill = { kind = "Color", color = "$danger" }, text = { value = "Supprimer" } }
		),
	},
	{
		id = "Button.Premium",
		label = "Premium dégradé",
		template = button("Premium", {
			fill = { kind = "Gradient", color = "#FFD54A", color2 = "#FF7A00", rotation = 90 },
			text = { value = "PREMIUM", strokeEnabled = true, strokeColor = "#7A3B00" },
			stroke = { enabled = true, color = "#7A3B00", thickness = 3 },
		}),
	},
	{
		id = "Button.Outline",
		label = "Contour",
		template = button("Outline", {
			fill = { kind = "None" },
			stroke = { enabled = true, color = "$primary", thickness = 3 },
			text = { value = "Contour", color = "$primary" },
		}),
	},
	{
		id = "Button.Pill",
		label = "Pilule",
		template = button("Pill", { corner = 100, size = { 0, 190, 0, 52 }, text = { value = "Jouer" } }),
	},
	{
		id = "Button.Round",
		label = "Rond",
		template = button(
			"Round",
			{ corner = 100, size = { 0, 64, 0, 64 }, text = { value = "+", size = 34 } }
		),
	},
	{ id = "Button.Close", label = "Fermer", template = CLOSE_BUTTON },
	{
		id = "Button.Cartoon",
		label = "Cartoon",
		template = button("Cartoon", {
			size = { 0, 190, 0, 64 },
			fill = { kind = "Gradient", color = "#7CF26A", color2 = "#22B14C", rotation = 90 },
			stroke = { enabled = true, color = "#0B4A17", thickness = 4 },
			corner = 18,
			text = {
				value = "GO!",
				font = "FredokaOne",
				size = 30,
				strokeEnabled = true,
				strokeColor = "#0B4A17",
			},
		}),
	},
	{
		id = "Button.Studs",
		label = "Studs",
		template = button("Studs", {
			fill = { kind = "Color", color = "#E53935" },
			stroke = { enabled = true, color = "#7F0000", thickness = 3 },
			corner = 3,
			text = { value = "BUILD", font = "LuckiestGuy", size = 26 },
		}),
	},
	{
		id = "Button.Flat",
		label = "Flat",
		template = button("Flat", {
			fill = { kind = "Color", color = "#3B82F6" },
			stroke = { enabled = false },
			corner = 8,
			text = { value = "Continuer", font = "GothamBold", size = 20, color = "#FFFFFF" },
		}),
	},
	{
		id = "Button.Icon",
		label = "Avec icône",
		template = button("Icon", { size = { 0, 190, 0, 56 }, text = { value = "   Boutique" } }, {
			{
				type = "Icon",
				name = "Icon",
				props = merge(at(10, 0, 0, 0.5), { position = { 0, 10, 0.5, 0 }, size = { 0, 36, 0, 36 } }),
			},
		}),
	},
}

Variants.Text = {
	{
		id = "Text.Title",
		label = "Titre",
		template = {
			type = "Text",
			name = "Title",
			props = { size = { 0, 320, 0, 56 }, text = { value = "Titre", size = 42, strokeEnabled = true } },
		},
	},
	{
		id = "Text.Subtitle",
		label = "Sous-titre",
		template = {
			type = "Text",
			name = "Subtitle",
			props = { text = { value = "Sous-titre", size = 28 } },
		},
	},
	{
		id = "Text.Body",
		label = "Paragraphe",
		template = {
			type = "Text",
			name = "Description",
			props = {
				size = { 0, 300, 0, 80 },
				text = {
					value = "Une description sur plusieurs lignes.",
					font = "$fontBody",
					size = 18,
					alignX = "Left",
					color = "$textMuted",
				},
			},
		},
	},
	{
		id = "Text.Price",
		label = "Prix",
		template = {
			type = "Text",
			name = "Price",
			props = {
				size = { 0, 120, 0, 36 },
				text = { value = "100", size = 26, color = "#FFD54A", strokeEnabled = true },
			},
		},
	},
	{
		id = "Text.Label",
		label = "Petite étiquette",
		template = {
			type = "Text",
			name = "Label",
			props = {
				size = { 0, 160, 0, 24 },
				text = { value = "Étiquette", size = 16, color = "$textMuted" },
			},
		},
	},
}

Variants.Window = {
	{ id = "Window.Basic", label = "Basique", template = { type = "Window", name = "Window" } },
	{
		id = "Window.Titled",
		label = "Avec titre",
		template = {
			type = "Window",
			name = "Window",
			children = {
				{
					type = "Text",
					name = "Title",
					props = {
						position = { 0.5, 0, 0, 14 },
						anchor = { 0.5, 0 },
						text = { value = "Titre", size = 34, strokeEnabled = true },
					},
				},
				CLOSE_BUTTON,
			},
		},
	},
	{
		id = "Window.Popup",
		label = "Popup",
		template = { type = "Window", name = "Popup", props = { size = { 0, 380, 0, 240 } } },
	},
	{
		id = "Window.Large",
		label = "Grande",
		template = { type = "Window", name = "Window", props = { size = { 0, 760, 0, 480 } } },
	},
	{
		id = "Window.Compact",
		label = "Compacte",
		template = { type = "Window", name = "Window", props = { size = { 0, 320, 0, 220 } } },
	},
	{
		id = "Window.Gradient",
		label = "Dégradé",
		template = {
			type = "Window",
			name = "Window",
			props = {
				fill = { kind = "Gradient", color = "$surface", color2 = "$background", rotation = 90 },
			},
		},
	},
	{
		id = "Window.Responsive",
		label = "Adaptée à l'écran",
		template = { type = "Window", name = "Window", props = { size = { 0.6, 0, 0.7, 0 } } },
	},
}

local function card(name: string, children: any, props: any?)
	return { type = "Card", name = name, props = props, children = children }
end

local CARD_IMAGE = {
	type = "Image",
	name = "Image",
	props = { position = { 0.5, 0, 0, 10 }, anchor = { 0.5, 0 }, size = { 0, 90, 0, 90 } },
}

Variants.Card = {
	{ id = "Card.Simple", label = "Carte simple", template = card("Card", {}) },
	{
		id = "Card.Shop",
		label = "Carte boutique",
		template = card("ShopCard", {
			CARD_IMAGE,
			{
				type = "Text",
				name = "ItemName",
				props = {
					position = { 0.5, 0, 0, 104 },
					anchor = { 0.5, 0 },
					size = { 1, -12, 0, 24 },
					text = { value = "Objet", size = 20 },
				},
			},
			{
				type = "Button",
				name = "BuyButton",
				props = {
					position = { 0.5, 0, 1, -8 },
					anchor = { 0.5, 1 },
					size = { 1, -16, 0, 38 },
					fill = { kind = "Color", color = "$success" },
					text = { value = "100", size = 20 },
				},
			},
		}, { size = { 0, 140, 0, 190 } }),
	},
	{
		id = "Card.Pet",
		label = "Carte pet",
		template = card("PetCard", {
			CARD_IMAGE,
			{
				type = "Text",
				name = "PetName",
				props = {
					position = { 0.5, 0, 0, 104 },
					anchor = { 0.5, 0 },
					size = { 1, -12, 0, 24 },
					text = { value = "Pet", size = 20 },
				},
			},
			{
				type = "Text",
				name = "Rarity",
				props = {
					position = { 0.5, 0, 0, 130 },
					anchor = { 0.5, 0 },
					size = { 1, -12, 0, 20 },
					text = { value = "Légendaire", size = 16, color = "#FFD54A" },
				},
			},
		}, { size = { 0, 130, 0, 165 } }),
	},
	{
		id = "Card.Reward",
		label = "Carte récompense",
		template = card("RewardCard", {
			{
				type = "Text",
				name = "Day",
				props = {
					position = { 0.5, 0, 0, 6 },
					anchor = { 0.5, 0 },
					size = { 1, 0, 0, 24 },
					text = { value = "Jour 1", size = 18 },
				},
			},
			{
				type = "Icon",
				name = "RewardIcon",
				props = { position = { 0.5, 0, 0.5, 0 }, size = { 0, 56, 0, 56 } },
			},
			{
				type = "Text",
				name = "Amount",
				props = {
					position = { 0.5, 0, 1, -6 },
					anchor = { 0.5, 1 },
					size = { 1, 0, 0, 24 },
					text = { value = "x100", size = 20, color = "#FFD54A" },
				},
			},
		}, { size = { 0, 110, 0, 130 } }),
	},
	{
		id = "Card.Codex",
		label = "Carte codex",
		template = card(
			"CodexCard",
			{
				CARD_IMAGE,
				{
					type = "Text",
					name = "EntryName",
					props = {
						position = { 0.5, 0, 1, -8 },
						anchor = { 0.5, 1 },
						size = { 1, -12, 0, 24 },
						text = { value = "???", size = 20 },
					},
				},
			},
			{
				size = { 0, 120, 0, 140 },
				fill = { kind = "Gradient", color = "$surface", color2 = "$background", rotation = 90 },
			}
		),
	},
}

Variants.Panel = {
	{ id = "Panel.Simple", label = "Panneau", template = { type = "Panel", name = "Panel" } },
	{
		id = "Panel.Header",
		label = "Bandeau du haut",
		template = {
			type = "Panel",
			name = "Header",
			props = {
				position = { 0.5, 0, 0, 0 },
				anchor = { 0.5, 0 },
				size = { 1, 0, 0, 64 },
				fill = { kind = "Color", color = "$primary" },
			},
		},
	},
	{
		id = "Panel.Footer",
		label = "Bandeau du bas",
		template = {
			type = "Panel",
			name = "Footer",
			props = { position = { 0.5, 0, 1, 0 }, anchor = { 0.5, 1 }, size = { 1, 0, 0, 56 } },
		},
	},
	{
		id = "Panel.Sidebar",
		label = "Barre latérale",
		template = {
			type = "Panel",
			name = "Sidebar",
			props = {
				position = { 0, 0, 0.5, 0 },
				anchor = { 0, 0.5 },
				size = { 0, 160, 1, 0 },
				layout = { kind = "Vertical", spacing = 8, padding = 10, align = "Start" },
			},
		},
	},
	{
		id = "Panel.Currency",
		label = "Barre de monnaie",
		template = {
			type = "Panel",
			name = "CurrencyBar",
			props = { size = { 0, 180, 0, 46 }, corner = 100, stroke = { enabled = true } },
			children = {
				{
					type = "Icon",
					name = "CoinIcon",
					props = { position = { 0, 6, 0.5, 0 }, anchor = { 0, 0.5 }, size = { 0, 36, 0, 36 } },
				},
				{
					type = "Text",
					name = "Amount",
					props = {
						position = { 0, 50, 0.5, 0 },
						anchor = { 0, 0.5 },
						size = { 1, -60, 1, 0 },
						text = { value = "1 250", alignX = "Left", size = 24 },
					},
				},
			},
		},
	},
}

Variants.Image = {
	{ id = "Image.Square", label = "Image carrée", template = { type = "Image", name = "Image" } },
	{
		id = "Image.Banner",
		label = "Bannière",
		template = {
			type = "Image",
			name = "Banner",
			props = { size = { 0, 360, 0, 120 }, image = { scaleType = "Crop" }, corner = "$radiusSmall" },
		},
	},
	{
		id = "Image.Round",
		label = "Avatar rond",
		template = {
			type = "Image",
			name = "Avatar",
			props = {
				corner = 100,
				image = { scaleType = "Crop" },
				stroke = { enabled = true, thickness = 3 },
			},
		},
	},
}

Variants.Icon = {
	{ id = "Icon.Small", label = "Petite icône", template = { type = "Icon", name = "Icon" } },
	{
		id = "Icon.Large",
		label = "Grande icône",
		template = { type = "Icon", name = "Icon", props = { size = { 0, 80, 0, 80 } } },
	},
	{
		id = "Icon.Badge",
		label = "Icône sur pastille",
		template = {
			type = "Icon",
			name = "Icon",
			props = { size = { 0, 56, 0, 56 }, corner = 100, fill = { kind = "Color", color = "$accent" } },
		},
	},
}

Variants.Grid = {
	{ id = "Grid.Cards", label = "Grille de cartes", template = { type = "Grid", name = "Grid" } },
	{
		id = "Grid.Small",
		label = "Petites cases",
		template = {
			type = "Grid",
			name = "Grid",
			props = { layout = { kind = "Grid", cellWidth = 80, cellHeight = 80, spacing = 8 } },
		},
	},
}

Variants.List = {
	{ id = "List.Vertical", label = "Liste verticale", template = { type = "List", name = "List" } },
	{
		id = "List.Horizontal",
		label = "Liste horizontale (onglets)",
		template = {
			type = "List",
			name = "Tabs",
			props = { size = { 0, 420, 0, 50 }, layout = { kind = "Horizontal", spacing = 8 } },
			children = {
				button("Tab1", { size = { 0, 120, 0, 42 }, text = { value = "Onglet 1", size = 18 } }),
				button(
					"Tab2",
					{
						size = { 0, 120, 0, 42 },
						fill = { kind = "Color", color = "$surface" },
						text = { value = "Onglet 2", size = 18 },
					}
				),
				button(
					"Tab3",
					{
						size = { 0, 120, 0, 42 },
						fill = { kind = "Color", color = "$surface" },
						text = { value = "Onglet 3", size = 18 },
					}
				),
			},
		},
	},
}

Variants.ScrollArea = {
	{
		id = "ScrollArea.Grid",
		label = "Grille défilante",
		template = { type = "ScrollArea", name = "ScrollGrid" },
	},
	{
		id = "ScrollArea.List",
		label = "Liste défilante",
		template = {
			type = "ScrollArea",
			name = "ScrollList",
			props = { layout = { kind = "Vertical", spacing = 8, padding = 8 } },
		},
	},
}

local Catalog = {}

function Catalog.list(typeName: string): { Variant }
	return Variants[typeName]
		or { { id = typeName, label = typeName, template = { type = typeName, name = typeName } } }
end

Catalog.CLOSE_BUTTON = CLOSE_BUTTON

return Catalog
