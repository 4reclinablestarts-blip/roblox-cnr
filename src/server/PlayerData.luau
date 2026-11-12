-- Saved player data, shared by every place in the experience.
-- If loading fails (or Studio has no API access) the player plays with defaults and nothing is saved,
-- so a bad load can never overwrite real data.
-- shortcut: no session locking; a save right before each teleport keeps places from racing in practice.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local PlayerData = {}

export type Data = {
	bag: { any },
	stash: { any }, -- hub stash
	policeStash: { any }, -- a cop's share of arrests
	unlocks: { [string]: boolean },
	cars: { [string]: { trunk: { any }, deployedIn: string? } },
	car: string, -- selected car
	home: { district: string, code: string, plot: number }?,
	leftRaids: { string }, -- access codes of raids this player already left
}

local function defaults(): Data
	local bag = {}
	for _, id in Config.STARTING_ITEMS do
		table.insert(bag, { id = id, amount = Config.Items[id].defaultAmount })
	end
	return {
		bag = bag,
		stash = {},
		policeStash = {},
		unlocks = {},
		cars = { Rental = { trunk = {} } },
		car = "Rental",
		home = nil,
		leftRaids = {},
	}
end

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("PlayerData_v1")
end)

local cache: { [Player]: Data } = {}
local canSave: { [Player]: boolean } = {}
local teleporting: { [Player]: boolean } = {}

local function key(player: Player): string
	return `player_{player.UserId}`
end

-- Yields until the player's data is loaded. Nil if they left first.
function PlayerData.get(player: Player): Data?
	while not cache[player] and player.Parent do
		task.wait()
	end
	return cache[player]
end

function PlayerData.save(player: Player)
	local data = cache[player]
	if not data or not canSave[player] or not store then
		return
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key(player), function()
			return data
		end)
	end)
	if not ok then
		warn(`Saving {player.Name} failed: {err}`)
	end
end

-- Saves now and skips the save on leave, so the next place loads fresh data.
function PlayerData.saveForTeleport(player: Player)
	PlayerData.save(player)
	teleporting[player] = true
end

function PlayerData.teleportFailed(player: Player)
	teleporting[player] = nil
end

local function load(player: Player)
	local data: Data? = nil
	local ok = false
	if store then
		ok = pcall(function()
			data = (store :: DataStore):GetAsync(key(player))
		end)
	end
	local fresh = defaults()
	if ok and data then
		for field, value in fresh :: any do -- fields added after the player's last save
			if (data :: any)[field] == nil then
				(data :: any)[field] = value
			end
		end
	end
	canSave[player] = ok
	if not ok then
		warn(`Couldn't load {player.Name}'s data; playing with defaults and not saving.`)
	end
	cache[player] = if ok and data then data else fresh
end

function PlayerData.start()
	Players.PlayerAdded:Connect(load)
	for _, player in Players:GetPlayers() do
		task.spawn(load, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		if not teleporting[player] then
			PlayerData.save(player)
		end
		cache[player] = nil
		canSave[player] = nil
		teleporting[player] = nil
	end)
	game:BindToClose(function()
		local pending = 0
		for player in cache do
			pending += 1
			task.spawn(function()
				PlayerData.save(player)
				pending -= 1
			end)
		end
		while pending > 0 do
			task.wait()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60)
			for player in cache do
				task.spawn(PlayerData.save, player)
			end
		end
	end)
end

return PlayerData
