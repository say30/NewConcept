-- ExplodedView : écarte les composants d'un blueprint autour du centre.
-- L'orientation de chaque pièce est conservée (seule la position change).

local Config = require(script.Parent.Parent.Config)

local ExplodedView = {}
local A = Config.ATTR

-- Facteur d'écartement maximal (à 100 %).
ExplodedView.MAX_SPREAD = 1.6

-- t : 0..1
function ExplodedView.apply(blueprint: Model, t: number)
	local pivot = blueprint:GetPivot()
	local center = blueprint:GetAttribute(A .. "Center") or Vector3.zero
	local k = 1 + math.clamp(t, 0, 1) * ExplodedView.MAX_SPREAD
	for _, part in blueprint:GetChildren() do
		if part:IsA("BasePart") then
			local base = part:GetAttribute(A .. "BaseCF")
			if typeof(base) == "CFrame" then
				local offset = base.Position - center
				local pos = center + offset * k
				part.CFrame = pivot * (CFrame.new(pos) * base.Rotation)
			end
		end
	end
	blueprint:SetAttribute(A .. "Explode", t)
end

return ExplodedView
