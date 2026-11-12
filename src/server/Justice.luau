-- Surrender, arrests, confiscation, bounties and the police station stash.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Combat = require(script.Parent.Combat)
local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Looting = require(script.Parent.Looting)
local Raid = require(script.Parent.Raid)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Justice = {}

-- A cop's share of arrests, collected at the police desk once off duty. Kept between raids.
-- shortcut: in memory only; moves to DataStore with the rest of player data.
local policeStash: { [Player]: { Inventory.Entry } } = {}

local function stashOf(player: Player): { Inventory.Entry }
	policeStash[player] = policeStash[player] or {}
	return policeStash[player]
end

local function addToStash(cop: Player, entry: Inventory.Entry)
	local stash = stashOf(cop)
	if entry.id == "Money" then
		for _, existing in stash do
			if existing.id == "Money" then
				existing.amount = (existing.amount or 0) + (entry.amount or 0)
				return
			end
		end
	end
	table.insert(stash, entry)
end

-- What a bag is worth in cash: item values times stack size, plus any cash in it.
function Justice.value(items: { Inventory.Entry }): number
	local total = 0
	for _, entry in items do
		if entry.id == "Money" then
			total += entry.amount or 0
		else
			total += Config.Items[entry.id].value * (entry.amount or 1)
		end
	end
	return total
end

local function arrest(cop: Player, criminal: Player)
	if
		not Roles.isPolice(cop)
		or cop:GetAttribute("Downed")
		or Roles.of(criminal) ~= "Criminal"
		or not (criminal:GetAttribute("Downed") or criminal:GetAttribute("Surrendered"))
	then
		return
	end

	local items = Inventory.takeAll(criminal)
	local level = criminal:GetAttribute("CriminalLevel") or 0
	local share = level >= Config.MAX_CRIMINAL_LEVEL and Config.ARREST_ITEM_SHARE_MAX_LEVEL or Config.ARREST_ITEM_SHARE
	local itemCount = 0
	for _, entry in items do
		if math.random() < share then
			addToStash(cop, entry)
			itemCount += 1
		end
	end
	local cash = math.floor(Justice.value(items) * Config.ARREST_CASH_SHARE)
	if criminal:GetAttribute("Wanted") then
		cash += Config.WANTED_BOUNTY
	end
	if cash > 0 then
		addToStash(cop, { id = "Money", amount = cash })
	end

	Remotes.Notify:FireClient(
		cop,
		`Arrested {criminal.DisplayName}: {itemCount} items and ${cash} go to your police station stash (collect it off duty).`
	)
	Combat.clearDowned(criminal)
	Raid.leave(criminal, "You were arrested. Everything you carried was confiscated.", false)
end

-- Downed or surrendered criminals get an Arrest prompt that only cops see.
local function updateArrestPrompt(player: Player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	local existing = root:FindFirstChild("Arrest")
	local arrestable = Roles.of(player) == "Criminal"
		and (player:GetAttribute("Downed") or player:GetAttribute("Surrendered"))
	if arrestable and not existing then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Arrest"
		prompt.ActionText = "Arrest"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Config.ARREST_TIME
		prompt.KeyboardKeyCode = Enum.KeyCode.F
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ShowFor", "Police")
		prompt.Triggered:Connect(function(cop)
			arrest(cop, player)
		end)
		prompt.Parent = root
	elseif not arrestable and existing then
		existing:Destroy()
	end
end

local function surrender(player: Player)
	if Roles.of(player) ~= "Criminal" or player:GetAttribute("Downed") or player:GetAttribute("Surrendered") then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	-- Hands up: can't move, can't shoot, can't take it back.
	humanoid.WalkSpeed = 0
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	player:SetAttribute("Surrendered", true)
	Combat.refreshTools(player)
	Remotes.Notify:FireClient(player, "Hands up. A cop can arrest you now.")
end

local function setupDesk(desk: BasePart)
	Looting.personalStashes[desk] = stashOf

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Police station stash"
	prompt.ObjectText = "Police desk"
	prompt.KeyboardKeyCode = Enum.KeyCode.G
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("ShowFor", "Civilian")
	prompt.Triggered:Connect(function(player)
		if Looting.inRange(player, desk) then
			Remotes.OpenStash:FireClient(player, desk, stashOf(player))
		end
	end)
	local spot = Instance.new("Attachment")
	spot.Position = Vector3.new(0, 3, 0) -- above the loadout prompts
	spot.Parent = desk
	prompt.Parent = spot
end

function Justice.start()
	local function onJoin(player: Player)
		for _, attribute in { "Downed", "Surrendered" } do
			player:GetAttributeChangedSignal(attribute):Connect(function()
				updateArrestPrompt(player)
			end)
		end
		player:GetPropertyChangedSignal("Team"):Connect(function()
			updateArrestPrompt(player)
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		policeStash[player] = nil
	end)

	Remotes.Surrender.OnServerEvent:Connect(surrender)

	CollectionService:GetInstanceAddedSignal("PoliceDesk"):Connect(setupDesk)
	for _, desk in CollectionService:GetTagged("PoliceDesk") do
		setupDesk(desk)
	end
end

assert(
	Justice.value({ { id = "Watch" }, { id = "Money", amount = 50 }, { id = "PistolAmmo", amount = 10 } }) == 140,
	"bag value"
)

return Justice
