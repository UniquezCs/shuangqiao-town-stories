# Development Baseline

This document is the baseline manual for project development. All gameplay,
scene, animation, and asset work must follow these rules unless the user
explicitly changes the baseline.

## Required Rules

### Pixel Asset Size Standard

- The baseline world tile size is `32x32` pixels.
- Character and NPC animation frames must use `48x64` pixels per frame.
- Small props and inventory-scale objects must use `32x32` pixels.
- Larger gameplay objects should use clean multiples of 32 pixels, such as
  `64x64`, `96x64`, `128x32`, or `256x128`.
- Godot `TileSet.tile_size` must stay at `32x32` unless the user explicitly
  changes the project scale.
- Sprite sheets must use fixed-size cells. Do not mix frame sizes in one
  animation sheet.
- Use nearest-neighbor texture filtering for pixel assets.
- New generated assets should be normalized before integration, not scaled
  ad hoc per scene.

### Character Animation

- Any character animation work must use sprite animations.
- Do not generate character animation procedurally through scripts as the
  primary implementation.
- Character movement animations must be authored for Godot `AnimatedSprite2D`.
- Character animation frames must be `48x64` pixels.
- If suitable character animation assets do not exist, use a clearly marked
  placeholder and document the asset requirement. Do not block programming
  work on final art.
- Generated walking animations must include four directions:
  - down
  - left
  - right
  - up
- Each direction must have 8 frames.
- The required visual style is pixel art.

### Map Scenes

- Any map scene work must use `TileMapLayer`.
- `TileMapLayer` scenes must use the project baseline `32x32` tile size.
- Do not generate map scenes procedurally through scripts as the primary
  implementation.
- If suitable map assets do not exist, use simple placeholder tiles or
  existing assets and document the asset requirement. Do not generate final
  art as part of programming work unless the user explicitly asks.

### Gameplay Node Design

- Prefer Godot nodes, collision shapes, areas, signals, timers, and scene
  composition for gameplay rules.
- Avoid implementing gameplay constraints as per-frame polling in
  `_process()` or `_physics_process()` when a node-based solution is practical.
- Use `Area2D` and signals for detection, such as customer entering a stall's
  influence range.
- Use `StaticBody2D`, `CollisionShape2D`, or other physics nodes for physical
  boundaries, such as the temporary air wall around an open stall.
- Per-frame checks are allowed only when continuous simulation is genuinely
  needed, such as movement input, animation state, or physics integration.
- When adding new gameplay, first consider whether a dedicated node can own
  the behavior before adding global scans or per-frame state checks.

### Config-Driven Systems

- 商品、作物和升级数据必须优先放在 `configs/*.json` 中驱动。
- 代码可以保留兼容接口，但不要把新增作物、售价、堆叠数、成长天数或升级数值硬编码进玩法脚本。
- 背包、摊位、商店、顾客需求和农田系统读取同一套商品/作物配置，避免出现多份名称或数值。

### Asset Integration Protocol

- 程序脚本不应该凭图片路径猜资源含义。所有正式接入的资源都应通过配置或资源注册表描述语义、尺寸、锚点和用途。
- 每次程序改动只要新增、删除、替换或改变资源用途，都必须同步检查并更新 `configs/assets.json` 和必要的人类可读说明文档。
- 即使程序改动暂时只使用占位图，也必须在资源注册表中记录该占位资源、真实资源需求和当前使用位置。
- 代码优先引用稳定 ID，例如 `item_id`、`crop_id`、`npc_id`、`prop_id`，再由配置映射到具体资源路径。
- 新资源应登记到 `configs/assets.json`。最小字段包括：
  - `id`
  - `type`
  - `path`
  - `size`
  - `anchor`
  - `collision`
  - `usage`
  - `tags`
- 资源路径应集中放在 `configs/*.json` 或专用资源 registry 中，避免散落在玩法脚本里。
- 缺少正式美术时，主程序应使用文字、简单图块、已有资源或明显占位资源继续实现逻辑，并记录后续美术需求。
- 不主动生成美术资源。只有用户明确要求生成资源时，才使用图像或资源生成 skill。
- 资源替换必须不改变玩法节点结构。美术接入只能替换 `Sprite2D.texture`、`AnimatedSprite2D.sprite_frames`、`TileSet` 或配置路径。
- 重要资源类型应有固定节点模板：
  - `FarmPlot(Area2D)` -> `Visual(Sprite2D)` -> `CollisionShape2D`
  - `Customer/Chengguan(CharacterBody2D)` -> visual sprite/animation -> body collision -> detection/catch/interaction areas
  - `Stall(Node2D)` -> `Visual(Sprite2D)` -> `InfluenceArea(Area2D)` -> `InspectionTarget(Area2D)` -> `PlayerBoundary(StaticBody2D)`
- 资源接入后应通过 debug preview 场景或测试场景验证尺寸、锚点、路径、帧数、碰撞和场景加载。
- `TileMapLayer` 对齐逻辑必须使用 Godot tile 坐标 API，例如 `local_to_map()` 和 `map_to_local()`，不要手写近似坐标去摆放 tile 对象，除非没有 TileMapLayer 可用。

### Generated Asset Directory Rules

- `assets/generated` 顶层只允许存在两个目录：
  - `assets/generated/sprites`
  - `assets/generated/tilesets`
- `sprites` 用于保存可直接被 `Sprite2D`、`AnimatedSprite2D`、UI、NPC、道具、地点标识等节点引用的最终素材。
- `tilesets` 用于保存可直接被 `TileMapLayer` 使用的最终 tileset 资源、tile 图片和对应 `.tres`。
- 允许保留的文件类型：
  - `.png`：最终可用的透明贴图、图标、切图、tile 图片、动画帧图集。
  - `.tres`：Godot 可直接加载的 `SpriteFrames`、`TileSet` 等资源。
  - `.import`：Godot 对最终资源的导入设置，应和对应 `.png`、`.tres` 一起保留。
- 禁止把生成中间产物留在 `assets/generated` 中，包括：
  - raw generation image
  - prompt 文本
  - manifest 或临时 JSON
  - contact sheet
  - preview GIF
  - 调试截图
  - 未切割的大图草稿
  - `.DS_Store`
- 如果生成流程需要中间文件，应放在项目外的临时目录，或在接入最终素材后立即删除。
- 最终接入游戏前，素材必须移动到 `sprites` 或 `tilesets` 下的语义化子目录，例如：
  - `sprites/characters`
  - `sprites/items/crops`
  - `sprites/props/stall`
  - `sprites/locations`
  - `sprites/ui`
  - `tilesets/rural_town_32`
- 任何进入 `assets/generated` 的最终素材，都必须同步登记到 `configs/assets.json`；如果它被设计文档或开发计划引用，也要同步更新 `docs/asset_registry.md`。
- 程序和场景只能引用最终素材路径，不引用 raw、preview、manifest、prompt 或生成工具临时路径。
- 每次整理或新增生成素材后，必须运行 `tests/generated_asset_layout_test.tscn`，确认目录结构没有回退。

## Practical Checklist

Before implementing character animation:

- Confirm whether an existing compatible sprite sheet is available.
- Confirm the animation target is `AnimatedSprite2D`.
- Confirm four-direction walking animations exist with 8 frames per direction.
- If assets are missing, wire the gameplay with placeholders and document the
  required asset registry entry instead of generating art by default.

Before implementing map scenes:

- Confirm the scene is built with `TileMapLayer`.
- Confirm required map tiles/assets exist.
- If tiles are missing, use placeholder tiles or existing assets and document
  the required tileset registry entry instead of generating art by default.

Before implementing gameplay constraints:

- Ask whether the rule can be expressed with `Area2D`, `StaticBody2D`,
  `CollisionShape2D`, `Timer`, or signals.
- Prefer creating a dedicated scene/node for the rule over adding per-frame
  distance checks.
- If per-frame logic is necessary, keep it local to the node that owns the
  continuous behavior and document why a node/signal approach is insufficient.

Before integrating or replacing art assets:

- Confirm the asset has a stable ID and an entry in config or the asset registry.
- Confirm the pixel size matches the baseline.
- Confirm the anchor/pivot expectation is explicit.
- Confirm collision is owned by the gameplay node, not implied by the bitmap.
- Confirm the asset can be previewed in a debug or test scene before it is
  relied on by production gameplay.

Before finishing any programming change:

- Check whether the change touched scenes, scripts, configs, UI, NPCs, props,
  map elements, tools, items, or feedback that use art assets.
- If yes, update `configs/assets.json`.
- If the change creates a new asset need but no final art exists, add a
  `placeholder` or `missing` entry with `generation_need`.
- Keep `docs/asset_registry.md` aligned when the change affects the human
  planning list or priority of needed art.
