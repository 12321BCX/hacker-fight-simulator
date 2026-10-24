# Hacker Fight Simulator

A beginner-friendly Roblox project for a hacker-themed arena fight game.

This repository includes:
- a one-time installer script to generate the Roblox structure automatically
- a server-authoritative gameplay setup
- a client-side GUI for movement, combat, teleport, ESP, and settings
- a reusable configuration module

## Project structure

- `Installer.lua` — one-click project generator for Roblox Studio
- `src/ReplicatedStorage/HackerFight/Modules/Config.lua` — shared settings
- `src/ServerScriptService/HackerFightServer.lua` — authoritative gameplay logic
- `src/StarterPlayer/HackerFightClient.lua` — GUI and client controls

## Quick start

1. Open Roblox Studio.
2. Create a new Baseplate place.
3. Open the Command Bar.
4. Paste `Installer.lua`.
5. Press Enter.
6. Play the place in Studio.

## Features included

- Fly
- ESP
- Kill Aura
- TP Walk
- Teleport to player
- God Mode
- Speed / Jump tweaks
- Noclip
- Combat validation
- Settings UI and basic save hooks

## Important note

This project is designed as a clean starter project for Roblox Studio beginners. The logic is split into server and client scripts so the server remains authoritative for sensitive actions like damage, teleportation, and invulnerability.

## License

MIT
