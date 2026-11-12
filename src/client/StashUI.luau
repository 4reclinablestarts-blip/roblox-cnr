-- The bag (a grid) plus the open stash panel.
--   stash -> bag: drag onto the bag to take
--   bag -> stash: drag onto the stash to store or sell (when allowed)
--   bag -> bag: drag onto another cell to move
--   right-click a bag item: use it (heals) or give it to a nearby player
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Grid = require(ReplicatedStorage.Shared.Grid)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer
local CELL = 52

type Entry = { id: string, amount: number?, x: number?, y: number? }

local gui = Instance.new("ScreenGui")
gui.Name = "Inventory"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function panel(anchorX: number, offsetX: number): (Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(anchorX, 0.5)
	frame.Position = UDim2.new(0.5, offsetX, 0.5, 0)
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
	return frame, title
end

local bagFrame, bagTitle = panel(1, -8)
local bagGrid = Instance.new("Frame")
bagGrid.Position = UDim2.fromOffset(8, 34)
bagGrid.BackgroundColor3 = Color3.fromRGB(40, 40, 48)
bagGrid.Parent = bagFrame

local stashFrame, stashTitle = panel(0, 8)
stashFrame.Size = UDim2.fromOffset(260, 360)
local stashList = Instance.new("ScrollingFrame")
stashList.Position = UDim2.fromOffset(8, 34)
stashList.Size = UDim2.new(1, -16, 1, -42)
stashList.BackgroundTransparency = 1
stashList.AutomaticCanvasSize = Enum.AutomaticSize.Y
stashList.CanvasSize = UDim2.new()
stashList.ScrollBarThickness = 4
stashList.Parent = stashFrame
local layout = Instance.new("UIGridLayout")
layout.CellSize = UDim2.fromOffset(76, 44)
layout.CellPadding = UDim2.fromOffset(4, 4)
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = stashList

local openStash: BasePart? = nil
local stashCanPut = false
local bagItems: { Entry } = {}

local function label(entry: Entry): string
	local item = Config.Items[entry.id]
	if entry.amount then
		local prefix = if entry.id == "Money" then "$" else "x"
		return `{item.name}\n{prefix}{entry.amount}`
	end
	return item.value > 0 and `{item.name}\n${item.value}` or item.name
end

local function itemButton(parent: GuiObject, entry: Entry): TextButton
	local button = Instance.new("TextButton")
	button.Text = label(entry)
	button.TextWrapped = true
	button.TextSize = 12
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(70, 70, 85)
	button.BorderSizePixel = 1
	button.AutoButtonColor = false
	button.Parent = parent
	return button
end

local function isOver(frame: GuiObject, position: Vector2): boolean
	local topLeft, size = frame.AbsolutePosition, frame.AbsoluteSize
	return position.X >= topLeft.X
		and position.X <= topLeft.X + size.X
		and position.Y >= topLeft.Y
		and position.Y <= topLeft.Y + size.Y
end

-- A copy of the button follows the pointer; onDrop gets where it was released.
-- InputObject.Position and AbsolutePosition both exclude the top bar inset, so they compare directly.
local function startDrag(button: TextButton, input: InputObject, onDrop: (Vector2, Vector2) -> ())
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
		-- The ghost's top-left cell is where the item lands when moving inside the bag.
		local corner = ghost.AbsolutePosition
		ghost:Destroy()
		onDrop(Vector2.new(release.Position.X, release.Position.Y), corner)
	end)
end

local function isPress(input: InputObject): boolean
	return input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch
end

local menu: Frame? = nil
local function closeMenu()
	if menu then
		menu:Destroy()
		menu = nil
	end
end

local function menuButton(parent: Frame, text: string, onClick: () -> ())
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 28)
	button.Text = text
	button.TextSize = 13
	button.TextColor3 = Color3.new(1, 1, 1)
	button.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
	button.Activated:Connect(function()
		closeMenu()
		onClick()
	end)
	button.Parent = parent
end

-- shortcut: right-click only, so touch players can't use or give items yet; add a long-press when mobile matters.
local function openMenu(button: TextButton, index: number, entry: Entry)
	closeMenu()
	local frame = Instance.new("Frame")
	frame.Position = UDim2.fromOffset(button.AbsolutePosition.X + button.AbsoluteSize.X, button.AbsolutePosition.Y)
	frame.Size = UDim2.fromOffset(170, 0)
	frame.AutomaticSize = Enum.AutomaticSize.Y
	frame.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	frame.ZIndex = 5
	Instance.new("UIListLayout").Parent = frame

	if Config.Heals[entry.id] then
		menuButton(frame, "Use", function()
			Remotes.UseItem:FireServer(index, entry.id)
		end)
	end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	for _, other in Players:GetPlayers() do
		local otherRoot = other ~= player and other.Character and other.Character:FindFirstChild("HumanoidRootPart")
		if root and otherRoot and (otherRoot.Position - root.Position).Magnitude <= Config.GIVE_RANGE then
			menuButton(frame, `Give to {other.DisplayName}`, function()
				Remotes.GiveItem:FireServer(other, index, entry.id)
			end)
		end
	end
	menuButton(frame, "Cancel", function() end)
	frame.Parent = gui
	menu = frame
end

local function renderBag(cols: number, rows: number)
	for _, child in bagGrid:GetChildren() do
		child:Destroy()
	end
	bagGrid.Size = UDim2.fromOffset(cols * CELL, rows * CELL)
	bagFrame.Size = UDim2.fromOffset(cols * CELL + 16, rows * CELL + 42)
	for x = 1, cols do -- faint cell lines
		for y = 1, rows do
			local cell = Instance.new("Frame")
			cell.Position = UDim2.fromOffset((x - 1) * CELL, (y - 1) * CELL)
			cell.Size = UDim2.fromOffset(CELL, CELL)
			cell.BackgroundTransparency = 1
			cell.BorderColor3 = Color3.fromRGB(60, 60, 70)
			cell.BorderSizePixel = 1
			cell.Parent = bagGrid
		end
	end

	local used = 0
	for i, entry in bagItems do
		local w, h = Grid.size(entry.id)
		used += w * h
		local button = itemButton(bagGrid, entry)
		button.Position = UDim2.fromOffset(((entry.x or 1) - 1) * CELL + 1, ((entry.y or 1) - 1) * CELL + 1)
		button.Size = UDim2.fromOffset(w * CELL - 2, h * CELL - 2)
		button.ZIndex = 2
		button.InputBegan:Connect(function(input)
			if input.UserInputType == Enum.UserInputType.MouseButton2 then
				openMenu(button, i, entry)
			elseif isPress(input) then
				startDrag(button, input, function(at: Vector2, corner: Vector2)
					local stash = openStash
					if stash and stashFrame.Visible and isOver(stashFrame, at) then
						if stashCanPut then
							Remotes.PutItem:FireServer(stash, i, entry.id)
						end
					elseif isOver(bagGrid, at) then
						local offset = corner - bagGrid.AbsolutePosition
						local x = math.floor(offset.X / CELL + 0.5) + 1
						local y = math.floor(offset.Y / CELL + 0.5) + 1
						if x ~= entry.x or y ~= entry.y then
							Remotes.MoveItem:FireServer(i, entry.id, x, y)
						end
					end
				end)
			end
		end)
	end
	bagTitle.Text = `Bag ({used}/{cols * rows} cells)`
end

local function closeStash()
	openStash = nil
	stashFrame.Visible = false
	bagFrame.Visible = false
	closeMenu()
end

Remotes.InventoryChanged.OnClientEvent:Connect(function(items: { Entry }, cols: number, rows: number)
	bagItems = items
	closeMenu()
	renderBag(cols, rows)
end)

Remotes.OpenStash.OnClientEvent:Connect(function(part: BasePart, items: { Entry }, canPut: boolean?)
	openStash = part
	stashCanPut = canPut == true
	for _, child in stashList:GetChildren() do
		if child:IsA("GuiButton") then
			child:Destroy()
		end
	end
	if CollectionService:HasTag(part, "SellStation") then
		stashTitle.Text = "Drag items here to sell"
	else
		stashTitle.Text = `{part.Name} ({#items})` .. (if stashCanPut then " · drag items in to store" else "")
	end
	for i, entry in items do
		local button = itemButton(stashList, entry)
		button.LayoutOrder = i
		button.InputBegan:Connect(function(input)
			if isPress(input) then
				startDrag(button, input, function(at: Vector2)
					if isOver(bagFrame, at) then
						Remotes.TakeItem:FireServer(part, i, entry.id)
					end
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
			closeMenu()
		end
	end,
}
