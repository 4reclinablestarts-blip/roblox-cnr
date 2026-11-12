-- Leaving the raid: death, arrest, extraction.
-- shortcut: teleporting to the Motel needs a published experience, so for now the player respawns
-- here with per-raid state reset; swap the body for TeleportService once the hub place exists.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(script.Parent.Inventory)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Raid = {}

-- keepItems: extraction and dead civilians keep their bag; arrests and other deaths don't.
function Raid.leave(player: Player, reason: string, keepItems: boolean)
	Roles.reset(player)
	if not keepItems then
		Inventory.fresh(player)
	end
	Remotes.Notify:FireClient(player, `{reason} You'd be back at the Motel now (hub not built yet).`)
end

return Raid
