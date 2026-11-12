-- Per-player bag contents, kept on the server.
-- shortcut: in memory only and 1 item = 1 slot; DataStore and the grid come in later milestones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local Inventory = {}

local items: { [Player]: { string } } = {}
local lockedAway: { [Player]: { string } } = {}

local function sync(player: Player)
	Remotes.InventoryChanged:FireClient(player, items[player], Config.BAG_SLOTS)
end

function Inventory.add(player: Player, itemId: string): boolean
	local list = items[player]
	if not list or #list >= Config.BAG_SLOTS then
		return false
	end
	table.insert(list, itemId)
	sync(player)
	return true
end

function Inventory.hasRoom(player: Player): boolean
	local list = items[player]
	return list ~= nil and #list < Config.BAG_SLOTS
end

-- Removes the item at `index` only if it is still `itemId` (the client's view can be stale).
function Inventory.remove(player: Player, index: number, itemId: string): boolean
	local list = items[player]
	if not list or list[index] ~= itemId then
		return false
	end
	table.remove(list, index)
	sync(player)
	return true
end

-- Going on duty: the personal bag is put away and replaced by the police kit.
function Inventory.lockAway(player: Player, kit: { string })
	lockedAway[player] = items[player]
	items[player] = table.clone(kit)
	sync(player)
end

-- Going off duty: the kit is dropped and the personal bag comes back.
function Inventory.restore(player: Player)
	items[player] = lockedAway[player] or {}
	lockedAway[player] = nil
	sync(player)
end

function Inventory.start()
	local function onJoin(player: Player)
		items[player] = table.clone(Config.STARTING_ITEMS)
		player:SetAttribute("Cash", 0)
		sync(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		items[player] = nil
		lockedAway[player] = nil
	end)
end

return Inventory
