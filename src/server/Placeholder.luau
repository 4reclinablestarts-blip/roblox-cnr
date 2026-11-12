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

	local sell =
		block(folder, "Sell station", Vector3.new(5, 4, 3), Vector3.new(0, 2, -30), Color3.fromRGB(40, 150, 70))
	CollectionService:AddTag(sell, "SellStation")

	for _, item in
		{
			{ "TV", Vector3.new(4, 3, 1), Vector3.new(48, 2.5, 0) },
			{ "Plant", Vector3.new(1, 3, 1), Vector3.new(32, 2.5, 0) },
		}
	do
		local part = block(folder, item[1], item[2], item[3], Color3.fromRGB(200, 120, 200))
		part:SetAttribute("ItemId", item[1])
		CollectionService:AddTag(part, "WorldItem")
	end

	-- Camera in the store's corner, looking at the register.
	local camera = block(folder, "Camera", Vector3.new(1, 1, 2), Vector3.new(53, 8, -11), Color3.fromRGB(30, 30, 30))
	camera.CFrame = CFrame.lookAt(camera.Position, Vector3.new(40, 2.5, -8))
	CollectionService:AddTag(camera, "SecurityCamera")

	-- Clerk behind the register: a witness.
	local clerk = Instance.new("Model")
	clerk.Name = "Clerk"
	local root =
		block(clerk, "HumanoidRootPart", Vector3.new(2, 2, 1), Vector3.new(40, 2, -11), Color3.fromRGB(80, 120, 200))
	root.Transparency = 0
	local head = block(clerk, "Head", Vector3.new(1, 1, 1), Vector3.new(40, 3.5, -11), Color3.fromRGB(240, 200, 160))
	head:ClearAllChildren() -- no label on the head; the body's label says "HumanoidRootPart" otherwise
	root:ClearAllChildren()
	Instance.new("Humanoid").Parent = clerk
	clerk.PrimaryPart = root
	clerk.Parent = folder
	CollectionService:AddTag(clerk, "Witness")

	-- Exit zone 80 studs north of the spawn.
	local border = block(
		folder,
		"Map border (extract)",
		Vector3.new(40, 12, 4),
		Vector3.new(0, 6, 80),
		Color3.fromRGB(60, 220, 120)
	)
	border.Transparency = 0.6
	border.CanCollide = false
	CollectionService:AddTag(border, "RaidBorder")

	folder.Parent = workspace
end
