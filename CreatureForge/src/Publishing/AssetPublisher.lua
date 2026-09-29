-- AssetPublisher : publie UNIQUEMENT les EditableMesh générés par le plugin
-- (AssetService:CreateAssetAsync, plugin local -> compte Studio connecté),
-- puis applique les nouveaux IDs aux MeshParts correspondantes.
--
-- Garde-fous : seules les pièces d'une créature générée (CF_Generated) et
-- portant une CF_ShapeSpec sont éligibles ; le mesh uploadé est toujours
-- reconstruit depuis ShapeLibrary. Aucun MeshId existant n'est jamais lu ni copié.

local AssetService = game:GetService("AssetService")

local Root = script.Parent.Parent
local Config = require(Root.Config)
local Util = require(Root.Core.Util)
local MeshRegistry = require(Root.Geometry.MeshRegistry)
local EditableMeshFactory = require(Root.Geometry.EditableMeshFactory)

local AssetPublisher = {}
local A = Config.ATTR
local C = Config.PUBLISH

local pluginRef = nil
local cache = nil -- hash64(clé de forme) -> assetId

function AssetPublisher.init(plugin)
	pluginRef = plugin
	local ok, stored = pcall(function()
		return plugin:GetSetting(C.CacheSetting)
	end)
	cache = if ok and type(stored) == "table" then stored else {}
end

local function saveCache()
	if not pluginRef then
		return
	end
	local count = 0
	for _ in cache do
		count += 1
	end
	if count > C.CacheMax then
		cache = {}
	end
	pcall(function()
		pluginRef:SetSetting(C.CacheSetting, cache)
	end)
end

-- "ratelimit" | "permission" | "timeout" | "failed"
function AssetPublisher.classify(err: string)
	local e = tostring(err):lower()
	if e:find("429") or e:find("too many") or e:find("rate") or e:find("throttl") or e:find("limit") then
		return "ratelimit"
	elseif e:find("403") or e:find("401") or e:find("permission") or e:find("denied") or e:find("forbidden")
		or e:find("not authorized") or e:find("unauthorized") or e:find("verif") then
		return "permission"
	elseif e:find("timeout") or e:find("timed out") then
		return "timeout"
	end
	return "failed"
end

local function withTimeout(fn, timeout: number)
	local done, result = false, nil
	task.spawn(function()
		result = table.pack(pcall(fn))
		done = true
	end)
	local t0 = Util.now()
	while not done do
		if Util.now() - t0 > timeout then
			return false, "timeout"
		end
		task.wait(0.1)
	end
	return table.unpack(result, 1, result.n)
end

-- Un upload, avec backoff sur 429 / timeout / échec transitoire.
function AssetPublisher.upload(editableMesh, name: string)
	local lastErr, lastKind = "?", "failed"
	for attempt = 1, C.MaxRetries + 1 do
		local ok, res, idOrErr = withTimeout(function()
			return AssetService:CreateAssetAsync(editableMesh, Enum.AssetType.Mesh, {
				Name = name,
				Description = "Mesh original généré par Creature Forge (géométrie procédurale).",
			})
		end, C.Timeout)
		if ok and res == Enum.CreateAssetResult.Success and tonumber(idOrErr) then
			return tonumber(idOrErr)
		end
		if ok then
			lastErr = tostring(res) .. " " .. tostring(idOrErr)
			lastKind = if res == Enum.CreateAssetResult.PermissionDenied
				then "permission"
				else AssetPublisher.classify(lastErr)
		else
			lastErr = tostring(res)
			lastKind = AssetPublisher.classify(lastErr)
		end
		if lastKind == "permission" or attempt > C.MaxRetries then
			break
		end
		task.wait(C.Backoff[attempt] or 16)
	end
	return nil, lastErr, lastKind
end

-- Applique un asset à des MeshParts (l'asset peut mettre un moment à être prêt).
function AssetPublisher.apply(parts, assetId: number)
	local lastErr = nil
	for attempt = 1, C.ApplyRetries do
		local ok, err = pcall(function()
			local temp = AssetService:CreateMeshPartAsync(Content.fromAssetId(assetId), {
				CollisionFidelity = Config.MESH.CollisionFidelity,
				RenderFidelity = Config.MESH.RenderFidelity,
			})
			for _, part in parts do
				local size = part.Size
				part:ApplyMesh(temp)
				part.Size = size
				part:SetAttribute(A .. "MeshAssetId", assetId)
			end
			temp:Destroy()
		end)
		if ok then
			return true
		end
		lastErr = err
		task.wait(C.ApplyDelay * attempt)
	end
	return false, lastErr
end

local function isPublished(part: MeshPart)
	local id = part:GetAttribute(A .. "MeshAssetId")
	return id ~= nil and part.MeshId:find(tostring(id), 1, true) ~= nil
end

-- Regroupe les pièces à publier par clé de forme.
function AssetPublisher.collect(model: Model)
	local groups, order = {}, {}
	local alreadyKeys = {}
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and d:GetAttribute(A .. "ShapeSpec") and d:GetAttribute(A .. "MeshKey") then
			local key = d:GetAttribute(A .. "MeshKey")
			if isPublished(d) then
				alreadyKeys[key] = true
			else
				if not groups[key] then
					groups[key] = { key = key, parts = {} }
					table.insert(order, groups[key])
				end
				table.insert(groups[key].parts, d)
			end
		end
	end
	local already = 0
	for key in alreadyKeys do
		if not groups[key] then
			already += 1
		end
	end
	return order, already
end

-- Publie toutes les géométries d'une créature générée.
-- onProgress(done, total, message). Retourne { total, done, failed = {...}, kinds = {...} }.
function AssetPublisher.publish(model: Model, onProgress)
	assert(model:GetAttribute(A .. "Generated") == true, "Seules les créatures générées par Creature Forge peuvent être publiées")
	if not cache then
		cache = {}
	end
	local groups, already = AssetPublisher.collect(model)
	local total = #groups + already
	local results = { total = total, done = already, failed = {}, kinds = {} }
	if onProgress then
		onProgress(results.done, total, "Préparation…")
	end

	for _, group in groups do
		local first = group.parts[1]
		local hashKey = Util.hash64(group.key)
		local assetId = first:GetAttribute(A .. "MeshAssetId") or cache[hashKey]
		local err, kind = nil, nil

		if assetId then
			-- Déjà uploadé (session précédente ou même forme ailleurs) : on applique seulement.
			local applied = AssetPublisher.apply(group.parts, assetId)
			if not applied then
				cache[hashKey] = nil
				for _, p in group.parts do
					p:SetAttribute(A .. "MeshAssetId", nil)
				end
				assetId = nil
			else
				results.done += 1
			end
		end

		if not assetId then
			local entry = MeshRegistry.ensureForPart(first)
			if not entry then
				err, kind = "Spécification de forme introuvable", "failed"
			else
				local name = string.sub(string.format("CF_%s_%s", model.Name, first.Name), 1, 50)
				assetId, err, kind = AssetPublisher.upload(entry.editableMesh, name)
				if assetId then
					cache[hashKey] = assetId
					saveCache()
					for _, p in group.parts do
						p:SetAttribute(A .. "MeshAssetId", assetId)
					end
					local applied, applyErr = AssetPublisher.apply(group.parts, assetId)
					if applied then
						results.done += 1
					else
						err, kind = "Asset publié (" .. assetId .. ") mais pas encore disponible : " .. tostring(applyErr), "timeout"
					end
				end
			end
		end

		if err then
			table.insert(results.failed, { key = group.key, part = first.Name, error = err, kind = kind })
			results.kinds[kind] = (results.kinds[kind] or 0) + 1
			if kind == "permission" then
				-- Inutile d'insister : même cause pour toutes les pièces.
				if onProgress then
					onProgress(results.done, total, "Permission refusée")
				end
				break
			end
		end
		if onProgress then
			onProgress(results.done, total, first.Name)
		end
		task.wait(C.DelayBetween)
	end

	model:SetAttribute(A .. "Published", results.done == total and #results.failed == 0)
	return results
end

-- Redonne un mesh (EditableMesh) aux pièces non publiées dont le mesh a disparu.
function AssetPublisher.restoreMissing(model: Model)
	local restored = 0
	for _, d in model:GetDescendants() do
		if d:IsA("MeshPart") and d:GetAttribute(A .. "ShapeSpec") and EditableMeshFactory.isMeshMissing(d) then
			local ok = pcall(MeshRegistry.restorePart, d)
			if ok then
				restored += 1
			end
		end
	end
	return restored
end

function AssetPublisher.describeFailure(results)
	local k = results.kinds
	if k.permission then
		return "Permission refusée : vérifiez que vous êtes connecté à Studio et autorisé à publier des assets (compte vérifié si requis)."
	elseif k.ratelimit then
		return "Trop de requêtes (429) : patientez une minute puis cliquez RÉESSAYER."
	elseif k.timeout then
		return "Délai dépassé : Roblox traite encore certains assets, cliquez RÉESSAYER."
	end
	local first = results.failed[1]
	return "Échec de l'upload" .. (if first then " : " .. Util.shortError(first.error) else "")
end

return AssetPublisher
