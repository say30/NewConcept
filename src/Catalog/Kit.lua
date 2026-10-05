--!strict
-- Building blocks drawn in the style of popular Roblox games: windows with a title and a
-- close button, section bars, item cards, price buttons, currency bars, HUD buttons...
-- Each function returns a node template (see Core/Document) whose colours follow the
-- project's style pack, so every model re-skins when the pack changes.

local Kit = {}

type Template = { [string]: any }

local function node(
	nodeType: string,
	name: string,
	props: { [string]: any }?,
	children: { Template }?
): Template
	return { type = nodeType, name = name, props = props or {}, children = children or {} }
end

Kit.node = node

local function at(x: number, xo: number, y: number, yo: number): { number }
	return { x, xo, y, yo }
end

-- Text -----------------------------------------------------------------------

function Kit.text(name: string, value: string, size: number, props: { [string]: any }?): Template
	local p = props or {}
	p.text = p.text or {}
	p.text.value = value
	p.text.size = size
	return node("Text", name, p)
end

function Kit.title(value: string, size: number?, props: { [string]: any }?): Template
	local p = props or {}
	p.text = p.text or {}
	p.text.font = "$fontTitle"
	p.text.stroke = { thickness = 3 }
	return Kit.text("Title", value, size or 32, p)
end

-- Buttons --------------------------------------------------------------------

export type ButtonOptions = {
	name: string?,
	text: string?,
	icon: string?,
	color: string?,
	size: { number }?,
	position: { number }?,
	anchor: { number }?,
	textSize: number?,
	corner: number | string?,
}

function Kit.button(o: ButtonOptions): Template
	return node("Button", o.name or "Button", {
		size = o.size or { 0, 170, 0, 54 },
		position = o.position,
		anchor = o.anchor,
		corner = o.corner,
		fill = { color = o.color or "$primary" },
		text = { value = o.text or "", size = o.textSize or 24 },
		icon = { id = o.icon or "" },
	})
end

-- Square close button with a white cross.
function Kit.closeButton(style: string?, size: number?): Template
	local s = size or 44
	return Kit.button({
		name = "CloseButton",
		icon = "Close",
		color = "$danger",
		size = { 0, s, 0, s },
		corner = if style == "Round" then -1 else "$radiusSmall",
		position = at(1, -10, 0, 10),
		anchor = { 1, 0 },
	})
end

-- A button showing a currency icon and a price.
function Kit.priceButton(
	price: string,
	currency: string?,
	color: string?,
	props: { [string]: any }?
): Template
	local b = Kit.button({
		name = "BuyButton",
		text = price,
		icon = currency or "Coin",
		color = color or "$warning",
		textSize = 22,
	})
	for key, value in props or {} do
		b.props[key] = value
	end
	return b
end

-- Windows --------------------------------------------------------------------

export type WindowOptions = {
	name: string?,
	title: string?,
	icon: string?, -- icon id shown next to the title, or nil
	titleStyle: string?, -- "Bar" | "Tab" | "Banner"
	width: number?,
	height: number?,
	close: string?, -- "Square" | "Round" | "None"
	tabs: { string }?,
	content: { Template }?, -- placed inside the window body
	bodyPattern: string?, -- overrides the pack pattern
}

local TAB_COLORS = { "$accent3", "$accent4", "$warning", "$accent1", "$accent2" }

-- A coloured frame, a title, an optional close button and tabs, and an inner body that
-- holds the content.
function Kit.window(o: WindowOptions): Template
	local w, h = o.width or 600, o.height or 420
	local style = o.titleStyle or "Bar"
	local top = if style == "Tab" then 40 elseif style == "Banner" then 70 else 64
	local children = {}

	local bodyProps: { [string]: any } = {
		anchor = { 0.5, 1 },
		position = at(0.5, 0, 1, -12),
		size = { 1, -24, 1, -(top + 12) },
		stroke = { thickness = 3 },
	}
	if o.bodyPattern then
		bodyProps.pattern = { kind = o.bodyPattern }
	end
	table.insert(children, node("Panel", "Body", bodyProps, o.content or {}))

	if style == "Tab" then
		local tab = node("Panel", "TitleTab", {
			anchor = { 0.5, 0.5 },
			position = at(0.5, 0, 0, 2),
			size = { 0, math.max(200, #(o.title or "") * 22 + 60), 0, 58 },
			corner = -1,
			fill = { kind = "Shade", color = "$frame" },
			pattern = { kind = "None" },
			zIndex = 3,
		}, {
			Kit.title(o.title or "Titre", 34, { size = { 1, -20, 1, -8 } }),
		})
		table.insert(children, tab)
	elseif style == "Banner" then
		table.insert(
			children,
			node("Panel", "Banner", {
				anchor = { 0.5, 0 },
				position = at(0.5, 0, 0, 10),
				size = { 1, -24, 0, 52 },
				fill = { kind = "Shade", color = "$header" },
				pattern = { kind = "None" },
				zIndex = 2,
			}, {
				-- With tabs on the right, the title moves to the left to leave them room.
				if o.tabs and #o.tabs > 0
					then Kit.title(o.title or "Titre", 34, {
						anchor = { 0, 0.5 },
						position = at(0, if o.icon then 66 else 16, 0.5, 0),
						size = { 0.45, 0, 1, -6 },
						text = { alignX = "Left" },
					})
					else Kit.title(o.title or "Titre", 34, {
						size = { 1, -120, 1, -6 },
						position = at(0.5, if o.icon then 20 else 0, 0.5, 0),
					}),
			})
		)
		if o.icon then
			table.insert(
				children,
				node("Icon", "TitleIcon", {
					size = { 0, 64, 0, 64 },
					position = at(0, 44, 0, 34),
					icon = { id = o.icon },
					zIndex = 4,
				})
			)
		end
	else
		local textX = if o.icon then 76 else 22
		table.insert(
			children,
			Kit.title(o.title or "Titre", 34, {
				anchor = { 0, 0.5 },
				position = at(0, textX, 0, 34),
				size = { 0.55, 0, 0, 44 },
				text = { alignX = "Left" },
			})
		)
		if o.icon then
			table.insert(
				children,
				node("Icon", "TitleIcon", {
					size = { 0, 62, 0, 62 },
					position = at(0, 40, 0, 28),
					icon = { id = o.icon },
					zIndex = 3,
				})
			)
		end
	end

	local closeStyle = o.close or "Square"
	if closeStyle ~= "None" then
		local close = Kit.closeButton(closeStyle, if style == "Bar" then 44 else 46)
		if style ~= "Bar" then
			close.props.position = at(1, 12, 0, -12)
			close.props.zIndex = 4
		end
		table.insert(children, close)
	end

	if o.tabs and #o.tabs > 0 then
		local tabButtons = {}
		for i, label in o.tabs do
			table.insert(
				tabButtons,
				Kit.button({
					name = label .. "Tab",
					text = label,
					color = TAB_COLORS[(i - 1) % #TAB_COLORS + 1],
					size = { 0, 104, 0, 40 },
					textSize = 20,
				})
			)
		end
		local right = if closeStyle ~= "None" and style == "Bar" then -64 else -14
		table.insert(
			children,
			node("List", "Tabs", {
				anchor = { 1, 0 },
				position = at(1, right, 0, if style == "Bar" then 12 else 14),
				size = { 0, #o.tabs * 112, 0, 44 },
				layout = { kind = "Horizontal", spacing = 8, padding = 0, align = "End" },
				zIndex = 3,
			}, tabButtons)
		)
	end

	return node("Window", o.name or "Window", { size = { 0, w, 0, h } }, children)
end

-- Section bar: a coloured strip with a title, used to split a window into parts.
function Kit.sectionBar(title: string, color: string?): Template
	return node("Panel", title:gsub("%W", "") .. "Bar", {
		size = { 1, 0, 0, 40 },
		fill = { kind = "Shade", color = color or "$header" },
		pattern = { kind = "None" },
		corner = "$radiusSmall",
	}, {
		Kit.title(title, 26, {
			anchor = { 0, 0.5 },
			position = at(0, 14, 0.5, 0),
			size = { 1, -28, 1, -4 },
			text = { alignX = "Left" },
		}),
	})
end

-- Cards ----------------------------------------------------------------------

export type CardOptions = {
	name: string?,
	style: string?, -- "Tall" | "Wide" | "Slot"
	title: string?,
	subtitle: string?,
	icon: string?,
	color: string?,
	textColor: string?,
	price: string?,
	currency: string?,
	priceColor: string?,
	badge: string?,
	pattern: string?,
}

function Kit.card(o: CardOptions): Template
	local style = o.style or "Tall"
	local children = {}
	local textColor = o.textColor or "$cardText"
	local cardProps: { [string]: any } = { fill = { color = o.color or "$card" } }
	if o.pattern then
		cardProps.pattern = { kind = o.pattern }
	end

	local function slot(props: { [string]: any })
		props.fill = { kind = "Color", color = "$slot", transparency = 0.15 }
		props.stroke = { enabled = false }
		props.pattern = { kind = "None" }
		props.shadow = { kind = "None" }
		return node("Panel", "Slot", props, {
			node("Icon", "ItemIcon", {
				size = { 0.78, 0, 0.78, 0 },
				icon = { id = o.icon or "Gift" },
			}),
		})
	end

	if style == "Wide" then
		table.insert(
			children,
			slot({
				anchor = { 0, 0.5 },
				position = at(0, 10, 0.5, 0),
				size = { 1, 0, 1, -20 },
				aspect = 1,
			})
		)
		table.insert(
			children,
			Kit.text("ItemName", o.title or "Objet", 22, {
				anchor = { 0, 0 },
				position = at(0, 100, 0, 10),
				size = { 1, -110, 0, 26 },
				text = { alignX = "Left", color = textColor },
			})
		)
		if o.subtitle then
			table.insert(
				children,
				Kit.text("Description", o.subtitle, 16, {
					anchor = { 0, 0 },
					position = at(0, 100, 0, 38),
					size = { 1, -230, 0, 20 },
					text = { alignX = "Left", color = textColor },
				})
			)
		end
		if o.price then
			table.insert(
				children,
				Kit.priceButton(o.price, o.currency, o.priceColor, {
					anchor = { 1, 1 },
					position = at(1, -10, 1, -12),
					size = { 0, 118, 0, 38 },
				})
			)
		end
	elseif style == "Slot" then
		-- Inventory slot: just the item, a small badge and a count.
		table.insert(
			children,
			node("Icon", "ItemIcon", {
				size = { 0.72, 0, 0.72, 0 },
				icon = { id = o.icon or "Egg" },
			})
		)
		if o.subtitle then
			table.insert(
				children,
				Kit.text("Amount", o.subtitle, 18, {
					anchor = { 1, 1 },
					position = at(1, -6, 1, -4),
					size = { 0.6, 0, 0, 22 },
					text = { alignX = "Right", color = textColor },
				})
			)
		end
	else
		-- Tall card: the picture on top, then the name, the description and the price,
		-- all placed from the bottom so short cards stay tidy.
		local bottom = if o.price then 54 else 10
		local textRoom = 24 + (if o.subtitle then 18 else 0)
		table.insert(
			children,
			slot({
				anchor = { 0.5, 0 },
				position = at(0.5, 0, 0, 10),
				size = { 1, -20, 1, -(10 + bottom + textRoom + 8) },
			})
		)
		if o.subtitle then
			table.insert(
				children,
				Kit.text("Description", o.subtitle, 15, {
					anchor = { 0.5, 1 },
					position = at(0.5, 0, 1, -bottom),
					size = { 1, -12, 0, 18 },
					text = { color = textColor },
				})
			)
		end
		table.insert(
			children,
			Kit.text("ItemName", o.title or "Objet", 20, {
				anchor = { 0.5, 1 },
				position = at(0.5, 0, 1, -(bottom + (if o.subtitle then 18 else 0))),
				size = { 1, -12, 0, 24 },
				text = { color = textColor },
			})
		)
		if o.price then
			table.insert(
				children,
				Kit.priceButton(o.price, o.currency, o.priceColor, {
					anchor = { 0.5, 1 },
					position = at(0.5, 0, 1, -12),
					size = { 1, -22, 0, 36 },
				})
			)
		end
	end

	if o.badge then
		table.insert(
			children,
			Kit.button({
				name = "Badge",
				text = o.badge,
				color = "$danger",
				size = { 0, 74, 0, 26 },
				position = at(0, -6, 0, -8),
				anchor = { 0, 0 },
				textSize = 15,
			})
		)
		children[#children].props.zIndex = 3
		children[#children].props.shadow = { kind = "None" }
		children[#children].props.rotation = -8
	end

	return node("Card", o.name or "Card", cardProps, children)
end

-- A grid of cards filling its parent.
function Kit.grid(
	name: string,
	columns: number,
	cellHeight: number,
	cards: { Template },
	props: { [string]: any }?
): Template
	local p = props or {
		size = { 1, -28, 1, -28 },
	}
	p.layout = { kind = "Grid", columns = columns, cellHeight = cellHeight, spacing = 12, padding = 6 }
	return node("Grid", name, p, cards)
end

function Kit.scroll(
	name: string,
	columns: number,
	cellHeight: number,
	cards: { Template },
	props: { [string]: any }?
): Template
	local p = props or { size = { 1, -16, 1, -16 } }
	p.layout = { kind = "Grid", columns = columns, cellHeight = cellHeight, spacing = 12, padding = 6 }
	return node("ScrollArea", name, p, cards)
end

-- HUD ------------------------------------------------------------------------

-- A pill showing a currency amount, with its icon overlapping the left end.
function Kit.currencyBar(name: string, icon: string, amount: string, props: { [string]: any }?): Template
	local p = props or {}
	p.size = p.size or { 0, 220, 0, 46 }
	p.fill = { kind = "Color", color = "$slot", transparency = 0.1 }
	p.corner = -1
	p.pattern = { kind = "None" }
	return node("Panel", name, p, {
		node("Icon", "CurrencyIcon", {
			size = { 0, 58, 0, 58 },
			position = at(0, 8, 0.5, 0),
			icon = { id = icon },
		}),
		Kit.text("Amount", amount, 26, {
			anchor = { 0, 0.5 },
			position = at(0, 44, 0.5, 0),
			size = { 1, -90, 1, 0 },
			text = { alignX = "Left" },
		}),
		Kit.button({
			name = "AddButton",
			icon = "Plus",
			color = "$success",
			size = { 0, 38, 0, 38 },
			position = at(1, -4, 0.5, 0),
			anchor = { 1, 0.5 },
			corner = -1,
		}),
	})
end

-- A square menu button with a big icon and a label across its bottom edge.
function Kit.hudButton(name: string, icon: string, label: string, color: string?): Template
	local b = Kit.button({ name = name, icon = icon, color = color or "$primary", size = { 0, 86, 0, 86 } })
	b.props.icon.id = icon
	table.insert(
		b.children,
		Kit.text("Label", label, 20, {
			anchor = { 0.5, 1 },
			position = at(0.5, 0, 1, 8),
			size = { 1, 16, 0, 26 },
			text = { font = "$fontTitle", stroke = { thickness = 3 } },
			zIndex = 3,
		})
	)
	return b
end

-- A text box with a button next to it (codes, search).
function Kit.inputRow(placeholder: string, buttonText: string): Template
	return node("Panel", "CodeRow", {
		size = { 1, -40, 0, 64 },
		fill = { kind = "None" },
		stroke = { enabled = false },
		pattern = { kind = "None" },
	}, {
		node("Input", "CodeInput", {
			anchor = { 0, 0.5 },
			position = at(0, 0, 0.5, 0),
			size = { 1, -170, 1, -8 },
			text = { value = "", placeholder = placeholder },
		}),
		Kit.button({
			name = "RedeemButton",
			text = buttonText,
			color = "$success",
			size = { 0, 156, 1, -8 },
			position = at(1, 0, 0.5, 0),
			anchor = { 1, 0.5 },
		}),
	})
end

-- A row with a label and an on/off switch (settings).
function Kit.toggleRow(label: string, on: boolean): Template
	return node("Card", label:gsub("%W", "") .. "Row", {
		size = { 1, 0, 0, 58 },
		shadow = { kind = "None" },
	}, {
		Kit.text("Label", label, 22, {
			anchor = { 0, 0.5 },
			position = at(0, 16, 0.5, 0),
			size = { 1, -150, 1, 0 },
			text = { alignX = "Left", color = "$cardText" },
		}),
		Kit.button({
			name = "Toggle",
			text = if on then "ON" else "OFF",
			color = if on then "$success" else "$danger",
			size = { 0, 96, 0, 40 },
			position = at(1, -12, 0.5, 0),
			anchor = { 1, 0.5 },
			textSize = 20,
		}),
	})
end

-- A progress bar with a label (quests, rebirth).
function Kit.progressBar(name: string, ratio: number, label: string, color: string?): Template
	return node("Panel", name, {
		size = { 1, -20, 0, 34 },
		fill = { kind = "Color", color = "$slot" },
		pattern = { kind = "None" },
		corner = -1,
	}, {
		node("Panel", "Fill", {
			anchor = { 0, 0.5 },
			position = at(0, 0, 0.5, 0),
			size = { ratio, 0, 1, 0 },
			fill = { kind = "Shade", color = color or "$success" },
			stroke = { enabled = false },
			pattern = { kind = "None" },
			corner = -1,
		}),
		Kit.text("Label", label, 20, { size = { 1, 0, 1, 0 }, zIndex = 3 }),
	})
end

return Kit
