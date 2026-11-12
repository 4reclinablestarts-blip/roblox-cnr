-- Which place this server is, and teleports between places.
-- Teleports need a published experience and Config.PlaceIds filled in; otherwise (and in Studio)
-- Places.teleport returns false and callers fall back to staying in this place.
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = ReplicatedStorage.Remotes

local Places = {}

-- "Hub", "Raid", "Sales" or "Housing", set per place in its *.project.json.
Places.kind = workspace:GetAttribute("PlaceKind") or "Raid"

function Places.canTeleport(kind: string): boolean
	return not RunService:IsStudio() and (Config.PlaceIds[kind] or 0) ~= 0
end

function Places.joinData(player: Player): { [string]: any }
	local joinData = player:GetJoinData()
	return joinData and joinData.TeleportData or {}
end

-- Sends players to another place, saving their data first. Pass accessCode for a reserved server.
function Places.teleport(players: { Player }, kind: string, data: { [string]: any }?, accessCode: string?): boolean
	if not Places.canTeleport(kind) then
		return false
	end
	for _, player in players do
		PlayerData.saveForTeleport(player)
	end
	local options = Instance.new("TeleportOptions")
	if accessCode then
		options.ReservedServerAccessCode = accessCode
	end
	options:SetTeleportData(data or {})
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(Config.PlaceIds[kind], players, options)
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

function Places.reserve(kind: string): string?
	if not Places.canTeleport(kind) then
		return nil
	end
	local ok, code = pcall(function()
		return TeleportService:ReserveServer(Config.PlaceIds[kind])
	end)
	return if ok then code else nil
end

-- Messages to a player wherever they are in the experience (home alarms).
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
