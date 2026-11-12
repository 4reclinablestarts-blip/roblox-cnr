-- Bag panel plus the open stash panel. Drag a stash item onto the bag to take it,
-- drag a bag item onto a sell station to sell it, right-click a bag item to give it away.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

local gui = Instance.new("ScreenGui")
gui.Name = "Inventory"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makePanel(anchorX: number, offsetX: number): (Frame, TextLabel, ScrollingFrame)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(anchorX, 0.5)
	frame.Position = UDim2.new(0.5, offsetX, 0.5, 0)
	frame.Size = UDim2.fromOffset(260, 360)
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	frame.BackgroundTransparency = 0.1
	frame.Visible = false
	frame.Parent = gui

	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0, 30)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.new(1, 1, 1)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 16
	title.Parent = frame

	local list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(8, 34)
	list.Size = UDim2.new(1, -16, 1, -42)
	list.BackgroundTransparency = 1
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.ScrollBarThickness = 4
	list.Parent = frame
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(76, 40)
	layout.CellPadding = UDim2.fromOffset(4, 4)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	return frame, title, list
end

local bagFrame, bagTitle, bagList = makePanel(1, -8)
local stashFrame, stashTitle, stashList = makePanel(0, 8)

local openStash: BasePart? = nil

local function itemButton(list: ScrollingFrame, index: number, itemId: string): TextButton
	local button = Instance.new("TextButton")
	button.LayoutOrder = index
	local item = Config.Items[itemId]
	button.Text = item and (item.value > 0 and `{item.name}\n${item.value}` or item.name) or itemId
	button.TextWrapped = true
	button.TextSize = 12
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
	button.AutoButtonColor = false
	button.Parent = list
	return button
end

local function clear(list: ScrollingFrame)
	for _, child in list:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
end

local function isOver(frame: GuiObject, position: Vector2): boolean
	local topLeft, size = frame.AbsolutePosition, frame.AbsoluteSize
	return position.X >= topLeft.X
		and position.X <= topLeft.X + size.X
		and position.Y >= topLeft.Y
		and position.Y <= topLeft.Y + size.Y
end

-- A copy of the button follows the pointer; dropping it on `target` calls onDrop.
-- InputObject.Position and AbsolutePosition both exclude the top bar inset, so they compare directly.
local function startDrag(button: TextButton, input: InputObject, target: GuiObject, onDrop: () -> ())
	local ghost = button:Clone()
	ghost.AnchorPoint = Vector2.new(0.5, 0.5)
	ghost.Size = UDim2.fromOffset(button.AbsoluteSize.X, button.AbsoluteSize.Y)
	ghost.ZIndex = 10
	ghost.Position = UDim2.fromOffset(input.Position.X, input.Position.Y)
	ghost.Parent = gui

	local moved, ended
	moved = UserInputService.InputChanged:Connect(function(change)
		if
			change.UserInputType == Enum.UserInputType.MouseMovement
			or change.UserInputType == Enum.UserInputType.Touch
		then
			ghost.Position = UDim2.fromOffset(change.Position.X, change.Position.Y)
		end
	end)
	ended = UserInputService.InputEnded:Connect(function(release)
		if
			release.UserInputType ~= Enum.UserInputType.MouseButton1
			and release.UserInputType ~= Enum.UserInputType.Touch
		then
			return
		end
		moved:Disconnect()
		ended:Disconnect()
		ghost:Destroy()
		if isOver(target, Vector2.new(release.Position.X, release.Position.Y)) then
			onDrop()
		end
	end)
end

local giveMenu: Frame? = nil

local function closeGiveMenu()
	if giveMenu then
		giveMenu:Destroy()
		giveMenu = nil
	end
end

local function closeStash()
	openStash = nil
	stashFrame.Visible = false
	bagFrame.Visible = false
	closeGiveMenu()
end

local function menuButton(menu: Frame, text: string, onClick: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 28)
	button.Text = text
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	button.Activated:Connect(function()
		closeGiveMenu()
		onClick()
	end)
	button.Parent = menu
end

-- shortcut: right-click only, so touch players can't give yet; add a long-press when mobile matters.
local function openGiveMenu(button: TextButton, index: number, itemId: string)
	closeGiveMenu()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end

	local menu = Instance.new("Frame")
	menu.Position = UDim2.fromOffset(button.AbsolutePosition.X + button.AbsoluteSize.X, button.AbsolutePosition.Y)
	menu.Size = UDim2.fromOffset(160, 0)
	menu.AutomaticSize = Enum.AutomaticSize.Y
	menu.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	menu.ZIndex = 5
	local layout = Instance.new("UIListLayout")
	layout.Parent = menu

	local found = false
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if otherRoot and (otherRoot.Position - root.Position).Magnitude <= Config.GIVE_RANGE then
			found = true
			menuButton(menu, `Give to {other.DisplayName}`, function()
				Remotes.GiveItem:FireServer(other, index, itemId)
			end)
		end
	end
	if not found then
		menuButton(menu, "Nobody close enough", function() end)
	end
	menuButton(menu, "Cancel", function() end)

	menu.Parent = gui
	giveMenu = menu
end

Remotes.InventoryChanged.OnClientEvent:Connect(function(items: { string }, slots: number)
	clear(bagList)
	closeGiveMenu()
	bagTitle.Text = `Bag {#items}/{slots}`
	for i, itemId in items do
		local button = itemButton(bagList, i, itemId)
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				openGiveMenu(button, i, itemId)
			elseif
				(
					input.UserInputType == Enum.UserInputType.MouseButton1
					or input.UserInputType == Enum.UserInputType.Touch
				)
				and openStash
				and CollectionService:HasTag(openStash, "SellStation")
			then
				local station = openStash
				startDrag(button, input, stashFrame, function()
					Remotes.PutItem:FireServer(station, i, itemId)
				end)
			end
		end)
	end
end)

Remotes.OpenStash.OnClientEvent:Connect(function(part: BasePart, items: { string })
	openStash = part
	clear(stashList)
	if CollectionService:HasTag(part, "SellStation") then
		stashTitle.Text = "Drag items here to sell"
	else
		stashTitle.Text = #items > 0 and part.Name or `{part.Name} (empty)`
	end
	for i, itemId in items do
		local button = itemButton(stashList, i, itemId)
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				startDrag(button, input, bagFrame, function()
					Remotes.TakeItem:FireServer(part, i, itemId)
				end)
			end
		end)
	end
	stashFrame.Visible = true
	bagFrame.Visible = true
end)

-- Close the stash once the player walks away from it.
RunService.Heartbeat:Connect(function()
	if not openStash then
		return
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or (root.Position - openStash.Position).Magnitude > Config.LOOT_RANGE + 2 then
		closeStash()
	end
end)

return {
	toggleBag = function()
		if openStash then
			closeStash()
		else
			bagFrame.Visible = not bagFrame.Visible
		end
	end,
}
