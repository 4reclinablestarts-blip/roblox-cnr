-- The world map: shown while the server has set MapOpen ("border", "extract" or "raidEnd").
-- Fixed locations along the bottom, housing districts as tiles above.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "WorldMap"
gui.ResetOnSpawn = false
gui.Enabled = false
gui.DisplayOrder = 10
gui.Parent = player:WaitForChild("PlayerGui")

local backdrop = Instance.new("Frame")
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.fromRGB(150, 110, 60)
backdrop.Parent = gui

local title = Instance.new("TextLabel")
title.Position = UDim2.fromOffset(30, 20)
title.Size = UDim2.fromOffset(600, 50)
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.TextSize = 40
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextColor3 = Color3.new(1, 1, 1)
title.Text = "ROCKY VALLEY"
title.Parent = backdrop

local districtArea = Instance.new("Frame")
districtArea.AnchorPoint = Vector2.new(0.5, 0)
districtArea.Position = UDim2.new(0.5, 0, 0, 90)
districtArea.Size = UDim2.fromScale(0.8, 0.55)
districtArea.BackgroundTransparency = 1
districtArea.Parent = backdrop
local districtLayout = Instance.new("UIGridLayout")
districtLayout.CellSize = UDim2.fromOffset(170, 90)
districtLayout.CellPadding = UDim2.fromOffset(12, 12)
districtLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
districtLayout.Parent = districtArea

local bottom = Instance.new("Frame")
bottom.AnchorPoint = Vector2.new(0.5, 1)
bottom.Position = UDim2.new(0.5, 0, 1, -30)
bottom.Size = UDim2.new(0.9, 0, 0, 90)
bottom.BackgroundTransparency = 1
bottom.Parent = backdrop
local bottomLayout = Instance.new("UIListLayout")
bottomLayout.FillDirection = Enum.FillDirection.Horizontal
bottomLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
bottomLayout.Padding = UDim.new(0, 12)
bottomLayout.Parent = bottom

local function tile(parent: Instance, text: string, color: Color3, enabled: boolean, onClick: () -> ()): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.fromOffset(170, 90)
	button.Text = text
	button.TextWrapped = true
	button.Font = Enum.Font.GothamBold
	button.TextSize = 16
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = enabled and color or Color3.fromRGB(90, 80, 70)
	button.AutoButtonColor = enabled
	button.Activated:Connect(function()
		if enabled then
			onClick()
		end
	end)
	button.Parent = parent
	return button
end

local function render()
	for _, area in { districtArea, bottom } do
		for _, child in area:GetChildren() do
			if child:IsA("GuiButton") then
				child:Destroy()
			end
		end
	end
	local reason = player:GetAttribute("MapOpen")
	local raidOver = reason == "raidEnd"
	local hasHome = player:GetAttribute("HasHome") == true
	local canBuy = player:GetAttribute("HomeDeed") == true and not hasHome
	local districtLevel = player:GetAttribute("DistrictLevel") or 1

	local function travel(destination: string, arg: string?)
		return function()
			Remotes.Travel:FireServer(destination, arg)
		end
	end

	tile(bottom, "HOME", Color3.fromRGB(110, 170, 40), hasHome, travel("Home"))
	tile(bottom, "SALES CENTER\n(PvP, +50% prices)", Color3.fromRGB(60, 90, 140), not raidOver, travel("SalesCenter"))
	tile(bottom, "LENNY'S MOTEL\n(hub)", Color3.fromRGB(170, 60, 60), true, travel("Motel"))
	tile(bottom, "LOOTY BAY\n(raid)", Color3.fromRGB(60, 140, 160), not raidOver, travel("LootyBay"))
	if reason == "border" then
		tile(bottom, "STAY HERE", Color3.fromRGB(80, 80, 80), true, travel("Stay"))
	end

	-- Anyone can visit any district (to raid homes); buying a plot needs the district's permit level.
	for _, district in Config.Districts do
		local heading = `{string.upper(district.name)}\nlevel {district.level} district\n`
		if canBuy then
			local permitted = district.level <= districtLevel
			tile(
				districtArea,
				heading .. (if permitted then "Buy a plot here" else "needs a permit"),
				Color3.fromRGB(110, 170, 40),
				permitted and not raidOver,
				travel("BuyPlot", district.name)
			)
		else
			tile(
				districtArea,
				heading .. "Visit",
				Color3.fromRGB(190, 140, 70),
				not raidOver,
				travel("Visit", district.name)
			)
		end
	end
end

local function update()
	gui.Enabled = player:GetAttribute("MapOpen") ~= nil
	if gui.Enabled then
		render()
	end
end
player.AttributeChanged:Connect(update)
update()

return {}
