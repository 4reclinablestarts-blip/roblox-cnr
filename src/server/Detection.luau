-- Security cameras (parts tagged "SecurityCamera", pointing where they look) and NPC witnesses
-- (models tagged "Witness" with a Humanoid and Head). Both alert the cops when they see a crime.
--
-- Witnesses: once they see a crime they wait. If no criminal aims a gun at them for
-- WITNESS_PATIENCE seconds they start a WITNESS_CALL_TIME call; aiming again cancels it.
-- Killing a witness makes the shooter wanted.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Detection = {}

type Witness = {
	model: Model,
	alarmed: boolean,
	lastAimed: number,
	callStarted: number?,
	health: number,
}

local witnesses: { [Model]: Witness } = {}
local cameraHealth: { [BasePart]: number } = {}
local lastAlert: { [Instance]: number } = {}

-- Pings every cop with a marker at `position`. One alert per source every ALERT_DURATION.
function Detection.alert(source: Instance, position: Vector3, message: string)
	local now = os.clock()
	if lastAlert[source] and now - lastAlert[source] < Config.ALERT_DURATION then
		return
	end
	lastAlert[source] = now
	for _, player in Players:GetPlayers() do
		if Roles.isPolice(player) then
			Remotes.PoliceAlert:FireClient(player, position, message)
		end
	end
end

local function canSee(from: Vector3, ignore: Instance, target: Model): boolean
	local head = target:FindFirstChild("Head") :: BasePart?
	if not head then
		return false
	end
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ignore }
	local result = workspace:Raycast(from, head.Position - from, params)
	return result ~= nil and result.Instance:IsDescendantOf(target)
end

-- Call when a criminal does something illegal: robbing, taking items, firing a gun.
function Detection.reportCrime(player: Player)
	local character = player.Character
	local head = character and character:FindFirstChild("Head") :: BasePart?
	if Roles.of(player) ~= "Criminal" or not character or not head then
		return
	end

	for _, camera in CollectionService:GetTagged("SecurityCamera") do
		if camera:IsA("BasePart") and not camera:GetAttribute("Broken") then
			local offset = head.Position - camera.Position
			local inView = offset.Magnitude <= Config.CAMERA_RANGE
				and camera.CFrame.LookVector:Dot(offset.Unit) >= math.cos(math.rad(Config.CAMERA_FOV))
			if inView and canSee(camera.Position, camera, character) then
				Detection.alert(camera, camera.Position, "A security camera spotted a robbery.")
			end
		end
	end

	for model, witness in witnesses do
		local witnessHead = model:FindFirstChild("Head") :: BasePart?
		if
			not witness.alarmed
			and witnessHead
			and (head.Position - witnessHead.Position).Magnitude <= Config.WITNESS_RANGE
			and canSee(witnessHead.Position, model, character)
		then
			witness.alarmed = true
			witness.lastAimed = os.clock()
		end
	end
end

-- Bullets hitting a camera or a witness. Only criminals shoot them out.
function Detection.onHit(shooter: Player, part: Instance, damage: number)
	if Roles.of(shooter) ~= "Criminal" then
		return
	end
	if
		CollectionService:HasTag(part, "SecurityCamera")
		and part:IsA("BasePart")
		and not part:GetAttribute("Broken")
	then
		cameraHealth[part] = (cameraHealth[part] or Config.CAMERA_HEALTH) - damage
		if cameraHealth[part] <= 0 then
			part:SetAttribute("Broken", true)
			part.Transparency = 0.6
			task.delay(Config.CAMERA_REPAIR, function()
				cameraHealth[part] = nil
				part:SetAttribute("Broken", nil)
				part.Transparency = 0
			end)
		end
		return
	end

	local model = part:FindFirstAncestorOfClass("Model")
	local witness = model and witnesses[model]
	if not witness then
		return
	end
	witness.health -= damage
	if witness.health <= 0 then
		-- Killing a witness: instantly wanted. The witness comes back with the next store reset.
		shooter:SetAttribute("Wanted", true)
		local home = model.Parent
		witnesses[model] = nil
		model.Parent = nil
		task.delay(Config.LOOT_RESET, function()
			model.Parent = home
		end)
	end
end

local function setupWitness(model: Instance)
	if not model:IsA("Model") or witnesses[model] then
		return
	end
	witnesses[model] = {
		model = model,
		alarmed = false,
		lastAimed = 0,
		health = Config.WITNESS_HEALTH,
	}
end

local function onAimAt(player: Player, model: Instance)
	local witness = typeof(model) == "Instance" and witnesses[model :: Model]
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local witnessHead = witness and witness.model:FindFirstChild("Head") :: BasePart?
	if
		not witness
		or not witnessHead
		or Roles.of(player) ~= "Criminal"
		or not tool
		or not Config.Weapons[tool:GetAttribute("ItemId")]
		or not root
		or (root.Position - witnessHead.Position).Magnitude > Config.AIM_RANGE
	then
		return
	end
	witness.lastAimed = os.clock()
	if witness.callStarted then
		witness.callStarted = nil
		witness.model:SetAttribute("Calling", nil)
	end
end

function Detection.start()
	CollectionService:GetInstanceAddedSignal("Witness"):Connect(setupWitness)
	for _, model in CollectionService:GetTagged("Witness") do
		setupWitness(model)
	end
	Remotes.AimAt.OnServerEvent:Connect(onAimAt)

	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		for model, witness in witnesses do
			if not witness.alarmed then
				continue
			end
			if not witness.callStarted and now - witness.lastAimed >= Config.WITNESS_PATIENCE then
				witness.callStarted = now
				model:SetAttribute("Calling", true) -- clients show the cue
			elseif witness.callStarted and now - witness.callStarted >= Config.WITNESS_CALL_TIME then
				local head = model:FindFirstChild("Head") :: BasePart?
				Detection.alert(
					model,
					head and head.Position or model:GetPivot().Position,
					"A witness called the police."
				)
				-- Calm down again; another crime in view starts the process over.
				witness.alarmed = false
				witness.callStarted = nil
				model:SetAttribute("Calling", nil)
			end
		end
	end)
end

return Detection
