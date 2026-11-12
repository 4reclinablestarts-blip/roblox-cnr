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
		{ name = "Patrol", items = { "PolicePistol", "PistolAmmo", "Handcuffs", "Bandage" } },
		{ name = "Pursuit", items = { "PoliceShotgun", "ShotgunAmmo", "Handcuffs", "Bandage", "Bandage" } },
	},

	ITEMS_PER_CRIMINAL_LEVEL = 20,
	MAX_CRIMINAL_LEVEL = 5,

	LOOT_RANGE = 12, -- studs; server rejects stash use from further away
	LOOT_RESET = 180, -- seconds after the first item is taken
	SELL_BONUS_PER_LEVEL = 0.05, -- criminal level 5 sells for +25%
	GIVE_RANGE = 10, -- studs between players to give an item

	-- Combat. Damage is per hit (per pellet for shotguns); players have 100 HP.
	Weapons = {
		StarterPistol = { damage = 20, cooldown = 0.35, range = 250, ammo = "PistolAmmo" },
		PolicePistol = { damage = 25, cooldown = 0.3, range = 300, ammo = "PistolAmmo" },
		PoliceShotgun = { damage = 12, pellets = 6, spread = 4, cooldown = 0.9, range = 90, ammo = "ShotgunAmmo" },
	},
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

	Items = {
		StarterPistol = { name = "Starter Pistol", value = 0 },
		PolicePistol = { name = "Police Pistol", value = 0 },
		PoliceShotgun = { name = "Police Shotgun", value = 0 },
		PistolAmmo = { name = "Pistol Ammo", value = 1, stackable = true, defaultAmount = 36 },
		ShotgunAmmo = { name = "Shotgun Ammo", value = 2, stackable = true, defaultAmount = 16 },
		Handcuffs = { name = "Handcuffs", value = 0 },
		Bandage = { name = "Bandage", value = 10 },
		-- Real money: one stacking slot. Selling pays into it, registers drop it.
		Money = { name = "Cash", value = 0, stackable = true, lootAmount = { 20, 80 } },
		Watch = { name = "Watch", value = 80 },
		Phone = { name = "Phone", value = 120 },
		Snacks = { name = "Snacks", value = 5 },
		Cigarettes = { name = "Cigarettes", value = 15 },
		TV = { name = "TV", value = 300 },
		Plant = { name = "Plant", value = 40 },
	},

	-- Each lootable rolls `count` picks from `items` when it fills.
	LootTables = {
		Register = { count = { 2, 4 }, items = { "Money", "Money", "Money", "Cigarettes" } },
		Shelf = { count = { 3, 6 }, items = { "Snacks", "Snacks", "Cigarettes", "Phone", "Watch" } },
	},
}
