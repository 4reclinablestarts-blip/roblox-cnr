-- The whole game is ONE Roblox place. Each server decides what it is when it starts:
--   public servers                   -> "Hub" (Lenny's Motel)
--   reserved servers                 -> whatever the first arrival's teleport data says
--                                       ("Raid", "Sales" or "Housing"), plus its access code
--   Studio                           -> Workspace's PlaceKind attribute (set in each *.project.json)
-- Teleports always go to this same place: the Motel is a public server, everything else reserved.
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local PlayerData = require(script.Parent.PlayerData)
local Remotes = ReplicatedStorage.Remotes

local Places = {}

Places.kind = "Hub" -- "Hub", "Raid", "Sales" or "Housing"; set by resolveKind before anything starts
Places.code = nil :: string? -- this reserved server's access code (it can't look it up itself)

function Places.joinData(player: Player): { [string]: any }
	local joinData = player:GetJoinData()
	return joinData and joinData.TeleportData or {}
end

-- Yields until we know what this server is. A reserved server waits for its first player.
function Places.resolveKind()
	if RunService:IsStudio() then
		Places.kind = workspace:GetAttribute("PlaceKind") or "Raid"
	elseif game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
		local data = Places.joinData(first)
		Places.kind = data.kind or "Hub"
		Places.code = data.accessCode
	end
	workspace:SetAttribute("PlaceKind", Places.kind) -- clients read it too
end

-- Studio can't teleport; callers fall back to keeping the player here.
function Places.canTeleport(): boolean
	return not RunService:IsStudio()
end

-- Sends players to another server of this game, saving their data first.
-- "Hub" goes to a public server; every other kind needs the reserved server's access code.
function Places.teleport(players: { Player }, kind: string, data: { [string]: any }?, accessCode: string?): boolean
	if not Places.canTeleport() or (kind ~= "Hub" and not accessCode) then
		return false
	end
	for _, player in players do
		PlayerData.saveForTeleport(player)
	end
	local teleportData = table.clone(data or {})
	teleportData.kind = kind
	teleportData.accessCode = accessCode
	local options = Instance.new("TeleportOptions")
	if accessCode then
		options.ReservedServerAccessCode = accessCode
	end
	options:SetTeleportData(teleportData)
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(game.PlaceId, players, options)
	end)
	if not ok then
		warn(`Teleport to {kind} failed: {err}`)
		for _, player in players do
			PlayerData.teleportFailed(player)
			Remotes.Notify:FireClient(player, "Travel failed, try again.")
		end
	end
	return ok
end

-- A new reserved server of this game (a raid, Sales Center or neighbourhood).
function Places.reserve(): string?
	if not Places.canTeleport() then
		return nil
	end
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(game.PlaceId)
	end)
	return if ok then code else nil
end

-- Messages to a player wherever they are in the game (home alarms).
function Places.notifyAnywhere(userId: number, message: string)
	local player = Players:GetPlayerByUserId(userId)
	if player then
		Remotes.Notify:FireClient(player, message)
		return
	end
	pcall(function()
		MessagingService:PublishAsync("Notify", { userId = userId, message = message })
	end)
end

function Places.start()
	TeleportService.TeleportInitFailed:Connect(function(player)
		PlayerData.teleportFailed(player)
		Remotes.Notify:FireClient(player, "Travel failed, try again.")
	end)
	pcall(function()
		MessagingService:SubscribeAsync("Notify", function(message)
			local player = Players:GetPlayerByUserId(message.Data.userId)
			if player then
				Remotes.Notify:FireClient(player, message.Data.message)
			end
		end)
	end)
end

return Places
