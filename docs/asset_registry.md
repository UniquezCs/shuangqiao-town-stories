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
- Player/main-character walk sheets may use 4 rows x 8 columns in this order:
  down, left, right, up. Each row should use the sequence standing, left leg
  low, right leg low, left leg high, right leg high, left leg lowering, right
  leg lowering, standing.
- Customer/random/civilian NPC walk sheets use 4 rows x 6 columns, `48x64`
  cells, in the same row order. They must not duplicate a standing pose at the
  first and last frame.
- Character walk QC requires one shared scale and one feet baseline per sheet;
  no cropped hair/feet, no split heads, no edge-touching body parts, and no
  detached shadow/noise fragments.
- Customer NPCs also carry gameplay demographics. `age_group` is one of
  `youth`, `middle`, `elder`; `gender` is one of `male`, `female`. Purchase
  behavior blends the demographic base budget/preferences and per-NPC random
  budget/preferences at `50% / 50%`.
- Raw character rows that touch their source grid boundary fail QC. Regenerate
  the broken direction as a separate padded sheet instead of trying to repair a
  cropped row after slicing.
- Missing resources should be represented with placeholders until art generation is explicitly requested.
- Town map TileMapLayers are editor-authored scene content. Gameplay scripts may read these layers, but must not auto-fill or mutate their tile cells; changes to roads, water, fields, decorations, trees, and stall-area markers should be made in the Godot editor and saved in the scene.
- `TownScene/MapLayers/RoadLayer` is the source of truth for NPC walking
  routes. New building entrances should be connected by painting road tiles on
  this layer in the editor, so every NPC, including chengguan, uses one road
  grid.

## Generated Pack Metadata

- `assets/generated` is intentionally limited to two top-level folders: `sprites` and `tilesets`.
- `sprites` contains final game-ready character, item, farm, location, object, prop, and UI PNG/TRES resources.
- `tilesets` contains final game-ready tile atlases and TileSet resources.
- Raw generation images, contact sheets, prompt text, manifests, preview GIFs, and other intermediate process files should not be kept under `assets/generated`.

## Current Resource Needs By System

### TileMap And Scene Ground

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `tileset.rural_town_32` | implemented | `res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres` | Used by Home, House, and editor-authored `TownScene/MapLayers`: ground, water, field, road, decoration, tree placeholders, and `StallAreaLayer`. |
| `tileset.prototype_scene_32` | available | `res://assets/generated/tilesets/prototype_scene_32/prototype_scene_tileset_32.tres` | Legacy/reference tileset. |
| `location.house_interior_floor` | placeholder | rural town tileset | HouseScene now has a visible TileMapLayer background marker; needs proper 1990s rural house interior floor/wall tiles. |

### Characters And NPCs

| Asset ID | Status | Current Resource | Future Need |
| --- | --- | --- | --- |
| `character.vendor` | implemented | `vendor_walk_spriteframes_48x64.tres` | Regenerated 2026-06-01 as a 1990s township middle-aged vendor; `48x64`, 4 directions, 8 frames, shared scale and stable feet baseline. `walk_right` is mirrored from normalized `walk_left` to keep crop height and foot position consistent. |
| `character.student_customer` | implemented | `student_walk_spriteframes_48x64.tres` | Student visual pool: `youth + male`; `48x64`, 4 directions, 6 frames. |
| `character.youth_female_customer` | implemented | `youth_female_walk_spriteframes_48x64.tres` | Student visual pool: `youth + female`; restored to the earlier preferred raw image on 2026-06-02, then only cleaned magenta/purple fringe pixels. |
| `character.worker_customer` | implemented | `worker_walk_spriteframes_48x64.tres` | Worker visual pool: `middle + male`; `48x64`, 4 directions, 6 frames. |
| `character.female_middle_customer` | implemented | `female_middle_walk_spriteframes_48x64.tres` | Worker visual pool: `middle + female`; `48x64`, 4 directions, 6 frames. |
| `character.elder_male_customer` | implemented | `elder_male_walk_spriteframes_48x64.tres` | Random town NPC visual pool: `elder + male`; restored to the earlier preferred raw image on 2026-06-02, then only cleaned magenta/purple fringe pixels. |
| `character.female_elder_customer` | implemented | `female_elder_walk_spriteframes_48x64.tres` | Random town NPC visual pool: `elder + female`; `48x64`, 4 directions, 6 frames. |
| `character.chengguan` | implemented | `chengguan_walk_spriteframes_48x64.tres` | 1990s township patrol officer; `48x64`, 4 directions, 6 frames, wired into `scenes/chengguan.tscn`. |

### Item Icons

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `item.apple` | implemented | `sprites/items/crops/apple_32.png` | Also has fallback `sprites/items/general/apple_32.png`. |
| `item.apple_seed` | implemented | `sprites/ui/icons/apple_seed_packet_32.png` | Wired in `configs/items.json`. |
| `item.cabbage` | implemented | `sprites/items/crops/cabbage_32.png` | Normalized generated crop icon. |
| `item.cucumber` | implemented | `sprites/items/crops/cucumber_32.png` | Normalized generated crop icon. |
| `item.tomato` | implemented | `sprites/items/crops/tomato_32.png` | Normalized generated crop icon. |
| `item.pear` | implemented | `sprites/items/pear_32.png` | Wired in `configs/items.json`. |
| `item.potato` | implemented | `sprites/items/crops/potato_32.png` | Normalized generated crop icon. |
| `item.cabbage_seed` | implemented | `sprites/items/cabbage_seed_packet_32.png` | Dedicated seed packet. |
| `item.cucumber_seed` | implemented | `sprites/items/cucumber_seed_packet_32.png` | Dedicated seed packet. |
| `item.tomato_seed` | implemented | `sprites/items/tomato_seed_packet_32.png` | Dedicated seed packet. |
| `item.pear_seed` | implemented | `sprites/items/pear_seed_packet_32.png` | Dedicated seed packet. |
| `item.potato_seed` | implemented | `sprites/items/potato_seed_packet_32.png` | Dedicated seed packet. |
| `item.generic_seed` | available | generic seed bag | Fallback only; active crop seeds have dedicated icons. |
| `item.fertilizer` | implemented | `sprites/items/fertilizer_bag_32.png` | Wired in `configs/items.json`. |

### Tools

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `tool.hoe` | available | `sprites/ui/icons/general/hoe_32.png` | Normalized `32x32`; not wired into HUD yet. |
| `tool.water` | available | `sprites/ui/icons/general/watering_can_32.png` | Normalized `32x32`; not wired into HUD yet. |
| `tool.sickle` | available | `sprites/items/sickle_32.png` | Not wired into HUD yet. |

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
| `location.school_gate` | implemented | `school_gate_256x128.png` | Used as a Town `NpcEndpoint` visual and centralized route destination. |
| `location.factory_gate` | implemented | `factory_gate_256x128.png` | Used as a Town `NpcEndpoint` visual and centralized route destination. |
| `location.police_station` | implemented | `police_station_256x128.png` | Used as the Town `PoliceStation` endpoint visual and chengguan patrol origin/return point. |
| `location.residential_area` | implemented | `residential_area_320x128.png` | Used as a Town `NpcEndpoint` visual for multiple `residential` spawn endpoints. |
| `location.seed_shop` | implemented | `seed_shop_64x64.png` | v2 seed shop stand exists as a future replacement candidate. |
| `location.home_exterior` | placeholder | embedded environment texture region | v2 rural house facade exists as a future replacement candidate. |
| `location.house_bed` | placeholder | folded tarp cutout | v2 bed roll exists. |
| `location.house_ledger` | implemented | ledger book cutout | v2 ledger table exists. |

### UI

Current UI is mostly Godot `Control` nodes with text and panels. This is acceptable for programmer implementation.

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `ui.hud` | placeholder | text labels | v2 UI icons exist. |
| `ui.backpack_panel` | placeholder | Control nodes | UI skin pack exists with registered component IDs. |
| `ui.stall_setup_panel` | placeholder | Control nodes + item icons from `configs/items.json` | Added in the 2026-06-02 backpack/stall programming pass. No new art was required; it reuses registered item icons and text controls. |
| `ui.shop_panel` | placeholder | Control nodes | UI skin pack exists with registered component IDs. |
| `ui.price_panel` | placeholder | Control nodes | Price tag icon exists. |
| `ui.daily_summary_panel` | placeholder | Control nodes | Ledger icon exists. |
| `ui.purchase_countdown` | implemented | v1 apple icon | Purchase bubble candidate exists. |
| `ui.penalty_warning` | available | `sprites/items/warning_badge_32.png`, `fine_penalty_32.png` | Not wired into Chengguan feedback yet. |

### Town Props

The street stall cutout pack already contains many usable props:

- cash box
- hanging scale / balance scale
- market umbrella
- brick wall / pillar / corner wall
- dirt path / dirt corner / dirt patch
- baskets, sacks, stool, radio, thermos, enamel mug

These are registered as available assets in `configs/assets.json`. They should be placed by scene design or map composition work, not directly by gameplay scripts.

The township reference map now also has a dedicated top-down pixel prop set under `assets/generated/sprites/props/township/`. These assets are registered as `available` with stable `prop.township.*` IDs and are intended for editor-authored map composition:

| Group | Count | Directory | Intended Use |
| --- | ---: | --- | --- |
| Buildings | 16 | `res://assets/generated/sprites/props/township/buildings/` | School, hospital, supply cooperative, factory, residential, government, bus station, grain depot, market, and village building footprints. |
| Infrastructure | 16 | `res://assets/generated/sprites/props/township/infrastructure/` | Asphalt roads, intersections, dirt roads, bridges, canal pieces, compound walls, gates, and utility details. |
| Daily Props And Trees | 16 | `res://assets/generated/sprites/props/township/daily_props/` | Trees, shrubs, bicycle parking, tricycle, truck, water pump, laundry line, notice board, sacks, coal, haystack, and market decoration. |

## Missing Or Weak Assets To Prioritize Later

1. Place the available police station landmark into TownScene when the town
   layout pass decides its final location.
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
