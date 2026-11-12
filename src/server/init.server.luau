-- One codebase for every place; Workspace's PlaceKind attribute (set in each *.project.json) picks what runs.
local Places = require(script.Places)
local kind = Places.kind

require(script.Placeholder)(kind)
require(script.PlayerData).start()
require(script.Inventory).start()
Places.start()
if kind == "Raid" then
	require(script.Roles).start()
end
require(script.Looting).start() -- also serves personal stashes (Motel stash, trunks, homes)
require(script.Trading).start()
require(script.Travel).start()
require(script.Cars).start()

if kind == "Hub" then
	require(script.Hub).start()
	require(script.Party).start()
else
	require(script.Combat).start() -- the Motel is a safe zone
end

if kind == "Raid" then
	require(script.Justice).start()
	require(script.Detection).start()
	require(script.Raid).start()
elseif kind == "Housing" then
	require(script.Housing).start()
end
