-- Bag grid maths. Entries placed in the bag have x, y (1-based, top-left cell).
local Config = require(script.Parent.Config)

local Grid = {}

function Grid.size(itemId: string): (number, number)
	local size = Config.Items[itemId].size
	if size then
		return size[1], size[2]
	end
	return 1, 1
end

-- True if an item of size w x h fits at (x, y) without overlapping anything except `skip`.
function Grid.fits(
	entries: { any },
	cols: number,
	rows: number,
	w: number,
	h: number,
	x: number,
	y: number,
	skip: any?
): boolean
	if x < 1 or y < 1 or x + w - 1 > cols or y + h - 1 > rows then
		return false
	end
	for _, entry in entries do
		if entry ~= skip and entry.x and entry.y then
			local ew, eh = Grid.size(entry.id)
			if x < entry.x + ew and entry.x < x + w and y < entry.y + eh and entry.y < y + h then
				return false
			end
		end
	end
	return true
end

-- First free spot for a w x h item, scanning rows top to bottom.
function Grid.findSpot(entries: { any }, cols: number, rows: number, w: number, h: number): (number?, number?)
	for y = 1, rows - h + 1 do
		for x = 1, cols - w + 1 do
			if Grid.fits(entries, cols, rows, w, h, x, y) then
				return x, y
			end
		end
	end
	return nil, nil
end

do -- self-check
	local bag = { { id = "TV", x = 1, y = 1 } }
	assert(not Grid.fits(bag, 4, 3, 1, 1, 2, 2), "overlap")
	local x, y = Grid.findSpot(bag, 4, 3, 2, 2)
	assert(x == 3 and y == 1, "spot next to the TV")
	assert(Grid.findSpot(bag, 2, 2, 1, 1) == nil, "full grid")
end

return Grid
