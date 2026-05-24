# Agent Guide

## Project Overview

This is a Godot 4.6 project for a 2D pixel-art management simulation game set in a Chinese township during the late 1980s and early 1990s.

The player is a middle-aged person who starts a small business after entering the private market economy. The long-term fantasy is not instant wealth, but earning money through labor, selling real goods, surviving pressure, and gradually expanding from a roadside stall into a stable shop.

Current repository: `UniquezCs/godot-pixel-sim`

## Core Game Direction

The game should focus on the satisfaction of turning labor into sales:

1. The player grows, raises, processes, or obtains goods through effort.
2. The player chooses where and when to sell based on foot traffic, weather, events, and risk.
3. The player sees goods leave inventory and money come in.
4. The player reinvests earnings into more production, better tools, transport, and business locations.

Selling should feel especially satisfying. Important feedback includes customers gathering, stock visibly decreasing, money increasing, satisfying sale sounds, end-of-day profit summaries, and tense last-minute clearance sales.

## First Prototype

The first playable loop is:

```text
Start with 5 apples -> walk into town -> choose a spot -> set up a roadside stall -> put apples from backpack onto the stall -> interact with NPC customers -> sell all 5 apples -> show settlement
```

Prototype goals:

- Start with 5 apples in the player's backpack.
- Let the player walk around a simple town map.
- Let the player choose a valid roadside spot and enter a stall/squatting state.
- Show a simple stall container such as a cloth mat or bamboo basket.
- Let the player move apples from backpack inventory onto the visible stall.
- NPCs should pass by, stop near the stall, ask about apples, and buy through interaction.
- Every sale should remove apples from the stall, add money, and provide strong feedback.
- Selling all 5 apples completes the prototype.
- Skip planting in the first prototype. Planting comes after selling feels good.

Important prototype principle:

- Harvesting and selling are the heart of the game. The first prototype should prove that putting goods on a stall and selling them to NPCs feels satisfying before adding crop growth, action points, or long-term economy.

## Long-Term Progression

Business stages:

1. Roadside stall
2. Tricycle selling
3. Truck selling
4. Fixed market stall
5. Rented shop
6. Owned shop

The first three stages should include township management risk. The player can be chased away, fined, lose goods, or in severe cases lose the tricycle or truck. This should be a strategic pressure, not just random punishment.

## Key Systems

- Labor and production
- Crops and livestock
- Inventory and freshness
- Foot traffic by location, time, weather, festival, and event
- Pricing and sales
- Customer demand and purchase probability
- Management inspection risk
- Daily action points and time pressure
- Money, reinvestment, and upgrades
- Business-stage progression

## Visual Style

The selected direction is clean, cute management-sim pixel art with a Chinese 1980s/1990s township identity.

Style notes:

- Bright, warm, approachable, and readable.
- Cute proportions, but adult characters should still feel like adults.
- Keep rural Chinese township details: brick houses, dirt roads, tricycles, old trucks, bamboo baskets, enamel mugs, abacus, ledgers, cloth price tags, old shopfronts, and roadside stalls.
- Avoid fantasy, modern city objects, smartphones, modern cars, or generic Western farm-game props.
- Selling scenes should feel lively and rewarding.

Reference images are stored in:

```text
docs/assets/style_refs/
```

The main design document is:

```text
docs/game_design.html
```

## Current Project Structure

```text
project.godot
scenes/main.tscn
scenes/player.tscn
scripts/player.gd
docs/game_design.html
docs/assets/style_refs/
addons/godot_ai/
```

Current implemented gameplay is only a basic movable `CharacterBody2D` player in `scenes/main.tscn`.

Movement controls:

- WASD
- Arrow keys

## Development Notes

- Use Godot 4.6.
- Keep Godot editor cache out of Git.
- Keep generated project assets inside the repository when they are referenced by scenes or docs.
- Prefer small, playable loops over large abstract systems.
- When adding gameplay, start from the 5-apple roadside selling prototype before expanding to planting, other crops, animals, shops, or towns.
- Keep UI and feedback focused on business pressure and sales satisfaction.

Useful local verification command:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/zhangcong/Documents/godot --quit
```

Run the main scene:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/zhangcong/Documents/godot --scene res://scenes/main.tscn --quit-after 1
```

## Collaboration Rules For Agents

- Read `docs/game_design.html` before making design-heavy changes.
- Preserve the selected visual style unless the user explicitly changes it.
- Do not remove Godot AI files under `addons/godot_ai/` unless asked.
- Do not commit or push unless the user asks.
- Keep changes scoped and explain what changed in plain language.
