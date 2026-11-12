-- Per-player bag, kept on the server and saved through PlayerData.
-- An entry is { id = itemId, amount = n?, x = col, y = row }. The bag is a grid (see Shared.Grid);
-- stackable items (cash, ammo) merge into one stack.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = ReplicatedStorage.Remotes

export type Entry = { id: string, amount: number?, x: number?, y: number? }

local Inventory = {}
Inventory.onChanged = nil :: ((Player) -> ())? -- set by Combat to keep weapon tools in sync

-- The bag in use. Normally the saved bag itself; a cop on duty carries the police kit instead.
local items: { [Player]: { Entry } } = {}

function Inventory.bagSize(player: Player): (number, number)
	local level = player:GetAttribute("BagLevel") or 1
	local size = Config.BagSizes[level] or Config.BagSizes[1]
	return size[1], size[2]
end

local function sync(player: Player)
	local list = items[player]
	if not list then
		return
	end
	local cash = 0
	for _, entry in list do
		if entry.id == "Money" then
			cash += entry.amount or 0
		end
	end
	player:SetAttribute("Cash", cash) -- display only; the bag is the source of truth
	local cols, rows = Inventory.bagSize(player)
	Remotes.InventoryChanged:FireClient(player, list, cols, rows)
	if Inventory.onChanged then
		Inventory.onChanged(player)
	end
end
Inventory.sync = sync

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

-- Where `entry` would go in the bag: a stack to merge into, or a free spot. Nil if it doesn't fit.
local function placement(player: Player, entry: Entry): (Entry?, number?, number?)
	local list = items[player]
	if not list then
		return nil
	end
	local stack = findStack(list, entry.id)
	if stack then
		return stack
	end
	local cols, rows = Inventory.bagSize(player)
	local w, h = Grid.size(entry.id)
	return nil, Grid.findSpot(list, cols, rows, w, h)
end

function Inventory.canAdd(player: Player, entry: Entry): boolean
	local stack, x = placement(player, entry)
	return stack ~= nil or x ~= nil
end

function Inventory.add(player: Player, entry: Entry): boolean
	local stack, x, y = placement(player, entry)
	if stack then
		stack.amount = (stack.amount or 0) + (entry.amount or 0)
	elseif x then
		table.insert(items[player], { id = entry.id, amount = entry.amount, x = x, y = y })
	else
		return false
	end
	sync(player)
	return true
end

-- What a list of items is worth in cash: item values times stack size, plus any cash in it.
function Inventory.value(list: { Entry }): number
	local total = 0
	for _, entry in list do
		if entry.id == "Money" then
			total += entry.amount or 0
		else
			total += Config.Items[entry.id].value * (entry.amount or 1)
		end
	end
	return total
end

function Inventory.get(player: Player): { Entry }
	return items[player] or {}
end

-- Removes the entry at `index` only if it is still `itemId` (the client's view can be stale).
function Inventory.remove(player: Player, index: number, itemId: string): Entry?
	local list = items[player]
	if not list or not list[index] or list[index].id ~= itemId then
		return nil
	end
	local entry = table.remove(list, index)
	sync(player)
	return { id = entry.id, amount = entry.amount }
end

-- Moves a bag item to another cell (drag inside the bag).
function Inventory.move(player: Player, index: number, itemId: string, x: number, y: number): boolean
	local list = items[player]
	local entry = list and list[index]
	if not entry or entry.id ~= itemId then
		return false
	end
	local cols, rows = Inventory.bagSize(player)
	local w, h = Grid.size(itemId)
	if not Grid.fits(list, cols, rows, w, h, x, y, entry) then
		return false
	end
	entry.x, entry.y = x, y
	sync(player)
	return true
end

-- Uses up `amount` from a stack (ammo, cash). Returns false if there isn't enough.
function Inventory.consume(player: Player, itemId: string, amount: number): boolean
	local list = items[player]
	local stack = list and findStack(list, itemId)
	if not stack or (stack.amount or 0) < amount then
		return false
	end
	stack.amount -= amount
	if stack.amount <= 0 then
		table.remove(list, table.find(list, stack))
	end
	sync(player)
	return true
end

function Inventory.count(player: Player, itemId: string): number
	local total = 0
	for _, entry in Inventory.get(player) do
		if entry.id == itemId then
			total += entry.amount or 1
		end
	end
	return total
end

-- Empties the bag and returns what was in it (death bags, confiscation).
function Inventory.takeAll(player: Player): { Entry }
	local list = items[player]
	if not list then
		return {}
	end
	local taken = {}
	for _, entry in list do
		table.insert(taken, { id = entry.id, amount = entry.amount })
	end
	table.clear(list) -- keep the table: it is the saved bag
	sync(player)
	return taken
end

-- Going on duty: the personal bag stays saved and untouched; the cop carries the police kit.
function Inventory.lockAway(player: Player, kit: { string })
	items[player] = {}
	for _, id in kit do
		Inventory.add(player, { id = id, amount = Config.Items[id].defaultAmount })
	end
	sync(player)
end

-- Going off duty: the kit is dropped and the personal bag comes back.
function Inventory.restore(player: Player)
	local data = PlayerData.get(player)
	items[player] = data and data.bag or {}
	sync(player)
end

function Inventory.refreshBagLevel(player: Player)
	local data = PlayerData.get(player)
	if not data then
		return
	end
	local level = 1
	for i = 2, #Config.BagSizes do
		if data.unlocks[`BagL{i}`] then
			level = i
		end
	end
	player:SetAttribute("BagLevel", level)
	sync(player)
end

-- Starting items (and anything saved before the grid existed) have no cell yet.
local function placeUnplaced(player: Player, list: { Entry })
	local cols, rows = Inventory.bagSize(player)
	for _, entry in list do
		if not entry.x then
			local w, h = Grid.size(entry.id)
			entry.x, entry.y = Grid.findSpot(list, cols, rows, w, h)
		end
	end
end

function Inventory.start()
	local function onJoin(player: Player)
		local data = PlayerData.get(player)
		if not data then
			return
		end
		items[player] = data.bag
		Inventory.refreshBagLevel(player)
		placeUnplaced(player, data.bag)
		sync(player)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		items[player] = nil
	end)
end

return Inventory
