-- MeshRegistry : cache des meshes générés, indexés par « clé de forme »
-- (forme + paramètres + miroir). Deux pièces identiques (patte gauche/droite)
-- partagent le même EditableMesh -> un seul asset à publier.
--
-- Chaque MeshPart générée porte l'attribut CF_ShapeSpec (JSON) : on peut donc
-- toujours reconstruire son mesh (ex. après un redémarrage de Studio).

local Geometry = script.Parent
local Config = require(Geometry.Parent.Config)
local Util = require(Geometry.Parent.Core.Util)
local ShapeLibrary = require(Geometry.ShapeLibrary)
local EditableMeshFactory = require(Geometry.EditableMeshFactory)

local MeshRegistry = {}
local entries = {}

function MeshRegistry.key(shape: string, params, mirror: boolean?)
	return shape .. "|" .. Util.serialize(params) .. (if mirror then "|M" else "")
end

-- Géométrie seule (sans EditableMesh) : { builder, center, size, tris }.
function MeshRegistry.geometry(shape: string, params, mirror: boolean?)
	local key = MeshRegistry.key(shape, params, mirror)
	local e = entries[key]
	if e then
		return e, key
	end
	local builder = ShapeLibrary.build(shape, params)
	if mirror then
		builder:mirrorX()
	end
	local center, size = builder:recenter()
	e = {
		key = key,
		shape = shape,
		params = params,
		mirror = mirror or false,
		builder = builder,
		center = center,
		size = size,
		tris = builder:triCount(),
	}
	entries[key] = e
	return e, key
end

-- Garantit l'existence de l'EditableMesh associé.
function MeshRegistry.ensureMesh(shape: string, params, mirror: boolean?)
	local e = MeshRegistry.geometry(shape, params, mirror)
	if not e.editableMesh then
		e.editableMesh = EditableMeshFactory.toEditableMesh(e.builder)
	end
	return e
end

function MeshRegistry.get(key: string)
	return entries[key]
end

function MeshRegistry.specJson(shape: string, params, mirror: boolean?)
	return Util.jsonEncode({ shape = shape, params = params, mirror = mirror or false })
end

-- Reconstruit l'entrée d'une pièce à partir de son attribut CF_ShapeSpec.
function MeshRegistry.ensureForPart(part: BasePart)
	local json = part:GetAttribute(Config.ATTR .. "ShapeSpec")
	if not json then
		return nil
	end
	local spec = Util.jsonDecode(json)
	if not spec or not spec.shape then
		return nil
	end
	return MeshRegistry.ensureMesh(spec.shape, spec.params, spec.mirror)
end

-- Réaffiche le mesh d'une pièce dont l'EditableMesh a été perdu.
function MeshRegistry.restorePart(part: MeshPart)
	local e = MeshRegistry.ensureForPart(part)
	if not e then
		return false
	end
	EditableMeshFactory.applyContent(part, Content.fromObject(e.editableMesh))
	return true
end

return MeshRegistry
