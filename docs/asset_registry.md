# Asset Registry

This document is the human-readable companion to `configs/assets.json`.
The JSON file is the source of truth for stable asset ids, paths, status, and future art requirements.

## Status Meaning

- `implemented`: currently used by scenes, scripts, or configs.
- `available`: asset exists in the repository but is not wired into gameplay yet.
- `placeholder`: gameplay uses a temporary or semantically imperfect asset.
- `missing`: design needs the asset, but no suitable asset is registered.

## Global Standards

- Tile size: `32x32`
- Character/NPC frame size: `48x64`
- Small prop and inventory icon size: `32x32`
- Texture filtering: nearest-neighbor
- Default anchor: center
- Collision belongs to gameplay nodes, not bitmap files.
- Missing resources should be represented with placeholders until art generation is explicitly requested.

## Generated Pack Metadata

- `assistant_art_2026_05_29/manifest.json` now includes stable item IDs, type, path, size, anchor, collision, usage, and tags for generated farm plots, crop icons, UI icons, and props.
- `ui_skins_2026_05_29/manifest.json` now includes stable component IDs, type, path, size, anchor, collision, usage, and tags for backpack and shop UI components.
- `critical_icons_2026_05_29/manifest.json` includes stable IDs for pear, non-apple seed packets, fertilizer, sickle, warning, and fine icons.
- Normalized `32x32` variants exist for generated crop icons and reusable UI icons. These are preferred for inventory/HUD usage.

## Current Resource Needs By System

### TileMap And Scene Ground

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `tileset.rural_town_32` | implemented | `res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres` | Used by Home, Town, House ground layers, and the Town `StallAreaLayer` marker layer. |
| `tileset.prototype_scene_32` | available | `res://assets/generated/prototype_v1_32/tiles/prototype_scene_tileset_32.tres` | Legacy/reference tileset. |
| `location.house_interior_floor` | placeholder | rural town tileset | HouseScene now has a visible TileMapLayer background marker; needs proper 1990s rural house interior floor/wall tiles. |

### Characters And NPCs

| Asset ID | Status | Current Resource | Future Need |
| --- | --- | --- | --- |
| `character.vendor` | implemented | `vendor_walk_spriteframes_48x64.tres` | Already usable as `AnimatedSprite2D`. |
| `character.student_customer` | placeholder | static `customer_student_48x64.png` | v2 animated SpriteFrames exists; integrate when Customer uses animation. |
| `character.worker_customer` | placeholder | static `customer_worker_48x64.png` | v2 animated SpriteFrames exists; integrate when Customer uses animation. |
| `character.chengguan` | placeholder | worker texture reused | Needs dedicated chengguan NPC, 4 directions, 8 frames each, `48x64`. |

### Item Icons

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `item.apple` | implemented | `assistant_art_2026_05_29/crop_icons/items/apple_32.png` | Also has v1 fallback. |
| `item.apple_seed` | implemented | `prototype_v2/ui/apple_seed_packet_32.png` | Wired in `configs/items.json`. |
| `item.cabbage` | implemented | `assistant_art_2026_05_29/crop_icons/items/cabbage_32.png` | Normalized from existing generated crop icon. |
| `item.cucumber` | implemented | `assistant_art_2026_05_29/crop_icons/items/cucumber_32.png` | Normalized from existing generated crop icon. |
| `item.tomato` | implemented | `assistant_art_2026_05_29/crop_icons/items/tomato_32.png` | Normalized from existing generated crop icon. |
| `item.pear` | implemented | `critical_icons_2026_05_29/items/pear_32.png` | Wired in `configs/items.json`. |
| `item.potato` | implemented | `assistant_art_2026_05_29/crop_icons/items/potato_32.png` | Normalized from existing generated crop icon. |
| `item.cabbage_seed` | implemented | `critical_icons_2026_05_29/items/cabbage_seed_packet_32.png` | Dedicated seed packet. |
| `item.cucumber_seed` | implemented | `critical_icons_2026_05_29/items/cucumber_seed_packet_32.png` | Dedicated seed packet. |
| `item.tomato_seed` | implemented | `critical_icons_2026_05_29/items/tomato_seed_packet_32.png` | Dedicated seed packet. |
| `item.pear_seed` | implemented | `critical_icons_2026_05_29/items/pear_seed_packet_32.png` | Dedicated seed packet. |
| `item.potato_seed` | implemented | `critical_icons_2026_05_29/items/potato_seed_packet_32.png` | Dedicated seed packet. |
| `item.generic_seed` | available | generic seed bag | Fallback only; active crop seeds have dedicated icons. |
| `item.fertilizer` | implemented | `critical_icons_2026_05_29/items/fertilizer_bag_32.png` | Wired in `configs/items.json`. |

### Tools

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `tool.hoe` | available | `assistant_art_2026_05_29/ui_icons/items/hoe_32.png` | Normalized `32x32`; not wired into HUD yet. |
| `tool.water` | available | `assistant_art_2026_05_29/ui_icons/items/watering_can_32.png` | Normalized `32x32`; not wired into HUD yet. |
| `tool.sickle` | available | `critical_icons_2026_05_29/items/sickle_32.png` | Not wired into HUD yet. |

### Farm Plots

Current gameplay uses `scenes/farm_plot.tscn` with a `Sprite2D` scaled to one `32x32` tile.

| Asset ID | Status | Current Resource | Better Available Candidate |
| --- | --- | --- | --- |
| `farm_plot.empty` | implemented | `farm_empty_64.png` | `grass_patch.png` |
| `farm_plot.tilled` | placeholder | `farm_seeded_64.png` | `freshly_hoed.png` |
| `farm_plot.seeded` | placeholder | `farm_growing_64.png` | `seeded.png` |
| `farm_plot.watered` | placeholder | `farm_growing_64.png` | `watered_seeded.png` |
| `farm_plot.ready` | implemented | `farm_ready_64.png` | `harvest_ready.png` |

### Stall Visuals

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `stall.empty` | implemented | `01_stall_empty.png` | Stock 0. |
| `stall.stock_1` | implemented | `04_stall_apple_1.png` | Stock 1. |
| `stall.stock_3` | implemented | `03_stall_apples_3.png` | Stock 2-3. |
| `stall.stock_6` | implemented | `02_stall_apples_6.png` | Stock 4+. |
| `stall.dirty_or_confiscated` | available | `05_stall_dirty.png` | Candidate for future chengguan feedback. |
| `stall.upgraded_level_2` | missing | none | Needs higher-capacity stall visual. |
| `stall.upgraded_level_3` | missing | none | Needs larger stall visual. |

### Locations And Buildings

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `location.school_gate` | implemented | `school_gate_256x128.png` | Used as a Town `NpcEndpoint` visual and centralized route destination; alternate cutout exists. |
| `location.factory_gate` | implemented | `factory_gate_256x128.png` | Used as a Town `NpcEndpoint` visual and centralized route destination; alternate cutout exists. |
| `location.residential_area` | implemented | `residential_area_320x128.png` | Used as a Town `NpcEndpoint` visual and centralized same-id home endpoint pool. |
| `location.seed_shop` | implemented | `seed_shop_64x64.png` | v2 seed shop stand exists. |
| `location.home_exterior` | placeholder | embedded environment texture region | v2 rural house facade exists. |
| `location.house_bed` | placeholder | folded tarp cutout | v2 bed roll exists. |
| `location.house_ledger` | implemented | ledger book cutout | v2 ledger table exists. |

### UI

Current UI is mostly Godot `Control` nodes with text and panels. This is acceptable for programmer implementation.

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `ui.hud` | placeholder | text labels | v2 UI icons exist. |
| `ui.backpack_panel` | placeholder | Control nodes | UI skin pack exists with registered component IDs. |
| `ui.shop_panel` | placeholder | Control nodes | UI skin pack exists with registered component IDs. |
| `ui.price_panel` | placeholder | Control nodes | Price tag icon exists. |
| `ui.daily_summary_panel` | placeholder | Control nodes | Ledger icon exists. |
| `ui.purchase_countdown` | implemented | v1 apple icon | Purchase bubble candidate exists. |
| `ui.penalty_warning` | available | `critical_icons_2026_05_29/items/warning_badge_32.png`, `fine_penalty_32.png` | Not wired into Chengguan feedback yet. |

### Town Props

The street stall cutout pack already contains many usable props:

- cash box
- hanging scale / balance scale
- market umbrella
- brick wall / pillar / corner wall
- dirt path / dirt corner / dirt patch
- baskets, sacks, stool, radio, thermos, enamel mug

These are registered as available assets in `configs/assets.json`. They should be placed by scene design or map composition work, not directly by gameplay scripts.

## Missing Or Weak Assets To Prioritize Later

1. Dedicated chengguan NPC animation, `48x64`, 4 directions, 8 frames.
2. Proper house interior tiles.
3. Home exterior replacement using the v2 rural house facade.
4. Stall upgrade level visuals.
5. Main character farming action animations: watering, hoeing, harvesting.
6. Wire available HUD/tool/warning icons into UI and Chengguan feedback.

## Debug And Validation

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `asset_preview_scene` | implemented | `res://scenes/debug/asset_preview_scene.tscn` | Developer-only scene that previews registered assets, statuses, dimensions, and load errors. |

## Integration Rule

When replacing art, update the registry and the relevant domain config first.
Gameplay scripts should move toward resolving resources by stable asset id instead of hard-coded paths.
