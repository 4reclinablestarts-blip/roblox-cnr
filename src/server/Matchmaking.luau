-- Puts a party into a random Looty Bay server, preferring servers with similar gear value
-- (skill = gear value until player levels exist). Raid servers list themselves in a MemoryStore
-- sorted map (see Raid.luau); if nothing fits, a new reserved server is made.
local MemoryStoreService = game:GetService("MemoryStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Places = require(script.Parent.Places)
local PlayerData = require(script.Parent.PlayerData)

local Matchmaking = {}

Matchmaking.raids = MemoryStoreService:GetSortedMap("Raids_LootyBay")

export type Listing = { code: string, players: number, startedAt: number, skill: number }

-- Picks a server code, or nil to make a new one. `left` holds codes any party member already left.
function Matchmaking.pick(
	listings: { Listing },
	partySize: number,
	skill: number,
	left: { [string]: boolean },
	now: number
): string?
	local open = {}
	for _, listing in listings do
		if
			listing.players + partySize <= Config.RAID_MAX_PLAYERS
			and now - listing.startedAt < Config.RAID_DURATION - Config.RAID_JOIN_CUTOFF
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

-- Sends the party to a raid. Returns false if travel isn't possible (Studio / unpublished).
function Matchmaking.join(players: { Player }, partyId: number?): boolean
	if not Places.canTeleport("Raid") then
		return false
	end

	local left: { [string]: boolean } = {}
	local skill = 0
	local cars = {}
	for _, player in players do
		local data = PlayerData.get(player)
		if data then
			for _, code in data.leftRaids do
				left[code] = true
			end
		end
		skill += Inventory.value(Inventory.get(player))
		cars[tostring(player.UserId)] = player:GetAttribute("CarToBring")
	end
	skill /= math.max(1, #players)

	local listings = {}
	pcall(function()
		for _, item in Matchmaking.raids:GetRangeAsync(Enum.SortDirection.Ascending, 100) do
			local value = item.value
			table.insert(listings, {
				code = item.key,
				players = value.players,
				startedAt = value.startedAt,
				skill = value.skill,
			})
		end
	end)

	local code = Matchmaking.pick(listings, #players, skill, left, os.time()) or Places.reserve("Raid")
	if not code then
		return false
	end
	return Places.teleport(players, "Raid", { accessCode = code, party = partyId, cars = cars }, code)
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
	assert(Matchmaking.pick(listings, 2, 0, { left = true }, now) == "good", "matchmaking pick")
	assert(Matchmaking.pick({}, 1, 0, {}, now) == nil, "no servers")
end

return Matchmaking
