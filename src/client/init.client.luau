-- Status bar, notifications and keybinds. M = mask up, B = bag.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local StashUI = require(script.StashUI)
local Remotes = ReplicatedStorage.Remotes

local player = Players.LocalPlayer

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
	text.Parent = gui
	return text
end

local status = label(8, 20)
local notice = label(36, 16)

local function updateStatus()
	local team = player.Team and player.Team.Name or "Lobby"
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
	status.Text = text
	status.TextColor3 = player.Team and player.Team.TeamColor.Color or Color3.new(1, 1, 1)
end

player:GetPropertyChangedSignal("Team"):Connect(updateStatus)
player.AttributeChanged:Connect(updateStatus)
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
	end
end)
