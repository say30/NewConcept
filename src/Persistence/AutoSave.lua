--!strict
-- Saves the open project shortly after each change, so nothing is lost if Studio closes.

local AutoSave = {}

AutoSave.DELAY = 1.5

function AutoSave.start(store: any, projectStore: any, onError: ((string) -> ())?)
	local pendingRevision: number? = nil

	local function flush()
		pendingRevision = nil
		local ok, err = pcall(projectStore.save, projectStore, store.project)
		if not ok and onError then
			onError(tostring(err))
		end
	end

	local connection = store.changed:Connect(function()
		if pendingRevision then
			return
		end
		pendingRevision = store.revision
		task.delay(AutoSave.DELAY, flush)
	end)

	return {
		flush = flush,
		stop = function()
			connection:Disconnect()
			if pendingRevision then
				flush()
			end
		end,
	}
end

return AutoSave
