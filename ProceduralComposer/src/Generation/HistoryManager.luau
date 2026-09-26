--[[
	HistoryManager
	Encapsule ChangeHistoryService (API d'enregistrement TryBeginRecording /
	FinishRecording).

	Stratégie d'historique :
	  - Generate Preview : un enregistrement "Preview" (Commit).
	  - Regenerate       : si le dernier point d'annulation est notre preview,
	                       les changements y sont ajoutés (Append) : une seule
	                       entrée d'historique, quel que soit le nombre de variantes.
	  - Accept           : ajouté (Append) au point "Preview" ; un seul Ctrl+Z
	                       après Accept annule donc toute la génération.
	  - Cancel / Clear   : enregistrement séparé (Commit) ; Ctrl+Z les annule.
	  - Erreur pendant une génération : Cancel -> Studio annule tous les
	    changements partiels, la scène reste propre.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local HistoryManager = {}

HistoryManager.PREVIEW = "ProceduralComposer: Generate Preview"
HistoryManager.ACCEPT = "ProceduralComposer: Accept Generation"
HistoryManager.CANCEL = "ProceduralComposer: Cancel Preview"
HistoryManager.CLEAR = "ProceduralComposer: Clear Generated"
HistoryManager.RESTORE = "ProceduralComposer: Restore Walls"

-- Démarre un enregistrement ; renvoie un identifiant (ou nil si impossible).
function HistoryManager.begin(name)
	local ok, id = pcall(ChangeHistoryService.TryBeginRecording, ChangeHistoryService, name, name)
	if ok and id then
		return id
	end
	return nil
end

-- mode : "Commit" | "Append" | "Cancel"
function HistoryManager.finish(id, mode)
	if not id then
		return false
	end
	local op = Enum.FinishRecordingOperation[mode] or Enum.FinishRecordingOperation.Commit
	local ok = pcall(ChangeHistoryService.FinishRecording, ChangeHistoryService, id, op)
	if not ok and mode == "Append" then
		ok = pcall(ChangeHistoryService.FinishRecording, ChangeHistoryService, id, Enum.FinishRecordingOperation.Commit)
	end
	return ok
end

-- Nom du dernier point d'annulation (ou nil).
function HistoryManager.lastWaypointName()
	local ok, canUndo, name = pcall(ChangeHistoryService.GetCanUndo, ChangeHistoryService)
	if ok and canUndo and type(name) == "string" then
		return name
	end
	return nil
end

function HistoryManager.lastIsPreview()
	return HistoryManager.lastWaypointName() == HistoryManager.PREVIEW
end

-- Exécute `fn` dans un enregistrement ; annule tout en cas d'erreur.
function HistoryManager.run(name, mode, fn)
	local id = HistoryManager.begin(name)
	if not id then
		return false, "Studio refused to start an undo recording (another plugin may be recording). Try again."
	end
	local ok, result = pcall(fn)
	if ok then
		HistoryManager.finish(id, mode)
		return true, result
	end
	HistoryManager.finish(id, "Cancel")
	return false, result
end

function HistoryManager.onUndoRedo(callback)
	local a = ChangeHistoryService.OnUndo:Connect(callback)
	local b = ChangeHistoryService.OnRedo:Connect(callback)
	return function()
		a:Disconnect()
		b:Disconnect()
	end
end

return HistoryManager
