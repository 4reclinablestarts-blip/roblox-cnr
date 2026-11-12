-- Tunable game rules. See docs/DESIGN.md.
return {
	Teams = {
		Civilian = BrickColor.new("Medium stone grey"),
		Criminal = BrickColor.new("Bright red"),
		Police = BrickColor.new("Bright blue"),
	},

	MAX_COPS = 5,
	BAG_SLOTS = 12,
	STARTING_ITEMS = { "StarterPistol", "PistolAmmo" },

	-- shortcut: loadouts are picked with one desk prompt each, upgrade to a picker UI when there are more than ~3.
	PoliceLoadouts = {
		{ name = "Patrol", items = { "PolicePistol", "PistolAmmo", "PistolAmmo", "Handcuffs", "Bandage" } },
		{ name = "Pursuit", items = { "PoliceShotgun", "ShotgunAmmo", "Handcuffs", "Bandage", "Bandage" } },
	},

	ITEMS_PER_CRIMINAL_LEVEL = 20,
	MAX_CRIMINAL_LEVEL = 5,

	LOOT_RANGE = 12, -- studs; server rejects stash use from further away
	LOOT_RESET = 180, -- seconds after the first item is taken
	SELL_BONUS_PER_LEVEL = 0.05, -- criminal level 5 sells for +25%
	GIVE_RANGE = 10, -- studs between players to give an item

	Items = {
		StarterPistol = { name = "Starter Pistol", value = 0 },
		PolicePistol = { name = "Police Pistol", value = 0 },
		PoliceShotgun = { name = "Police Shotgun", value = 0 },
		PistolAmmo = { name = "Pistol Ammo", value = 5 },
		ShotgunAmmo = { name = "Shotgun Ammo", value = 8 },
		Handcuffs = { name = "Handcuffs", value = 0 },
		Bandage = { name = "Bandage", value = 10 },
		Cash = { name = "Cash Stack", value = 50 },
		Watch = { name = "Watch", value = 80 },
		Phone = { name = "Phone", value = 120 },
		Snacks = { name = "Snacks", value = 5 },
		Cigarettes = { name = "Cigarettes", value = 15 },
		TV = { name = "TV", value = 300 },
		Plant = { name = "Plant", value = 40 },
	},

	-- Each lootable rolls `count` picks from `items` when it fills.
	LootTables = {
		Register = { count = { 2, 4 }, items = { "Cash", "Cash", "Cash", "Cigarettes" } },
		Shelf = { count = { 3, 6 }, items = { "Snacks", "Snacks", "Cigarettes", "Phone", "Watch" } },
	},
}
