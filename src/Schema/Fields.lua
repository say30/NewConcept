--!strict
-- Every setting of an element as a plain field (number, colour, choice...). The visual
-- inspector covers the common choices with pictures; these fields are the "Avancé" part,
-- for exact values. Labels avoid Roblox jargon (UICorner, UIStroke, ZIndex...).

export type Option = { value: any, label: string }
export type Field = {
	path: { string },
	label: string,
	kind: "text" | "multiline" | "number" | "color" | "toggle" | "choice" | "udim2" | "asset",
	min: number?,
	max: number?,
	step: number?,
	options: { Option }?,
	-- Pack values this field can link to (for numbers and fonts).
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
	"BuilderSansExtraBold",
	"BuilderSansBold",
	"Cartoon",
	"Arcade",
	"Michroma",
	"Oswald",
	"PermanentMarker",
	"DenkOne",
	"Creepster",
}

local function options(values: { any }, labels: { string }?): { Option }
	local out = {}
	for i, value in values do
		table.insert(out, { value = value, label = if labels then labels[i] else tostring(value) })
	end
	return out
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
				options = options(FONTS),
				tokens = { "font", "fontTitle" },
			},
			{ path = { "text", "size" }, label = "Taille", kind = "number", min = 6, max = 100, step = 1 },
			{ path = { "text", "scaled" }, label = "Taille automatique", kind = "toggle" },
			{ path = { "text", "color" }, label = "Couleur", kind = "color" },
			{
				path = { "text", "alignX" },
				label = "Alignement",
				kind = "choice",
				options = options({ "Left", "Center", "Right" }, { "Gauche", "Centre", "Droite" }),
			},
			{ path = { "text", "wrap" }, label = "Retour à la ligne", kind = "toggle" },
			{ path = { "text", "stroke", "enabled" }, label = "Contour du texte", kind = "toggle" },
			{ path = { "text", "stroke", "color" }, label = "Couleur du contour", kind = "color" },
			{
				path = { "text", "stroke", "thickness" },
				label = "Épaisseur du contour",
				kind = "number",
				min = 0,
				max = 8,
				step = 1,
			},
			{
				path = { "text", "transparency" },
				label = "Transparence",
				kind = "number",
				min = 0,
				max = 1,
				step = 0.05,
			},
		},
	},
	Input = {
		id = "Input",
		label = "Zone de saisie",
		fields = {
			{ path = { "text", "placeholder" }, label = "Texte d'aide", kind = "text" },
			{ path = { "text", "value" }, label = "Texte de départ", kind = "text" },
			{ path = { "text", "size" }, label = "Taille", kind = "number", min = 6, max = 60, step = 1 },
			{ path = { "text", "color" }, label = "Couleur du texte", kind = "color" },
			{ path = { "fill", "color" }, label = "Fond", kind = "color" },
			{
				path = { "corner" },
				label = "Arrondi",
				kind = "number",
				min = -1,
				max = 60,
				step = 1,
				tokens = { "radius", "radiusSmall" },
			},
		},
	},
	Icon = {
		id = "Icon",
		label = "Icône",
		fields = {
			{ path = { "icon", "image" }, label = "Ou une image à toi (ID Roblox)", kind = "asset" },
			{ path = { "icon", "color" }, label = "Teinte de l'image", kind = "color" },
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
				kind = "number",
				min = 0,
				max = 1,
				step = 0.05,
			},
			{
				path = { "image", "scaleType" },
				label = "Remplissage",
				kind = "choice",
				options = options(
					{ "Fit", "Stretch", "Crop", "Tile" },
					{ "Ajuster", "Étirer", "Rogner", "Répéter" }
				),
			},
			{ path = { "corner" }, label = "Arrondi", kind = "number", min = -1, max = 200, step = 1 },
		},
	},
	Fill = {
		id = "Fill",
		label = "Fond",
		fields = {
			{
				path = { "fill", "kind" },
				label = "Type",
				kind = "choice",
				options = options(
					{ "Color", "Shade", "Gradient", "Image", "None" },
					{ "Uni", "Ombré", "Dégradé", "Image", "Transparent" }
				),
			},
			{
				path = { "fill", "color" },
				label = "Couleur",
				kind = "color",
				showIf = is({ "fill", "kind" }, { "Color", "Shade", "Gradient" }),
			},
			{
				path = { "fill", "shade" },
				label = "Force de l'ombré",
				kind = "number",
				min = 0,
				max = 0.8,
				step = 0.05,
				showIf = is({ "fill", "kind" }, "Shade"),
			},
			{
				path = { "fill", "color2" },
				label = "Deuxième couleur",
				kind = "color",
				showIf = is({ "fill", "kind" }, "Gradient"),
			},
			{
				path = { "fill", "rotation" },
				label = "Direction",
				kind = "number",
				min = -180,
				max = 180,
				step = 15,
				showIf = is({ "fill", "kind" }, "Gradient"),
			},
			{
				path = { "fill", "image" },
				label = "Image (ID Roblox)",
				kind = "asset",
				showIf = is({ "fill", "kind" }, "Image"),
			},
			{
				path = { "fill", "scaleType" },
				label = "Remplissage",
				kind = "choice",
				options = options(
					{ "Stretch", "Tile", "Crop", "Fit" },
					{ "Étirer", "Répéter", "Rogner", "Ajuster" }
				),
				showIf = is({ "fill", "kind" }, "Image"),
			},
			{
				path = { "fill", "tileSize" },
				label = "Taille du motif",
				kind = "number",
				min = 8,
				max = 512,
				step = 8,
				showIf = is({ "fill", "kind" }, "Image"),
			},
			{
				path = { "fill", "transparency" },
				label = "Transparence",
				kind = "number",
				min = 0,
				max = 1,
				step = 0.05,
			},
		},
	},
	Pattern = {
		id = "Pattern",
		label = "Motif",
		fields = {
			{ path = { "pattern", "color" }, label = "Couleur du motif", kind = "color" },
			{
				path = { "pattern", "transparency" },
				label = "Discrétion",
				kind = "number",
				min = 0,
				max = 1,
				step = 0.05,
			},
			{
				path = { "pattern", "size" },
				label = "Taille",
				kind = "number",
				min = 8,
				max = 80,
				step = 2,
				tokens = { "patternSize" },
			},
		},
	},
	Stroke = {
		id = "Stroke",
		label = "Contour",
		fields = {
			{ path = { "stroke", "enabled" }, label = "Afficher le contour", kind = "toggle" },
			{ path = { "stroke", "color" }, label = "Couleur", kind = "color" },
			{
				path = { "stroke", "thickness" },
				label = "Épaisseur",
				kind = "number",
				min = 0,
				max = 20,
				step = 1,
				tokens = { "outlineThickness" },
			},
		},
	},
	Corner = {
		id = "Corner",
		label = "Coins",
		fields = {
			{
				path = { "corner" },
				label = "Arrondi (-1 = pilule)",
				kind = "number",
				min = -1,
				max = 200,
				step = 1,
				tokens = { "radius", "radiusSmall" },
			},
		},
	},
	Shadow = {
		id = "Shadow",
		label = "Ombre",
		fields = {
			{
				path = { "shadow", "size" },
				label = "Décalage",
				kind = "number",
				min = 0,
				max = 30,
				step = 1,
				tokens = { "depth" },
			},
			{
				path = { "shadow", "transparency" },
				label = "Transparence",
				kind = "number",
				min = 0,
				max = 1,
				step = 0.05,
			},
		},
	},
	Layout = {
		id = "Layout",
		label = "Rangement",
		fields = {
			{
				path = { "layout", "kind" },
				label = "Rangement des éléments",
				kind = "choice",
				options = options(
					{ "Grid", "Vertical", "Horizontal", "None" },
					{ "Grille", "Colonne", "Ligne", "Libre" }
				),
			},
			{
				path = { "layout", "columns" },
				label = "Colonnes",
				kind = "number",
				min = 1,
				max = 12,
				step = 1,
				showIf = is({ "layout", "kind" }, "Grid"),
			},
			{
				path = { "layout", "cellHeight" },
				label = "Hauteur des cases",
				kind = "number",
				min = 20,
				max = 600,
				step = 5,
				showIf = is({ "layout", "kind" }, "Grid"),
			},
			{
				path = { "layout", "spacing" },
				label = "Espace entre",
				kind = "number",
				min = 0,
				max = 100,
				step = 1,
			},
			{
				path = { "layout", "padding" },
				label = "Marge intérieure",
				kind = "number",
				min = 0,
				max = 100,
				step = 1,
			},
		},
	},
	Transform = {
		id = "Transform",
		label = "Position et taille",
		fields = {
			{ path = { "position" }, label = "Position", kind = "udim2" },
			{ path = { "size" }, label = "Taille", kind = "udim2" },
			{ path = { "rotation" }, label = "Rotation", kind = "number", min = -180, max = 180, step = 5 },
			{
				path = { "aspect" },
				label = "Garder les proportions (0 = non)",
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
				label = "Devant / derrière",
				kind = "number",
				min = 0,
				max = 50,
				step = 1,
			},
			{ path = { "clip" }, label = "Couper ce qui dépasse", kind = "toggle" },
		},
	},
} :: { [string]: Section }

-- Which advanced sections each kind of element shows.
Fields.byType = {
	Window = { "Fill", "Pattern", "Stroke", "Corner", "Shadow", "Transform", "Display" },
	Panel = { "Fill", "Pattern", "Stroke", "Corner", "Shadow", "Transform", "Display" },
	Card = { "Fill", "Pattern", "Stroke", "Corner", "Shadow", "Transform", "Display" },
	Button = { "Text", "Fill", "Pattern", "Stroke", "Corner", "Shadow", "Transform", "Display" },
	Text = { "Text", "Transform", "Display" },
	Input = { "Input", "Transform", "Display" },
	Icon = { "Icon", "Transform", "Display" },
	Image = { "Image", "Transform", "Display" },
	Grid = { "Layout", "Transform", "Display" },
	List = { "Layout", "Transform", "Display" },
	ScrollArea = { "Layout", "Transform", "Display" },
}

return Fields
