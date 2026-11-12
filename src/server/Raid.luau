-- Leaving the raid: death, arrest, extraction.
-- shortcut: teleporting to the Motel needs a published experience, so for now the player respawns
-- here with per-raid state reset; swap the body for TeleportService once the hub place exists.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Inventory = require(script.Parent.Inventory)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Raid = {}

-- keepItems: extraction and dead civilians keep their bag; arrests and other deaths don't.
local leaving: { [Player]: boolean } = {}

function Raid.leave(player: Player, reason: string, keepItems: boolean)
	-- Touched fires many times in one step; only the first one counts.
	if leaving[player] then
		return
	end
	leaving[player] = true
	task.delay(1, function()
		leaving[player] = nil
	end)
	Roles.reset(player)
	if not keepItems then
		Inventory.fresh(player)
	end
	-- Dead players respawn on their own; living ones (arrested, extracted) are taken out now.
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		player:LoadCharacter()
	end
	Remotes.Notify:FireClient(player, `{reason} You'd be back at the Motel now (hub not built yet).`)
end

-- Map border (parts tagged "RaidBorder"): walking or driving into it extracts you with your bag.
-- Downed and surrendered players can't escape that way.
local function setupBorder(part: BasePart)
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			player
			and humanoid
			and humanoid.Health > 0
			and not player:GetAttribute("Downed")
			and not player:GetAttribute("Surrendered")
		then
			Raid.leave(player, "You extracted with everything you carried.", true)
		end
	end)
end

function Raid.start()
	CollectionService:GetInstanceAddedSignal("RaidBorder"):Connect(setupBorder)
	for _, part in CollectionService:GetTagged("RaidBorder") do
		setupBorder(part)
	end
end

return Raid
