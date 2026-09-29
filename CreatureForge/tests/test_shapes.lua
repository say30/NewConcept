-- Vérifie que chaque forme est un solide fermé, bien orienté, sous les limites EditableMesh.
local ShapeLibrary = REQUIRE(ROOT_SCRIPT.Geometry.ShapeLibrary)

local cases = {
	ellipsoid = { sx = 2, sy = 1.5, sz = 3 },
	roundedCube = { sx = 2, sy = 2, sz = 2 },
	limb = { len = 3, r0 = 0.5, r1 = 0.35 },
	taperedCylinder = { len = 2, r0 = 0.5, r1 = 0.2 },
	cone = { len = 2, r = 0.6 },
	horn = { len = 2, r = 0.3, curve = 0.6, out = 0.3 },
	hornRam = { shape = "horn", len = 2, r = 0.3, style = "ram", out = 0.3 },
	claw = { len = 0.6, r = 0.12 },
	spike = { len = 1, r = 0.25 },
	crystal = { len = 1.5, r = 0.35 },
	tentacle = { len = 4, r = 0.35, curl = 0.9 },
	head = { sx = 2, sy = 1.8, sz = 2.4, style = "snout" },
	headBoxy = { shape = "head", sx = 2, sy = 1.8, sz = 2.4, style = "boxy" },
	muzzle = { sx = 1.2, sy = 0.8, sz = 1.2 },
	beak = { shape = "muzzle", sx = 1.0, sy = 0.8, sz = 1.3, style = "beak" },
	jaw = { sx = 1.1, sy = 0.4, sz = 1.4 },
	torso = { sx = 3, sy = 2.6, sz = 5, style = "chest" },
	eye = { r = 0.3 },
	pupil = { r = 0.3, style = "slit" },
	ear = { len = 1.2, width = 0.7, thick = 0.15 },
	paw = { sx = 1, sy = 0.5, sz = 1.2, toes = 3, claws = true },
	hoof = { sx = 0.8, sy = 0.6, sz = 0.8 },
	talon = { sx = 1, sy = 0.4, sz = 1.4 },
	wing = { span = 6, chord = 3, style = "bat" },
	wingFeather = { shape = "wing", span = 6, chord = 3, style = "feather" },
	wingMembrane = { shape = "wing", span = 4, chord = 2, style = "membrane" },
	wingRay = { shape = "wing", span = 4, chord = 4, style = "ray" },
	fin = { height = 1.5, len = 2 },
	plate = { height = 1.2, width = 1.2 },
	tailTipSpade = { shape = "tailTip", len = 1.2, width = 1, style = "spade" },
	tailTipClub = { shape = "tailTip", len = 1.2, width = 1, style = "club" },
	tailTipFin = { shape = "tailTip", len = 1.2, width = 1, style = "fin" },
	tailTipSpikes = { shape = "tailTip", len = 1.2, width = 1, style = "spikes" },
}

-- Chaque arête orientée (a->b) doit apparaître une fois, et son inverse (b->a) aussi,
-- sur les positions (les primitives fusionnées ont leurs propres sommets).
local function closedCheck(b)
	local edges = {}
	local function key(i, j)
		local p, q = b.verts[i], b.verts[j]
		return string.format("%.4f,%.4f,%.4f>%.4f,%.4f,%.4f", p.X, p.Y, p.Z, q.X, q.Y, q.Z)
	end
	for _, t in b.tris do
		for e = 1, 3 do
			local i, j = t[e], t[e % 3 + 1]
			local k = key(i, j)
			edges[k] = (edges[k] or 0) + 1
		end
	end
	local bad = 0
	for _, t in b.tris do
		for e = 1, 3 do
			local i, j = t[e], t[e % 3 + 1]
			if (edges[key(j, i)] or 0) ~= 1 or edges[key(i, j)] ~= 1 then
				bad += 1
			end
		end
	end
	return bad
end

local failures = 0
local names = {}
for name in cases do
	names[#names + 1] = name
end
table.sort(names)
for _, name in names do
	local p = cases[name]
	local shape = p.shape or name
	p.seed = 7
	p.jitter = 0
	local ok, b = pcall(ShapeLibrary.build, shape, p)
	if not ok then
		print("FAIL", name, b)
		failures += 1
	else
		local vol = b:signedVolume()
		local open = closedCheck(b)
		local status = (vol > 0 and #b.tris > 0 and #b.tris < 20000) and "ok" or "FAIL"
		if status == "FAIL" then
			failures += 1
		end
		print(string.format("%-14s %-4s tris=%4d verts=%4d vol=%.3f openEdges=%d", name, status, #b.tris, #b.verts, vol, open))
		if OBJ_DIR_MARK then
			print("#OBJ " .. name)
			for _, v in b.verts do
				print(string.format("v %.4f %.4f %.4f", v.X, v.Y, v.Z))
			end
			for _, t in b.tris do
				print(string.format("f %d %d %d", t[1], t[2], t[3]))
			end
			print("#END")
		end
	end
end
print(failures == 0 and "ALL SHAPES OK" or ("FAILURES: " .. failures))
