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
