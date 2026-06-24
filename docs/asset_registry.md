# Asset Registry

This document is the human-readable companion to `configs/assets.json`.
The JSON file is the source of truth for stable asset ids, paths, status, and future art requirements.

## Status Meaning

- `implemented`: currently used by scenes, scripts, or configs.
- `available`: asset exists in the repository but is not wired into gameplay yet.
- `trial`: temporary proof-of-fit asset kept for comparison only; it must not be wired into runtime scenes.
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
  `youth`, `middle`, `elder`; `gender` is one of `male`, `female`. Crop
  preference items, demographic base budget/preferences, and personal random
  ranges are configured in `configs/customer_preferences.json`; runtime behavior
  blends demographic and per-NPC values at `50% / 50%`.
- Raw character rows that touch their source grid boundary fail QC. Regenerate
  the broken direction as a separate padded sheet instead of trying to repair a
  cropped row after slicing.
- Missing resources should be represented with placeholders until art generation is explicitly requested.
- Town map TileMapLayers are editor-authored scene content. Gameplay scripts may read these layers, but must not auto-fill or mutate their tile cells; changes to roads, water, fields, decorations, trees, and stall-area markers should be made in the Godot editor and saved in the scene.
- `TownScene/MapLayers/RoadLayer` is the source of truth for NPC walking
  routes. New building entrances should be connected by painting road tiles on
  this layer in the editor, so every NPC, including chengguan, uses one road
  grid.
- Large raster maps use a hybrid setup: `Sprite2D` background chunks provide
  the visual map, while exits, collision, navigation, and interactions stay in
  separate gameplay nodes or logic layers.
- Raster maps must carry a `map_stage`: `runtime` maps may be referenced by
  scenes, `candidate` maps are available for design review, and `trial` maps
  are temporary proof-of-fit references that must stay out of `.tscn` files
  until promoted.
- Baked-map pixel occlusion can use `Polygon2D` with
  `scripts/world/polygon_texture_occluder.gd`: the polygon samples a configured
  map/background `Sprite2D` texture, such as `TownScene/MapLayers/Sprite2D`,
  with matching UVs and renders above the player.
  Collision still belongs to separate `StaticBody2D` geometry.
- `CameraBounds` uses a `StaticBody2D` root on a non-player collision layer as
  editable rectangle data for camera limits. `TownScene/CameraBounds` also
  enables `create_boundary_walls`, so the outer boundary collision is generated
  from the same rectangle instead of separate top/left/right/bottom `Wall`
  nodes.

## Generated Pack Metadata

- `assets/generated` is intentionally limited to two top-level folders: `sprites` and `tilesets`.
- `sprites` contains final game-ready character, item, farm, location, object, prop, and UI PNG/TRES resources.
- `tilesets` contains final game-ready tile atlases and TileSet resources.
- Raw generation images, contact sheets, prompt text, manifests, preview GIFs, and other intermediate process files should not be kept under `assets/generated`.
- Run `tools/audit_generated_assets.py` before pruning generated files. It reports generated resources missing from `configs/assets.json`, generated paths referenced by text files, and registry paths whose files no longer exist.

## Generated Inventory Closure

On 2026-06-24, the remaining final generated PNG/TRES resources were registered
in `configs/assets.json` under `generated_inventory` with `available` status.
These entries are inventory-only: they close the audit loop without wiring new
art into runtime scenes, scripts, or configs.

| Group | Registered Resources | Notes |
| --- | ---: | --- |
| `sprites/characters` | 3 | Legacy/customer character resources and spriteframes kept available for review. |
| `sprites/farm` | 12 | Shared farm-state and stage textures not currently selected by crop configs. |
| `sprites/items` | 13 | Extra crop, seed, basket, and marker icons. |
| `sprites/objects` | 12 | General environment/object sprites. |
| `sprites/props/stall` | 30 | Stall-side props, markers, stock states, and money props. |
| `sprites/props/town` | 20 | Small town prop sprites. |
| `sprites/ui/backpack` | 11 | Backpack UI component art. |
| `sprites/ui/icons` | 26 | General UI and feedback icons. |
| `sprites/ui/shop` | 11 | Shop panel component art. |
| `tilesets/ui_feedback_32` | 1 | Available feedback icon TileSet resource. |

## Current Resource Needs By System

### Fonts

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `font.noto_sans_cjk_sc_regular` | implemented | `res://assets/fonts/NotoSansCJKsc-Regular.otf` | Added 2026-06-10 and wired through `project.godot` `gui/theme/custom_font`, so Chinese UI text, HUD labels, menus, and dialogue bubbles use a font with Simplified Chinese glyph coverage. Licensed under SIL Open Font License 1.1; license stored at `res://assets/fonts/OFL.txt`. |

### TileMap And Scene Ground

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `tileset.rural_town_32` | implemented | `res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres` | Used by Home, House, and editor-authored `TownScene/MapLayers`: ground, water, field, road, decoration, tree placeholders, and `StallAreaLayer`. |
| `tileset.prototype_scene_32` | available | `res://assets/generated/tilesets/prototype_scene_32/prototype_scene_tileset_32.tres` | Legacy/reference tileset. |
| `location.house_interior_floor` | placeholder | rural town tileset | HouseScene now has a visible TileMapLayer background marker; needs proper 1990s rural house interior floor/wall tiles. |

### Characters And NPCs

| Asset ID | Status | Current Resource | Future Need |
| --- | --- | --- | --- |
| `character.vendor` | implemented | `player_spriteframes_48x64.tres`; `vendor_beg_kneel_48x64.png`; `vendor_beg_kowtow_48x64.png` | Regenerated 2026-06-01 as a 1990s township middle-aged vendor; `48x64`, 4-direction walk plus 2026-06-02 farming actions. Added 2026-06-03 kneel/kowtow Sprite2D poses for begging mode, matched to the current vendor design. |
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
| `item.apple` | implemented | `sprites/items/crops/apple_32.png` | Regenerated 2026-06-02 as part of the apple 8-resource crop pack; new games start with 1 apple. |
| `item.apple_seed` | implemented | `sprites/items/apple_seed_packet_32.png` | Regenerated 2026-06-02 as part of the apple 8-resource crop pack. |
| `item.cabbage` | implemented | `sprites/items/crops/cabbage_32.png` | Normalized generated crop icon. |
| `item.cucumber` | implemented | `sprites/items/crops/cucumber_32.png` | Normalized generated crop icon. |
| `item.tomato` | implemented | `sprites/items/crops/tomato_32.png` | Normalized generated crop icon. |
| `item.pear` | implemented | `sprites/items/crops/pear_32.png` | Regenerated 2026-06-02 as part of the pear 8-resource crop pack; new games start with 1 pear. |
| `item.banana` | implemented | `sprites/items/crops/banana_32.png` | Generated 2026-06-02 as part of the banana 8-resource crop pack. |
| `item.grape` | implemented | `sprites/items/crops/grape_32.png` | Generated 2026-06-02 as part of the grape 8-resource crop pack. |
| `item.potato` | implemented | `sprites/items/crops/potato_32.png` | Normalized generated crop icon. |
| `item.cabbage_seed` | implemented | `sprites/items/cabbage_seed_packet_32.png` | Dedicated seed packet. |
| `item.cucumber_seed` | implemented | `sprites/items/cucumber_seed_packet_32.png` | Dedicated seed packet. |
| `item.tomato_seed` | implemented | `sprites/items/tomato_seed_packet_32.png` | Dedicated seed packet. |
| `item.pear_seed` | implemented | `sprites/items/pear_seed_packet_32.png` | Regenerated 2026-06-02 as part of the pear 8-resource crop pack. |
| `item.banana_seed` | implemented | `sprites/items/banana_seed_packet_32.png` | Generated 2026-06-02 as part of the banana 8-resource crop pack. |
| `item.grape_seed` | implemented | `sprites/items/grape_seed_packet_32.png` | Generated 2026-06-02 as part of the grape 8-resource crop pack. |
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

Current gameplay uses `scenes/farm_plot.tscn` with a `Sprite2D` and one `32x32` texture per farm state.

Farm plot runtime states are standardized to:

- `tilled`: 空耕地
- `seed_dry`: 种子无水
- `seed_watered`: 种子有水
- `growing_dry`: 成长中无水
- `growing_watered`: 成长中有水
- `ready`: 成熟

Each crop should eventually provide 8 resources: the 6 farm-state textures above plus one inventory crop icon and one inventory seed icon.

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `farm_plot.apple.tilled` | implemented | `farm/crops/apple/apple_empty_tilled_32.png` | Apple 8-resource pack. |
| `farm_plot.apple.seed_dry` | implemented | `farm/crops/apple/apple_seed_dry_32.png` | Apple 8-resource pack. |
| `farm_plot.apple.seed_watered` | implemented | `farm/crops/apple/apple_seed_watered_32.png` | Water is intentionally visible as blue puddles. |
| `farm_plot.apple.growing_dry` | implemented | `farm/crops/apple/apple_growing_dry_32.png` | Apple 8-resource pack. |
| `farm_plot.apple.growing_watered` | implemented | `farm/crops/apple/apple_growing_watered_32.png` | Water is intentionally visible as blue puddles. |
| `farm_plot.apple.ready` | implemented | `farm/crops/apple/apple_mature_32.png` | Apple 8-resource pack. |
| `farm_plot.pear.*` | implemented | `farm/crops/pear/*.png` | Pear 8-resource pack; all six state textures wired in `configs/crops.json`. |
| `farm_plot.banana.*` | implemented | `farm/crops/banana/*.png` | Banana 8-resource pack; all six state textures wired in `configs/crops.json`. |
| `farm_plot.grape.*` | implemented | `farm/crops/grape/*.png` | Grape 8-resource pack; all six state textures wired in `configs/crops.json`. |

### Stall Visuals

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `stall.empty` | implemented | `01_stall_empty.png` | Runtime base visual for every open stall. Current selling goods are displayed by item icon/count overlay nodes. |
| `stall.stock_1` | available | `04_stall_apple_1.png` | Legacy stock-specific visual; no longer used by runtime. |
| `stall.stock_3` | available | `03_stall_apples_3.png` | Legacy stock-specific visual; no longer used by runtime. |
| `stall.stock_6` | available | `02_stall_apples_6.png` | Legacy stock-specific visual; no longer used by runtime. |
| `stall.dirty_or_confiscated` | available | `05_stall_dirty.png` | Candidate for future chengguan feedback. |
| `stall.upgraded_level_2` | missing | none | Needs higher-capacity stall visual. |
| `stall.upgraded_level_3` | missing | none | Needs larger stall visual. |

Runtime note: `stall.influence_radius` is configured per stall upgrade level in
`configs/upgrades.json`. `scripts/world/stall.gd` reads it when opening a stall
and applies the same radius to `InfluenceArea` and `InspectionTarget`.

Runtime collision note: `scenes/stall_spot.tscn` may include a
`StaticBody2D/CollisionShape2D` for the physical stall blocker. The template
size and offset are preserved relative to `Stall`; `scripts/world/stall_spot.gd`
keeps it disabled before opening, then enables and repositions it when a stall
opens at the player's position.

### Locations And Buildings

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `location.school_gate` | implemented | `school_gate_256x128.png` | Used as a Town `NpcEndpoint` visual and centralized route destination. |
| `location.factory_gate` | implemented | `factory_gate_256x128.png` | Used as a Town `NpcEndpoint` visual and centralized route destination. |
| `location.police_station` | implemented | `police_station_256x128.png` | Used as the Town `PoliceStation` endpoint visual and chengguan patrol origin/return point. |
| `location.back_mountain_full` | implemented | `back_mountain_full_4096.png` | Full `4096x4096` pixel-art back-mountain raster reference. Runtime uses chunked Sprite2D backgrounds. |
| `location.back_mountain_chunk_*` | implemented | `back_mountain_chunk_{x}_{y}_1024.png` | Four `1024x1024` background chunks placed in `scenes/back_mountain_scene.tscn` as a 2x2 Sprite2D grid. |
| `location.back_mountain_detail_1024` | available | `back_mountain_detail_1024.png` | Standalone `1024x1024` back-mountain visual layer candidate with winding mountain paths, stone steps, dense vegetation, grassland, bamboo/trees, rocks, and shrine details. Gameplay logic should be supplied by separate TileMapLayer or scene nodes. |
| `location.back_mountain_trails_1024` | available | `back_mountain_trails_1024.png` | Standalone `1024x1024` back-mountain visual layer candidate with complex forked mountain trails, stone steps, grassy clearings, bamboo/trees, rocks, shrubs, and cliff edges. Gameplay logic should be supplied by separate TileMapLayer or scene nodes. |
| `location.rural_bungalow_fields_1024` | available | `rural_bungalow_fields_1024.png` | Standalone `1024x1024` rural homestead visual layer candidate with a rural bungalow, courtyard, vegetable plots, grain fields, dirt paths, bamboo/trees, rocks, and water/irrigation edge details. Gameplay logic should be supplied by separate TileMapLayer or scene nodes. |
| `location.protagonist_home_fields_1920` | available | `protagonist_home_fields_1920x1080.png` | Standalone `1920x1080` protagonist-home visual layer candidate matching the supplied township map style, with a rural house, courtyard, crop fields, vegetable plots, trees, dirt paths, fences, shed, well, haystack, and stream edge details. Gameplay logic should be supplied by separate TileMapLayer or scene nodes. |
| `location.township_1990s_wide_roads_1920` | available | `township_1990s_wide_roads_1920x1080.png` | Standalone `1920x1080` township visual layer candidate with wide empty roads, shopfronts, civic buildings, courtyards, roadside trees, water/drainage edges, and building signs. Gameplay logic should be supplied by separate TileMapLayer or scene nodes. |
| `location.town_map_runtime_3635` | implemented | `down_map.png` | Runtime township raster map referenced by `scenes/town_scene.tscn` and `scenes/npc_endpoint.tscn`; gameplay logic remains in separate scene nodes and camera bounds define the visible contract. |
| `location.town_map_trial_clean_2026_06_10` | trial | `Gemini_Generated_Image_sebjzasebjzasebj-clean.png` | Temporary clean township map proof-of-fit retained only for comparison; do not wire into runtime scenes unless promoted and renamed. |
| `location.town_map_trial_export_2026_06_10` | trial | `export.png` | Temporary exported township map proof-of-fit removed from `TownScene` runtime wiring on 2026-06-11; promote and rename before any future scene use. |
| `location.home_map_runtime_1024` | implemented | `home_map.png` | Runtime home raster map referenced by `scenes/home_scene.tscn`; gameplay logic remains in separate scene nodes. |
| `location.house_map_runtime_1024` | implemented | `house_map.png` | Runtime house raster map referenced by `scenes/house_scene.tscn`; gameplay logic remains in separate scene nodes. |
| `location.back_mountain_runtime_1024` | implemented | `mountain.png` | Runtime back-mountain raster map referenced by `scenes/back_mountain_scene.tscn`; current `BoundaryWalls` remain the playable logic bounds. |
| `location.residential_area` | implemented | `residential_area_320x128.png` | Used as a Town `NpcEndpoint` visual for multiple `residential` spawn endpoints. |
| `location.seed_shop` | implemented | `seed_shop_64x64.png` | v2 seed shop stand exists as a future replacement candidate. |
| `location.home_exterior` | placeholder | embedded environment texture region | v2 rural house facade exists as a future replacement candidate. |
| `location.house_bed` | placeholder | folded tarp cutout | v2 bed roll exists. |
| `location.house_ledger` | implemented | ledger book cutout | v2 ledger table exists. |

### UI

Current UI is mostly Godot `Control` nodes with text and panels. This is acceptable for programmer implementation.

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `ui.title_screen` | implemented | `scenes/title_screen.tscn` | New game entry screen for 「双桥镇往事」 with new game, load autosave, quit buttons, and a three-slide new-game story intro. |
| `ui.title_background` | implemented | `sprites/ui/title/title_background_1920x1080.png` | Generated 2026-06-04; 1920x1080 township street background for the title screen. |
| `ui.intro_story_01_factory_layoff` | implemented | `sprites/ui/intro/story_01_factory_layoff_1920x1080.png` | Generated 2026-06-05; pixel-comic opening slide for the protagonist's 1998 state-owned factory layoff. |
| `ui.intro_story_02_family_pressure` | implemented | `sprites/ui/intro/story_02_family_pressure_1920x1080.png` | Generated 2026-06-05; pixel-comic opening slide for household cash pressure after losing wages. |
| `ui.intro_story_03_hometown_stall` | implemented | `sprites/ui/intro/story_03_hometown_stall_1920x1080.png` | Regenerated 2026-06-05; pixel-comic slide showing abandoned family farmland and the decision to go to town to start selling fruit and vegetables. |
| `ui.hud` | placeholder | text labels | v2 UI icons exist. |
| `ui.backpack_panel` | placeholder | Control nodes + `ui.backpack_panel_background` + `ui.backpack_slot` | Backpack window is draggable as of 2026-06-04. It now uses generated panel and slot UI art. |
| `ui.backpack_panel_background` | implemented | `sprites/ui/panels/backpack_panel_360x420.png` | Generated 2026-06-04; used by standalone backpack UI and the stall setup backpack panel. |
| `ui.backpack_slot` | implemented | `sprites/ui/slots/backpack_slot_78x72.png` | Generated 2026-06-04; used by `InventorySlotControl` for backpack slots. |
| `ui.stall_setup_panel` | placeholder | Two draggable Control panels + item icons + `ui.backpack_panel_background` + `ui.stall_panel_background` | Stall setup now opens backpack and stall as two independent panels; transfer dialog labels quantity and unit price explicitly. |
| `ui.stall_panel_background` | implemented | `sprites/ui/panels/stall_panel_420x520.png` | Generated 2026-06-04; used by the stall goods setup panel. |
| `ui.stall_slot` | implemented | `sprites/ui/slots/stall_slot_78x72.png` | Generated 2026-06-04; used by `InventorySlotControl` for stall setup slots. |
| `ui.shop_panel` | placeholder | Control nodes | UI skin pack exists with registered component IDs. |
| `ui.price_panel` | placeholder | Control nodes | Price tag icon exists. |
| `ui.daily_summary_panel` | placeholder | Control nodes | Ledger icon exists. |
| `ui.purchase_countdown` | implemented | v1 apple icon | Purchase bubble candidate exists. |
| `ui.customer_dialogue_bubble` | implemented | Runtime `PanelContainer` + `Label` | NPC overhead dialogue is probabilistic, fades in/out, uses only in-stock desired stall items, and waiting customers leave if their requested item sells out. |
| `ui.penalty_warning` | available | `sprites/items/warning_badge_32.png`, `fine_penalty_32.png` | Not wired into Chengguan feedback yet. |

### Audio

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `audio.bgm.shuangqiao_town_loop` | implemented | `res://assets/audio/bgm/shuangqiao_town_loop.wav` | Replaced 2026-06-05; about 85 seconds, 1980s/1990s game-style pentatonic loop, source sketch in `assets/source/audio/shuangqiao_town_loop.strudel.js`, looped by `MusicManager` from title screen through gameplay. |
| `audio.sfx.cash_received` | implemented | `res://assets/audio/sfx/cash_received.wav` | Added 2026-06-05; 0.5-second cash-received chime, played by `SfxManager` on `SignalBus.sale_completed` after each successful stall transaction. |

### Town Props

The street stall cutout pack already contains many usable props:

- cash box
- hanging scale / balance scale
- market umbrella
- brick wall / pillar / corner wall
- dirt path / dirt corner / dirt patch
- baskets, sacks, stool, radio, thermos, enamel mug

These are registered as available assets in `configs/assets.json`. They should be placed by scene design or map composition work, not directly by gameplay scripts.

Begging mode also registers and uses `prop.begging_bowl` at
`res://assets/generated/sprites/props/begging/begging_bowl_32.png`; it is a
`32x32` Sprite2D prop spawned by `BeggingSession` in front of the player.

The township reference map now also has a dedicated top-down pixel prop set under `assets/generated/sprites/props/township/`. These assets are registered with stable `prop.township.*` IDs and are intended for editor-authored map composition; entries move from `available` to `implemented` when wired into scenes.

Five rural homestead props are now wired into `TownScene/Buildings` as right-bottom
residential `NpcEndpoint` nodes: `WorkingFarmyardResidence`,
`HomesteadPlotResidence`, `RuralVillageClusterResidence`,
`EarthWallCourtyardResidence`, and `FarmhouseCourtyardResidence`.

| Group | Count | Directory | Intended Use |
| --- | ---: | --- | --- |
| Buildings | 33 | `res://assets/generated/sprites/props/township/buildings/` | School, hospital, supply cooperative, factory, residential, government, bus station, grain depot, market, village, vegetable market, welfare lottery shop, middle school, primary school, kindergarten, barber shop, restaurant, pharmacy, bookstore, department store, arcade hall, temple, rural farmhouse courtyards, homestead plot, working farmyard, and village cluster building footprints. |
| Infrastructure | 16 | `res://assets/generated/sprites/props/township/infrastructure/` | Asphalt roads, intersections, dirt roads, bridges, canal pieces, compound walls, gates, and utility details. |
| Daily Props And Trees | 16 | `res://assets/generated/sprites/props/township/daily_props/` | Trees, shrubs, bicycle parking, tricycle, truck, water pump, laundry line, notice board, sacks, coal, haystack, and market decoration. |

## Missing Or Weak Assets To Prioritize Later

1. Place the available police station landmark into TownScene when the town
   layout pass decides its final location.
2. Proper house interior tiles.
3. Home exterior replacement using the v2 rural house facade.
4. Stall upgrade level visuals.
5. Wire available HUD/tool/warning icons into UI and Chengguan feedback.

## Debug And Validation

| Asset ID | Status | Current Resource | Notes |
| --- | --- | --- | --- |
| `asset_preview_scene` | implemented | `res://scenes/debug/asset_preview_scene.tscn` | Developer-only scene that previews registered assets, statuses, dimensions, and load errors. |
| `runtime_diagnostics_panel` | implemented | `res://scenes/debug/runtime_diagnostics_panel.tscn` | Developer-only scene that shows `RuntimeDiagnostics` summary, recent issue rows, and manual log export. |

## Integration Rule

When replacing art, update the registry and the relevant domain config first.
Gameplay scripts should move toward resolving resources by stable asset id instead of hard-coded paths.
