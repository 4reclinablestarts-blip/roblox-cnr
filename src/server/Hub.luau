-- The Motel: a safe zone with the small stash (part tagged "HubStash"), the tech tree shop
-- (tagged "Shop") and the garage (tagged "Garage"). Leave through a MapBorder to travel.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Cars = require(script.Parent.Cars)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Looting = require(script.Parent.Looting)
local PlayerData = require(script.Parent.PlayerData)
local Travel = require(script.Parent.Travel)
local Remotes = ReplicatedStorage.Remotes

local Hub = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

local function techEntry(id: string)
	for _, entry in Config.TechTree do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Hub.ownsCar(data: PlayerData.Data, carId: string): boolean
	return carId == "Rental" or data.unlocks[carId] == true
end

local function sendShop(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local cars = {}
	for carId in Config.Cars do
		if Hub.ownsCar(data, carId) then
			cars[carId] = { deployed = data.cars[carId] ~= nil and data.cars[carId].deployedIn ~= nil }
		end
	end
	Remotes.OpenShop:FireClient(player, { unlocks = data.unlocks, cars = cars, selected = data.car })
end

local function buy(player: Player, id: string)
	local data = PlayerData.get(player)
	local entry = techEntry(id)
	if not data or not entry then
		return
	end
	for _, required in entry.requires or {} do
		if not data.unlocks[required] then
			notify(player, `Unlock {techEntry(required).name} first.`)
			return
		end
	end
	if not entry.item and data.unlocks[id] then
		notify(player, "You already own that.")
		return
	end
	if Inventory.count(player, "Money") < entry.cost then
		notify(player, `You need ${entry.cost} cash in your bag.`)
		return
	end
	if entry.item and not Inventory.canAdd(player, { id = entry.item }) then
		notify(player, "No room in your bag.")
		return
	end
	if entry.cost > 0 and not Inventory.consume(player, "Money", entry.cost) then
		return
	end
	if entry.item then
		Inventory.add(player, { id = entry.item, amount = Config.Items[entry.item].defaultAmount })
	else
		data.unlocks[id] = true
		if Config.Cars[id] then
			data.cars[id] = data.cars[id] or { trunk = {} }
		end
		Inventory.refreshBagLevel(player)
		Travel.refresh(player)
	end
	notify(player, `Bought {entry.name}.`)
	sendShop(player)
end

local function garage(player: Player, action: string, carId: string, spot: BasePart)
	local data = PlayerData.get(player)
	if not data or not Config.Cars[carId] or not Hub.ownsCar(data, carId) then
		return
	end
	local saved = data.cars[carId]
	if action == "select" then
		data.car = carId
	elseif action == "spawn" then
		if saved and saved.deployedIn and carId ~= "Rental" then
			notify(player, "That car is still in a raid. Recall it first.")
			return
		end
		data.car = carId
		local car = Cars.spawn(player, carId, spot.CFrame + Vector3.new(0, 3, 0))
		if car then
			Cars.seat(player, car)
		end
	elseif action == "recall" then
		Cars.recall(player, carId)
	end
	sendShop(player)
end

function Hub.start()
	local function setupStash(part: BasePart)
		Looting.personalStashes[part] = {
			items = function(player: Player)
				local data = PlayerData.get(player)
				return data and data.stash
			end,
			capacity = Config.HUB_STASH_SLOTS,
			canPut = function()
				return true
			end,
		}
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open stash"
		prompt.ObjectText = `Stash ({Config.HUB_STASH_SLOTS} slots)`
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(function(player)
			local data = PlayerData.get(player)
			if data then
				Remotes.OpenStash:FireClient(player, part, data.stash, true)
			end
		end)
		prompt.Parent = part
	end

	local function setupMenu(part: BasePart, text: string)
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = text
		prompt.RequiresLineOfSight = false
		prompt.Triggered:Connect(sendShop)
		prompt.Parent = part
	end

	for tag, setup in
		{
			HubStash = setupStash,
			Shop = function(part)
				setupMenu(part, "Tech tree")
			end,
			Garage = function(part)
				setupMenu(part, "Garage")
			end,
		}
	do
		CollectionService:GetInstanceAddedSignal(tag):Connect(setup)
		for _, part in CollectionService:GetTagged(tag) do
			setup(part)
		end
	end

	Remotes.Buy.OnServerEvent:Connect(function(player, id)
		if type(id) == "string" then
			buy(player, id)
		end
	end)
	Remotes.Garage.OnServerEvent:Connect(function(player, action, carId)
		local spot = CollectionService:GetTagged("Garage")[1]
		if type(action) == "string" and type(carId) == "string" and spot then
			garage(player, action, carId, spot)
		end
	end)
end

return Hub
