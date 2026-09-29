-- EditableMeshFactory : MeshBuilder -> EditableMesh -> MeshPart.
-- Ombrage « flat » (une normale par face = look low-poly) et UV planaires
-- en studs (pour que les MaterialVariants comme Studs s'affichent correctement).

local AssetService = game:GetService("AssetService")

local Config = require(script.Parent.Parent.Config)

local EditableMeshFactory = {}

local function planarUV(p: Vector3, n: Vector3, scale: number)
	local ax, ay, az = math.abs(n.X), math.abs(n.Y), math.abs(n.Z)
	if ax >= ay and ax >= az then
		return Vector2.new(p.Z * scale, -p.Y * scale)
	elseif ay >= az then
		return Vector2.new(p.X * scale, p.Z * scale)
	end
	return Vector2.new(p.X * scale, -p.Y * scale)
end

function EditableMeshFactory.toEditableMesh(builder)
	local em = AssetService:CreateEditableMesh()
	if not em then
		error("Budget mémoire EditableMesh atteint (fermez d'autres créations puis réessayez)")
	end
	local verts = builder.verts
	local ids = table.create(#verts)
	for i, p in verts do
		ids[i] = em:AddVertex(p)
	end
	local uvScale = 1 / Config.UV_STUDS_PER_TILE
	for _, t in builder.tris do
		local a, b, c = verts[t[1]], verts[t[2]], verts[t[3]]
		local n = (b - a):Cross(c - a)
		if n.Magnitude > 1e-9 then
			n = n.Unit
			local fid = em:AddTriangle(ids[t[1]], ids[t[2]], ids[t[3]])
			local nid = em:AddNormal(n)
			em:SetFaceNormals(fid, { nid, nid, nid })
			em:SetFaceUVs(fid, {
				em:AddUV(planarUV(a, n, uvScale)),
				em:AddUV(planarUV(b, n, uvScale)),
				em:AddUV(planarUV(c, n, uvScale)),
			})
		end
	end
	pcall(function()
		em:RemoveUnused()
	end)
	return em
end

function EditableMeshFactory.createMeshPart(em, size: Vector3)
	local part = AssetService:CreateMeshPartAsync(Content.fromObject(em), {
		CollisionFidelity = Config.MESH.CollisionFidelity,
		RenderFidelity = Config.MESH.RenderFidelity,
	})
	part.Size = Vector3.new(math.max(size.X, 0.05), math.max(size.Y, 0.05), math.max(size.Z, 0.05))
	return part
end

-- Remplace le mesh d'une MeshPart existante (conserve taille, couleur, CFrame...).
function EditableMeshFactory.applyContent(part: MeshPart, content)
	local size = part.Size
	local temp = AssetService:CreateMeshPartAsync(content, {
		CollisionFidelity = Config.MESH.CollisionFidelity,
		RenderFidelity = Config.MESH.RenderFidelity,
	})
	part:ApplyMesh(temp)
	temp:Destroy()
	part.Size = size
end

-- Vrai si la MeshPart n'affiche plus rien (EditableMesh perdu après redémarrage de Studio).
function EditableMeshFactory.isMeshMissing(part: MeshPart)
	if part.MeshId ~= "" then
		return false
	end
	local ok, missing = pcall(function()
		local content = part.MeshContent
		if content.SourceType == Enum.ContentSourceType.Object then
			return content.Object == nil
		elseif content.SourceType == Enum.ContentSourceType.Uri then
			return (content.Uri or "") == ""
		end
		return true
	end)
	return if ok then missing else true
end

return EditableMeshFactory
