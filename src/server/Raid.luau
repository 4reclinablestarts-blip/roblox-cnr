-- Leaving a place after death, arrest or extraction, and the raid's own lifecycle:
-- listing itself for matchmaking, party friendly fire info, and the 1-hour end.
-- Without teleports (Studio / unpublished) leaving falls back to respawning here.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Cars = require(script.Parent.Cars)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Matchmaking = require(script.Parent.Matchmaking)
local Places = require(script.Parent.Places)
local PlayerData = require(script.Parent.PlayerData)
local Roles = require(script.Parent.Roles)
local Travel = require(script.Parent.Travel)
local Remotes = ReplicatedStorage.Remotes

local Raid = {}

Raid.code = nil :: string? -- this raid's reserved server access code
Raid.startedAt = os.time()

local leaving: { [Player]: boolean } = {}

-- how: "out" (died / arrested: straight to the Motel), "extract" or "raidEnd" (world map).
function Raid.leave(player: Player, reason: string, keepItems: boolean, how: string?)
	-- Touched fires many times in one step; only the first one counts.
	if leaving[player] then
		return
	end
	leaving[player] = true
	task.delay(1, function()
		leaving[player] = nil
	end)

	local data = PlayerData.get(player)
	if data and Raid.code and not table.find(data.leftRaids, Raid.code) then
		table.insert(data.leftRaids, Raid.code)
		if #data.leftRaids > 30 then
			table.remove(data.leftRaids, 1)
		end
	end
	Roles.reset(player)
	if not keepItems then
		Inventory.takeAll(player) -- usually already empty: dropped in a bag or confiscated
	end
	Remotes.Notify:FireClient(player, reason)

	if how == "extract" or how == "raidEnd" then
		Travel.open(player, how)
		return
	end
	if Places.teleport({ player }, "Hub") then
		return
	end
	-- Testing without teleports: respawn here. Hand back the starter kit so testing can go on.
	if RunService:IsStudio() and #Inventory.get(player) == 0 then
		for _, id in Config.STARTING_ITEMS do
			Inventory.add(player, { id = id, amount = Config.Items[id].defaultAmount })
		end
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		player:LoadCharacter()
	end
end

-- Map border (parts tagged "RaidBorder"): walking or driving into it extracts you with your bag.
-- Downed and surrendered players can't escape that way.
local function setupBorder(part: BasePart)
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		local player = character and Players:GetPlayerFromCharacter(character)
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if
			player
			and humanoid
			and humanoid.Health > 0
			and not player:GetAttribute("Downed")
			and not player:GetAttribute("Surrendered")
		then
			Raid.leave(player, "You extracted with everything you carried.", true, "extract")
		end
	end)
end

-- Keeps this server listed for matchmaking: player count, cops and average gear value.
local function advertise()
	while Raid.code do
		local players = Players:GetPlayers()
		local cops, skill = 0, 0
		for _, player in players do
			if Roles.isPolice(player) then
				cops += 1
			end
			skill += Inventory.value(Inventory.get(player))
		end
		pcall(function()
			Matchmaking.raids:SetAsync(Raid.code, {
				players = #players,
				cops = cops,
				skill = skill / math.max(1, #players),
				startedAt = Raid.startedAt,
			}, 60)
		end)
		task.wait(15)
	end
end

local function endRaid()
	local code = Raid.code
	Raid.code = nil -- stops advertising
	if code then
		pcall(function()
			Matchmaking.raids:RemoveAsync(code)
		end)
	end
	for _, player in Players:GetPlayers() do
		Raid.leave(player, "The raid is over.", true, "raidEnd")
	end
	-- Anyone who hasn't picked hub or home by then goes to the Motel.
	task.wait(Config.MAP_CHOICE_TIME)
	for _, player in Players:GetPlayers() do
		Places.teleport({ player }, "Hub")
	end
end

function Raid.start()
	CollectionService:GetInstanceAddedSignal("RaidBorder"):Connect(setupBorder)
	for _, part in CollectionService:GetTagged("RaidBorder") do
		setupBorder(part)
	end

	local function onJoin(player: Player)
		local joinData = Places.joinData(player)
		-- The reserved server doesn't know its own access code; the first arrival brings it.
		if not Raid.code and type(joinData.accessCode) == "string" then
			Raid.code = joinData.accessCode
			Cars.raidCode = joinData.accessCode
			task.spawn(advertise)
		end
		if joinData.party then
			player:SetAttribute("PartyId", joinData.party)
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end

	task.delay(Config.RAID_DURATION, endRaid)
end

return Raid
