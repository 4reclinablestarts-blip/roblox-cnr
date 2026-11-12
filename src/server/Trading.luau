-- Moving items around: selling (parts tagged "SellStation"), storing in personal stashes,
-- rearranging the bag grid, using heals, and giving items to other players.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Looting = require(script.Parent.Looting)
local Places = require(script.Parent.Places)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Trading = {}

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

-- Base value plus the criminal level bonus (+5% per level) plus any place bonus (Sales Center).
function Trading.sellPrice(itemId: string, criminalLevel: number, placeBonus: number?): number
	return math.floor(
		Config.Items[itemId].value * (1 + Config.SELL_BONUS_PER_LEVEL * criminalLevel + (placeBonus or 0))
	)
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
			Remotes.OpenStash:FireClient(player, part, {}, true)
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

local function sell(player: Player, index: number, itemId: string)
	if Roles.isPolice(player) then
		return
	end
	local bonus = if Places.kind == "Sales" then Config.SALES_CENTER_BONUS else 0
	local price = Trading.sellPrice(itemId, player:GetAttribute("CriminalLevel") or 0, bonus)
	if price <= 0 then
		notify(player, `Nobody buys a {Config.Items[itemId].name} here.`)
		return
	end
	-- Selling frees the item's cells, so the cash always fits.
	local entry = Inventory.remove(player, index, itemId)
	if entry then
		price *= entry.amount or 1 -- a stack (ammo) sells per round
		Inventory.add(player, { id = "Money", amount = price })
		notify(player, `Sold {Config.Items[itemId].name} for ${price}.`)
	end
end

local function store(player: Player, part: BasePart, stash: Looting.PersonalStash, index: number, itemId: string)
	local items = stash.items(player)
	if not items or not stash.canPut or not stash.canPut(player) then
		return
	end
	if stash.capacity and #items >= stash.capacity then
		notify(player, "That stash is full.")
		return
	end
	local entry = Inventory.remove(player, index, itemId)
	if entry then
		table.insert(items, entry)
		Remotes.OpenStash:FireClient(player, part, items, true)
	end
end

local function heal(player: Player, index: number, itemId: string)
	local amount = Config.Heals[itemId]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not amount or not humanoid or humanoid.Health <= 0 or player:GetAttribute("Downed") then
		return
	end
	if humanoid.Health >= humanoid.MaxHealth then
		notify(player, "You're already at full health.")
	elseif Inventory.remove(player, index, itemId) then
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	end
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
			or not part:IsA("BasePart")
			or type(index) ~= "number"
			or type(itemId) ~= "string"
			or not Config.Items[itemId]
			or not Looting.inRange(player, part)
		then
			return
		end
		local stash = Looting.personalStashes[part]
		if CollectionService:HasTag(part, "SellStation") then
			sell(player, index, itemId)
		elseif stash then
			store(player, part, stash, index, itemId)
		end
	end)

	Remotes.MoveItem.OnServerEvent:Connect(function(player, index, itemId, x, y)
		if type(index) == "number" and type(itemId) == "string" and type(x) == "number" and type(y) == "number" then
			Inventory.move(player, index, itemId, math.floor(x), math.floor(y))
		end
	end)

	Remotes.UseItem.OnServerEvent:Connect(function(player, index, itemId)
		if type(index) == "number" and type(itemId) == "string" then
			heal(player, index, itemId)
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
		elseif not Inventory.canAdd(target, { id = itemId }) then
			notify(player, `{target.DisplayName}'s bag is full.`)
		else
			local entry = Inventory.remove(player, index, itemId)
			if not entry then
				return
			end
			Inventory.add(target, entry)
			notify(player, `Gave {Config.Items[itemId].name} to {target.DisplayName}.`)
			notify(target, `{player.DisplayName} gave you a {Config.Items[itemId].name}.`)
		end
	end)
end

-- Self-check for the price curve from the design doc.
assert(Trading.sellPrice("Watch", 0) == 80 and Trading.sellPrice("Watch", 5) == 100, "sell price curve")
assert(Trading.sellPrice("Watch", 0, 0.5) == 120, "Sales Center bonus")

return Trading
