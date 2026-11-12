-- Per-player bag contents, kept on the server.
-- An entry is { id = itemId, amount = n? }. Stackable items (cash) share one slot.
-- shortcut: in memory only and 1 item = 1 slot; DataStore and the grid come in later milestones.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

export type Entry = { id: string, amount: number? }

local Inventory = {}

local items: { [Player]: { Entry } } = {}
local lockedAway: { [Player]: { Entry } } = {}

local function entries(ids: { string }): { Entry }
	local list = {}
	for _, id in ids do
		table.insert(list, { id = id })
	end
	return list
end

local function sync(player: Player)
	local cash = 0
	for _, entry in items[player] do
		if entry.id == "Money" then
			cash += entry.amount or 0
		end
	end
	player:SetAttribute("Cash", cash) -- display only; the bag is the source of truth
	Remotes.InventoryChanged:FireClient(player, items[player], Config.BAG_SLOTS)
end

local function findStack(list: { Entry }, id: string): Entry?
	if not Config.Items[id].stackable then
		return nil
	end
	for _, entry in list do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function Inventory.canAdd(player: Player, entry: Entry): boolean
	local list = items[player]
	return list ~= nil and (#list < Config.BAG_SLOTS or findStack(list, entry.id) ~= nil)
end

function Inventory.add(player: Player, entry: Entry): boolean
	if not Inventory.canAdd(player, entry) then
		return false
	end
	local list = items[player]
	local stack = findStack(list, entry.id)
	if stack then
		stack.amount = (stack.amount or 0) + (entry.amount or 0)
	else
		table.insert(list, table.clone(entry))
	end
	sync(player)
	return true
end

-- Removes the entry at `index` only if it is still `itemId` (the client's view can be stale).
function Inventory.remove(player: Player, index: number, itemId: string): Entry?
	local list = items[player]
	if not list or not list[index] or list[index].id ~= itemId then
		return nil
	end
	local entry = table.remove(list, index)
	sync(player)
	return entry
end

-- Going on duty: the personal bag is put away and replaced by the police kit.
function Inventory.lockAway(player: Player, kit: { string })
	lockedAway[player] = items[player]
	items[player] = entries(kit)
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
		items[player] = entries(Config.STARTING_ITEMS)
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
