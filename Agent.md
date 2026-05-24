# Agent Guide

## Project Overview

This is a Godot 4.6 project for a 2D pixel-art management simulation game set in a Chinese township during the late 1980s and early 1990s.

The player is a middle-aged person who starts a small business after entering the private market economy. The long-term fantasy is not instant wealth, but earning money through labor, selling real goods, judging risk and reward, surviving family and cash-flow pressure, and gradually growing from doing everything alone into managing goods, money, locations, people, and risk.

Current repository: `UniquezCs/godot-pixel-sim`

## Core Game Direction

The game should focus on the satisfaction of turning labor into sales, but its strategic center is business judgment rather than pure labor execution:

1. The player grows, raises, processes, or obtains goods through effort.
2. The player decides whether going out to sell is worth the risk, based on inventory, freshness, bills, foot traffic, transport capacity, location risk, time, and events.
3. The player chooses what to carry, how much to carry, where to sell, how to price goods, and how long to stay.
4. The player sees goods leave inventory, money come in, customers react, and risk events change the day's outcome.
5. The player reinvests earnings into more production, better transport, broader inventory, stable locations, debt buffers, and eventually employees.

Selling should feel especially satisfying. Important feedback includes customers gathering, stock visibly decreasing, money increasing, satisfying sale sounds, clear rejection/acceptance feedback, end-of-day profit summaries, and tense last-minute clearance sales.

The main daily decision chain is:

```text
Check inventory and freshness -> check cash, bills, and debt pressure -> read location opportunity and risk -> decide whether to sell -> choose goods and carrying method -> choose location -> set price -> decide how long to stay -> settle profit, loss, risk, and tomorrow's plan
```

## First Prototype

The first playable loop is:

```text
Plant apple seeds at home -> wait for a short growth cycle -> harvest 5 apples -> go to town -> choose a selling spot -> set up a roadside stall -> put apples from backpack onto the stall -> set the price -> sell to NPC customers -> earn cash -> buy seeds -> plant again -> show settlement
```

Prototype goals:

- Build a 10-15 minute playable loop with minimal farming, selling, and reinvestment.
- Start at a home/farm scene with a small number of fixed plots.
- Let the player plant apple seeds, wait through a short readable growth cycle, and harvest 5 apples into the backpack.
- Let the player travel to a town street scene.
- Let the player choose a valid roadside spot and enter a stall/squatting state.
- Show a simple stall container such as a cloth mat or bamboo basket.
- Let the player move apples from backpack inventory onto the visible stall.
- Let the player set the apple price.
- NPCs should pass by, stop near the stall, ask about apples, and decide whether to buy based on customer type and price.
- Every sale should remove apples from the stall, add money, and provide strong feedback.
- Rejections should be readable and non-punitive, such as "too expensive" or "maybe next time."
- Selling the first batch, buying seeds, and planting again completes the prototype.

Important prototype principle:

- Farming in the first prototype should be minimal. It exists to make the apples feel earned and to close the reinvestment loop.
- Selling remains the emotional center. The prototype should prove that putting goods on a stall, pricing them, reading customers, and seeing cash come in feels satisfying.
- Do not add management inspection risk, weather, festivals, freshness decay, employees, or long-term upgrades to the first prototype unless explicitly requested.
- The dedicated prototype document is `docs/prototype_v1_plan.html`.

## Long-Term Progression

Long-term progression should emphasize expanding business scale, not just unlocking a fixed stage ladder.

Growth dimensions:

- Goods scale: from a few self-produced goods to multiple crops, processed goods, daily items, and bulk purchased stock.
- Inventory scale: from backpack stock to vehicle stock, stall stock, and storage stock.
- Foot traffic scale: from scattered roadside customers to markets, factory gates, school gates, regular stalls, and stable shop traffic.
- Business radius: from short local selling to cross-village and cross-township routes.
- Cash-flow scale: from same-day cash turnover to rent, wages, repairs, fines, debt, and family expenses.
- Organization scale: from doing everything alone to hiring people for farming, processing, selling, transport, purchasing, and bookkeeping.

Different selling methods must have different carrying capacity, mobility, cost, and risk exposure:

- Hand-carry/back basket: low capacity, low cost, flexible, small loss if caught.
- Shoulder pole/bamboo baskets: medium capacity, slower movement, good for short-distance selling.
- Tricycle: larger capacity and route choice, but higher loss if fined or goods are seized.
- Small truck: highest mobile capacity and cross-area opportunity, with fuel, repair, fine, and vehicle seizure risk.
- Fixed stall/shop: shifts from carrying capacity to display space, storage, rent, staff, and stable foot traffic.

## Key Systems

- Labor and production
- Crops and livestock
- Inventory and freshness
- Foot traffic by location, time, weather, festival, and event
- Pricing and sales
- Ordinary customer types and important relationship NPCs
- Customer demand, purchase probability, budget, and preference
- Management inspection risk with readable warnings, probability differences, response windows, and loss limits
- Carrying capacity, mobility, and selling method trade-offs
- Daily decision pressure around whether to sell, where to sell, what to carry, how much to carry, how to price, and how long to stay
- Money, reinvestment, and upgrades
- Family bills, debt pressure, soft failure states, and a distant bankruptcy failure line
- Employees, wages, trust, skill, mistakes, and management cost
- Business-scale progression

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

The first prototype plan is:

```text
docs/prototype_v1_plan.html
```

## Current Project Structure

```text
project.godot
scenes/main.tscn
scenes/player.tscn
scripts/player.gd
docs/game_design.html
docs/prototype_v1_plan.html
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
- When adding gameplay, start from the first prototype plan: minimal apple planting, town selling, player-set price, NPC customer decisions, cash gain, seed purchase, and planting again.
- Keep the main `docs/game_design.html` focused on the overall game direction. Keep prototype-specific goals in `docs/prototype_v1_plan.html`.
- Keep UI and feedback focused on business pressure and sales satisfaction.

Useful local verification command:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/hui/project/godot-pixel-sim --quit
```

Run the main scene:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/hui/project/godot-pixel-sim --scene res://scenes/main.tscn --quit-after 1
```

## Collaboration Rules For Agents

- Read `docs/game_design.html` before making design-heavy changes.
- Read `docs/prototype_v1_plan.html` before making first-prototype implementation changes.
- Preserve the selected visual style unless the user explicitly changes it.
- Do not remove Godot AI files under `addons/godot_ai/` unless asked.
- Do not commit or push unless the user asks.
- Keep changes scoped and explain what changed in plain language.
