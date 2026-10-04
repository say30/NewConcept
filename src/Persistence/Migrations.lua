--!strict
-- Upgrades projects saved by older versions of the plugin, one version at a time.
-- To change the format: bump Document.FORMAT_VERSION and add a step here
-- (steps[1] upgrades version 1 to version 2, and so on).

local Migrations = {}

local steps: { [number]: (project: any) -> () } = {}

function Migrations.run(project: any, targetVersion: number): any
	local version = project.formatVersion or 1
	assert(
		version <= targetVersion,
		"This project was made with a newer version of the plugin. Please update the plugin."
	)
	while version < targetVersion do
		local step = steps[version]
		assert(step, "No migration from format " .. version)
		step(project)
		version += 1
		project.formatVersion = version
	end
	return project
end

return Migrations
