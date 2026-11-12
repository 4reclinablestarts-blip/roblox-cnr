-- The world map. It opens when you cross a map border (Motel, Sales Center, neighbourhoods),
-- extract from a raid, or a raid ends. Picking a destination teleports you there.
-- MapOpen attribute: "border" (can also stay), "extract", or "raidEnd" (Motel or home only).
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cars = require(script.Parent.Cars)
local Matchmaking = require(script.Parent.Matchmaking)
local Neighbourhoods = require(script.Parent.Neighbourhoods)
local Party = require(script.Parent.Party)
local Places = require(script.Parent.Places)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = ReplicatedStorage.Remotes

local Travel = {}

-- Takes the player off the map (no character) and shows the world map.
function Travel.open(player: Player, reason: string)
	if player:GetAttribute("MapOpen") then
		return
	end
	Cars.leaveWithPlayer(player)
	player:SetAttribute("MapOpen", reason)
	if player.Character then
		player.Character:Destroy()
		player.Character = nil
	end
end

-- Back into this place (chose to stay, or travel isn't possible here).
local function stay(player: Player)
	player:SetAttribute("MapOpen", nil)
	player:SetAttribute("CarToBring", nil)
	player:LoadCharacter()
end

local function go(player: Player, destination: string, arg: any): boolean
	local car = player:GetAttribute("CarToBring")
	if destination == "Motel" then
		return Places.teleport({ player }, "Hub", { car = car })
	elseif destination == "LootyBay" then
		local party = Party.of(player)
		if party and party.leader ~= player then
			Remotes.Notify:FireClient(player, "Only the party leader picks the raid. Leave the party to go alone.")
			return false
		end
		local players, partyId = Party.travellers(player)
		return Matchmaking.join(players, partyId)
	elseif destination == "SalesCenter" then
		return Places.teleport({ player }, "Sales", { car = car })
	elseif destination == "Home" then
		return Neighbourhoods.goHome(player)
	elseif destination == "Visit" and type(arg) == "string" then
		return Neighbourhoods.visit(player, arg)
	elseif destination == "BuyPlot" and type(arg) == "string" then
		Neighbourhoods.buyPlot(player, arg)
		return true
	end
	return false
end

local function onTravel(player: Player, destination: any, arg: any)
	local reason = player:GetAttribute("MapOpen")
	if not reason or type(destination) ~= "string" then
		return
	end
	if destination == "Stay" then
		if reason == "border" then
			stay(player)
		end
		return
	end
	if reason == "raidEnd" and destination ~= "Motel" and destination ~= "Home" then
		return
	end
	if not go(player, destination, arg) and not Places.canTeleport("Hub") then
		Remotes.Notify:FireClient(
			player,
			"Travel needs the published game (fill in Config.PlaceIds). Staying here for testing."
		)
		stay(player)
	end
end

-- What the world map needs to know about the player (home, deed, district permit).
function Travel.refresh(player: Player)
	local data = PlayerData.get(player)
	if data then
		player:SetAttribute("HasHome", data.home ~= nil)
		player:SetAttribute("HomeDeed", data.unlocks.HomeDeed == true)
		player:SetAttribute("DistrictLevel", Neighbourhoods.levelAllowed(data.unlocks))
	end
end

function Travel.start()
	Remotes.Travel.OnServerEvent:Connect(onTravel)

	-- Map borders in the Motel, Sales Center and neighbourhoods (the raid uses RaidBorder for extraction).
	local function setupBorder(part: BasePart)
		part.Touched:Connect(function(hit)
			local character = hit:FindFirstAncestorOfClass("Model")
			local player = character and Players:GetPlayerFromCharacter(character)
			if player and not player:GetAttribute("Downed") then
				Travel.open(player, "border")
			end
		end)
	end
	CollectionService:GetInstanceAddedSignal("MapBorder"):Connect(setupBorder)
	for _, part in CollectionService:GetTagged("MapBorder") do
		setupBorder(part)
	end

	Players.PlayerAdded:Connect(Travel.refresh)
	for _, player in Players:GetPlayers() do
		task.spawn(Travel.refresh, player)
	end
end

return Travel
