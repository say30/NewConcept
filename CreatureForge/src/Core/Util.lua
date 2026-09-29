-- Utilitaires partagés (maths, sérialisation, sélection, historique).

local Config = require(script.Parent.Parent.Config)

local Util = {}

----------------------------------------------------------------------
-- Maths
----------------------------------------------------------------------

function Util.clamp(x, a, b)
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

function Util.round(x, step)
	step = step or 1
	return math.floor(x / step + 0.5) * step
end

-- CFrame dont l'axe Y part de `from` vers `to`.
function Util.cframeAlongY(from: Vector3, to: Vector3, hint: Vector3?)
	local dir = to - from
	if dir.Magnitude < 1e-6 then
		return CFrame.new(from)
	end
	local up = dir.Unit
	local h = hint or Vector3.new(1, 0, 0)
	if math.abs(up:Dot(h.Unit)) > 0.98 then
		h = Vector3.new(0, 0, 1)
	end
	local right = (h - up * h:Dot(up)).Unit
	return CFrame.fromMatrix(from, right, up)
end

-- Miroir d'un CFrame par rapport au plan X = 0 (reste une rotation propre).
-- À combiner avec un mesh lui-même miroir en X.
function Util.mirrorCFrameX(cf: CFrame)
	local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
	return CFrame.new(-x, y, z, r00, -r01, -r02, -r10, r11, r12, -r20, r21, r22)
end

----------------------------------------------------------------------
-- Sérialisation déterministe (sert de clé de cache pour les meshes)
----------------------------------------------------------------------

local function serialize(v, out)
	local t = typeof(v)
	if t == "number" then
		out[#out + 1] = string.format("%.3f", v)
	elseif t == "string" then
		out[#out + 1] = string.format("%q", v)
	elseif t == "boolean" then
		out[#out + 1] = v and "T" or "F"
	elseif t == "table" then
		local keys = {}
		for k in v do
			keys[#keys + 1] = k
		end
		table.sort(keys, function(a, b)
			return tostring(a) < tostring(b)
		end)
		out[#out + 1] = "{"
		for _, k in keys do
			out[#out + 1] = tostring(k)
			out[#out + 1] = "="
			serialize(v[k], out)
			out[#out + 1] = ","
		end
		out[#out + 1] = "}"
	elseif t == "Vector3" then
		out[#out + 1] = string.format("V(%.3f,%.3f,%.3f)", v.X, v.Y, v.Z)
	else
		out[#out + 1] = tostring(v)
	end
end

function Util.serialize(v)
	local out = {}
	serialize(v, out)
	return table.concat(out)
end

-- Hash court et stable (djb2 / sdbm) pour nommer les assets et indexer le cache.
function Util.shortHash(s: string)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + string.byte(s, i)) % 4294967296
	end
	return string.format("%08x", h)
end

function Util.hash64(s: string)
	local h2 = 0
	for i = 1, #s do
		h2 = (string.byte(s, i) + h2 * 65599) % 4294967296
	end
	return Util.shortHash(s) .. string.format("%08x", h2)
end

-- Horloge murale (secondes, précision milliseconde).
function Util.now()
	return DateTime.now().UnixTimestampMillis / 1000
end

function Util.jsonEncode(v)
	return game:GetService("HttpService"):JSONEncode(v)
end

function Util.jsonDecode(s)
	local ok, v = pcall(function()
		return game:GetService("HttpService"):JSONDecode(s)
	end)
	return ok and v or nil
end

----------------------------------------------------------------------
-- Noms
----------------------------------------------------------------------

-- "FrontLeftLeg_02" -> { "front", "left", "leg" }
function Util.tokenize(name: string)
	local spaced = name:gsub("(%l)(%u)", "%1 %2"):gsub("(%u)(%u%l)", "%1 %2")
	local tokens = {}
	for word in spaced:lower():gmatch("%a+") do
		tokens[#tokens + 1] = word
	end
	return tokens
end

----------------------------------------------------------------------
-- Instances
----------------------------------------------------------------------

function Util.getOutputFolder(create: boolean?)
	local folder = workspace:FindFirstChild(Config.OUTPUT_FOLDER)
	if not folder and create then
		folder = Instance.new("Folder")
		folder.Name = Config.OUTPUT_FOLDER
		folder.Parent = workspace
	end
	return folder
end

function Util.isInOutput(inst: Instance)
	local folder = Util.getOutputFolder(false)
	return folder ~= nil and inst:IsDescendantOf(folder)
end

-- Un Model « collection » ne contient que des sous-Models (ex. CreatureReferences).
local function isCollection(model: Instance)
	local subModels = 0
	for _, child in model:GetChildren() do
		if child:IsA("BasePart") then
			return false
		elseif child:IsA("Model") then
			subModels += 1
		end
	end
	return subModels >= 2
end

-- Résout la créature visée par la sélection :
--   * un Model sélectionné directement est pris tel quel ;
--   * une pièce remonte jusqu'au Model créature (sans dépasser une collection).
function Util.resolveCreature(inst: Instance?)
	if not inst then
		return nil
	end
	if inst:IsA("Model") then
		return inst
	end
	local current = inst:FindFirstAncestorWhichIsA("Model")
	if not current then
		return nil
	end
	while current.Parent and current.Parent:IsA("Model") and current.Parent ~= workspace do
		if isCollection(current.Parent) then
			break
		end
		current = current.Parent
	end
	return current
end

-- Chemin stable d'une instance relativement à `root` ("Body/Head#2").
function Util.pathOf(inst: Instance, root: Instance)
	local parts = {}
	local cur = inst
	while cur and cur ~= root do
		local name = cur.Name
		local parent = cur.Parent
		if parent then
			local index, count = 0, 0
			for _, sibling in parent:GetChildren() do
				if sibling.Name == name then
					count += 1
					if sibling == cur then
						index = count
					end
				end
			end
			if count > 1 then
				name = name .. "#" .. index
			end
		end
		table.insert(parts, 1, name)
		cur = parent
	end
	return table.concat(parts, "/")
end

function Util.isGenerated(model: Instance?)
	return model ~= nil and model:IsA("Model") and model:GetAttribute(Config.ATTR .. "Generated") == true
end

function Util.isBlueprint(model: Instance?)
	return model ~= nil and model:IsA("Model") and model:GetAttribute(Config.ATTR .. "Blueprint") == true
end

----------------------------------------------------------------------
-- Historique (Undo) : chaque opération = un enregistrement annulable.
----------------------------------------------------------------------

function Util.record(displayName: string, fn)
	local ChangeHistoryService = game:GetService("ChangeHistoryService")
	local id = nil
	local okBegin = pcall(function()
		id = ChangeHistoryService:TryBeginRecording("CreatureForge_" .. displayName:gsub("%W", ""), displayName)
	end)
	if not okBegin or not id then
		-- Repli (ancienne API) : un simple waypoint avant l'opération.
		pcall(function()
			ChangeHistoryService:SetWaypoint("CreatureForge: avant " .. displayName)
		end)
	end
	local results = table.pack(xpcall(fn, debug.traceback))
	if id then
		pcall(function()
			ChangeHistoryService:FinishRecording(
				id,
				results[1] and Enum.FinishRecordingOperation.Commit or Enum.FinishRecordingOperation.Cancel
			)
		end)
	elseif results[1] then
		pcall(function()
			ChangeHistoryService:SetWaypoint("CreatureForge: " .. displayName)
		end)
	end
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- Message d'erreur lisible (sans la trace complète).
function Util.shortError(err)
	local s = tostring(err)
	local firstLine = s:match("^[^\n]+") or s
	return (firstLine:gsub("^.-:%d+: ", ""))
end

return Util
