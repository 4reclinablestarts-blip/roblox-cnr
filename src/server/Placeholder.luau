-- Test parts for building mechanics before the Looty Bay map exists.
-- Delete this module (and its require in init.server.luau) once the real map has tagged parts.
local CollectionService = game:GetService("CollectionService")

local function block(parent: Instance, name: string, size: Vector3, position: Vector3, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part.Size = size
	part.Position = position
	part.Color = color

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(160, 30)
	billboard.StudsOffset = Vector3.new(0, size.Y / 2 + 1.5, 0)
	billboard.MaxDistance = 80
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = name
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0
	label.TextScaled = true
	label.Parent = billboard
	billboard.Parent = part

	part.Parent = parent
	return part
end

local function lootable(
	parent: Instance,
	name: string,
	lootTable: string,
	holdTime: number,
	size: Vector3,
	position: Vector3
)
	local part = block(parent, name, size, position, Color3.fromRGB(200, 160, 60))
	part:SetAttribute("LootTable", lootTable)
	part:SetAttribute("HoldTime", holdTime)
	CollectionService:AddTag(part, "Lootable")
end

return function()
	if workspace:FindFirstChild("Placeholder") then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Placeholder"

	local spawn = Instance.new("SpawnLocation")
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Size = Vector3.new(8, 1, 8)
	spawn.Position = Vector3.new(0, 0.5, 0)
	spawn.Parent = folder

	block(folder, "Store", Vector3.new(30, 1, 24), Vector3.new(40, 0.5, 0), Color3.fromRGB(90, 90, 110))
	lootable(folder, "Register", "Register", 3, Vector3.new(4, 3, 2), Vector3.new(40, 2.5, -8))
	lootable(folder, "Shelf", "Shelf", 6, Vector3.new(10, 6, 2), Vector3.new(40, 4, 8))

	local desk =
		block(folder, "Police desk", Vector3.new(6, 3, 3), Vector3.new(-40, 1.5, 0), Color3.fromRGB(40, 70, 160))
	CollectionService:AddTag(desk, "PoliceDesk")

	folder.Parent = workspace
end
