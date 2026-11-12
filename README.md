<img src="assets/icon.svg" width="64" height="64" alt="">

# roblox cnr

Created in [T3 Code](https://t3.codes).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` (Rojo, Wally, Selene, StyLua).
2. `wally install` to fetch packages into `Packages/`.
3. `rojo plugin install` for the Studio plugin, and install the VS Code extensions recommended in `.vscode/`.
   If it fails with "os error 2", create `%LOCALAPPDATA%\Roblox\Plugins` first and run it again.

## Develop

The whole game is ONE Roblox place. Each server works out what it is when it starts
(public servers are the Motel; raids, the Sales Center and neighbourhoods are reserved servers
that learn their kind from the arriving players). In Studio, each `*.project.json` sets
Workspace's `PlaceKind` attribute so you can test one kind at a time:

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

### Publishing

1. `rojo build hub.project.json -o game.rbxl`, open `game.rbxl` in Studio.
2. File > Publish to Roblox > Create new experience. That's it: travel, saving and matchmaking
   work in the published game (travel never works inside Studio).
3. Optional: Game Settings > Security > Studio Access to API Services, to save data while
   testing in Studio.
4. To update later: rebuild `game.rbxl`, open it, File > Publish to Roblox (same experience).

Real maps go in `ServerStorage.Maps.<Hub|Raid|Sales|Housing>`; they replace the placeholders.
