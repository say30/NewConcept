--[[
	Utilities
	Fonctions génériques sans dépendance au moteur : tables, nombres, attributs,
	parcours d'instances, yield coopératif.
]]

local Config = require(script.Parent.Config)

local Utilities = {}

-- Tables ---------------------------------------------------------------------

function Utilities.shallowCopy(t)
	local out = {}
	for k, v in pairs(t) do
		out[k] = v
	end
	return out
end

function Utilities.deepCopy(t)
	if type(t) ~= "table" then
		return t
	end
	local out = {}
	for k, v in pairs(t) do
		out[k] = Utilities.deepCopy(v)
	end
	return out
end

function Utilities.sortedKeys(t)
	local keys = {}
	for k in pairs(t) do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	return keys
end

function Utilities.count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

function Utilities.contains(list, value)
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

function Utilities.appendAll(target, source)
	for _, v in ipairs(source) do
		table.insert(target, v)
	end
	return target
end

-- Nombres --------------------------------------------------------------------

function Utilities.clamp(x, a, b)
	if a > b then
		a, b = b, a
	end
	if x < a then
		return a
	elseif x > b then
		return b
	end
	return x
end

function Utilities.lerp(a, b, t)
	return a + (b - a) * t
end

function Utilities.inverseLerp(a, b, x)
	if math.abs(b - a) < Config.Precision.NUMERIC_EPSILON then
		return 0
	end
	return (x - a) / (b - a)
end

function Utilities.round(x, step)
	step = step or 1
	return math.floor(x / step + 0.5) * step
end

function Utilities.smoothstep(t)
	t = Utilities.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function Utilities.isFiniteNumber(x)
	return type(x) == "number" and x == x and x ~= math.huge and x ~= -math.huge
end

function Utilities.padNumber(n, digits)
	return string.format("%0" .. tostring(digits) .. "d", n)
end

function Utilities.formatStuds(x)
	return string.format("%.2f", x)
end

function Utilities.formatVector(v)
	return string.format("%.1f × %.1f × %.1f", v.X, v.Y, v.Z)
end

-- Attributs -------------------------------------------------------------------

-- Lit un attribut typé ; renvoie `default` si absent ou de mauvais type.
function Utilities.getAttribute(instance, name, expectedType, default)
	local ok, value = pcall(instance.GetAttribute, instance, name)
	if not ok or value == nil then
		return default
	end
	if expectedType and typeof(value) ~= expectedType then
		-- Tolérance : nombres sous forme de chaîne, booléens "true"/"false".
		if expectedType == "number" and type(value) == "string" then
			local n = tonumber(value)
			if n then
				return n
			end
		elseif expectedType == "boolean" and type(value) == "string" then
			local lower = string.lower(value)
			if lower == "true" or lower == "1" or lower == "yes" then
				return true
			elseif lower == "false" or lower == "0" or lower == "no" then
				return false
			end
		elseif expectedType == "string" and type(value) == "number" then
			return tostring(value)
		end
		return default
	end
	return value
end

-- Lit un attribut sur l'instance puis sur ses ancêtres jusqu'à `stopAt` inclus.
-- Permet de poser une métadonnée sur un dossier et qu'elle s'applique à son contenu.
function Utilities.getInheritedAttribute(instance, name, expectedType, stopAt)
	local current = instance
	while current do
		local value = Utilities.getAttribute(current, name, expectedType, nil)
		if value ~= nil then
			return value
		end
		if current == stopAt then
			break
		end
		current = current.Parent
	end
	return nil
end

function Utilities.setAttributeSafe(instance, name, value)
	pcall(instance.SetAttribute, instance, name, value)
end

-- Instances ---------------------------------------------------------------------

function Utilities.isAlive(instance)
	if typeof(instance) ~= "Instance" then
		return false
	end
	local ok, parent = pcall(function()
		return instance.Parent
	end)
	return ok and parent ~= nil
end

function Utilities.fullName(instance)
	local ok, name = pcall(instance.GetFullName, instance)
	if ok then
		return name
	end
	return tostring(instance)
end

-- Collecte les BaseParts de l'instance (elle-même incluse), dans l'ordre stable du parcours.
function Utilities.collectBaseParts(instance, limit)
	local parts = {}
	if instance:IsA("BasePart") then
		table.insert(parts, instance)
	end
	for _, d in ipairs(instance:GetDescendants()) do
		if d:IsA("BasePart") then
			table.insert(parts, d)
			if limit and #parts >= limit then
				break
			end
		end
	end
	return parts
end

function Utilities.isDescendantOfAny(instance, roots)
	for _, root in ipairs(roots) do
		if instance == root or instance:IsDescendantOf(root) then
			return true
		end
	end
	return false
end

-- Hachage ------------------------------------------------------------------------

-- FNV-1a 32 bits : hachage déterministe d'une chaîne.
function Utilities.hashString(str)
	local hash = 2166136261
	for i = 1, #str do
		hash = bit32.bxor(hash, string.byte(str, i))
		-- hash * 16777619 mod 2^32, décomposé pour rester exact en double précision.
		local lo = bit32.band(hash, 0xFFFF)
		local hi = bit32.rshift(hash, 16)
		hash = (lo * 16777619 + ((hi * 16777619) % 65536) * 65536) % 4294967296
	end
	return hash
end

-- Yield coopératif ----------------------------------------------------------------

-- Crée une fonction qui rend la main à Studio quand le budget de temps est dépassé.
function Utilities.createYielder(budget, onYield)
	budget = budget or Config.Performance.YIELD_BUDGET
	local last = os.clock()
	return function(force)
		local now = os.clock()
		if force or now - last >= budget then
			if onYield then
				onYield()
			end
			task.wait()
			last = os.clock()
		end
	end
end

return Utilities
