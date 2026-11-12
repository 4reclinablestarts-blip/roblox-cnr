-- Fires the equipped gun at the mouse, and draws every shot's tracer.
local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local mouse = player:GetMouse()

local hooked: { [Tool]: boolean } = setmetatable({}, { __mode = "k" }) :: any

-- Tools move between Backpack and character on equip, so hook each one only once.
local function hook(tool: Instance)
	if not tool:IsA("Tool") or hooked[tool] then
		return
	end
	hooked[tool] = true
	tool.Activated:Connect(function()
		Remotes.Shoot:FireServer(mouse.Hit.Position)
	end)
end

local function watchBackpack(backpack: Instance)
	backpack.ChildAdded:Connect(hook)
	for _, tool in backpack:GetChildren() do
		hook(tool)
	end
end

player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then
		watchBackpack(child)
	end
end)
local backpack = player:FindFirstChildOfClass("Backpack")
if backpack then
	watchBackpack(backpack)
end

Remotes.ShotFired.OnClientEvent:Connect(function(from: Vector3, to: Vector3)
	local tracer = Instance.new("Part")
	tracer.Anchored = true
	tracer.CanCollide = false
	tracer.CanQuery = false
	tracer.Material = Enum.Material.Neon
	tracer.Color = Color3.fromRGB(255, 220, 120)
	tracer.Size = Vector3.new(0.08, 0.08, (to - from).Magnitude)
	tracer.CFrame = CFrame.lookAt((from + to) / 2, to)
	tracer.Parent = workspace
	Debris:AddItem(tracer, 0.06)
end)

return {}
