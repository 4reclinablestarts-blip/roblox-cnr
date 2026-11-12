-- Motel menus: the tech tree shop + garage (opened from their prompts) and the party panel (P).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Menus"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function window(title: string, width: number): (Frame, ScrollingFrame)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.Size = UDim2.fromOffset(width, 440)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	frame.Visible = false
	frame.Parent = gui

	local heading = Instance.new("TextLabel")
	heading.Size = UDim2.new(1, -40, 0, 34)
	heading.Position = UDim2.fromOffset(10, 0)
	heading.BackgroundTransparency = 1
	heading.Font = Enum.Font.GothamBold
	heading.TextSize = 18
	heading.TextXAlignment = Enum.TextXAlignment.Left
	heading.TextColor3 = Color3.new(1, 1, 1)
	heading.Text = title
	heading.Parent = frame

	local close = Instance.new("TextButton")
	close.AnchorPoint = Vector2.new(1, 0)
	close.Position = UDim2.new(1, -4, 0, 4)
	close.Size = UDim2.fromOffset(28, 28)
	close.Text = "X"
	close.TextColor3 = Color3.new(1, 1, 1)
	close.BackgroundColor3 = Color3.fromRGB(120, 40, 40)
	close.Activated:Connect(function()
		frame.Visible = false
	end)
	close.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 40)
	list.Size = UDim2.new(1, -16, 1, -48)
	list.BackgroundTransparency = 1
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 4
	list.Parent = frame
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return frame, list
end

local function clear(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
end

-- One row: a label and up to a few buttons on the right.
local function row(list: ScrollingFrame, order: number, text: string, buttons: { { any } })
	local frame = Instance.new("Frame")
	frame.LayoutOrder = order
	frame.Size = UDim2.new(1, -8, 0, 34)
	frame.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
	frame.Parent = list
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -90 * #buttons, 1, 0)
	label.Position = UDim2.fromOffset(8, 0)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.Text = text
	label.Parent = frame
	for i, spec in buttons do
		local button = Instance.new("TextButton")
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.new(1, -4 - (#buttons - i) * 90, 0.5, 0)
		button.Size = UDim2.fromOffset(84, 26)
		button.Text = spec[1]
		button.TextSize = 13
		button.TextColor3 = Color3.new(1, 1, 1)
		button.BackgroundColor3 = spec[2] and Color3.fromRGB(50, 120, 60) or Color3.fromRGB(70, 70, 70)
		button.AutoButtonColor = spec[2] ~= nil
		if spec[2] then
			button.Activated:Connect(spec[2])
		end
		button.Parent = frame
	end
end

-- Tech tree + garage ------------------------------------------------------------

local shopFrame, shopList = window("Tech tree & garage (pay with cash in your bag)", 520)

Remotes.OpenShop.OnClientEvent:Connect(function(state)
	clear(shopList)
	local order = 0
	local function nextOrder()
		order += 1
		return order
	end
	row(shopList, nextOrder(), "GARAGE", {})
	for carId, car in state.cars do
		local name = Config.Cars[carId].name .. (if state.selected == carId then " (selected)" else "")
		if car.deployed and carId ~= "Rental" then
			row(shopList, nextOrder(), `{name}: left in a raid`, {
				{
					"Recall",
					function()
						Remotes.Garage:FireServer("recall", carId)
					end,
				},
			})
		else
			row(shopList, nextOrder(), name, {
				{
					"Take out",
					function()
						Remotes.Garage:FireServer("spawn", carId)
						shopFrame.Visible = false
					end,
				},
			})
		end
	end

	row(shopList, nextOrder(), "TECH TREE", {})
	for _, entry in Config.TechTree do
		local owned = not entry.item and state.unlocks[entry.id]
		local missing = {}
		for _, required in entry.requires or {} do
			if not state.unlocks[required] then
				table.insert(missing, required)
			end
		end
		local text = `{entry.name}  ${entry.cost}`
		if owned then
			row(shopList, nextOrder(), text, { { "Owned", nil } })
		elseif #missing > 0 then
			row(shopList, nextOrder(), `{text}  (needs {table.concat(missing, ", ")})`, { { "Locked", nil } })
		else
			row(shopList, nextOrder(), text, {
				{
					"Buy",
					function()
						Remotes.Buy:FireServer(entry.id)
					end,
				},
			})
		end
	end
	shopFrame.Visible = true
end)

-- Party -------------------------------------------------------------------------

local partyFrame, partyList = window("Party (the leader picks the raid)", 420)
local partyState = { members = {} }

local function renderParty()
	clear(partyList)
	local order = 0
	local inParty = {}
	if partyState.invitedBy then
		order += 1
		row(partyList, order, `{partyState.invitedBy.name} invited you`, {
			{
				"Accept",
				function()
					Remotes.Party:FireServer("accept")
				end,
			},
		})
	end
	for _, member in partyState.members do
		inParty[member.userId] = true
		order += 1
		local leader = if member.userId == partyState.leader then " (leader)" else ""
		row(partyList, order, member.name .. leader, {})
	end
	if #partyState.members > 0 then
		order += 1
		row(partyList, order, "", {
			{
				"Leave party",
				function()
					Remotes.Party:FireServer("leave")
				end,
			},
		})
	end
	for _, other in Players:GetPlayers() do
		if other ~= player and not inParty[other.UserId] then
			order += 1
			row(partyList, order, other.DisplayName, {
				{
					"Invite",
					function()
						Remotes.Party:FireServer("invite", other)
					end,
				},
			})
		end
	end
end

Remotes.PartyChanged.OnClientEvent:Connect(function(state)
	partyState = state
	renderParty()
end)

return {
	toggleParty = function()
		if workspace:GetAttribute("PlaceKind") ~= "Hub" then
			return
		end
		renderParty()
		partyFrame.Visible = not partyFrame.Visible
	end,
}
