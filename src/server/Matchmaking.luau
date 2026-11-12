-- Finding a server for a party. Raids and the Sales Center are reserved servers that list
-- themselves in a MemoryStore sorted map per kind (see advertise). Joining picks a random listed
-- server with room, for raids preferring similar gear value (skill = gear value until player
-- levels exist) and never one a party member already left. If nothing fits, a new one is made.
local MemoryStoreService = game:GetService("MemoryStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Places = require(script.Parent.Places)
local PlayerData = require(script.Parent.PlayerData)
local Roles = require(script.Parent.Roles)

local Matchmaking = {}

local MAX_PLAYERS = { Raid = Config.RAID_MAX_PLAYERS, Sales = Config.SALES_MAX_PLAYERS }

local maps: { [string]: MemoryStoreSortedMap } = {}
function Matchmaking.map(kind: string): MemoryStoreSortedMap
	maps[kind] = maps[kind] or MemoryStoreService:GetSortedMap(`Servers_{kind}`)
	return maps[kind]
end

export type Listing = { code: string, players: number, startedAt: number, skill: number }

-- Picks a server code, or nil to make a new one. `left` holds codes any party member already left.
-- `expires`: servers this old (seconds) are about to end and get skipped.
function Matchmaking.pick(
	listings: { Listing },
	partySize: number,
	skill: number,
	left: { [string]: boolean },
	now: number,
	maxPlayers: number,
	expires: number?
): string?
	local open = {}
	for _, listing in listings do
		if
			listing.players + partySize <= maxPlayers
			and (not expires or now - listing.startedAt < expires)
			and not left[listing.code]
		then
			table.insert(open, listing)
		end
	end
	if #open == 0 then
		return nil
	end
	table.sort(open, function(a, b)
		return math.abs(a.skill - skill) < math.abs(b.skill - skill)
	end)
	-- Random among the servers close enough in skill; otherwise the closest one.
	local close = {}
	for _, listing in open do
		if math.abs(listing.skill - skill) <= Config.SKILL_TOLERANCE then
			table.insert(close, listing)
		end
	end
	if #close > 0 then
		return close[math.random(#close)].code
	end
	return open[1].code
end

-- Sends the players to a "Raid" or "Sales" server. Returns false if travel isn't possible (Studio).
function Matchmaking.join(players: { Player }, kind: string, partyId: number?): boolean
	if not Places.canTeleport() then
		return false
	end

	local left: { [string]: boolean } = {}
	local skill = 0
	local cars = {}
	for _, player in players do
		local data = PlayerData.get(player)
		if data and kind == "Raid" then
			for _, code in data.leftRaids do
				left[code] = true
			end
		end
		skill += Inventory.value(Inventory.get(player))
		cars[tostring(player.UserId)] = player:GetAttribute("CarToBring")
	end
	skill = if kind == "Raid" then skill / math.max(1, #players) else 0

	local listings = {}
	pcall(function()
		for _, item in Matchmaking.map(kind):GetRangeAsync(Enum.SortDirection.Ascending, 100) do
			local value = item.value
			table.insert(listings, {
				code = item.key,
				players = value.players,
				startedAt = value.startedAt,
				skill = value.skill,
			})
		end
	end)

	local expires = if kind == "Raid" then Config.RAID_DURATION - Config.RAID_JOIN_CUTOFF else nil
	local code = Matchmaking.pick(listings, #players, skill, left, os.time(), MAX_PLAYERS[kind], expires)
		or Places.reserve()
	if not code then
		return false
	end
	return Places.teleport(players, kind, { party = partyId, cars = cars }, code)
end

local advertising = false

-- Keeps this reserved server listed for matchmaking: players, cops and average gear value.
function Matchmaking.advertise()
	local code = Places.code
	if not code or advertising then
		return
	end
	advertising = true
	local startedAt = os.time()
	task.spawn(function()
		while advertising do
			local players = Players:GetPlayers()
			local cops, skill = 0, 0
			for _, player in players do
				if Roles.isPolice(player) then
					cops += 1
				end
				skill += Inventory.value(Inventory.get(player))
			end
			pcall(function()
				Matchmaking.map(Places.kind):SetAsync(code, {
					players = #players,
					cops = cops,
					skill = skill / math.max(1, #players),
					startedAt = startedAt,
				}, 60)
			end)
			task.wait(15)
		end
	end)
end

function Matchmaking.stopAdvertising()
	advertising = false
	local code = Places.code
	if code then
		pcall(function()
			Matchmaking.map(Places.kind):RemoveAsync(code)
		end)
	end
end

do -- self-check
	local now = 10000
	local listings = {
		{ code = "full", players = 24, startedAt = now, skill = 0 },
		{ code = "old", players = 1, startedAt = now - 3500, skill = 0 },
		{ code = "left", players = 1, startedAt = now, skill = 0 },
		{ code = "far", players = 1, startedAt = now, skill = 9000 },
		{ code = "good", players = 5, startedAt = now, skill = 100 },
	}
	assert(Matchmaking.pick(listings, 2, 0, { left = true }, now, 25, 3000) == "good", "matchmaking pick")
	assert(Matchmaking.pick({}, 1, 0, {}, now, 25) == nil, "no servers")
end

return Matchmaking
