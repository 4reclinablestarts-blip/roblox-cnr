-- A neighbourhood server: up to HOMES_PER_NEIGHBOURHOOD homes in a row, each with a door and a stash.
-- The owner uses their stash freely. Anyone else has to break the door in first (a Crowbar is needed
-- from security 1 up) and can then take everything. Home security from the tech tree also
-- sends the owner an alarm wherever they are. Raiding works while the owner is offline.
-- Each home's stash is saved under its own key, written only by its neighbourhood server.
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Looting = require(script.Parent.Looting)
local Neighbourhoods = require(script.Parent.Neighbourhoods)
local Places = require(script.Parent.Places)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = ReplicatedStorage.Remotes

local Housing = {}

local homeStore: DataStore? = nil
local playerStore: DataStore? = nil
pcall(function()
	homeStore = DataStoreService:GetDataStore("Homes_v1")
	playerStore = DataStoreService:GetDataStore("PlayerData_v1")
end)

type Home = {
	ownerId: number,
	stash: { any },
	security: number,
	brokenUntil: number,
	canSave: boolean,
}

local homes: { [number]: Home } = {}
local district = "Dustbowl"
local started = false

local function securityOf(ownerId: number): number
	local unlocks = {}
	local owner = Players:GetPlayerByUserId(ownerId)
	if owner then
		local data = PlayerData.get(owner)
		unlocks = data and data.unlocks or {}
	elseif playerStore then
		pcall(function()
			local data = (playerStore :: DataStore):GetAsync(`player_{ownerId}`)
			unlocks = data and data.unlocks or {}
		end)
	end
	return if unlocks.HomeSecurity2 then 2 elseif unlocks.HomeSecurity1 then 1 else 0
end

local function loadHome(ownerId: number): Home
	local stash, ok = {}, homeStore ~= nil
	if homeStore then
		ok = pcall(function()
			local saved = (homeStore :: DataStore):GetAsync(`home_{ownerId}`)
			stash = saved and saved.stash or {}
		end)
	end
	return {
		ownerId = ownerId,
		stash = stash,
		security = securityOf(ownerId),
		brokenUntil = 0,
		canSave = ok,
	}
end

local function saveHome(home: Home)
	if not home.canSave or not homeStore then
		return
	end
	pcall(function()
		(homeStore :: DataStore):SetAsync(`home_{home.ownerId}`, { stash = home.stash })
	end)
end

local function part(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	p.Parent = parent
	return p
end

local function isOpen(home: Home): boolean
	return os.clock() < home.brokenUntil
end

local function buildHome(home: Home, plot: number)
	local origin = CFrame.new((plot - 1) * 60 - 210, 0, -60)
	local model = Instance.new("Model")
	model.Name = `Home {plot}`

	part(model, "Plot", Vector3.new(50, 1, 50), origin * CFrame.new(0, 0.5, 0), Color3.fromRGB(110, 140, 90))
	local walls =
		part(model, "Trailer", Vector3.new(30, 10, 14), origin * CFrame.new(0, 6, -8), Color3.fromRGB(200, 190, 170))
	walls.Transparency = 0.5
	walls.CanCollide = false -- placeholder shell: the door is what keeps raiders out of the stash
	local door = part(model, "Door", Vector3.new(4, 8, 1), origin * CFrame.new(0, 5, -0.5), Color3.fromRGB(110, 70, 40))
	local stashPart =
		part(model, "Home stash", Vector3.new(4, 3, 3), origin * CFrame.new(0, 2.5, -10), Color3.fromRGB(90, 70, 50))

	local sign = Instance.new("BillboardGui")
	sign.Size = UDim2.fromOffset(220, 30)
	sign.StudsOffset = Vector3.new(0, 8, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.TextScaled = true
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.Text = `Home {plot} (security {home.security})`
	label.Parent = sign
	sign.Parent = walls
	task.spawn(function()
		local ok, name = pcall(Players.GetNameFromUserIdAsync, Players, home.ownerId)
		if ok then
			label.Text = `{name}'s home (security {home.security})`
		end
	end)

	-- Breaking in: hold on the door. The alarm goes off as soon as someone starts.
	local breakIn = Instance.new("ProximityPrompt")
	breakIn.ActionText = "Break in"
	breakIn.ObjectText = `Door (security {home.security})`
	breakIn.HoldDuration = Config.BREAK_IN_TIME * (1 + home.security)
	breakIn.RequiresLineOfSight = false
	breakIn:SetAttribute("HideForUserId", home.ownerId)
	breakIn.PromptButtonHoldBegan:Connect(function(player)
		if player.UserId ~= home.ownerId and home.security >= 1 and not isOpen(home) then
			Places.notifyAnywhere(home.ownerId, `ALARM: someone is breaking into your home in {district}!`)
		end
	end)
	breakIn.Triggered:Connect(function(player)
		if player.UserId == home.ownerId or isOpen(home) then
			return
		end
		if home.security >= 1 and Inventory.count(player, "Crowbar") == 0 then
			Remotes.Notify:FireClient(player, "This door needs a Crowbar (Motel shop).")
			return
		end
		home.brokenUntil = os.clock() + 300
		door.Transparency = 0.8
		door.CanCollide = false
		Remotes.Notify:FireClient(player, "The door is open. The stash is inside.")
		task.delay(300, function()
			door.Transparency = 0
			door.CanCollide = true
		end)
	end)
	breakIn.Parent = door

	Looting.personalStashes[stashPart] = {
		items = function(player: Player)
			return if player.UserId == home.ownerId or isOpen(home) then home.stash else nil
		end,
		capacity = Config.HOME_STASH_SLOTS,
		canPut = function(player: Player)
			return player.UserId == home.ownerId
		end,
	}
	local open = Instance.new("ProximityPrompt")
	open.ActionText = "Open stash"
	open.ObjectText = `Home stash ({Config.HOME_STASH_SLOTS} slots)`
	open.RequiresLineOfSight = false
	open.Triggered:Connect(function(player)
		local owner = player.UserId == home.ownerId
		if owner or isOpen(home) then
			Remotes.OpenStash:FireClient(player, stashPart, home.stash, owner)
		else
			Remotes.Notify:FireClient(player, "Locked. Break the door in first.")
		end
	end)
	open.Parent = stashPart

	model.Parent = workspace
end

-- Builds the neighbourhood once the first player tells us which one this server is.
local function setup(player: Player)
	if started then
		return
	end
	started = true
	local joinData = Places.joinData(player)
	local owners: { number } = {}
	if type(joinData.district) == "string" and type(joinData.code) == "string" then
		district = joinData.district
		for _, neighbourhood in Neighbourhoods.list(district) do
			if neighbourhood.code == joinData.code then
				owners = neighbourhood.homes
			end
		end
	else
		owners = { player.UserId } -- Studio test: the first player owns plot 1
	end
	for plot, ownerId in owners do
		local home = loadHome(ownerId)
		homes[ownerId] = home
		buildHome(home, plot)
	end
end

function Housing.start()
	Players.PlayerAdded:Connect(setup)
	for _, player in Players:GetPlayers() do
		setup(player)
	end
	-- shortcut: saves every home every 15 s; track changes if DataStore budgets get tight.
	task.spawn(function()
		while true do
			task.wait(15)
			for _, home in homes do
				saveHome(home)
			end
		end
	end)
	game:BindToClose(function()
		for _, home in homes do
			saveHome(home)
		end
	end)
end

return Housing
