-- Which homes live in which neighbourhood server. Each district has a list of neighbourhoods,
-- each a reserved Housing server (access code) with up to HOMES_PER_NEIGHBOURHOOD owners.
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Places = require(script.Parent.Places)
local PlayerData = require(script.Parent.PlayerData)
local Remotes = ReplicatedStorage.Remotes

local Neighbourhoods = {}

export type Neighbourhood = { code: string, homes: { number } }

local store: DataStore? = nil
pcall(function()
	store = DataStoreService:GetDataStore("Neighbourhoods_v1")
end)

local function notify(player: Player, message: string)
	Remotes.Notify:FireClient(player, message)
end

function Neighbourhoods.district(name: string): { name: string, level: number }?
	for _, district in Config.Districts do
		if district.name == name then
			return district
		end
	end
	return nil
end

-- The highest district level this player may live in or buy into.
function Neighbourhoods.levelAllowed(unlocks: { [string]: boolean }): number
	return if unlocks.DistrictL3 then 3 elseif unlocks.DistrictL2 then 2 else 1
end

function Neighbourhoods.list(district: string): { Neighbourhood }
	local list = {}
	if store then
		pcall(function()
			list = (store :: DataStore):GetAsync(district) or {}
		end)
	end
	return list
end

-- Buys a plot in `district`: joins a neighbourhood with room, or starts a new one.
function Neighbourhoods.buyPlot(player: Player, districtName: string)
	local data = PlayerData.get(player)
	local district = Neighbourhoods.district(districtName)
	if not data or not district then
		return
	end
	if not data.unlocks.HomeDeed then
		notify(player, "Buy a Trailer Home in the Motel shop first.")
		return
	elseif data.home then
		notify(player, "You already have a home.")
		return
	elseif district.level > Neighbourhoods.levelAllowed(data.unlocks) then
		notify(player, `{districtName} needs a level {district.level} district permit.`)
		return
	end
	-- Reserve first: UpdateAsync's callback can't yield. An unused code costs nothing.
	local spareCode = Places.reserve()
	if not spareCode or not store then
		notify(player, "Homes need the published game.")
		return
	end
	local chosenCode, plot
	local ok = pcall(function()
		(store :: DataStore):UpdateAsync(districtName, function(list: { Neighbourhood }?)
			list = list or {}
			for _, neighbourhood in list :: { Neighbourhood } do
				if #neighbourhood.homes < Config.HOMES_PER_NEIGHBOURHOOD then
					table.insert(neighbourhood.homes, player.UserId)
					chosenCode, plot = neighbourhood.code, #neighbourhood.homes
					return list
				end
			end
			table.insert(list :: { Neighbourhood }, { code = spareCode, homes = { player.UserId } })
			chosenCode, plot = spareCode, 1
			return list
		end)
	end)
	if not ok then
		notify(player, "Buying the plot failed, try again.")
		return
	end
	data.home = { district = districtName, code = chosenCode, plot = plot }
	player:SetAttribute("HasHome", true)
	Neighbourhoods.goHome(player)
end

function Neighbourhoods.goHome(player: Player): boolean
	local data = PlayerData.get(player)
	local home = data and data.home
	if not home then
		return false
	end
	return Places.teleport({ player }, "Housing", { district = home.district, code = home.code }, home.code)
end

-- Anyone can load into a random neighbourhood of any district (to raid homes).
function Neighbourhoods.visit(player: Player, districtName: string): boolean
	local list = Neighbourhoods.list(districtName)
	if #list == 0 then
		notify(player, `Nobody lives in {districtName} yet.`)
		return false
	end
	local neighbourhood = list[math.random(#list)]
	return Places.teleport(
		{ player },
		"Housing",
		{ district = districtName, code = neighbourhood.code },
		neighbourhood.code
	)
end

return Neighbourhoods
