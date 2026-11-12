-- Police alerts (a marker at the reported spot) and the witness "calling the cops" cue.
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local PING_SOUND = "rbxasset://sounds/electronicpingshort.wav"

local function beep()
	local sound = Instance.new("Sound")
	sound.SoundId = PING_SOUND
	SoundService:PlayLocalSound(sound)
	Debris:AddItem(sound, 2)
end

local function marker(adornee: Instance, text: string, color: Color3): BillboardGui
	local billboard = Instance.new("BillboardGui")
	billboard.Adornee = adornee
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(180, 28)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color
	label.TextStrokeTransparency = 0
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.Parent = billboard
	billboard.Parent = adornee
	return billboard
end

-- Cops: a marker at the alert's position for ALERT_DURATION.
Remotes.PoliceAlert.OnClientEvent:Connect(function(position: Vector3, message: string)
	local spot = Instance.new("Part")
	spot.Anchored = true
	spot.CanCollide = false
	spot.CanQuery = false
	spot.Transparency = 1
	spot.Size = Vector3.one
	spot.Position = position
	spot.Parent = workspace
	marker(spot, `🚨 {message}`, Color3.fromRGB(80, 160, 255))
	Debris:AddItem(spot, Config.ALERT_DURATION)
	beep()
end)

-- Everyone near a witness sees and hears when they start calling, so the robber knows to aim at them.
local watched: { [Instance]: boolean } = setmetatable({}, { __mode = "k" }) :: any
local function watchWitness(model: Instance)
	if watched[model] then
		return
	end
	watched[model] = true
	model:GetAttributeChangedSignal("Calling"):Connect(function()
		local existing = model:FindFirstChild("CallingCue", true)
		if model:GetAttribute("Calling") then
			local head = model:FindFirstChild("Head")
			if head and not existing then
				marker(head, "📞 CALLING THE COPS!", Color3.fromRGB(255, 200, 40)).Name = "CallingCue"
				beep()
			end
		elseif existing then
			existing:Destroy()
		end
	end)
end
CollectionService:GetInstanceAddedSignal("Witness"):Connect(watchWitness)
for _, model in CollectionService:GetTagged("Witness") do
	watchWitness(model)
end

return {}
