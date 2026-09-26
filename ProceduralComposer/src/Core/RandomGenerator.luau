--[[
	RandomGenerator
	Générateur pseudo-aléatoire 100 % déterministe (SplitMix32), indépendant de
	math.random et de l'implémentation de Random côté moteur.

	Même seed => même suite de nombres, sur toutes les machines et versions.
	`fork(name)` dérive un sous-flux stable : modifier les réglages du sol ne
	change pas le résultat des murs, ce qui rend l'itération beaucoup plus
	agréable.

	Contient aussi un bruit de valeur 2D (value noise) déterministe, utilisé
	pour créer des zones "respirantes" cohérentes plutôt que du bruit blanc.
]]

local Utilities = require(script.Parent.Utilities)

local TWO_32 = 4294967296
local GOLDEN = 0x9E3779B9

local RandomGenerator = {}
RandomGenerator.__index = RandomGenerator

-- Multiplication 32 bits exacte (équivalent de Math.imul) en double précision.
local function imul(a, b)
	local aLo = bit32.band(a, 0xFFFF)
	local aHi = bit32.rshift(a, 16)
	local bLo = bit32.band(b, 0xFFFF)
	local bHi = bit32.rshift(b, 16)
	local lo = aLo * bLo
	local mid = (aHi * bLo + aLo * bHi) % 65536
	return (lo + mid * 65536) % TWO_32
end
RandomGenerator.imul = imul

local function mix32(z)
	z = imul(bit32.bxor(z, bit32.rshift(z, 16)), 0x85EBCA6B)
	z = imul(bit32.bxor(z, bit32.rshift(z, 13)), 0xC2B2AE35)
	return bit32.bxor(z, bit32.rshift(z, 16))
end
RandomGenerator.mix32 = mix32

local function normalizeSeed(seed)
	if type(seed) == "string" then
		return Utilities.hashString(seed)
	end
	seed = tonumber(seed) or 0
	seed = math.floor(math.abs(seed)) % TWO_32
	return seed
end
RandomGenerator.normalizeSeed = normalizeSeed

function RandomGenerator.new(seed)
	local self = setmetatable({}, RandomGenerator)
	self.Seed = normalizeSeed(seed)
	self._state = mix32((self.Seed + GOLDEN) % TWO_32)
	return self
end

function RandomGenerator:nextUInt32()
	self._state = (self._state + GOLDEN) % TWO_32
	return mix32(self._state)
end

-- Réel uniforme dans [0, 1).
function RandomGenerator:next()
	return self:nextUInt32() / TWO_32
end

function RandomGenerator:range(a, b)
	return a + (b - a) * self:next()
end

-- Entier uniforme dans [a, b].
function RandomGenerator:int(a, b)
	if b < a then
		a, b = b, a
	end
	return a + math.floor(self:next() * (b - a + 1))
end

function RandomGenerator:chance(p)
	return self:next() < p
end

function RandomGenerator:sign()
	return if self:next() < 0.5 then -1 else 1
end

function RandomGenerator:pick(list)
	if #list == 0 then
		return nil
	end
	return list[self:int(1, #list)]
end

-- Tirage pondéré : renvoie l'index choisi (ou nil si tous les poids sont nuls).
function RandomGenerator:weightedIndex(weights)
	local total = 0
	for _, w in ipairs(weights) do
		if w > 0 then
			total += w
		end
	end
	if total <= 0 then
		return nil
	end
	local r = self:next() * total
	local acc = 0
	local lastPositive = nil
	for i, w in ipairs(weights) do
		if w > 0 then
			acc += w
			lastPositive = i
			if r < acc then
				return i
			end
		end
	end
	return lastPositive
end

function RandomGenerator:shuffle(list)
	for i = #list, 2, -1 do
		local j = self:int(1, i)
		list[i], list[j] = list[j], list[i]
	end
	return list
end

-- Loi approximativement normale (somme de 3 uniformes), centrée, écart-type ~ 1.
function RandomGenerator:gaussian()
	return (self:next() + self:next() + self:next() - 1.5) * 2
end

-- Sous-flux déterministe nommé.
function RandomGenerator:fork(name)
	local h = Utilities.hashString(tostring(name))
	return RandomGenerator.new(bit32.bxor(self.Seed, mix32((h + 0x632BE5AB) % TWO_32)))
end

-- Nouvelle seed aléatoire (non déterministe) pour le bouton "Random Seed".
function RandomGenerator.randomSeed()
	local r = Random.new()
	return r:NextInteger(1, 2147483646)
end

-- Bruit de valeur 2D ----------------------------------------------------------

local function latticeValue(seed, ix, iy)
	local x = ix % TWO_32
	local y = iy % TWO_32
	local h = mix32(bit32.bxor(seed, imul(x, 0x27D4EB2D)))
	h = mix32(bit32.bxor(h, imul(y, 0x165667B1)))
	return h / TWO_32
end

-- Renvoie une valeur lisse dans [0, 1].
function RandomGenerator.noise2D(seed, x, y)
	local x0 = math.floor(x)
	local y0 = math.floor(y)
	local fx = x - x0
	local fy = y - y0
	local sx = fx * fx * (3 - 2 * fx)
	local sy = fy * fy * (3 - 2 * fy)
	local v00 = latticeValue(seed, x0, y0)
	local v10 = latticeValue(seed, x0 + 1, y0)
	local v01 = latticeValue(seed, x0, y0 + 1)
	local v11 = latticeValue(seed, x0 + 1, y0 + 1)
	local a = v00 + (v10 - v00) * sx
	local b = v01 + (v11 - v01) * sx
	return a + (b - a) * sy
end

-- Bruit fractal à 2 octaves, plus naturel.
function RandomGenerator.fractalNoise2D(seed, x, y)
	local n1 = RandomGenerator.noise2D(seed, x, y)
	local n2 = RandomGenerator.noise2D((seed + 1013904223) % TWO_32, x * 2.03, y * 2.03)
	return (n1 * 2 + n2) / 3
end

return RandomGenerator
