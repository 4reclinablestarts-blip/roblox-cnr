-- Civilian / Criminal / Police teams, the police desk, and masking up.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Teams = game:GetService("Teams")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Remotes = ReplicatedStorage.Remotes

local Roles = {}

local teams: { [string]: Team } = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

-- Criminal status lasts until the player leaves the raid, so this only ever goes one way.
function Roles.makeCriminal(player: Player)
	if player.Team == teams.Civilian then
		player.Team = teams.Criminal
	end
end

function Roles.isPolice(player: Player): boolean
	return player.Team == teams.Police
end

local function goOnDuty(player: Player, loadout)
	if player.Team ~= teams.Civilian then
		notify(player, "Only civilians can join the police.")
	elseif player:GetAttribute("WentOffDuty") then
		notify(player, "You already went off duty this raid.")
	elseif #teams.Police:GetPlayers() >= Config.MAX_COPS then
		notify(player, `The police force is full ({Config.MAX_COPS}/{Config.MAX_COPS}).`)
	else
		Inventory.lockAway(player, loadout.items)
		player.Team = teams.Police
		notify(player, `On duty with the {loadout.name} loadout.`)
	end
end

local function goOffDuty(player: Player)
	if player.Team ~= teams.Police then
		return
	end
	Inventory.restore(player)
	player.Team = teams.Civilian
	player:SetAttribute("WentOffDuty", true)
	notify(player, "Off duty. You can't rejoin the police this raid.")
end

local DUTY_KEYS = { Enum.KeyCode.E, Enum.KeyCode.R, Enum.KeyCode.T }

local function setupDesk(desk: Instance)
	for i, loadout in Config.PoliceLoadouts do
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = `Go on duty: {loadout.name}`
		prompt.ObjectText = "Police desk"
		prompt.KeyboardKeyCode = DUTY_KEYS[i]
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player)
			goOnDuty(player, loadout)
		end)
		prompt.Parent = desk
	end

	local offDuty = Instance.new("ProximityPrompt")
	offDuty.ActionText = "Go off duty"
	offDuty.ObjectText = "Police desk"
	offDuty.KeyboardKeyCode = Enum.KeyCode.F
	offDuty.RequiresLineOfSight = false
	offDuty.Triggered:Connect(goOffDuty)
	offDuty.Parent = desk
end

function Roles.start()
	for name, color in Config.Teams do
		local team = Instance.new("Team")
		team.Name = name
		team.TeamColor = color
		team.AutoAssignable = false
		team.Parent = Teams
		teams[name] = team
	end

	local function onJoin(player: Player)
		player.Team = teams.Civilian
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end

	Remotes.MaskUp.OnServerEvent:Connect(function(player)
		if player.Team == teams.Police then
			notify(player, "Cops can't mask up.")
		elseif not player:GetAttribute("Masked") then
			player:SetAttribute("Masked", true)
			Roles.makeCriminal(player)
			notify(player, "Masked up. You're a criminal until you leave the raid.")
		end
	end)

	CollectionService:GetInstanceAddedSignal("PoliceDesk"):Connect(setupDesk)
	for _, desk in CollectionService:GetTagged("PoliceDesk") do
		setupDesk(desk)
	end
end

return Roles
