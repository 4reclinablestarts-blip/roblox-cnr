-- Status bar, notifications, wanted markers and keybinds.
-- M = mask up, B = bag, H = surrender, P = party (Motel).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local StashUI = require(script.StashUI)
local Menus = require(script.Menus)
require(script.Weapons)
require(script.Alerts)
require(script.WorldMap)
require(script.Driving)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

-- Prompts can be limited to one team (ShowFor), one player (ShowForUserId) or everyone but one
-- player (HideForUserId). Enabled set on the client stays local.
-- Prompts on your own character (your revive prompt) never show for you.
local function updatePrompt(prompt: Instance)
	if not prompt:IsA("ProximityPrompt") then
		return
	end
	local showFor = prompt:GetAttribute("ShowFor")
	local onlyFor = prompt:GetAttribute("ShowForUserId")
	local hideFor = prompt:GetAttribute("HideForUserId")
	if showFor then
		local own = player.Character ~= nil and prompt:IsDescendantOf(player.Character)
		prompt.Enabled = not own and player.Team ~= nil and player.Team.Name == showFor
	elseif onlyFor then
		prompt.Enabled = onlyFor == player.UserId
	elseif hideFor then
		prompt.Enabled = hideFor ~= player.UserId
	end
end
local function updatePrompts()
	for _, prompt in workspace:GetDescendants() do
		updatePrompt(prompt)
	end
end
workspace.DescendantAdded:Connect(updatePrompt)
player:GetPropertyChangedSignal("Team"):Connect(updatePrompts)
updatePrompts()

local gui = Instance.new("ScreenGui")
gui.Name = "Hud"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function label(y: number, size: number): TextLabel
	local text = Instance.new("TextLabel")
	text.AnchorPoint = Vector2.new(0.5, 0)
	text.Position = UDim2.new(0.5, 0, 0, y)
	text.Size = UDim2.fromOffset(500, size)
	text.BackgroundTransparency = 1
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0.3
	text.Font = Enum.Font.GothamBold
	text.TextSize = size
	text.Text = ""
	text.Parent = gui
	return text
end

local status = label(8, 20)
local notice = label(36, 16)

local function updateStatus()
	local placeNames = { Hub = "Motel", Sales = "Sales Center", Housing = "Neighbourhood" }
	local team = player.Team and player.Team.Name or placeNames[workspace:GetAttribute("PlaceKind")] or "Lobby"
	local text = team
	if team == "Criminal" then
		local level = player:GetAttribute("CriminalLevel") or 0
		local progress = (player:GetAttribute("LootedItems") or 0) % Config.ITEMS_PER_CRIMINAL_LEVEL
		text ..= ` · Criminal level {level}`
		if level < Config.MAX_CRIMINAL_LEVEL then
			text ..= ` ({progress}/{Config.ITEMS_PER_CRIMINAL_LEVEL})`
		end
	end
	if player:GetAttribute("Masked") then
		text ..= " · Masked"
	end
	if player:GetAttribute("Wanted") then
		text ..= " · WANTED"
	end
	if player:GetAttribute("Surrendered") then
		text ..= " · Hands up"
	end
	if player:GetAttribute("Downed") then
		text = `DOWNED · bleeding out in {player:GetAttribute("BleedOut") or 0}s`
	end
	status.Text = `{text} · ${player:GetAttribute("Cash") or 0}`
	status.TextColor3 = player.Team and player.Team.TeamColor.Color or Color3.new(1, 1, 1)
end

player:GetPropertyChangedSignal("Team"):Connect(updateStatus)
player.AttributeChanged:Connect(updateStatus)
workspace:GetAttributeChangedSignal("PlaceKind"):Connect(updateStatus)
updateStatus()

local noticeId = 0
Remotes.Notify.OnClientEvent:Connect(function(message: string)
	noticeId += 1
	local id = noticeId
	notice.Text = message
	task.delay(4, function()
		if noticeId == id then
			notice.Text = ""
		end
	end)
end)

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		Remotes.MaskUp:FireServer()
	elseif input.KeyCode == Enum.KeyCode.B then
		StashUI.toggleBag()
	elseif input.KeyCode == Enum.KeyCode.H then
		Remotes.Surrender:FireServer()
	elseif input.KeyCode == Enum.KeyCode.P then
		Menus.toggleParty()
	end
end)

-- Wanted criminals get a marker everyone can see through walls (stand-in for the map until it exists).
local markers = Instance.new("Folder")
markers.Name = "WantedMarkers"
markers.Parent = gui

local function updateMarker(other: Player)
	local existing = markers:FindFirstChild(other.Name)
	local head = other.Character and other.Character:FindFirstChild("Head")
	if not other:GetAttribute("Wanted") or not head then
		if existing then
			existing:Destroy()
		end
		return
	end
	local billboard = existing or Instance.new("BillboardGui")
	billboard.Name = other.Name
	billboard.Adornee = head
	billboard.AlwaysOnTop = true
	billboard.Size = UDim2.fromOffset(120, 24)
	billboard.StudsOffset = Vector3.new(0, 3, 0)
	if not existing then
		local text = Instance.new("TextLabel")
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Text = `WANTED: {other.DisplayName}`
		text.TextColor3 = Color3.fromRGB(255, 60, 60)
		text.TextStrokeTransparency = 0
		text.Font = Enum.Font.GothamBold
		text.TextScaled = true
		text.Parent = billboard
		billboard.Parent = markers
	end
end

local function watch(other: Player)
	if other == player then
		return
	end
	other:GetAttributeChangedSignal("Wanted"):Connect(function()
		updateMarker(other)
	end)
	other.CharacterAdded:Connect(function(character)
		character:WaitForChild("Head")
		updateMarker(other)
	end)
	updateMarker(other)
end
Players.PlayerAdded:Connect(watch)
Players.PlayerRemoving:Connect(function(other)
	local marker = markers:FindFirstChild(other.Name)
	if marker then
		marker:Destroy()
	end
end)
for _, other in Players:GetPlayers() do
	watch(other)
end
