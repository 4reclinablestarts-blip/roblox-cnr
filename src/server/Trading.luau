-- Sell stations (parts tagged "SellStation") and giving items to other players.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Looting = require(script.Parent.Looting)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Trading = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

-- Base value plus the criminal level bonus (+5% per level).
function Trading.sellPrice(itemId: string, criminalLevel: number): number
	return math.floor(Config.Items[itemId].value * (1 + Config.SELL_BONUS_PER_LEVEL * criminalLevel))
end

local function setupStation(part: BasePart)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Sell items"
	prompt.ObjectText = part.Name
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		if Roles.isPolice(player) then
			notify(player, "Cops can't sell.")
		elseif Looting.inRange(player, part) then
			Remotes.OpenStash:FireClient(player, part, {})
		end
	end)
	prompt.Parent = part
end

local function distance(a: Player, b: Player): number
	local rootA = a.Character and a.Character:FindFirstChild("HumanoidRootPart")
	local rootB = b.Character and b.Character:FindFirstChild("HumanoidRootPart")
	if not rootA or not rootB then
		return math.huge
	end
	return (rootA.Position - rootB.Position).Magnitude
end

function Trading.start()
	CollectionService:GetInstanceAddedSignal("SellStation"):Connect(setupStation)
	for _, part in CollectionService:GetTagged("SellStation") do
		setupStation(part)
	end

	Remotes.PutItem.OnServerEvent:Connect(function(player, part, index, itemId)
		-- Client input: check every argument before using it.
		if
			typeof(part) ~= "Instance"
			or not CollectionService:HasTag(part, "SellStation")
			or type(index) ~= "number"
			or type(itemId) ~= "string"
			or not Config.Items[itemId]
		then
			return
		end
		if Roles.isPolice(player) or not Looting.inRange(player, part) then
			return
		end
		local price = Trading.sellPrice(itemId, player:GetAttribute("CriminalLevel") or 0)
		if price <= 0 then
			notify(player, `Nobody buys a {Config.Items[itemId].name} here.`)
			return
		end
		if Inventory.remove(player, index, itemId) then
			player:SetAttribute("Cash", (player:GetAttribute("Cash") or 0) + price)
			notify(player, `Sold {Config.Items[itemId].name} for ${price}.`)
		end
	end)

	Remotes.GiveItem.OnServerEvent:Connect(function(player, target, index, itemId)
		if
			typeof(target) ~= "Instance"
			or not target:IsA("Player")
			or target == player
			or type(index) ~= "number"
			or type(itemId) ~= "string"
			or not Config.Items[itemId]
		then
			return
		end
		-- The police kit can't leave the police, and cops don't carry personal items.
		if Roles.isPolice(player) or Roles.isPolice(target) then
			notify(player, "Cops can't trade items.")
		elseif distance(player, target) > Config.GIVE_RANGE then
			notify(player, `{target.DisplayName} is too far away.`)
		elseif not Inventory.hasRoom(target) then
			notify(player, `{target.DisplayName}'s bag is full.`)
		elseif Inventory.remove(player, index, itemId) then
			Inventory.add(target, itemId)
			notify(player, `Gave {Config.Items[itemId].name} to {target.DisplayName}.`)
			notify(target, `{player.DisplayName} gave you a {Config.Items[itemId].name}.`)
		end
	end)
end

-- Self-check for the price curve from the design doc.
assert(Trading.sellPrice("Watch", 0) == 80 and Trading.sellPrice("Watch", 5) == 100, "sell price curve")

return Trading
