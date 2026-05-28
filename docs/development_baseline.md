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
- If suitable character animation assets do not exist, create them with
  `Generate 2D Sprite`.
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
- If suitable map assets do not exist, create them with `Generate 2D Map`.

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

## Practical Checklist

Before implementing character animation:

- Confirm whether an existing compatible sprite sheet is available.
- Confirm the animation target is `AnimatedSprite2D`.
- Confirm four-direction walking animations exist with 8 frames per direction.
- Generate missing assets with `Generate 2D Sprite` before wiring the scene.

Before implementing map scenes:

- Confirm the scene is built with `TileMapLayer`.
- Confirm required map tiles/assets exist.
- Generate missing map assets with `Generate 2D Map` before building the scene.

Before implementing gameplay constraints:

- Ask whether the rule can be expressed with `Area2D`, `StaticBody2D`,
  `CollisionShape2D`, `Timer`, or signals.
- Prefer creating a dedicated scene/node for the rule over adding per-frame
  distance checks.
- If per-frame logic is necessary, keep it local to the node that owns the
  continuous behavior and document why a node/signal approach is insufficient.
