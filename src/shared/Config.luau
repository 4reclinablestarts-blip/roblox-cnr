-- Tunable game rules. See docs/DESIGN.md.
return {
	Teams = {
		Civilian = BrickColor.new("Medium stone grey"),
		Criminal = BrickColor.new("Bright red"),
		Police = BrickColor.new("Bright blue"),
	},

	MAX_COPS = 5,
	RAID_MAX_PLAYERS = 25,
	SALES_MAX_PLAYERS = 30,
	RAID_DURATION = 3600,
	RAID_JOIN_CUTOFF = 600, -- matchmaking stops sending players this many seconds before the raid ends
	MAP_CHOICE_TIME = 60, -- seconds to pick a destination after a raid ends before you're sent to the Motel
	MAX_PARTY = 4,
	SKILL_TOLERANCE = 1500, -- gear value difference still counted as "close" for matchmaking

	STARTING_ITEMS = { "StarterPistol", "PistolAmmo" },

	-- Bag grid (columns, rows) per bag level. Upgrades come from the tech tree.
	BagSizes = { { 4, 3 }, { 4, 4 }, { 5, 5 }, { 6, 6 } },
	HUB_STASH_SLOTS = 20,
	HOME_STASH_SLOTS = 40,

	-- shortcut: loadouts are picked with one desk prompt each, upgrade to a picker UI when there are more than ~3.
	PoliceLoadouts = {
		{ name = "Patrol", items = { "PolicePistol", "PistolAmmo", "Handcuffs", "Bandage" } },
		{ name = "Pursuit", items = { "PoliceShotgun", "ShotgunAmmo", "Handcuffs", "Bandage", "Bandage" } },
	},

	ITEMS_PER_CRIMINAL_LEVEL = 20,
	MAX_CRIMINAL_LEVEL = 5,

	LOOT_RANGE = 12, -- studs; server rejects stash use from further away
	LOOT_RESET = 180, -- seconds after the first item is taken
	SELL_BONUS_PER_LEVEL = 0.05, -- criminal level 5 sells for +25%
	SALES_CENTER_BONUS = 0.5, -- the Sales Center pays +50%
	GIVE_RANGE = 10, -- studs between players to give an item

	-- Combat. Damage is per hit (per pellet for shotguns); players have 100 HP.
	Weapons = {
		StarterPistol = { damage = 20, cooldown = 0.35, range = 250, ammo = "PistolAmmo" },
		PolicePistol = { damage = 25, cooldown = 0.3, range = 300, ammo = "PistolAmmo" },
		PoliceShotgun = { damage = 12, pellets = 6, spread = 4, cooldown = 0.9, range = 90, ammo = "ShotgunAmmo" },
		SMG = { damage = 14, cooldown = 0.1, range = 200, ammo = "PistolAmmo" },
	},
	Heals = { Bandage = 25, Medkit = 75 },
	BLEED_OUT = 45, -- seconds while downed; crawling drains it at 2x
	DOWNED_SPEED = 4,
	REVIVE_TIME = 5,
	REVIVE_HEALTH = 30,
	DEATH_BAG_LIFETIME = 300,

	-- Arrests. The cop gets each confiscated item with this chance, plus cash = value share (+ bounty if wanted).
	ARREST_TIME = 2,
	ARREST_ITEM_SHARE = 0.2,
	ARREST_ITEM_SHARE_MAX_LEVEL = 0.3, -- arresting a level-5 criminal
	ARREST_CASH_SHARE = 0.1,
	WANTED_BOUNTY = 500,

	-- Detection. Cameras and NPC witnesses alert the cops with a marker at their location.
	CAMERA_RANGE = 60,
	CAMERA_FOV = 70, -- degrees either side of where the camera points
	CAMERA_HEALTH = 30,
	CAMERA_REPAIR = 300, -- seconds until a shot-out camera works again
	WITNESS_RANGE = 40,
	WITNESS_HEALTH = 50,
	WITNESS_PATIENCE = 20, -- seconds without a gun on them before they call
	WITNESS_CALL_TIME = 5,
	AIM_RANGE = 60, -- studs; holding up a witness from further away does nothing
	ALERT_DURATION = 30,

	-- Cars. security comes from tech tree upgrades and slows down lockpicking the trunk.
	Cars = {
		Rental = { name = "Rental", speed = 45, trunkSlots = 6, color = Color3.fromRGB(150, 150, 140) },
		Sedan = { name = "Sedan", speed = 65, trunkSlots = 10, color = Color3.fromRGB(40, 60, 110) },
		Sports = { name = "Sports Car", speed = 85, trunkSlots = 6, color = Color3.fromRGB(180, 30, 30) },
	},
	LOCKPICK_TIME = 4, -- seconds, plus the same again per car security level

	-- Housing districts from the world map. Level 2-3 need a tech tree permit.
	Districts = {
		{ name = "Dustbowl", level = 1 },
		{ name = "Redstone", level = 1 },
		{ name = "Fairfield", level = 1 },
		{ name = "Loneford", level = 1 },
		{ name = "Rustvale", level = 1 },
		{ name = "Cascadas", level = 1 },
		{ name = "Rivertown", level = 2 },
		{ name = "Fallrock", level = 2 },
		{ name = "El Peso", level = 2 },
		{ name = "Highlands", level = 3 },
	},
	HOMES_PER_NEIGHBOURHOOD = 8,
	BREAK_IN_TIME = 10, -- seconds, plus the same again per home security level

	-- Tech tree. Everything costs cash from your bag. `item` puts an item in your bag;
	-- otherwise buying unlocks `id` for good. `requires` lists unlocks you need first.
	-- shortcut: placeholder contents and prices; robbery tiers are still undecided.
	TechTree = {
		{ id = "StarterPistol", name = "Starter Pistol", cost = 0, item = "StarterPistol" },
		{ id = "PistolAmmo", name = "Pistol Ammo (36)", cost = 40, item = "PistolAmmo" },
		{ id = "Bandage", name = "Bandage", cost = 30, item = "Bandage" },
		{ id = "Medkit", name = "Medkit", cost = 150, item = "Medkit" },
		{ id = "Lockpick", name = "Lockpick", cost = 200, item = "Lockpick" },
		{ id = "BagL2", name = "Bigger Bag (4x4)", cost = 500 },
		{ id = "Crowbar", name = "Crowbar", cost = 600, item = "Crowbar", requires = { "BagL2" } },
		{ id = "HomeDeed", name = "Trailer Home", cost = 1000 },
		{ id = "Sedan", name = "Sedan", cost = 2500, requires = { "BagL2" } },
		{ id = "CarSecurity1", name = "Car Alarm (security 1)", cost = 800, requires = { "Sedan" } },
		{ id = "HomeSecurity1", name = "Home Alarm (security 1)", cost = 1500, requires = { "HomeDeed" } },
		{ id = "BagL3", name = "Backpack (5x5)", cost = 2000, requires = { "BagL2" } },
		{ id = "SMG", name = "SMG", cost = 3000, item = "SMG", requires = { "BagL3" } },
		{ id = "DistrictL2", name = "District Permit (level 2)", cost = 4000, requires = { "HomeDeed" } },
		{ id = "CarSecurity2", name = "Car Immobilizer (security 2)", cost = 2500, requires = { "CarSecurity1" } },
		{ id = "HomeSecurity2", name = "Reinforced Door (security 2)", cost = 4000, requires = { "HomeSecurity1" } },
		{ id = "Sports", name = "Sports Car", cost = 9000, requires = { "Sedan", "BagL3" } },
		{ id = "BagL4", name = "Hiking Pack (6x6)", cost = 6000, requires = { "BagL3" } },
		{ id = "DistrictL3", name = "District Permit (level 3)", cost = 12000, requires = { "DistrictL2" } },
	},

	-- size = { columns, rows } in the bag grid; 1x1 if missing.
	Items = {
		StarterPistol = { name = "Starter Pistol", value = 0 },
		PolicePistol = { name = "Police Pistol", value = 0 },
		PoliceShotgun = { name = "Police Shotgun", value = 0, size = { 3, 1 } },
		SMG = { name = "SMG", value = 600, size = { 2, 1 } },
		PistolAmmo = { name = "Pistol Ammo", value = 1, stackable = true, defaultAmount = 36 },
		ShotgunAmmo = { name = "Shotgun Ammo", value = 2, stackable = true, defaultAmount = 16 },
		Handcuffs = { name = "Handcuffs", value = 0 },
		Bandage = { name = "Bandage", value = 10 },
		Medkit = { name = "Medkit", value = 60, size = { 1, 2 } },
		Lockpick = { name = "Lockpick", value = 40 },
		Crowbar = { name = "Crowbar", value = 120, size = { 1, 2 } },
		-- Real money: one stacking slot. Selling pays into it, registers drop it.
		Money = { name = "Cash", value = 0, stackable = true, lootAmount = { 20, 80 } },
		Watch = { name = "Watch", value = 80 },
		Phone = { name = "Phone", value = 120 },
		Snacks = { name = "Snacks", value = 5 },
		Cigarettes = { name = "Cigarettes", value = 15 },
		TV = { name = "TV", value = 300, size = { 2, 2 } },
		Plant = { name = "Plant", value = 40, size = { 1, 2 } },
	},

	-- Each lootable rolls `count` picks from `items` when it fills.
	LootTables = {
		Register = { count = { 2, 4 }, items = { "Money", "Money", "Money", "Cigarettes" } },
		Shelf = { count = { 3, 6 }, items = { "Snacks", "Snacks", "Cigarettes", "Phone", "Watch" } },
	},
}
