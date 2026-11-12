-- Guns, damage rules, the downed state (bleed out, revive, finish) and what happens on death.
-- Weapons in the bag show up as Tools, but only for criminals and cops who aren't downed.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Config = require(ReplicatedStorage.Shared.Config)
local Inventory = require(script.Parent.Inventory)
local Detection = require(script.Parent.Detection)
local Looting = require(script.Parent.Looting)
local Raid = require(script.Parent.Raid)
local Roles = require(script.Parent.Roles)
local Remotes = ReplicatedStorage.Remotes

local Combat = {}

local lastShot: { [Player]: number } = {}
local bleedLeft: { [Player]: number } = {}

local function humanoidOf(player: Player): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Civilians never fight. Cops only hurt criminals. Criminals hurt anyone.
-- shortcut: parties don't exist yet, so there is no party friendly-fire check.
function Combat.canHurt(attackerRole: string?, victimRole: string?): boolean
	if attackerRole == "Police" then
		return victimRole == "Criminal"
	end
	return attackerRole == "Criminal"
end

function Combat.refreshTools(player: Player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then
		return
	end
	local want = {}
	if
		Roles.of(player) ~= "Civilian"
		and not player:GetAttribute("Downed")
		and not player:GetAttribute("Surrendered")
	then
		for _, entry in Inventory.get(player) do
			if Config.Weapons[entry.id] then
				want[entry.id] = true
			end
		end
	end
	for _, container in { backpack, character } do
		for _, tool in container:GetChildren() do
			if tool:IsA("Tool") then
				local id = tool:GetAttribute("ItemId")
				if want[id] then
					want[id] = nil
				else
					tool:Destroy()
				end
			end
		end
	end
	for id in want do
		local tool = Instance.new("Tool")
		tool.Name = Config.Items[id].name
		tool.RequiresHandle = false
		tool.CanBeDropped = false
		tool:SetAttribute("ItemId", id)
		tool.Parent = backpack
	end
end

-- Stops the bleed-out timer, e.g. before an arrested player is respawned.
function Combat.clearDowned(player: Player)
	bleedLeft[player] = nil
	player:SetAttribute("Downed", nil)
	player:SetAttribute("BleedOut", nil)
end

local function revive(player: Player)
	local humanoid = humanoidOf(player)
	bleedLeft[player] = nil
	player:SetAttribute("Downed", nil)
	player:SetAttribute("BleedOut", nil)
	if humanoid then
		humanoid.Health = Config.REVIVE_HEALTH
		humanoid.WalkSpeed = StarterPlayer.CharacterWalkSpeed
		humanoid.JumpPower = StarterPlayer.CharacterJumpPower
		humanoid.JumpHeight = StarterPlayer.CharacterJumpHeight
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	local prompt = root and root:FindFirstChild("Revive")
	if prompt then
		prompt:Destroy()
	end
	Combat.refreshTools(player)
end

local function down(player: Player, humanoid: Humanoid)
	humanoid.Health = 1
	humanoid.WalkSpeed = Config.DOWNED_SPEED
	humanoid.JumpPower = 0
	humanoid.JumpHeight = 0
	player:SetAttribute("Downed", true)
	bleedLeft[player] = Config.BLEED_OUT
	Combat.refreshTools(player)

	-- Cops revive cops, criminals revive criminals. Nobody revives civilians.
	local role = Roles.of(player)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if root and (role == "Police" or role == "Criminal") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "Revive"
		prompt.ActionText = "Revive"
		prompt.ObjectText = player.DisplayName
		prompt.HoldDuration = Config.REVIVE_TIME
		prompt.RequiresLineOfSight = false
		prompt:SetAttribute("ShowFor", role)
		prompt.Triggered:Connect(function(reviver)
			if
				reviver ~= player
				and Roles.of(reviver) == Roles.of(player)
				and not reviver:GetAttribute("Downed")
				and player:GetAttribute("Downed")
			then
				revive(player)
			end
		end)
		prompt.Parent = root
	end
end

function Combat.damage(victim: Player, attacker: Player, amount: number)
	local humanoid = humanoidOf(victim)
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	if victim:GetAttribute("Downed") then
		humanoid.Health = 0 -- finished off
	elseif humanoid.Health > amount then
		humanoid.Health -= amount
	else
		down(victim, humanoid)
	end
	-- Downing (or killing) a civilian makes a criminal wanted.
	if Roles.of(attacker) == "Criminal" and Roles.of(victim) == "Civilian" then
		attacker:SetAttribute("Wanted", true)
	end
end

local function onDied(player: Player, character: Model)
	bleedLeft[player] = nil
	player:SetAttribute("Downed", nil)
	player:SetAttribute("BleedOut", nil)
	local role = Roles.of(player)
	if role == "Civilian" then
		Raid.leave(player, "You were killed.", true)
		return
	end
	-- Everyone else drops what they carry. For cops that's the issued kit; their own bag is locked away.
	local items = Inventory.takeAll(player)
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		Looting.dropBag(root.Position - Vector3.new(0, 2, 0), items)
	end
	Raid.leave(player, "You died.", role == "Police")
end

local function onShoot(player: Player, target: Vector3)
	local character = player.Character
	local tool = character and character:FindFirstChildOfClass("Tool")
	local weapon = tool and Config.Weapons[tool:GetAttribute("ItemId")]
	local head = character and character:FindFirstChild("Head")
	if not weapon or not head or player:GetAttribute("Downed") then
		return
	end
	local now = os.clock()
	if now - (lastShot[player] or 0) < weapon.cooldown * 0.9 then -- 10% slack for network jitter
		return
	end
	local origin = head.Position
	if (target - origin).Magnitude < 0.1 then
		return
	end
	if not Inventory.consume(player, weapon.ammo, 1) then
		Remotes.Notify:FireClient(player, "Out of ammo.")
		return
	end
	lastShot[player] = now
	Detection.reportCrime(player) -- gunfire alarms cameras and witnesses

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	local aim = CFrame.lookAt(origin, target)
	for _ = 1, weapon.pellets or 1 do
		local spread = math.rad(weapon.spread or 0)
		local direction = (aim * CFrame.Angles((math.random() * 2 - 1) * spread, (math.random() * 2 - 1) * spread, 0)).LookVector
		local result = workspace:Raycast(origin, direction * weapon.range, params)
		Remotes.ShotFired:FireAllClients(origin, result and result.Position or origin + direction * weapon.range)

		local model = result and result.Instance:FindFirstAncestorOfClass("Model")
		local victim = model and Players:GetPlayerFromCharacter(model)
		if result and not victim then
			Detection.onHit(player, result.Instance, weapon.damage)
		elseif victim and Combat.canHurt(Roles.of(player), Roles.of(victim)) then
			Combat.damage(victim, player, weapon.damage)
		end
	end
end

function Combat.start()
	Inventory.onChanged = Combat.refreshTools

	local function onJoin(player: Player)
		player:GetPropertyChangedSignal("Team"):Connect(function()
			Combat.refreshTools(player)
		end)
		-- A new Backpack is made on every spawn.
		player.ChildAdded:Connect(function(child)
			if child:IsA("Backpack") then
				task.defer(Combat.refreshTools, player)
			end
		end)
		player.CharacterAdded:Connect(function(character)
			local humanoid = character:WaitForChild("Humanoid") :: Humanoid
			humanoid.Died:Connect(function()
				onDied(player, character)
			end)
		end)
	end
	Players.PlayerAdded:Connect(onJoin)
	for _, player in Players:GetPlayers() do
		onJoin(player)
	end
	Players.PlayerRemoving:Connect(function(player)
		lastShot[player] = nil
		bleedLeft[player] = nil
	end)

	Remotes.Shoot.OnServerEvent:Connect(function(player, target)
		if typeof(target) == "Vector3" then
			onShoot(player, target)
		end
	end)

	-- Bleeding out: the timer runs at 2x while the downed player crawls.
	RunService.Heartbeat:Connect(function(dt)
		for player, left in bleedLeft do
			local humanoid = humanoidOf(player)
			if not humanoid then
				bleedLeft[player] = nil
				continue
			end
			left -= dt * (humanoid.MoveDirection.Magnitude > 0 and 2 or 1)
			bleedLeft[player] = left
			player:SetAttribute("BleedOut", math.max(0, math.ceil(left)))
			if left <= 0 then
				humanoid.Health = 0
			end
		end
	end)
end

assert(
	Combat.canHurt("Police", "Criminal")
		and not Combat.canHurt("Police", "Civilian")
		and not Combat.canHurt("Civilian", "Criminal")
		and Combat.canHurt("Criminal", "Civilian"),
	"damage rules"
)

return Combat
