--[[
	Presets
	Un preset ne fait que modifier les paramètres du moteur. Il ne contient
	aucune règle propre à un jeu, un biome ou une bibliothèque d'assets.
]]

local Presets = {}

Presets.Order = {
	"Balanced", "EdgesOnly", "Sparse", "Dense", "WallDecor", "Architectural",
	"Nature", "Industrial", "CleanCorridor", "Chaotic",
}

-- Paramètres remis à leur valeur par défaut avant d'appliquer un preset.
Presets.ResetKeys = {
	"Density", "SpacingScale", "ClusterStrength", "EmptySpaceRatio",
	"LargeAssetFrequency", "MediumAssetFrequency", "SmallAssetFrequency",
	"Symmetry", "Randomness", "Variation", "VisualRhythm",
	"RotationMode", "ScaleMode", "MinScale", "MaxScale",
	"WallTreatment", "WallMode", "WallDensity", "PillarSpacing",
	"TopDecoration", "BaseDecoration", "CornerDecoration",
	"FloorAlgorithm", "KeepCenterClear", "CenterClearStart", "CenterClearEnd",
	"EdgeDepth", "PathWidth", "CeilingDensity", "MinimumSpacing", "CenterClearAxis",
}

Presets.Values = {
	Balanced = {},

	-- Décor uniquement sur les côtés : le centre de la zone reste toujours vide.
	EdgesOnly = {
		KeepCenterClear = true,
		CenterClearStart = 0.2,
		CenterClearEnd = 0.8,
		CenterClearAxis = "Auto",
		FloorAlgorithm = "EdgeDecoration",
		EdgeDepth = 10,
		EmptySpaceRatio = 0.3,
		ClusterStrength = 0.7,
	},

	Sparse = {
		Density = 0.25,
		EmptySpaceRatio = 0.6,
		ClusterStrength = 0.7,
		LargeAssetFrequency = 0.35,
		SmallAssetFrequency = 0.4,
		SpacingScale = 1.6,
		WallDensity = 0.3,
		CeilingDensity = 0.2,
	},

	Dense = {
		Density = 0.85,
		EmptySpaceRatio = 0.15,
		ClusterStrength = 0.55,
		SmallAssetFrequency = 0.9,
		MediumAssetFrequency = 0.75,
		SpacingScale = 0.7,
		WallDensity = 0.75,
		CeilingDensity = 0.6,
		MinimumSpacing = 0.25,
	},

	WallDecor = {
		WallTreatment = "Keep",
		WallMode = "Hybrid",
		WallDensity = 0.7,
		Density = 0.3,
		FloorAlgorithm = "EdgeDecoration",
		EdgeDepth = 6,
	},

	Architectural = {
		WallTreatment = "Rebuild",
		WallMode = "Architectural",
		WallDensity = 0.6,
		Symmetry = 0.8,
		Randomness = 0.2,
		VisualRhythm = 0.7,
		RotationMode = "AlignToWall",
		FloorAlgorithm = "EdgeDecoration",
		Density = 0.35,
		TopDecoration = true,
		BaseDecoration = true,
		CornerDecoration = true,
	},

	Nature = {
		Density = 0.55,
		ClusterStrength = 0.8,
		EmptySpaceRatio = 0.35,
		Randomness = 0.7,
		Variation = 0.8,
		RotationMode = "Random360",
		ScaleMode = "RandomRange",
		MinScale = 0.85,
		MaxScale = 1.2,
		FloorAlgorithm = "Hybrid",
		Symmetry = 0,
	},

	Industrial = {
		Density = 0.5,
		ClusterStrength = 0.45,
		Randomness = 0.25,
		Variation = 0.45,
		RotationMode = "Random90",
		FloorAlgorithm = "EdgeDecoration",
		WallTreatment = "Cover",
		WallMode = "Modular",
		VisualRhythm = 0.65,
		Symmetry = 0.3,
		CeilingDensity = 0.55,
	},

	CleanCorridor = {
		Density = 0.35,
		KeepCenterClear = true,
		CenterClearStart = 0.25,
		CenterClearEnd = 0.75,
		FloorAlgorithm = "EdgeDecoration",
		Symmetry = 0.75,
		Randomness = 0.2,
		VisualRhythm = 0.8,
		RotationMode = "AlignToWall",
		EmptySpaceRatio = 0.4,
	},

	Chaotic = {
		Density = 0.8,
		ClusterStrength = 0.2,
		EmptySpaceRatio = 0.1,
		Randomness = 1,
		Variation = 1,
		RotationMode = "Random360",
		ScaleMode = "RandomRange",
		MinScale = 0.7,
		MaxScale = 1.35,
		FloorAlgorithm = "Scatter",
		VisualRhythm = 0.1,
	},
}

return Presets
