# Character Animation QC Notes

This document records character animation failures and the required prevention
rules. Use it before generating or rebuilding any `48x64` character/NPC walk
sheet.

## 2026-06-01 Random NPC 6-Frame Standard

### Affected Assets

- `assets/generated/sprites/characters/student_walk_4dir_6f_48x64.png`
- `assets/generated/sprites/characters/student_walk_spriteframes_48x64.tres`
- `assets/generated/sprites/characters/worker_walk_4dir_6f_48x64.png`
- `assets/generated/sprites/characters/worker_walk_spriteframes_48x64.tres`
- `assets/generated/sprites/characters/female_elder_walk_4dir_6f_48x64.png`
- `assets/generated/sprites/characters/female_elder_walk_spriteframes_48x64.tres`
- `assets/generated/sprites/characters/female_middle_walk_4dir_6f_48x64.png`
- `assets/generated/sprites/characters/female_middle_walk_spriteframes_48x64.tres`

### Required Result

- Final sheet size is `288x256`, split into `4x6` frames at `48x64`.
- Rows are `walk_down`, `walk_left`, `walk_right`, `walk_up`.
- Each row has 6 frames.
- Six-frame random/civilian NPC rows must not duplicate a standing pose at the
  first and last frame; the sequence should be continuous walking motion only.
- Every frame keeps one shared scale and one stable feet baseline.
- Runtime customer logic separates `customer_type` from `visual_variant`:
  budget and demand can still use student/worker type logic, while random town
  NPCs can use independent visual appearances.
- Student and worker customer sheets now expose the same 6-frame NPC standard
  through SpriteFrames. The previous 8-frame source sheets may remain as legacy
  source material, but active customer animations use the six middle motion
  frames.

## 2026-06-01 Vendor Walk Rebuild

### Affected Assets

- `assets/generated/sprites/characters/vendor_walk_4dir_8f_48x64.png`
- `assets/generated/sprites/characters/vendor_walk_spriteframes_48x64.tres`

### Required Result

- Final sheet size is `384x256`, split into `4x8` frames at `48x64`.
- Rows are `walk_down`, `walk_left`, `walk_right`, `walk_up`.
- Each row has 8 frames and frame 8 is an exact copy of frame 1.
- The protagonist keeps a stable middle-aged 1990s township vendor identity:
  blue work jacket, dark trousers, black cloth shoes, and white towel.
- The sheet is used by `Player/AnimatedSprite2D` through SpriteFrames; no
  script-generated character animation is involved.
- Every frame snaps to the same feet baseline in its `48x64` cell.
- `walk_right` is mirrored from the normalized `walk_left` row so the two side
  directions keep matching crop height, top padding, and foot position.

### Follow-up Alignment Fix

The first rebuild left `walk_right` with inconsistent transparent bounds: some
right-facing frames ended at `y=50`, while the other directions ended at `y=61`.
That made the player visually lift when the right-walk animation looped.

The corrected sheet rebuilds `walk_right` from the normalized `walk_left` row
and runs a final baseline snap across all rows. Current QC requires every final
frame to use the same bottom bbox value before the asset can be accepted.

## 2026-05-31 Customer Walk-Up Cropped Hair Fix

### Affected Assets

- `assets/generated/sprites/characters/student_walk_4dir_8f_48x64.png`
- `assets/generated/sprites/characters/worker_walk_4dir_8f_48x64.png`
- `assets/generated/sprites/characters/student_walk_spriteframes_48x64.tres`
- `assets/generated/sprites/characters/worker_walk_spriteframes_48x64.tres`

### Symptom

The fourth row, `walk_up`, appeared to have the upper hair/head area cut off.
Earlier analysis incorrectly focused on the fourth column. The actual failing
area was the entire fourth row.

### Root Cause

The original generated `4x8` raw sheets already had invalid source rows:

- The fourth row touched the top boundary of the raw grid cells, so the back
  view hair was cropped before normalization.
- The third row also touched the raw grid boundary and incorrectly influenced
  shared scale calculation, even though the final right-facing row was intended
  to be mirrored from the left-facing row.
- Post-processing cannot recover pixels that are already cropped by the raw
  grid split. Attempts to clean this after slicing caused tradeoffs: either
  cropped hair or detached noise fragments.

### Correct Fix

- Regenerate the broken `walk_up` direction as a separate padded `2x4` back-view
  sheet.
- Replace the fourth row in the final `4x8` sheet with those dedicated back-view
  frames.
- Mirror the valid left-facing row into the right-facing row before scale
  calculation, so invalid right-facing raw frames do not affect normalization.
- Use group-level scale for sources that come from different raw sheets, then
  align all final frames to the same feet baseline.

### Do Not Do This

- Do not try to salvage a raw row whose head/hair already touches the source
  grid boundary.
- Do not use "largest connected component only" as a general cleanup step for
  character frames; it can delete separated hair highlights or small head pixels.
- Do not let invalid raw rows participate in scale calculation if the final row
  will be replaced or mirrored.
- Do not approve a sheet only because final `48x64` cells do not touch edges;
  source-level cropping must also be checked.

### Required QC Checks

- Final sheet size must be `384x256` for `4x8` frames at `48x64`.
- Each animation must have exactly 8 frames.
- Frame 1 and frame 8 must match for each direction unless explicitly designed
  otherwise.
- Every frame must have one significant character component and no detached
  hair, shadow, or noise fragments.
- Every frame must keep visible padding around head/hair and feet.
- Feet baseline must be stable within each row.
- Character height must not collapse; for current customer walk cycles, each
  final frame must be at least `44px` tall.
- Source raw frames must not touch their grid boundaries. If they do, regenerate
  that direction separately.

### Verification

Run these checks after rebuilding customer walk cycles:

```bash
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/zhangcong/Documents/godot tests/customer_walk_cycle_quality_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/zhangcong/Documents/godot tests/customer_animation_test.tscn
/Applications/Godot.app/Contents/MacOS/Godot --headless --path /Users/zhangcong/Documents/godot tests/generated_asset_layout_test.tscn
```

Useful visual debug outputs from this incident:

- `assets/source/customer_walk_rework_2026_05_31/customer_walk_rework_preview.png`
- `assets/source/customer_walk_rework_2026_05_31/fourth_row_zoom_current.png`
- `assets/source/customer_walk_rework_2026_05_31/student_row4_stage_diagnostic.png`
- `assets/source/customer_walk_rework_2026_05_31/worker_row4_stage_diagnostic.png`
