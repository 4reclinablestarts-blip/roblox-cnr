-- Lootables: parts tagged "Lootable" with a LootTable attribute (and optional HoldTime).
-- Searching one opens it as a stash; the client drags items out with TakeItem.
-- World items: parts tagged "WorldItem" with an ItemId attribute, picked up whole (a TV, a plant).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Looting = {}

local contents: { [BasePart]: { string } } = {}
local resetting: { [BasePart]: boolean } = {}

local function roll(part: BasePart): { string }
	local lootTable = Config.LootTables[part:GetAttribute("LootTable")]
	local out = {}
	for _ = 1, math.random(lootTable.count[1], lootTable.count[2]) do
		table.insert(out, lootTable.items[math.random(#lootTable.items)])
	end
	return out
end

function Looting.inRange(player: Player, part: BasePart): boolean
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	return root ~= nil and (root.Position - part.Position).Magnitude <= Config.LOOT_RANGE
end
local inRange = Looting.inRange

local function canRob(player: Player): boolean
	if Roles.isPolice(player) then
		Remotes.Notify:FireClient(player, "Cops can't rob.")
		return false
	end
	return true
end

local function addCriminalProgress(player: Player)
	local looted = (player:GetAttribute("LootedItems") or 0) + 1
	player:SetAttribute("LootedItems", looted)
	player:SetAttribute("CriminalLevel", math.min(Config.MAX_CRIMINAL_LEVEL, looted // Config.ITEMS_PER_CRIMINAL_LEVEL))
end

local function setup(part: BasePart)
	if contents[part] then
		return
	end
	contents[part] = roll(part)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Search"
	prompt.ObjectText = part.Name
	prompt.HoldDuration = part:GetAttribute("HoldTime") or 3
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		if not canRob(player) or not inRange(player, part) then
			return
		end
		-- Robbing unmasked makes you a criminal on the spot.
		Roles.makeCriminal(player)
		Remotes.OpenStash:FireClient(player, part, contents[part])
	end)
	prompt.Parent = part
end

local worldItems: { [BasePart]: boolean } = {}

local function setupWorldItem(part: BasePart)
	-- Taken items are parked in ServerStorage and put back, which fires the added signal again.
	if worldItems[part] then
		return
	end
	worldItems[part] = true
	local itemId = part:GetAttribute("ItemId")

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = `Take {Config.Items[itemId].name}`
	prompt.HoldDuration = part:GetAttribute("HoldTime") or 2
	prompt.RequiresLineOfSight = false
	prompt.Triggered:Connect(function(player)
		if not canRob(player) or not inRange(player, part) or part.Parent == ServerStorage then
			return
		end
		if not Inventory.add(player, itemId) then
			Remotes.Notify:FireClient(player, "Your bag is full.")
			return
		end
		Roles.makeCriminal(player)
		addCriminalProgress(player)

		local home = part.Parent
		part.Parent = ServerStorage
		task.delay(Config.LOOT_RESET, function()
			part.Parent = home
		end)
	end)
	prompt.Parent = part
end

function Looting.start()
	CollectionService:GetInstanceAddedSignal("Lootable"):Connect(setup)
	for _, part in CollectionService:GetTagged("Lootable") do
		setup(part)
	end
	CollectionService:GetInstanceAddedSignal("WorldItem"):Connect(setupWorldItem)
	for _, part in CollectionService:GetTagged("WorldItem") do
		setupWorldItem(part)
	end

	Remotes.TakeItem.OnServerEvent:Connect(function(player, part, index, itemId)
		-- Client input: check every argument before using it.
		if typeof(part) ~= "Instance" or not contents[part] or type(index) ~= "number" then
			return
		end
		local items = contents[part]
		if not canRob(player) or not inRange(player, part) then
			return
		end
		if items[index] ~= itemId then
			-- Someone else took it first; send the current contents.
			Remotes.OpenStash:FireClient(player, part, items)
			return
		end
		if not Inventory.add(player, itemId) then
			Remotes.Notify:FireClient(player, "Your bag is full.")
			return
		end
		table.remove(items, index)
		addCriminalProgress(player)
		Remotes.OpenStash:FireClient(player, part, items)

		if not resetting[part] then
			resetting[part] = true
			task.delay(Config.LOOT_RESET, function()
				contents[part] = roll(part)
				resetting[part] = nil
			end)
		end
	end)
end

return Looting
