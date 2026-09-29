-- MeshBuilder : géométrie pure Lua (liste de sommets + triangles).
-- Indépendant de Roblox Instance : on construit ici, puis EditableMeshFactory
-- convertit en EditableMesh. Convention : triangles CCW vus de l'extérieur.

local MeshBuilder = {}
MeshBuilder.__index = MeshBuilder

function MeshBuilder.new()
	return setmetatable({ verts = {}, tris = {} }, MeshBuilder)
end

function MeshBuilder:addVertex(p: Vector3): number
	local v = self.verts
	v[#v + 1] = p
	return #v
end

function MeshBuilder:addTri(a: number, b: number, c: number)
	if a == b or b == c or a == c then
		return
	end
	local t = self.tris
	t[#t + 1] = { a, b, c }
end

function MeshBuilder:addQuad(a: number, b: number, c: number, d: number)
	self:addTri(a, b, c)
	self:addTri(a, c, d)
end

function MeshBuilder:triCount(): number
	return #self.tris
end

-- Ajoute `other` (optionnellement transformé par `cf`).
function MeshBuilder:merge(other, cf: CFrame?)
	local offset = #self.verts
	for _, p in other.verts do
		self.verts[#self.verts + 1] = if cf then cf:PointToWorldSpace(p) else p
	end
	for _, t in other.tris do
		self.tris[#self.tris + 1] = { t[1] + offset, t[2] + offset, t[3] + offset }
	end
	return self
end

function MeshBuilder:transform(cf: CFrame)
	for i, p in self.verts do
		self.verts[i] = cf:PointToWorldSpace(p)
	end
	return self
end

function MeshBuilder:scale(s: Vector3)
	for i, p in self.verts do
		self.verts[i] = p * s
	end
	if s.X * s.Y * s.Z < 0 then
		self:flip()
	end
	return self
end

function MeshBuilder:flip()
	for _, t in self.tris do
		t[2], t[3] = t[3], t[2]
	end
	return self
end

-- Miroir X (garde les faces orientées vers l'extérieur).
function MeshBuilder:mirrorX()
	for i, p in self.verts do
		self.verts[i] = Vector3.new(-p.X, p.Y, p.Z)
	end
	return self:flip()
end

function MeshBuilder:bounds()
	local minV = Vector3.new(math.huge, math.huge, math.huge)
	local maxV = -minV
	for _, p in self.verts do
		minV = minV:Min(p)
		maxV = maxV:Max(p)
	end
	return minV, maxV
end

-- Volume signé : > 0 si les faces pointent vers l'extérieur.
function MeshBuilder:signedVolume(): number
	local v = self.verts
	local minV, maxV = self:bounds()
	local c = (minV + maxV) * 0.5
	local vol = 0
	for _, t in self.tris do
		local a, b, d = v[t[1]] - c, v[t[2]] - c, v[t[3]] - c
		vol += a:Dot(b:Cross(d))
	end
	return vol / 6
end

-- Corrige l'orientation globale d'un solide fermé.
function MeshBuilder:fixWinding()
	if self:signedVolume() < 0 then
		self:flip()
	end
	return self
end

-- Recentre sur le centre de la boîte englobante. Retourne (centre, taille).
function MeshBuilder:recenter()
	local minV, maxV = self:bounds()
	local center = (minV + maxV) * 0.5
	for i, p in self.verts do
		self.verts[i] = p - center
	end
	return center, maxV - minV
end

-- Irrégularité low-poly déterministe (garde le mesh fermé : sommets partagés).
function MeshBuilder:jitter(rng, amount: number)
	if amount <= 0 then
		return self
	end
	for i, p in self.verts do
		self.verts[i] = p
			+ Vector3.new(
				rng:NextNumber(-amount, amount),
				rng:NextNumber(-amount, amount),
				rng:NextNumber(-amount, amount)
			)
	end
	return self
end

return MeshBuilder
