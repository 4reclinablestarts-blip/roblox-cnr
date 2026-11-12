-- Arcade driving for cars built by server/Cars.luau. The driver's client owns the car's physics,
-- so it sets the chassis velocity straight from the seat's throttle and steering.
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local ACCELERATION = 35 -- studs/s per second
local BRAKING = 70
local TURN_RATE = 1.6 -- radians/s at speed

RunService.Heartbeat:Connect(function(dt)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	if not seat or not seat:IsA("VehicleSeat") then
		return
	end
	local car = seat.Parent
	local chassis = car and car:IsA("Model") and car.PrimaryPart
	if not chassis or chassis.Anchored or not car:GetAttribute("CarId") then
		return
	end

	local look = chassis.CFrame.LookVector
	local forward = Vector3.new(look.X, 0, look.Z).Unit
	local velocity = chassis.AssemblyLinearVelocity
	local speed = velocity:Dot(forward)
	local maxSpeed = car:GetAttribute("Speed") or 45
	local target = seat.ThrottleFloat * (if seat.ThrottleFloat < 0 then maxSpeed * 0.4 else maxSpeed)
	local rate = if math.abs(target) < math.abs(speed) or target * speed < 0 then BRAKING else ACCELERATION
	speed += math.clamp(target - speed, -rate * dt, rate * dt)

	chassis.AssemblyLinearVelocity = forward * speed + Vector3.new(0, velocity.Y, 0)
	local grip = math.clamp(math.abs(speed) / 15, 0, 1) * math.sign(speed)
	chassis.AssemblyAngularVelocity = Vector3.new(0, -seat.SteerFloat * TURN_RATE * grip, 0)
end)

return {}
