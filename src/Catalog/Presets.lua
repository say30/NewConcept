--!strict
-- Complete interfaces to start from (Shop, Inventory, Daily Rewards...). A preset is inserted
-- as ordinary elements with readable names; nothing stays linked to the preset afterwards.

local Variants = require(script.Parent.Variants)

export type Preset = { id: string, label: string, description: string, template: any }

local function text(name: string, value: string, props: any?)
	local p = props or {}
	p.text = p.text or {}
	p.text.value = value
	return { type = "Text", name = name, props = p }
end

local function title(value: string)
	return text("Title", value, {
		position = { 0.5, 0, 0, 14 },
		anchor = { 0.5, 0 },
		size = { 1, -120, 0, 48 },
		text = { size = 38, strokeEnabled = true },
	})
end

local function buttonNode(name: string, label: string, props: any)
	props.text = props.text or {}
	props.text.value = label
	return { type = "Button", name = name, props = props }
end

local function window(name: string, size: { number }, children: { any })
	return { type = "Window", name = name, props = { size = size }, children = children }
end

local function repeatCards(variantId: string, count: number): { any }
	local template
	for _, list in { Variants.list("Card") } do
		for _, variant in list do
			if variant.id == variantId then
				template = variant.template
			end
		end
	end
	local cards = {}
	for i = 1, count do
		local copy = table.clone(template)
		copy.name = string.format("%s%02d", template.name, i)
		table.insert(cards, copy)
	end
	return cards
end

local function tabs(labels: { string })
	local children = {}
	for i, label in labels do
		table.insert(
			children,
			buttonNode(label .. "Tab", label, {
				size = { 0, 130, 0, 40 },
				fill = { kind = "Color", color = if i == 1 then "$primary" else "$surface" },
				text = { size = 18 },
			})
		)
	end
	return {
		type = "List",
		name = "Tabs",
		props = {
			position = { 0.5, 0, 0, 72 },
			anchor = { 0.5, 0 },
			size = { 1, -40, 0, 44 },
			layout = { kind = "Horizontal", spacing = 8, align = "Start", padding = 0 },
		},
		children = children,
	}
end

local function scrollGrid(cards: { any }, top: number, bottom: number, cellW: number, cellH: number)
	return {
		type = "ScrollArea",
		name = "ItemGrid",
		props = {
			position = { 0.5, 0, 0, top },
			anchor = { 0.5, 0 },
			size = { 1, -40, 1, -(top + bottom) },
			layout = {
				kind = "Grid",
				cellWidth = cellW,
				cellHeight = cellH,
				spacing = 12,
				padding = 6,
				align = "Start",
			},
		},
		children = cards,
	}
end

local CLOSE = Variants.CLOSE_BUTTON

local Presets: { Preset } = {
	{
		id = "Shop",
		label = "Shop",
		description = "Boutique avec onglets, grille d'objets et prix",
		template = window("ShopWindow", { 0, 680, 0, 460 }, {
			title("BOUTIQUE"),
			CLOSE,
			tabs({ "Objets", "Pets", "Bonus" }),
			scrollGrid(repeatCards("Card.Shop", 8), 128, 20, 140, 190),
		}),
	},
	{
		id = "Inventory",
		label = "Inventory",
		description = "Inventaire de pets avec bouton Équiper",
		template = window("InventoryWindow", { 0, 680, 0, 460 }, {
			title("INVENTAIRE"),
			CLOSE,
			scrollGrid(repeatCards("Card.Pet", 10), 76, 84, 130, 165),
			buttonNode("EquipButton", "Équiper", {
				position = { 0.5, 0, 1, -16 },
				anchor = { 0.5, 1 },
				size = { 0, 200, 0, 52 },
				fill = { kind = "Color", color = "$success" },
			}),
		}),
	},
	{
		id = "PetCodex",
		label = "Pet Codex",
		description = "Codex des pets à découvrir",
		template = window("CodexWindow", { 0, 680, 0, 460 }, {
			title("CODEX"),
			CLOSE,
			tabs({ "Commun", "Rare", "Légendaire" }),
			scrollGrid(repeatCards("Card.Codex", 12), 128, 20, 120, 140),
		}),
	},
	{
		id = "DailyRewards",
		label = "Daily Rewards",
		description = "7 jours de récompenses et un bouton Récupérer",
		template = window("DailyRewardsWindow", { 0, 640, 0, 400 }, {
			title("RÉCOMPENSES"),
			CLOSE,
			{
				type = "Grid",
				name = "Days",
				props = {
					position = { 0.5, 0, 0, 80 },
					anchor = { 0.5, 0 },
					size = { 1, -40, 0, 230 },
					layout = {
						kind = "Grid",
						cellWidth = 110,
						cellHeight = 110,
						spacing = 10,
						align = "Center",
					},
				},
				children = repeatCards("Card.Reward", 7),
			},
			buttonNode("ClaimButton", "Récupérer", {
				position = { 0.5, 0, 1, -16 },
				anchor = { 0.5, 1 },
				size = { 0, 220, 0, 54 },
				fill = { kind = "Gradient", color = "#7CF26A", color2 = "#22B14C", rotation = 90 },
			}),
		}),
	},
	{
		id = "FuseMachine",
		label = "Fuse Machine",
		description = "Deux emplacements, un résultat et un bouton Fusionner",
		template = window("FuseWindow", { 0, 620, 0, 400 }, {
			title("FUSION"),
			CLOSE,
			{
				type = "Card",
				name = "SlotA",
				props = { position = { 0.2, 0, 0.45, 0 }, size = { 0, 120, 0, 140 } },
			},
			text(
				"Plus",
				"+",
				{ position = { 0.35, 0, 0.45, 0 }, size = { 0, 40, 0, 40 }, text = { size = 40 } }
			),
			{
				type = "Card",
				name = "SlotB",
				props = { position = { 0.5, 0, 0.45, 0 }, size = { 0, 120, 0, 140 } },
			},
			text(
				"Arrow",
				"=",
				{ position = { 0.65, 0, 0.45, 0 }, size = { 0, 40, 0, 40 }, text = { size = 40 } }
			),
			{
				type = "Card",
				name = "Result",
				props = {
					position = { 0.8, 0, 0.45, 0 },
					size = { 0, 120, 0, 140 },
					stroke = { enabled = true, color = "#FFD54A", thickness = 4 },
				},
			},
			buttonNode("FuseButton", "Fusionner", {
				position = { 0.5, 0, 1, -16 },
				anchor = { 0.5, 1 },
				size = { 0, 220, 0, 54 },
				fill = { kind = "Color", color = "$accent" },
			}),
		}),
	},
	{
		id = "MutationMachine",
		label = "Mutation Machine",
		description = "Un pet, les chances de mutation et un bouton Muter",
		template = window("MutationWindow", { 0, 560, 0, 420 }, {
			title("MUTATION"),
			CLOSE,
			{
				type = "Card",
				name = "PetSlot",
				props = { position = { 0.5, 0, 0, 90 }, anchor = { 0.5, 0 }, size = { 0, 150, 0, 160 } },
			},
			text(
				"Chance",
				"Chance : 25 %",
				{
					position = { 0.5, 0, 0, 266 },
					anchor = { 0.5, 0 },
					size = { 0, 300, 0, 32 },
					text = { size = 22 },
				}
			),
			buttonNode("MutateButton", "Muter", {
				position = { 0.5, 0, 1, -16 },
				anchor = { 0.5, 1 },
				size = { 0, 220, 0, 54 },
				fill = { kind = "Gradient", color = "#C77DFF", color2 = "#7B2CBF", rotation = 90 },
			}),
		}),
	},
	{
		id = "Settings",
		label = "Settings",
		description = "Liste de réglages avec boutons ON/OFF",
		template = window("SettingsWindow", { 0, 460, 0, 420 }, {
			title("RÉGLAGES"),
			CLOSE,
			{
				type = "List",
				name = "Options",
				props = {
					position = { 0.5, 0, 0, 80 },
					anchor = { 0.5, 0 },
					size = { 1, -40, 1, -100 },
					layout = { kind = "Vertical", spacing = 10, align = "Start", padding = 0 },
				},
				children = {
					{
						type = "Panel",
						name = "MusicRow",
						props = { size = { 1, 0, 0, 56 } },
						children = {
							text(
								"Label",
								"Musique",
								{
									position = { 0, 14, 0.5, 0 },
									anchor = { 0, 0.5 },
									size = { 0.6, 0, 1, 0 },
									text = { alignX = "Left", size = 22 },
								}
							),
							buttonNode(
								"Toggle",
								"ON",
								{
									position = { 1, -10, 0.5, 0 },
									anchor = { 1, 0.5 },
									size = { 0, 80, 0, 38 },
									fill = { kind = "Color", color = "$success" },
									text = { size = 18 },
								}
							),
						},
					},
					{
						type = "Panel",
						name = "SoundsRow",
						props = { size = { 1, 0, 0, 56 } },
						children = {
							text(
								"Label",
								"Effets sonores",
								{
									position = { 0, 14, 0.5, 0 },
									anchor = { 0, 0.5 },
									size = { 0.6, 0, 1, 0 },
									text = { alignX = "Left", size = 22 },
								}
							),
							buttonNode(
								"Toggle",
								"ON",
								{
									position = { 1, -10, 0.5, 0 },
									anchor = { 1, 0.5 },
									size = { 0, 80, 0, 38 },
									fill = { kind = "Color", color = "$success" },
									text = { size = 18 },
								}
							),
						},
					},
					{
						type = "Panel",
						name = "ShadowsRow",
						props = { size = { 1, 0, 0, 56 } },
						children = {
							text(
								"Label",
								"Ombres",
								{
									position = { 0, 14, 0.5, 0 },
									anchor = { 0, 0.5 },
									size = { 0.6, 0, 1, 0 },
									text = { alignX = "Left", size = 22 },
								}
							),
							buttonNode(
								"Toggle",
								"OFF",
								{
									position = { 1, -10, 0.5, 0 },
									anchor = { 1, 0.5 },
									size = { 0, 80, 0, 38 },
									fill = { kind = "Color", color = "$danger" },
									text = { size = 18 },
								}
							),
						},
					},
				},
			},
		}),
	},
	{
		id = "Codes",
		label = "Codes",
		description = "Champ de code et bouton Valider",
		template = window("CodesWindow", { 0, 440, 0, 260 }, {
			title("CODES"),
			CLOSE,
			{
				type = "Panel",
				name = "CodeField",
				props = {
					position = { 0.5, 0, 0, 90 },
					anchor = { 0.5, 0 },
					size = { 1, -60, 0, 52 },
					stroke = { enabled = true },
				},
				children = {
					text(
						"Placeholder",
						"Entre un code...",
						{ size = { 1, -20, 1, 0 }, text = { color = "$textMuted", size = 20 } }
					),
				},
			},
			buttonNode("RedeemButton", "Valider", {
				position = { 0.5, 0, 1, -18 },
				anchor = { 0.5, 1 },
				size = { 0, 200, 0, 52 },
				fill = { kind = "Color", color = "$success" },
			}),
		}),
	},
	{
		id = "Rebirth",
		label = "Rebirth",
		description = "Coût, bonus et bouton Renaître",
		template = window("RebirthWindow", { 0, 480, 0, 340 }, {
			title("REBIRTH"),
			CLOSE,
			text(
				"Bonus",
				"Bonus x2 de pièces",
				{
					position = { 0.5, 0, 0, 100 },
					anchor = { 0.5, 0 },
					size = { 1, -40, 0, 36 },
					text = { size = 26, color = "#7CF26A" },
				}
			),
			text(
				"Cost",
				"Coût : 1 000 000",
				{
					position = { 0.5, 0, 0, 150 },
					anchor = { 0.5, 0 },
					size = { 1, -40, 0, 30 },
					text = { size = 22, color = "$textMuted" },
				}
			),
			buttonNode("RebirthButton", "Renaître", {
				position = { 0.5, 0, 1, -18 },
				anchor = { 0.5, 1 },
				size = { 0, 220, 0, 54 },
				fill = { kind = "Gradient", color = "#FFD54A", color2 = "#FF7A00", rotation = 90 },
			}),
		}),
	},
	{
		id = "GamepassShop",
		label = "Gamepass Shop",
		description = "Liste de gamepass avec prix en Robux",
		template = window("GamepassWindow", { 0, 560, 0, 440 }, {
			title("GAMEPASS"),
			CLOSE,
			{
				type = "ScrollArea",
				name = "PassList",
				props = {
					position = { 0.5, 0, 0, 76 },
					anchor = { 0.5, 0 },
					size = { 1, -40, 1, -96 },
					layout = { kind = "Vertical", spacing = 10, padding = 4, align = "Start" },
				},
				children = {
					{
						type = "Panel",
						name = "VipPass",
						props = { size = { 1, -12, 0, 80 }, stroke = { enabled = true } },
						children = {
							{
								type = "Icon",
								name = "PassIcon",
								props = {
									position = { 0, 12, 0.5, 0 },
									anchor = { 0, 0.5 },
									size = { 0, 56, 0, 56 },
								},
							},
							text(
								"PassName",
								"VIP",
								{
									position = { 0, 80, 0.5, 0 },
									anchor = { 0, 0.5 },
									size = { 0.5, 0, 0, 30 },
									text = { alignX = "Left", size = 24 },
								}
							),
							buttonNode(
								"BuyButton",
								"R$ 199",
								{
									position = { 1, -12, 0.5, 0 },
									anchor = { 1, 0.5 },
									size = { 0, 120, 0, 44 },
									fill = { kind = "Color", color = "$success" },
									text = { size = 20 },
								}
							),
						},
					},
					{
						type = "Panel",
						name = "DoubleCoinsPass",
						props = { size = { 1, -12, 0, 80 }, stroke = { enabled = true } },
						children = {
							{
								type = "Icon",
								name = "PassIcon",
								props = {
									position = { 0, 12, 0.5, 0 },
									anchor = { 0, 0.5 },
									size = { 0, 56, 0, 56 },
								},
							},
							text(
								"PassName",
								"Pièces x2",
								{
									position = { 0, 80, 0.5, 0 },
									anchor = { 0, 0.5 },
									size = { 0.5, 0, 0, 30 },
									text = { alignX = "Left", size = 24 },
								}
							),
							buttonNode(
								"BuyButton",
								"R$ 299",
								{
									position = { 1, -12, 0.5, 0 },
									anchor = { 1, 0.5 },
									size = { 0, 120, 0, 44 },
									fill = { kind = "Color", color = "$success" },
									text = { size = 20 },
								}
							),
						},
					},
				},
			},
		}),
	},
	{
		id = "SimplePopup",
		label = "Simple Popup",
		description = "Message et bouton OK",
		template = window("Popup", { 0, 380, 0, 220 }, {
			title("INFO"),
			text(
				"Message",
				"Ton message ici.",
				{
					position = { 0.5, 0, 0.45, 0 },
					size = { 1, -40, 0, 50 },
					text = { font = "$fontBody", size = 20, color = "$textMuted" },
				}
			),
			buttonNode(
				"OkButton",
				"OK",
				{ position = { 0.5, 0, 1, -16 }, anchor = { 0.5, 1 }, size = { 0, 140, 0, 48 } }
			),
		}),
	},
	{
		id = "ConfirmPopup",
		label = "Confirmation Popup",
		description = "Question avec boutons Oui et Non",
		template = window("ConfirmPopup", { 0, 400, 0, 230 }, {
			title("SÛR ?"),
			text(
				"Question",
				"Veux-tu vraiment continuer ?",
				{
					position = { 0.5, 0, 0.45, 0 },
					size = { 1, -40, 0, 50 },
					text = { font = "$fontBody", size = 20, color = "$textMuted" },
				}
			),
			buttonNode(
				"YesButton",
				"Oui",
				{
					position = { 0.28, 0, 1, -16 },
					anchor = { 0.5, 1 },
					size = { 0, 140, 0, 48 },
					fill = { kind = "Color", color = "$success" },
				}
			),
			buttonNode(
				"NoButton",
				"Non",
				{
					position = { 0.72, 0, 1, -16 },
					anchor = { 0.5, 1 },
					size = { 0, 140, 0, 48 },
					fill = { kind = "Color", color = "$danger" },
				}
			),
		}),
	},
	{
		id = "HUD",
		label = "HUD",
		description = "Monnaies en haut à gauche et menu sur le côté",
		template = {
			type = "Panel",
			name = "HUD",
			props = {
				position = { 0, 0, 0, 0 },
				anchor = { 0, 0 },
				size = { 1, 0, 1, 0 },
				fill = { kind = "None" },
			},
			children = {
				{
					type = "List",
					name = "Currencies",
					props = {
						position = { 0, 16, 0, 16 },
						anchor = { 0, 0 },
						size = { 0, 200, 0, 110 },
						layout = { kind = "Vertical", spacing = 8, align = "Start", padding = 0 },
					},
					children = {
						{
							type = "Panel",
							name = "CoinsBar",
							props = { size = { 0, 190, 0, 46 }, corner = 100, stroke = { enabled = true } },
							children = {
								{
									type = "Icon",
									name = "CoinIcon",
									props = {
										position = { 0, 6, 0.5, 0 },
										anchor = { 0, 0.5 },
										size = { 0, 36, 0, 36 },
									},
								},
								text(
									"Amount",
									"1 250",
									{
										position = { 0, 50, 0.5, 0 },
										anchor = { 0, 0.5 },
										size = { 1, -60, 1, 0 },
										text = { alignX = "Left", size = 24 },
									}
								),
							},
						},
						{
							type = "Panel",
							name = "GemsBar",
							props = { size = { 0, 190, 0, 46 }, corner = 100, stroke = { enabled = true } },
							children = {
								{
									type = "Icon",
									name = "GemIcon",
									props = {
										position = { 0, 6, 0.5, 0 },
										anchor = { 0, 0.5 },
										size = { 0, 36, 0, 36 },
									},
								},
								text(
									"Amount",
									"45",
									{
										position = { 0, 50, 0.5, 0 },
										anchor = { 0, 0.5 },
										size = { 1, -60, 1, 0 },
										text = { alignX = "Left", size = 24 },
									}
								),
							},
						},
					},
				},
				{
					type = "List",
					name = "SideMenu",
					props = {
						position = { 0, 16, 0.5, 0 },
						anchor = { 0, 0.5 },
						size = { 0, 80, 0, 260 },
						layout = { kind = "Vertical", spacing = 10, align = "Center", padding = 0 },
					},
					children = {
						buttonNode(
							"ShopButton",
							"Shop",
							{ size = { 0, 72, 0, 72 }, corner = 18, text = { size = 18 } }
						),
						buttonNode(
							"PetsButton",
							"Pets",
							{
								size = { 0, 72, 0, 72 },
								corner = 18,
								fill = { kind = "Color", color = "$secondary" },
								text = { size = 18 },
							}
						),
						buttonNode(
							"RewardsButton",
							"Cadeaux",
							{
								size = { 0, 72, 0, 72 },
								corner = 18,
								fill = { kind = "Color", color = "$accent" },
								text = { size = 16 },
							}
						),
					},
				},
			},
		},
	},
}

local PresetCatalog = {}

function PresetCatalog.list(): { Preset }
	return Presets
end

function PresetCatalog.get(id: string): Preset?
	for _, preset in Presets do
		if preset.id == id then
			return preset
		end
	end
	return nil
end

return PresetCatalog
