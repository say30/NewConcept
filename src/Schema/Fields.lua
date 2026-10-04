--!strict
-- Every editable property, grouped into the inspector sections. The inspector draws these
-- definitions; it has no per-component code. Labels are what the user reads, so they avoid
-- Roblox jargon (UICorner, UIStroke, ZIndex...).

export type Option = { value: any, label: string }
export type Field = {
	path: { string },
	label: string,
	kind: "text" | "multiline" | "number" | "slider" | "color" | "toggle" | "choice" | "udim2" | "asset",
	min: number?,
	max: number?,
	step: number?,
	options: { Option }?,
	-- Theme tokens this field can link to (for numbers and fonts).
	tokens: { string }?,
	showIf: ((props: any) -> boolean)?,
}
export type Section = { id: string, label: string, fields: { Field } }

local FONTS = {
	"FredokaOne",
	"LuckiestGuy",
	"Bangers",
	"GothamBlack",
	"GothamBold",
	"Gotham",
	"SourceSansBold",
	"SourceSans",
	"Arcade",
	"Cartoon",
	"SciFi",
	"Fantasy",
	"DenkOne",
	"Oswald",
	"PermanentMarker",
	"Creepster",
}

local fontOptions: { Option } = {}
for _, font in FONTS do
	table.insert(fontOptions, { value = font, label = font })
end

local function is(path: { string }, expected: any)
	return function(props: any): boolean
		local value = props
		for _, key in path do
			value = type(value) == "table" and value[key] or nil
		end
		if type(expected) == "table" then
			return table.find(expected, value) ~= nil
		end
		return value == expected
	end
end

local Fields = {}

Fields.FONTS = FONTS

Fields.sections = {
	Text = {
		id = "Text",
		label = "Texte",
		fields = {
			{ path = { "text", "value" }, label = "Texte", kind = "multiline" },
			{
				path = { "text", "font" },
				label = "Police",
				kind = "choice",
				options = fontOptions,
				tokens = { "font", "fontBody" },
			},
			{ path = { "text", "size" }, label = "Taille", kind = "number", min = 6, max = 100, step = 1 },
			{ path = { "text", "scaled" }, label = "Taille automatique", kind = "toggle" },
			{ path = { "text", "color" }, label = "Couleur", kind = "color" },
			{
				path = { "text", "alignX" },
				label = "Alignement",
				kind = "choice",
				options = {
					{ value = "Left", label = "Gauche" },
					{ value = "Center", label = "Centre" },
					{ value = "Right", label = "Droite" },
				},
			},
			{ path = { "text", "wrap" }, label = "Retour à la ligne", kind = "toggle" },
			{
				path = { "text", "transparency" },
				label = "Transparence",
				kind = "slider",
				min = 0,
				max = 1,
				step = 0.05,
			},
			{ path = { "text", "strokeEnabled" }, label = "Contour du texte", kind = "toggle" },
			{
				path = { "text", "strokeColor" },
				label = "Couleur du contour",
				kind = "color",
				showIf = is({ "text", "strokeEnabled" }, true),
			},
		},
	},
	Image = {
		id = "Image",
		label = "Image",
		fields = {
			{ path = { "image", "id" }, label = "Image (ID Roblox)", kind = "asset" },
			{ path = { "image", "color" }, label = "Teinte", kind = "color" },
			{
				path = { "image", "transparency" },
				label = "Transparence",
				kind = "slider",
				min = 0,
				max = 1,
				step = 0.05,
			},
			{
				path = { "image", "scaleType" },
				label = "Ajustement",
				kind = "choice",
				options = {
					{ value = "Fit", label = "Contenir" },
					{ value = "Stretch", label = "Étirer" },
					{ value = "Crop", label = "Remplir" },
					{ value = "Tile", label = "Répéter" },
				},
			},
		},
	},
	Fill = {
		id = "Fill",
		label = "Fond",
		fields = {
			{
				path = { "fill", "kind" },
				label = "Type de fond",
				kind = "choice",
				options = {
					{ value = "Color", label = "Couleur" },
					{ value = "Gradient", label = "Dégradé" },
					{ value = "Image", label = "Image" },
					{ value = "None", label = "Transparent" },
				},
			},
			{
				path = { "fill", "color" },
				label = "Couleur",
				kind = "color",
				showIf = is({ "fill", "kind" }, { "Color", "Gradient", nil }),
			},
			{
				path = { "fill", "color2" },
				label = "Couleur 2",
				kind = "color",
				showIf = is({ "fill", "kind" }, "Gradient"),
			},
			{
				path = { "fill", "rotation" },
				label = "Angle du dégradé",
				kind = "number",
				min = -180,
				max = 180,
				step = 15,
				showIf = is({ "fill", "kind" }, "Gradient"),
			},
			{
				path = { "fill", "image" },
				label = "Image de fond (ID)",
				kind = "asset",
				showIf = is({ "fill", "kind" }, "Image"),
			},
			{
				path = { "fill", "scaleType" },
				label = "Ajustement",
				kind = "choice",
				options = {
					{ value = "Stretch", label = "Étirer" },
					{ value = "Crop", label = "Remplir" },
					{ value = "Fit", label = "Contenir" },
					{ value = "Tile", label = "Répéter" },
				},
				showIf = is({ "fill", "kind" }, "Image"),
			},
			{
				path = { "fill", "tileSize" },
				label = "Taille du motif",
				kind = "number",
				min = 4,
				max = 512,
				step = 4,
				showIf = is({ "fill", "scaleType" }, "Tile"),
			},
			{
				path = { "fill", "tint" },
				label = "Teinte de l'image",
				kind = "color",
				showIf = is({ "fill", "kind" }, "Image"),
			},
			{
				path = { "fill", "transparency" },
				label = "Transparence",
				kind = "slider",
				min = 0,
				max = 1,
				step = 0.05,
			},
		},
	},
	Stroke = {
		id = "Stroke",
		label = "Contour",
		fields = {
			{ path = { "stroke", "enabled" }, label = "Afficher le contour", kind = "toggle" },
			{
				path = { "stroke", "color" },
				label = "Couleur",
				kind = "color",
				showIf = is({ "stroke", "enabled" }, true),
			},
			{
				path = { "stroke", "thickness" },
				label = "Épaisseur",
				kind = "number",
				min = 0,
				max = 20,
				step = 1,
				tokens = { "strokeThickness" },
				showIf = is({ "stroke", "enabled" }, true),
			},
			{
				path = { "stroke", "transparency" },
				label = "Transparence",
				kind = "slider",
				min = 0,
				max = 1,
				step = 0.05,
				showIf = is({ "stroke", "enabled" }, true),
			},
		},
	},
	Corner = {
		id = "Corner",
		label = "Coins",
		fields = {
			{
				path = { "corner" },
				label = "Arrondi",
				kind = "number",
				min = 0,
				max = 200,
				step = 2,
				tokens = { "radius", "radiusSmall" },
			},
		},
	},
	Layout = {
		id = "Layout",
		label = "Disposition des enfants",
		fields = {
			{
				path = { "layout", "kind" },
				label = "Disposition",
				kind = "choice",
				options = {
					{ value = "None", label = "Libre" },
					{ value = "Horizontal", label = "Horizontale" },
					{ value = "Vertical", label = "Verticale" },
					{ value = "Grid", label = "Grille" },
				},
			},
			{
				path = { "layout", "spacing" },
				label = "Espacement",
				kind = "number",
				min = 0,
				max = 100,
				step = 2,
				showIf = is({ "layout", "kind" }, { "Horizontal", "Vertical", "Grid" }),
			},
			{
				path = { "layout", "padding" },
				label = "Marge intérieure",
				kind = "number",
				min = 0,
				max = 100,
				step = 2,
				showIf = is({ "layout", "kind" }, { "Horizontal", "Vertical", "Grid" }),
			},
			{
				path = { "layout", "align" },
				label = "Alignement",
				kind = "choice",
				options = {
					{ value = "Start", label = "Début" },
					{ value = "Center", label = "Centre" },
					{ value = "End", label = "Fin" },
				},
				showIf = is({ "layout", "kind" }, { "Horizontal", "Vertical", "Grid" }),
			},
			{
				path = { "layout", "cellWidth" },
				label = "Largeur des cases",
				kind = "number",
				min = 10,
				max = 600,
				step = 5,
				showIf = is({ "layout", "kind" }, "Grid"),
			},
			{
				path = { "layout", "cellHeight" },
				label = "Hauteur des cases",
				kind = "number",
				min = 10,
				max = 600,
				step = 5,
				showIf = is({ "layout", "kind" }, "Grid"),
			},
		},
	},
	Transform = {
		id = "Transform",
		label = "Position et taille",
		fields = {
			{ path = { "position" }, label = "Position", kind = "udim2" },
			{ path = { "size" }, label = "Taille", kind = "udim2" },
			{
				path = { "anchor" },
				label = "Point d'ancrage",
				kind = "choice",
				options = {
					{ value = { 0, 0 }, label = "Haut gauche" },
					{ value = { 0.5, 0 }, label = "Haut" },
					{ value = { 0.5, 0.5 }, label = "Centre" },
					{ value = { 0.5, 1 }, label = "Bas" },
					{ value = { 1, 1 }, label = "Bas droite" },
				},
			},
			{ path = { "rotation" }, label = "Rotation", kind = "number", min = -180, max = 180, step = 5 },
			{
				path = { "aspect" },
				label = "Garder le ratio (0 = non)",
				kind = "number",
				min = 0,
				max = 10,
				step = 0.1,
			},
		},
	},
	Display = {
		id = "Display",
		label = "Affichage",
		fields = {
			{ path = { "visible" }, label = "Visible en jeu", kind = "toggle" },
			{
				path = { "zIndex" },
				label = "Ordre d'affichage",
				kind = "number",
				min = 0,
				max = 50,
				step = 1,
			},
			{ path = { "clip" }, label = "Couper ce qui dépasse", kind = "toggle" },
		},
	},
}

return Fields
