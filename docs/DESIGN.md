# roblox-cnr design

Cops and robbers with instanced raids. Players have a safe hub and a home
of their own. They drive out into 1-hour Looty Bay servers to rob stores, sell
loot, and climb a tech tree toward bigger robberies.

Reference for the world map: a strategic "state" map split into hex
**districts**, each with a level (1-3) and icons for what's inside. Fixed
locations sit on the same map:

| Location | What it is |
|---|---|
| **Motel** | The hub. Safe zone, everyone spawns here |
| **Looty Bay** | The raid map (cops and robbers). First version ships with only this one |
| **Sales Center** | Separate PvP map with its own player limit. Sells loot at better prices. You can lose your inventory here |
| **Hex districts** | **Housing neighbourhoods**. Your home sits in one. Higher-level districts are unlocked through the tech tree |

The maps get built in a separate session (Looty Bay: [MAP_LOOTY_BAY.md](MAP_LOOTY_BAY.md)). For now the work is core
mechanics, tested on placeholder parts.

## Loop

1. **Motel (hub, safe zone).** Spawn here with a tiny stash and a free rental car.
2. **Drive out of the Motel border** → the world map opens → pick Looty Bay.
3. **Matchmaking** puts you (and your party) in a random server for that map. See Matchmaking.
4. **Raid server (max 25 players, max 5 cops, 1 hour).** You arrive as a `Civilian`.
   - **Rob a store** or **mask up** → `Criminal` until you leave the server.
   - **Sell** items at sell stations for cash.
   - **Police desk**: join (if under 5 cops) or go off duty.
5. **Leaving a raid server:**
   | How | Result |
   |---|---|
   | Cross the map border | Keep inventory → world map |
   | Arrested (downed + cuffed, or surrendered) | Inventory confiscated → hub with nothing |
   | Any death (not civilians) | Inventory drops in a lootable bag → hub with nothing |
   | Civilian killed | Removed from the server, **keeps all items**, no bag |
   | Server hits 1 hour | Everyone keeps inventory → world map (pick hub or home) |
6. You **never get matched back into a server you already left**.

## Robbery (Looty Bay)

- **Civilians and criminals** can rob, with no items needed. **Cops can't rob.**
- Robbing unmasked makes you a criminal on the spot. **Silent robbing** needs you to be a criminal already (masked up).
- A robbery location has **individual lootables** inside. Looting all of it takes a few minutes. You can leave at any time and keep what you grabbed.
- **Lootable** (register, safe, shelf): hold a prompt (3–10 s, depending on value) → it opens as a stash. **Drag** items into your inventory. You can't drag anything in once your inventory is full.
- **World items** (e.g. a TV, a plant): picked up directly, but only if you have room.
- A location **resets** a few minutes after it's robbed.
- **Detection**: **cameras** and **NPC witnesses** (clerks, security). If they spot you, cops get a map ping plus an in-world marker at the location. Cameras can be destroyed.
- **Holding up NPCs**: aim your gun at an NPC to keep them quiet. If nobody aims at them for **20 s**, they start a **5 s call** to the cops. Aiming at them again cancels the call. The criminal gets an **audio and visual cue** when a call starts. **Killing an NPC** makes you **wanted** instantly.
- **Criminal level** (0–5) goes up 5% of a level per item looted (20 items per level), and resets to 0 every raid. Sell bonus is +5% per level, so **+25% at level 5**. Arresting a level-5 criminal gives the cop a slightly bigger share of the confiscated items.
- **3 sell stations**, all paying the same base price (scaled by your criminal level).
- **One police station.** Going off duty is final for that raid.
- Cops only see **wanted** criminals on the map. Alerts mark the location, not the robber.

## Matchmaking

- Not a server browser. You pick a map, and you're placed into a **random** server for it.
- **Parties** of up to 4 join together, so a server needs room for the whole party. Party members can be on different sides.
- **Skill-based**: prefer servers whose average skill is close to the party's. Skill = player level + gear value. Levels aren't designed yet, so use gear value alone until they are.
- **Exclude** servers that any party member already left, and servers close to their 1-hour end.
- If no server fits, reserve a new one.

## Roles and combat

| Role | Weapon out? | Can hurt | Notes |
|---|---|---|---|
| Civilian | no | nobody | Can mask up to become a criminal |
| Criminal | yes | anyone | Can surrender. Downing or killing a civilian → **wanted** |
| Police | yes | criminals only | Can down and arrest a criminal, or kill them outright |

- **Downed state (Fortnite-style), for everyone**: at 0 HP you go down instead of dying. You can crawl but not fight. From there you can be:
  - **finished** (death → death bag),
  - **arrested**, if you're a criminal and a cop does it,
  - **revived** by holding a key on you. Cops revive cops and criminals revive criminals. Civilians can't revive, and nobody revives them,
  - or you **bleed out** after **45 s**. The timer runs at **2x speed while you crawl**.
- Downed players can't be carried.
- **Downing** a civilian already makes the criminal **wanted**. The civilian doesn't have to be finished off.
- **Wanted**: every player sees the criminal's location at all times. It lasts until they leave the server, die, or get arrested. Cops get a **bounty** for arresting a wanted criminal.
- **Arrest rewards**: the cop gets a small % of confiscated items, plus cash equal to a % of the inventory value. Their share of the items goes to a personal **police station stash** they can take from once they're off duty. A cop who **kills** a criminal gets no arrest reward. The criminal's inventory drops in a normal death bag instead.
- **Police kit**: going on duty locks your personal inventory away and you pick a police loadout. A dead cop drops only the issued kit. Going off duty gives your personal inventory back **right away**, in the same raid.
- **Surrender**: a criminal presses a key to put their hands up, then a cop can arrest them. Downed criminals can't surrender, because a cop can just arrest them.
- **Masks** don't hide your name tag.
- **Ammo** is an inventory item. **Healing** only comes from items (bandages, medkits). Health doesn't regenerate.
- **No friendly fire** inside a party.
- **Death bags** disappear after **5 min**.

## Inventory and progression

- Your loadout is always on you. Move items between your inventory and stashes.
- **Grid inventory** (Tarkov-style): items have grid sizes (a TV is bigger than a watch). Grid size comes from your **bag**, which you can upgrade.
  shortcut: first build uses a simple slot list (1 item = 1 slot); the grid comes later.
- **Trading**: right-click an item → give it to another player.
- **Stashes**: a tiny one in the hub (**20 slots**), a bigger one at home. The starting bag has **12 slots**.
- **Shop**: skin cosmetics bought with Robux.
- **Tech tree**: everything costs cash except the starter pistol. Higher tiers unlock tools for bigger robberies.
- **Stores** drop items, and sometimes progression items for the next robbery tier. Tiers: undecided.

## Cars

- Everyone gets a free rental. Better cars can be bought and are owned forever.
- A car stays spawned in the raid server until you **recall** it. If you died, recalling drops its trunk loot in a bag.
- **Lockpicking** a car opens its **trunk**. Thieves can't drive it away. Car security upgrades make lockpicking harder.

## Homes

- Housing is **its own world**: neighbourhood servers of about **8 homes**. You pick your plot on the world map.
- You **own** your home for now. Rent is undecided.
- Anyone can load into any neighbourhood from the world map.
- Homes can be raided, **including offline**. Raiders need certain items to get past the security (undecided). Once inside, they can take **everything in every stash** in the home.
- **Security upgrades** can notify you in-game while your home is being raided.

## Places (one Roblox experience)

| Place | Role |
|---|---|
| Motel (start place) | Hub: safe zone, small stash, tech tree shop, rental car, exit border → world map |
| Looty Bay | Raid: roles, stores, sell stations, police desk, downed/arrest, bags, cars, border, 1-hour shutdown |
| Sales Center | PvP selling map, own player limit |
| Housing (one place per hex district) | Neighbourhoods of ~8 plots, home stash, home raiding |

- Raid servers are reserved servers (`TeleportService:ReserveServer`, `MaxPlayers = 25`).
- Each server reports `{ map, accessCode, players, cops, avgSkill, startedAt }` to a `MemoryStoreService` sorted map with a short TTL. Matchmaking reads from it.
- Player data (inventory, stashes, cash, unlocks, cars, home, pending cop rewards, servers already left) lives in DataStore and is saved on every teleport.
- Teleports only work in a published experience. Each map's logic can be tested alone in Studio.

## Milestones

Until the map exists, mechanics are tested on placeholder parts in a
`Workspace.Placeholder` folder that the map session can delete.

All eight milestones have a first version in code (untested in a live server):

1. Roles, police desk, mask up, lootables, criminal level.
2. Cash, sell stations, world items, giving items.
3. Combat, downed/revive, surrender/arrest, police stash, wanted, border, cameras, witnesses.
4. Motel hub: stash, shop, garage, map border → world map → teleports; 1-hour raid end.
5. Parties (Motel) + matchmaking by gear value, never back into a raid you left.
6. Tech tree shop (placeholder contents), owned cars, trunks, lockpicking, recall.
7. Housing: neighbourhoods of 8 plots, home stash, break-ins, alarms, offline raiding.
8. Grid bag with item sizes (drag to move). Stashes are still simple lists.

Still open: robbery tiers, player levels/XP, real tech tree contents, rent, home break-in items beyond the Crowbar.
