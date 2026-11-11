<img src="assets/icon.svg" width="64" height="64" alt="">

# roblox cnr

Created in [T3 Code](https://t3.codes).

## Setup

1. Install [Rokit](https://github.com/rojo-rbx/rokit), then run `rokit install` (Rojo, Wally, Selene, StyLua).
2. `wally install` to fetch packages into `Packages/`.
3. `rojo plugin install` for the Studio plugin, and install the VS Code extensions recommended in `.vscode/`.
   If it fails with "os error 2", create `%LOCALAPPDATA%\Roblox\Plugins` first and run it again.

## Develop

- `rojo serve`, then connect from the Rojo plugin in Studio. Code lives in `src/` (`client`, `server`, `shared`).
- `selene src` to lint, `stylua src` to format.
- `rojo build -o game.rbxl` to build a place file.
