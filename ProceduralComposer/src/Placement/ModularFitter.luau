--[[
	ModularFitter
	Remplit exactement une longueur avec des modules, sans trou et sans
	chevauchement (murs modulaires, bordures, soubassements, corniches,
	rangées verticales...).

	Méthode :
	  1. Programmation dynamique (sac à dos non borné) sur les largeurs
	     quantifiées : pour chaque longueur atteignable, la combinaison de coût
	     minimal (moins de modules, poids élevés, bruit déterministe pour la
	     variété selon la seed).
	  2. Choix de la combinaison la plus proche de la longueur cible dans la
	     tolérance de déformation autorisée, puis mise à l'échelle uniforme très
	     légère pour tomber EXACTEMENT sur la longueur (ex. 211.507 studs avec
	     des modules de 14 : 15 modules à 1.0072).
	  3. Sinon : absorption du reste par les modules étirables, puis par des
	     espacements répartis (si autorisés), puis par un module de remplissage
	     (jamais une pièce ridicule de 0.2 stud), et en dernier recours une
	     petite marge centrée.
	  4. Ordonnancement : répartition régulière des types (A B A C A B A),
	     ou palindrome si la symétrie est demandée.

	Module = { Key, Width, Weight, Scalable, MinFactor, MaxFactor,
	           Stretchable, MinStretch, MaxStretch, IsFiller, Data }
]]

local Core = script.Parent.Parent.Core
local Config = require(Core.Config)

local ModularFitter = {}

local F = Config.Fitting

local function emptyResult(length, method)
	return { Items = {}, Covered = 0, Residual = length, Method = method or "empty", StartOffset = 0, Length = length }
end

local function moduleFactorRange(m, dev)
	local lo = 1 - dev
	local hi = 1 + dev
	if not m.Scalable then
		return 1, 1
	end
	if m.MinFactor then
		lo = math.max(lo, m.MinFactor)
	end
	if m.MaxFactor then
		hi = math.min(hi, m.MaxFactor)
	end
	if lo > hi then
		return 1, 1
	end
	return lo, hi
end

-- Ordonnancement régulier (smooth weighted round robin) avec départage déterministe.
local function interleave(counts, order, rng)
	local total = 0
	for _, c in pairs(counts) do
		total += c
	end
	local current = {}
	for _, k in ipairs(order) do
		current[k] = 0
	end
	local remaining = table.clone(counts)
	local seq = {}
	for _ = 1, total do
		local best, bestVal = nil, -math.huge
		for _, k in ipairs(order) do
			if remaining[k] > 0 then
				current[k] += counts[k]
				local jitter = if rng then rng:next() * 1e-3 else 0
				if current[k] + jitter > bestVal then
					best, bestVal = k, current[k] + jitter
				end
			end
		end
		if not best then
			break
		end
		current[best] -= total
		remaining[best] -= 1
		table.insert(seq, best)
	end
	return seq
end

local function arrange(counts, modules, symmetric, rng)
	local order = {}
	for i = 1, #modules do
		if (counts[i] or 0) > 0 then
			table.insert(order, i)
		end
	end
	table.sort(order, function(a, b)
		if counts[a] ~= counts[b] then
			return counts[a] > counts[b]
		end
		return a < b
	end)
	-- Les fillers vont au centre (symétrique) ou en fin de séquence.
	local fillerCounts, mainCounts = {}, {}
	local mainOrder = {}
	for _, i in ipairs(order) do
		if modules[i].IsFiller then
			fillerCounts[i] = counts[i]
		else
			mainCounts[i] = counts[i]
			table.insert(mainOrder, i)
		end
	end
	local fillers = {}
	for _, i in ipairs(order) do
		for _ = 1, (fillerCounts[i] or 0) do
			table.insert(fillers, i)
		end
	end
	if symmetric then
		local halfCounts = {}
		local middle = {}
		for _, i in ipairs(mainOrder) do
			halfCounts[i] = math.floor(mainCounts[i] / 2)
			if mainCounts[i] % 2 == 1 then
				table.insert(middle, i)
			end
		end
		local half = interleave(halfCounts, mainOrder, nil)
		local seq = table.clone(half)
		local center = {}
		for _, i in ipairs(middle) do
			table.insert(center, i)
		end
		for _, i in ipairs(fillers) do
			table.insert(center, math.ceil((#center + 1) / 2), i)
		end
		for _, i in ipairs(center) do
			table.insert(seq, i)
		end
		for k = #half, 1, -1 do
			table.insert(seq, half[k])
		end
		return seq
	end
	local seq = interleave(mainCounts, mainOrder, rng)
	for _, i in ipairs(fillers) do
		table.insert(seq, i)
	end
	return seq
end

local function buildItems(seq, modules, factors, stretches, gaps, startOffset)
	local items = {}
	local cursor = startOffset
	for k, i in ipairs(seq) do
		local m = modules[i]
		local w = m.Width * (factors[k] or 1) * (stretches[k] or 1)
		table.insert(items, {
			Module = m,
			Index = i,
			Start = cursor,
			Width = w,
			Factor = factors[k] or 1,
			Stretch = stretches[k] or 1,
		})
		cursor += w + (gaps[k] or 0)
	end
	return items, cursor
end

--[[
	options = {
	  MaxDeviation, AllowScale, AllowGaps, MaxGapFraction, EndsFlush,
	  Symmetric, Rng, Variety (0..1), AllowFillers
	}
]]
function ModularFitter.fit(length, modules, options)
	options = options or {}
	local valid = {}
	for _, m in ipairs(modules) do
		if m.Width and m.Width > 1e-3 then
			table.insert(valid, m)
		end
	end
	modules = valid
	if length <= F.LENGTH_TOLERANCE or #modules == 0 then
		return emptyResult(math.max(length, 0))
	end
	local dev = if options.AllowScale then (options.MaxDeviation or F.DEFAULT_MAX_SCALE_DEVIATION) else 0
	local rng = options.Rng
	local variety = options.Variety or 0.5

	-- Longueur plus petite que tous les modules : un seul module mis à l'échelle / étiré.
	local minWidth = math.huge
	for _, m in ipairs(modules) do
		minWidth = math.min(minWidth, m.Width)
	end
	if length < minWidth * (1 - dev) - F.LENGTH_TOLERANCE then
		local best, bestErr = nil, math.huge
		for i, m in ipairs(modules) do
			if m.Stretchable then
				local k = length / m.Width
				if k >= (m.MinStretch or F.MIN_STRETCH) and k <= (m.MaxStretch or F.MAX_STRETCH) then
					local err = math.abs(math.log(k))
					if err < bestErr then
						best, bestErr = { i, 1, k }, err
					end
				end
			end
		end
		if best then
			local items = buildItems({ best[1] }, modules, { best[2] }, { best[3] }, {}, 0)
			return { Items = items, Covered = length, Residual = 0, Method = "single-stretch", StartOffset = 0, Length = length }
		end
		return emptyResult(length, "too-short")
	end

	-- 1) Programmation dynamique.
	local q = math.max(F.QUANTUM, length / F.MAX_UNITS)
	local T = length / q
	local wq, cost = {}, {}
	local maxWq = 0
	local maxWeight = 0
	for _, m in ipairs(modules) do
		maxWeight = math.max(maxWeight, m.Weight or 1)
	end
	for i, m in ipairs(modules) do
		wq[i] = math.max(1, math.floor(m.Width / q + 0.5))
		maxWq = math.max(maxWq, wq[i])
		local wNorm = if maxWeight > 0 then (m.Weight or 1) / maxWeight else 1
		local noise = if rng then rng:next() * F.NOISE_COST * variety else 0
		cost[i] = F.MODULE_COST * (1 + (1 - wNorm)) + (if m.IsFiller then F.FILLER_COST else 0) + noise
	end
	local tMax = math.floor(T * (1 + dev)) + maxWq
	local best = table.create(tMax + 1, math.huge)
	local choice = table.create(tMax + 1, 0)
	best[1] = 0 -- index t+1 (t = 0)
	for t = 1, tMax do
		local bt, bc = math.huge, 0
		for i = 1, #modules do
			local prev = t - wq[i]
			if prev >= 0 then
				local c = best[prev + 1] + cost[i]
				if c < bt then
					bt, bc = c, i
				end
			end
		end
		best[t + 1] = bt
		choice[t + 1] = bc
	end

	local function reconstruct(t)
		local counts = {}
		local n = 0
		while t > 0 do
			local i = choice[t + 1]
			if i == 0 then
				return nil
			end
			counts[i] = (counts[i] or 0) + 1
			n += 1
			t -= wq[i]
		end
		return counts, n
	end

	local function realWidths(counts)
		local scalable, fixed = 0, 0
		for i, c in pairs(counts) do
			local lo, hi = moduleFactorRange(modules[i], dev)
			if hi - lo > 1e-9 then
				scalable += modules[i].Width * c
			else
				fixed += modules[i].Width * c
			end
		end
		return scalable, fixed
	end

	-- 2) Route "mise à l'échelle exacte".
	if dev > 0 then
		local bestT, bestScore, bestF = nil, math.huge, 1
		local tLo = math.max(1, math.floor(T / (1 + dev)))
		local tHi = math.min(tMax, math.ceil(T / math.max(1 - dev, 1e-3)))
		for t = tLo, tHi do
			if best[t + 1] < math.huge then
				local counts = reconstruct(t)
				if counts then
					local scalable, fixed = realWidths(counts)
					if scalable > 1e-6 then
						local f = (length - fixed) / scalable
						-- Tous les modules doivent accepter ce facteur.
						local okAll = f > 0
						for i in pairs(counts) do
							local lo, hi = moduleFactorRange(modules[i], dev)
							if hi - lo > 1e-9 and (f < lo - 1e-9 or f > hi + 1e-9) then
								okAll = false
								break
							end
						end
						if okAll then
							local score = F.DEFORMATION_COST * math.abs(math.log(f)) + best[t + 1] * 0.15
							if score < bestScore then
								bestT, bestScore, bestF = t, score, f
							end
						end
					elseif math.abs(fixed - length) <= F.LENGTH_TOLERANCE then
						local score = best[t + 1] * 0.15
						if score < bestScore then
							bestT, bestScore, bestF = t, score, 1
						end
					end
				end
			end
		end
		if bestT then
			local counts = reconstruct(bestT)
			local seq = arrange(counts, modules, options.Symmetric, rng)
			local factors = {}
			for k, i in ipairs(seq) do
				local lo, hi = moduleFactorRange(modules[i], dev)
				factors[k] = if hi - lo > 1e-9 then bestF else 1
			end
			local items, finish = buildItems(seq, modules, factors, {}, {}, 0)
			return {
				Items = items,
				Covered = finish,
				Residual = length - finish,
				Method = "exact-scale",
				StartOffset = 0,
				Length = length,
				Factor = bestF,
			}
		end
	end

	-- 3) Route "sous-remplissage" : plus grande combinaison <= longueur.
	local tBelow = nil
	for t = math.min(tMax, math.floor(T + 1e-9)), 1, -1 do
		if best[t + 1] < math.huge then
			local counts = reconstruct(t)
			if counts then
				local s = 0
				for i, c in pairs(counts) do
					s += modules[i].Width * c
				end
				if s <= length + F.LENGTH_TOLERANCE then
					tBelow = t
					break
				end
			end
		end
	end
	if not tBelow then
		return emptyResult(length, "no-combination")
	end
	local counts = reconstruct(tBelow)
	local seq = arrange(counts, modules, options.Symmetric, rng)
	local natural = 0
	for _, i in ipairs(seq) do
		natural += modules[i].Width
	end
	local residual = length - natural
	local factors, stretches, gaps = {}, {}, {}
	for k = 1, #seq do
		factors[k] = 1
		stretches[k] = 1
	end
	local method = "exact"

	-- 3a) Étirement des modules étirables.
	if residual > F.LENGTH_TOLERANCE then
		local capacity = 0
		for _, i in ipairs(seq) do
			local m = modules[i]
			if m.Stretchable then
				capacity += m.Width * ((m.MaxStretch or F.MAX_STRETCH) - 1)
			end
		end
		if capacity > 1e-6 then
			local ratio = math.min(1, residual / capacity)
			local used = 0
			for k, i in ipairs(seq) do
				local m = modules[i]
				if m.Stretchable then
					local extra = m.Width * ((m.MaxStretch or F.MAX_STRETCH) - 1) * ratio
					stretches[k] = 1 + extra / m.Width
					used += extra
				end
			end
			residual -= used
			method = "stretch"
		end
	end

	-- 3b) Module de remplissage (jamais plus petit que MIN_FILLER_WIDTH).
	if residual > F.END_MARGIN_TOLERANCE and residual >= F.MIN_FILLER_WIDTH and options.AllowFillers ~= false then
		local fillerIndex, fillerStretch, fillerFactor, fillerErr = nil, 1, 1, math.huge
		for i, m in ipairs(modules) do
			local lo, hi = moduleFactorRange(m, dev)
			local f = residual / m.Width
			local stretchOk = m.Stretchable and f >= (m.MinStretch or F.MIN_STRETCH) and f <= (m.MaxStretch or F.MAX_STRETCH)
			local scaleOk = f >= lo - 1e-9 and f <= hi + 1e-9
			if stretchOk or scaleOk then
				local err = math.abs(math.log(f)) + (if m.IsFiller then 0 else 0.25)
				if err < fillerErr then
					fillerIndex, fillerErr = i, err
					if scaleOk then
						fillerFactor, fillerStretch = f, 1
					else
						fillerFactor, fillerStretch = 1, f
					end
				end
			end
		end
		if fillerIndex then
			local pos = if options.Symmetric then math.ceil((#seq + 1) / 2) else #seq + 1
			table.insert(seq, pos, fillerIndex)
			table.insert(factors, pos, fillerFactor)
			table.insert(stretches, pos, fillerStretch)
			residual = 0
			method = "filler"
		end
	end

	-- 3c) Espacements répartis.
	local startOffset = 0
	if residual > F.LENGTH_TOLERANCE and options.AllowGaps then
		local slots = if options.EndsFlush then #seq - 1 else #seq + 1
		if slots >= 1 then
			local gap = residual / slots
			local avgWidth = natural / math.max(1, #seq)
			if gap <= avgWidth * (options.MaxGapFraction or F.MAX_GAP_FRACTION) then
				if options.EndsFlush then
					for k = 1, #seq - 1 do
						gaps[k] = gap
					end
				else
					startOffset = gap
					for k = 1, #seq do
						gaps[k] = gap
					end
					gaps[#seq] = 0
				end
				residual = if options.EndsFlush then 0 else gap
				method = "gaps"
			end
		end
	end

	-- 3d) Dernier recours : marge centrée.
	if residual > F.LENGTH_TOLERANCE and method ~= "gaps" then
		startOffset = residual * 0.5
		method = if residual <= F.END_MARGIN_TOLERANCE then "margin" else "margin-large"
	end

	local items, finish = buildItems(seq, modules, factors, stretches, gaps, startOffset)
	return {
		Items = items,
		Covered = finish - startOffset,
		Residual = length - (finish - startOffset),
		Method = method,
		StartOffset = startOffset,
		Length = length,
	}
end

return ModularFitter
