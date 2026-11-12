<img src="assets/icon.svg" width="64" height="64" alt="">

# roblox cnr

Created in [T3 Code](https://t3.codes).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` (Rojo, Wally, Selene, StyLua).
2. `wally install` to fetch packages into `Packages/`.
3. `rojo plugin install` for the Studio plugin, and install the VS Code extensions recommended in `.vscode/`.
   If it fails with "os error 2", create `%LOCALAPPDATA%\Roblox\Plugins` first and run it again.

## Develop

The experience has four places built from the same code. Each `*.project.json` sets
Workspace's `PlaceKind` attribute, which picks what the server runs:

| Project | Place |
|---|---|
| `default.project.json` | Looty Bay (raid) |
| `hub.project.json` | Lenny's Motel (hub, start place) |
| `sales.project.json` | Sales Center |
| `housing.project.json` | Neighbourhoods |

- `rojo serve` (Looty Bay), or e.g. `rojo serve hub.project.json --port 34873` for another place,
  then connect from the Rojo plugin in Studio. Code lives in `src/` (`client`, `server`, `shared`).
- `selene src` to lint, `stylua src` to format.
- `rojo build hub.project.json -o hub.rbxl` to build a place file.

### Publishing (needed for travel between places)

1. Publish the Motel as the experience's start place, then add the other three places to the
   same experience (Asset Manager > Places > Add New Place) and publish each one.
2. Put the four place IDs in `Config.PlaceIds` (`src/shared/Config.luau`).
3. In Game Settings > Security, turn on Studio Access to API Services (for saving in Studio).
4. Set Max Players: Looty Bay 25, Motel and Sales Center as you like, Neighbourhoods ~16.

Until then (and always in Studio) travel falls back to staying in the current place,
and player data only saves if API access is on.
