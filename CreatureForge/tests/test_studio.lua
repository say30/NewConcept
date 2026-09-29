-- Parcours complet « comme dans Studio » (services simulés) :
-- sélection -> analyse -> blueprint -> vue éclatée -> rig -> créer -> couleurs
-- -> matériau -> rig -> publication (avec 429) -> restauration.
local Controller = REQUIRE(ROOT_SCRIPT.Core.Controller)
local Config = REQUIRE(ROOT_SCRIPT.Config)
local A = Config.ATTR

local plugin = {
	settings = {},
	GetSetting = function(self, k)
		return self.settings[k]
	end,
	SetSetting = function(self, k, v)
		self.settings[k] = v
	end,
}

local function check(cond, msg)
	if not cond then
		error("ÉCHEC : " .. msg, 2)
	end
	print("  ok  " .. msg)
end

-- Référence : petit dragon à 4 pattes, rangé dans un dossier.
local refs = MockInstance("Folder", { Name = "CreatureReferences" }, workspace)
local pivot = CFrame.new(20, 0, 0)
local dragon = MockInstance("Model", { Name = "Sunshine Dragon", WorldPivot = pivot }, refs)
local function part(name, pos, size, color)
	return MockInstance("MeshPart", {
		Name = name,
		Size = size,
		CFrame = pivot * CFrame.new(pos),
		Color = color or Color3.fromRGB(240, 190, 40),
		Material = Enum.Material.Plastic,
		MaterialVariant = "",
		MeshId = "rbxassetid://123456",
	}, dragon)
end
local body = part("Body", Vector3.new(0, 3, 0), Vector3.new(2.6, 2.2, 4.2))
local head = part("Head", Vector3.new(0, 5.5, -3), Vector3.new(1.8, 1.6, 2))
part("Snout", Vector3.new(0, 5.2, -4.3), Vector3.new(1.1, 0.8, 1.2), Color3.fromRGB(250, 230, 160))
for _, sx in { -1, 1 } do
	part("Eye" .. sx, Vector3.new(0.6 * sx, 5.8, -3.8), Vector3.new(0.4, 0.4, 0.3), Color3.fromRGB(40, 200, 255))
	part("Horn" .. sx, Vector3.new(0.5 * sx, 6.6, -2.8), Vector3.new(0.3, 0.9, 0.3), Color3.fromRGB(120, 60, 20))
	part("Wing" .. sx, Vector3.new(2.6 * sx, 4.5, 0), Vector3.new(3.8, 0.2, 2.4), Color3.fromRGB(230, 120, 30))
	for _, z in { -1.3, 1.3 } do
		part("Leg" .. sx .. z, Vector3.new(1.1 * sx, 1, z), Vector3.new(0.7, 2, 0.7))
	end
end
for i = 1, 3 do
	part("Tail" .. i, Vector3.new(0, 3 - i * 0.4, 2.2 + i * 1.1), Vector3.new(0.7, 0.6, 1.3))
end
local motor = MockInstance("Motor6D", { Name = "Neck", Part0 = body, Part1 = head, C0 = CFrame.new(0, 1, -2), C1 = CFrame.new(0, -0.5, 1) }, body)
local boneRoot = MockInstance("Bone", { Name = "Spine", WorldCFrame = pivot * CFrame.new(0, 3, 0), CFrame = CFrame.new() }, body)
MockInstance("Bone", { Name = "Spine2", WorldCFrame = pivot * CFrame.new(0, 3, 1), CFrame = CFrame.new(0, 0, 1) }, boneRoot)

local snapshot = {}
for _, d in dragon:GetDescendants() do
	snapshot[d] = { cf = d.CFrame, parent = d.Parent, n = #d:GetChildren() }
end

local c = Controller.new(plugin)
local emits = 0
c:onChanged(function()
	emits += 1
end)

print("1. Sélection d'une pièce -> créature")
c:setSelection({ head })
check(c.state.selection == dragon and c.state.selectionKind == "reference", "la pièce sélectionnée remonte au Model créature")

print("2. Analyse")
c:analyze()
local r = c.state.report
check(r ~= nil, "rapport créé")
check(r.counts.parts == 16 and r.counts.motor6D == 1 and r.counts.bones == 2, "compteurs (16 pièces, 1 Motor6D, 2 bones)")
print("     " .. r.morphology)

print("3. Blueprint")
c:blueprint()
local bp = c.state.blueprint
check(bp ~= nil and bp.Parent ~= nil, "blueprint créé dans CreatureForge_Output")
check(#bp:GetChildren() == 16, "une boîte par pièce source")
local bpHead = bp:FindFirstChild("Head")
check((bpHead.CFrame.Position - (head.CFrame.Position + (bp.WorldPivot.Position - pivot.Position))).Magnitude < 1e-4, "position exacte (décalée)")

print("4. Vue éclatée")
local before = bpHead.CFrame
c:toggleExplode()
check((bpHead.CFrame.Position - before.Position).Magnitude > 0.1, "la tête s'écarte du centre")
local r1 = { before:GetComponents() }
local r2 = { bpHead.CFrame:GetComponents() }
local sameRot = true
for i = 4, 12 do
	sameRot = sameRot and math.abs(r1[i] - r2[i]) < 1e-6
end
check(sameRot, "orientation conservée")
c:setExplode(0, "begin")
c:setExplode(0, "end")
check((bpHead.CFrame.Position - before.Position).Magnitude < 1e-6, "slider à 0 : retour à la position exacte")

print("5. Afficher le rig (sur le blueprint)")
c:toggleRig()
local beams, attachments = 0, 0
for _, d in bp:GetDescendants() do
	if d.ClassName == "Beam" then
		beams += 1
	elseif d.ClassName == "Attachment" then
		attachments += 1
	end
end
check(beams >= 4 and attachments >= 6, "beams + attachments (Motor6D + bones)")
c:toggleRig()
local left = 0
for _, d in bp:GetDescendants() do
	if d.ClassName == "Beam" then
		left += 1
	end
end
check(left == 0, "masquer le rig nettoie tout")

print("6. Créer ma créature")
plugin.settings = {}
c.state.settings.material = "Studs"
c:createCreature()
local g = c.state.generated
check(g ~= nil and g.Parent ~= nil, "nouvelle créature dans CreatureForge_Output : " .. (g and g.Name or "?"))
check(c.state.status.error == nil, "aucune erreur")
local meshParts, motors, welds, reused = 0, 0, 0, 0
for _, d in g:GetDescendants() do
	if d.ClassName == "MeshPart" then
		meshParts += 1
		if d.MeshId:find("123456") then
			reused += 1
		end
		check(d:GetAttribute(A .. "ShapeSpec") ~= nil and d.MeshContent.SourceType == Enum.ContentSourceType.Object, "")
	elseif d.ClassName == "Motor6D" then
		motors += 1
	elseif d.ClassName == "WeldConstraint" then
		welds += 1
	end
end
check(reused == 0, "aucun MeshId source réutilisé")
check(motors > 10 and welds > 3, string.format("rig : %d Motor6D, %d welds", motors, welds))
check(g.PrimaryPart and g.PrimaryPart.Name == "Root" and g.PrimaryPart.Anchored, "Root ancré = PrimaryPart")
check((g:GetPivot().Position - g.WorldPivot.Position).Magnitude < 1e-6, "pivot du modèle stable (au sol)")
local bodyPart = g:FindFirstChild("Body")
check(bodyPart.MaterialVariant == "Studs" and not bodyPart.Anchored, "Studs appliqué, pièces tenues par les joints")
local neck = g:FindFirstChild("Neck") or g:FindFirstChild("Head")
local m6 = neck:FindFirstChildWhichIsA("Motor6D")
local p0w = m6.Part0.CFrame * m6.C0
local p1w = m6.Part1.CFrame * m6.C1
check((p0w.Position - p1w.Position).Magnitude < 1e-5, "Motor6D cohérent (C0/C1 au même point)")
check(g:FindFirstChild("Palette") and #g.Palette:GetChildren() == 5, "dossier Palette (5 Color3Value)")

print("7. Nouvelles couleurs + édition d'une couleur")
local oldColor = bodyPart.Color
c:newColors()
check(bodyPart.Color ~= oldColor, "couleur Primary changée")
g.Palette.Primary.Value = Color3.new(1, 0, 0)
check(bodyPart.Color == Color3.new(1, 0, 0), "modifier Palette.Primary recolore la créature")

print("8. Matériau")
c:setMaterial("SmoothPlastic")
check(bodyPart.MaterialVariant == "" and bodyPart.Material == Enum.Material.SmoothPlastic, "SmoothPlastic")
c.state.settings.variant = "Introuvable"
c:setMaterial("Studs")
check(c.state.status.material.ok == false, "variant manquant signalé : " .. c.state.status.material.text)
c.state.settings.variant = "Studs"
c:setMaterial("Studs")

print("9. Recréer le rig")
c:buildRig()
local motors2 = 0
for _, d in g:GetDescendants() do
	if d.ClassName == "Motor6D" then
		motors2 += 1
	end
end
check(motors2 == motors, "rig reconstruit sans doublon")

print("10. Publication (2 erreurs 429 simulées)")
FAIL_UPLOADS = 2
c:publish()
local pub = c.state.publish
check(#pub.failed == 0 and pub.done == pub.total, string.format("%d / %d meshes publiés", pub.done, pub.total))
local allPublished = true
for _, d in g:GetDescendants() do
	if d.ClassName == "MeshPart" and d:GetAttribute(A .. "ShapeSpec") then
		allPublished = allPublished and d.MeshId:find("rbxassetid://9") ~= nil
	end
end
check(allPublished, "chaque MeshPart pointe vers un nouvel asset")
check(g:GetAttribute(A .. "Published") == true, "créature marquée publiée")
print("     " .. c.state.status.publish.text)

print("11. Deuxième créature (même seed) : réutilise les assets déjà publiés")
local uploadsBefore = game:GetService("AssetService")._uploads
c.state.settings.seed = tostring(g:GetAttribute(A .. "Seed"))
c:createCreature()
c:publish()
check(game:GetService("AssetService")._uploads == uploadsBefore, "aucun nouvel upload (cache clé -> assetId)")

print("12b. Permission refusée puis RÉESSAYER")
c.state.settings.seed = "4242"
c:createCreature()
FAIL_PERMISSION = true
c:publish()
check(#c.state.publish.failed > 0 and c.state.status.publish.ok == false, "échec signalé : " .. c.state.status.publish.text)
FAIL_PERMISSION = false
c:publish()
check(#c.state.publish.failed == 0, "RÉESSAYER : " .. c.state.status.publish.text)

print("12c. Meshes perdus (redémarrage Studio) -> restauration automatique")
c.state.settings.seed = "777"
c:createCreature()
local g3 = c.state.generated
local lost = g3:FindFirstChild("Body")
lost.MeshContent = { SourceType = Enum.ContentSourceType.None }
c:setSelection({})
c:setSelection({ g3 })
check(lost.MeshContent.SourceType == Enum.ContentSourceType.Object, "mesh du corps reconstruit depuis sa CF_ShapeSpec")

print("12. Sécurité")
for d, snap in snapshot do
	if d.CFrame ~= snap.cf or d.Parent ~= snap.parent or #d:GetChildren() ~= snap.n then
		error("ÉCHEC : le modèle source a été modifié (" .. d.Name .. ")")
	end
end
print("  ok  modèle source intact")
check(game:GetService("ChangeHistoryService")._open ~= true, "aucun enregistrement Undo laissé ouvert")
check(game:GetService("ChangeHistoryService")._recordings >= 10, "opérations enregistrées dans l'historique (Undo)")

print("\nStatut final :")
for _, line in c:statusLines() do
	print("  " .. (line.ok == true and "✓" or line.ok == false and "✗" or "•") .. " " .. line.text)
end
print("STUDIO FLOW OK")
