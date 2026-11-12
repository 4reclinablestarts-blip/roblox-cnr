-- Cars: spawning, arriving in a place in your car, trunks, lockpicking and recall.
-- In a raid a car stays behind when you leave without it (its trunk with it) until you recall it
-- from the Motel; recalling drops the trunk in a bag where the car was.
-- Driving itself runs on the driver's client (client/Driving.luau).
local CollectionService = game:GetService("CollectionService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Detection = require(script.Parent.Detection)
local Inventory = require(script.Parent.Inventory)
local Looting = require(script.Parent.Looting)
local Places = require(script.Parent.Places)
local PlayerData = require(script.Parent.PlayerData)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Cars = {}

type Car = { model: Model, carId: string, ownerId: number, trunk: { any }, granted: { [Player]: boolean } }

local cars: { [number]: Car } = {} -- by owner UserId; one car per player per server

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = a, b
	w.Parent = a
end

local function part(model: Model, size: Vector3, cframe: CFrame, color: Color3, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cframe
	p.Color = color
	if shape then
		p.Shape = shape
	end
	p.Parent = model
	return p
end

function Cars.security(unlocks: { [string]: boolean }): number
	return if unlocks.CarSecurity2 then 2 elseif unlocks.CarSecurity1 then 1 else 0
end

local function build(carId: string, owner: Player, cframe: CFrame): Model
	local def = Config.Cars[carId]
	local model = Instance.new("Model")
	model.Name = `{owner.DisplayName}'s {def.name}`

	-- A frictionless slab the driver's client pushes around; the rest is welded on for looks.
	local chassis = part(model, Vector3.new(6, 1.6, 11), cframe, def.color)
	chassis.Name = "Chassis"
	chassis.CustomPhysicalProperties = PhysicalProperties.new(0.7, 0, 0, 100, 1)
	local cabin =
		part(model, Vector3.new(5.6, 2.2, 5), cframe * CFrame.new(0, 1.9, 0.5), def.color:Lerp(Color3.new(), 0.3))
	cabin.Transparency = 0.2
	weld(chassis, cabin)
	for _, offset in
		{
			Vector3.new(-3, -0.6, -3.6),
			Vector3.new(3, -0.6, -3.6),
			Vector3.new(-3, -0.6, 3.6),
			Vector3.new(3, -0.6, 3.6),
		}
	do
		local wheel = part(
			model,
			Vector3.new(1, 2.4, 2.4),
			cframe * CFrame.new(offset),
			Color3.fromRGB(25, 25, 25),
			Enum.PartType.Cylinder
		)
		wheel.CanCollide = false
		weld(chassis, wheel)
	end

	local seat = Instance.new("VehicleSeat")
	seat.Size = Vector3.new(2, 1, 2)
	seat.CFrame = cframe * CFrame.new(-1.2, 1.3, 0.5)
	seat.HeadsUpDisplay = false
	seat.MaxSpeed = def.speed
	seat.Parent = model
	weld(chassis, seat)

	-- Keeps the car upright.
	local up = Instance.new("Attachment")
	up.Axis = Vector3.yAxis
	up.Parent = chassis
	local align = Instance.new("AlignOrientation")
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.AlignType = Enum.AlignType.PrimaryAxisParallel
	align.PrimaryAxis = Vector3.yAxis
	align.Attachment0 = up
	align.MaxTorque = 1e7
	align.Responsiveness = 20
	align.Parent = chassis

	model.PrimaryPart = chassis
	model:SetAttribute("CarId", carId)
	model:SetAttribute("OwnerId", owner.UserId)
	model:SetAttribute("Speed", def.speed)

	-- Parked cars are anchored; the driver's client gets physics while someone sits in it.
	chassis.Anchored = true
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occupant = seat.Occupant
		local driver = occupant and Players:GetPlayerFromCharacter(occupant.Parent)
		chassis.Anchored = driver == nil
		if driver then
			chassis:SetNetworkOwner(driver)
		end
	end)
	return model
end

local function trunkPrompt(car: Car)
	local chassis = car.model.PrimaryPart :: BasePart
	local spot = Instance.new("Attachment")
	spot.Position = Vector3.new(0, 1, 5.5)
	spot.Parent = chassis

	local owner = Instance.new("ProximityPrompt")
	owner.ActionText = "Open trunk"
	owner.ObjectText = car.model.Name
	owner.RequiresLineOfSight = false
	owner:SetAttribute("ShowForUserId", car.ownerId)
	owner.Triggered:Connect(function(player)
		if player.UserId == car.ownerId then
			Remotes.OpenStash:FireClient(player, chassis, car.trunk, true)
		end
	end)
	owner.Parent = spot

	local data = Players:GetPlayerByUserId(car.ownerId)
		and PlayerData.get(Players:GetPlayerByUserId(car.ownerId) :: Player)
	local security = data and Cars.security(data.unlocks) or 0
	car.model:SetAttribute("Security", security)

	local pick = Instance.new("ProximityPrompt")
	pick.ActionText = "Lockpick trunk"
	pick.ObjectText = `{car.model.Name} (security {security})`
	pick.HoldDuration = Config.LOCKPICK_TIME * (1 + security)
	pick.KeyboardKeyCode = Enum.KeyCode.R
	pick.RequiresLineOfSight = false
	pick:SetAttribute("HideForUserId", car.ownerId)
	pick.Triggered:Connect(function(player)
		if player.UserId == car.ownerId or Places.kind == "Hub" or Roles.isPolice(player) then
			return
		end
		if Inventory.count(player, "Lockpick") == 0 then
			Remotes.Notify:FireClient(player, "You need a Lockpick (Motel shop).")
			return
		end
		car.granted[player] = true
		Roles.makeCriminal(player)
		Detection.reportCrime(player)
		Remotes.OpenStash:FireClient(player, chassis, car.trunk, false)
	end)
	pick.Parent = spot

	Looting.personalStashes[chassis] = {
		items = function(player: Player)
			return if player.UserId == car.ownerId or car.granted[player] then car.trunk else nil
		end,
		capacity = Config.Cars[car.carId].trunkSlots,
		canPut = function(player: Player)
			return player.UserId == car.ownerId
		end,
	}
end

local function despawn(car: Car)
	cars[car.ownerId] = nil
	Looting.personalStashes[car.model.PrimaryPart :: BasePart] = nil
	car.model:Destroy()
end

-- Spawns `carId` for `player` at `cframe`, replacing any car they have in this server.
function Cars.spawn(player: Player, carId: string, cframe: CFrame): Car?
	local data = PlayerData.get(player)
	if not data or not Config.Cars[carId] then
		return nil
	end
	data.cars[carId] = data.cars[carId] or { trunk = {} }
	local existing = cars[player.UserId]
	if existing then
		despawn(existing)
	end
	local saved = data.cars[carId]
	local car: Car = {
		model = build(carId, player, cframe),
		carId = carId,
		ownerId = player.UserId,
		trunk = saved.trunk,
		granted = {},
	}
	-- In a raid the trunk lives in the car until it leaves again (or is recalled).
	if Places.kind == "Raid" then
		saved.trunk = {}
		saved.deployedIn = Places.code or "studio"
	end
	trunkPrompt(car)
	car.model.Parent = workspace
	cars[player.UserId] = car
	return car
end

-- Puts the player in the driver's seat. Right after joining, a single Sit doesn't stick while the
-- character is still loading in, so move them to the car and retry for a few seconds.
function Cars.seat(player: Player, car: Car)
	task.spawn(function()
		for _ = 1, 20 do
			local seat = car.model.Parent and car.model:FindFirstChildOfClass("VehicleSeat")
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not seat or not player.Parent then
				return
			end
			if humanoid and seat.Occupant == humanoid then
				return
			end
			if humanoid and humanoid.Health > 0 and character:FindFirstChild("HumanoidRootPart") then
				character:PivotTo(seat.CFrame + Vector3.new(0, 3, 0))
				seat:Sit(humanoid)
			end
			task.wait(0.5)
		end
	end)
end

-- Called when the player leaves this place through the map. Their car goes with them if they're driving it.
function Cars.leaveWithPlayer(player: Player)
	local car = cars[player.UserId]
	player:SetAttribute("CarToBring", nil)
	if not car then
		return
	end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local driving = humanoid and humanoid.SeatPart and humanoid.SeatPart:IsDescendantOf(car.model)
	local data = PlayerData.get(player)
	if driving and data then
		player:SetAttribute("CarToBring", car.carId)
		data.cars[car.carId].trunk = car.trunk
		data.cars[car.carId].deployedIn = nil
		despawn(car)
	elseif Places.kind ~= "Raid" then
		despawn(car) -- outside raids a parked car simply goes home with its owner
	end
end

-- From the Motel: give up a car left in a raid. The raid drops its trunk where it stands.
function Cars.recall(player: Player, carId: string)
	local data = PlayerData.get(player)
	local saved = data and data.cars[carId]
	if not saved or not saved.deployedIn then
		return
	end
	local code = saved.deployedIn
	saved.deployedIn = nil
	pcall(function()
		MessagingService:PublishAsync("CarRecall", { userId = player.UserId, code = code })
	end)
	Remotes.Notify:FireClient(player, `{Config.Cars[carId].name} recalled. Its trunk was left behind in the raid.`)
end

local function arrivalCFrame(): CFrame
	local points = CollectionService:GetTagged("Arrival")
	if #points > 0 then
		return (points[math.random(#points)] :: BasePart).CFrame + Vector3.new(0, 2, 0)
	end
	return CFrame.new(math.random(-20, 20), 2, -15)
end

function Cars.start()
	local function onJoin(player: Player)
		if Places.kind == "Hub" then
			return -- cars come out of the Motel garage
		end
		local data = PlayerData.get(player)
		if not data then
			return
		end
		-- Matchmaking sends { cars = { [userId] = carId } } for a party; other travel sends { car = carId }.
		local joinData = Places.joinData(player)
		local carId = joinData.car or (joinData.cars and joinData.cars[tostring(player.UserId)]) or data.car
		local saved = carId and data.cars[carId]
		if not saved or saved.deployedIn then
			carId = "Rental"
		end
		-- Players arrive in their car, just inside the border.
		local car = Cars.spawn(player, carId :: string, arrivalCFrame())
		local character = player.Character or player.CharacterAdded:Wait()
		character:WaitForChild("HumanoidRootPart")
		if car then
			Cars.seat(player, car)
		end
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		task.spawn(onJoin, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		local car = cars[player.UserId]
		if car and Places.kind ~= "Raid" then
			despawn(car)
		end
	end)

	if Places.kind == "Raid" then
		pcall(function()
			MessagingService:SubscribeAsync("CarRecall", function(message)
				local car = cars[message.Data.userId]
				if car and message.Data.code == Places.code then
					Looting.dropBag((car.model.PrimaryPart :: BasePart).Position, car.trunk)
					despawn(car)
				end
			end)
		end)
	end
end

return Cars
