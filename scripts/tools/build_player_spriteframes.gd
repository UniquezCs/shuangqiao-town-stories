extends SceneTree

const WALK_FRAMES_PATH := "res://assets/generated/sprites/characters/vendor_walk_spriteframes_48x64.tres"
const OUTPUT_PATH := "res://assets/generated/sprites/characters/player_spriteframes_48x64.tres"
const ACTION_ORDER := ["hoe", "water", "harvest"]
const ACTION_SHEETS := {
	"hoe": "res://assets/generated/sprites/characters/player_hoe_4dir_4f_48x64.png",
	"water": "res://assets/generated/sprites/characters/player_water_4dir_4f_48x64.png",
	"harvest": "res://assets/generated/sprites/characters/player_harvest_4dir_4f_48x64.png",
}
const DIRECTIONS := ["down", "left", "right", "up"]
const CELL_WIDTH := 48
const CELL_HEIGHT := 64
const ACTION_FRAME_COUNT := 4
const ACTION_SPEED := 8.0


func _init() -> void:
	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	if not _copy_walk_animations(frames):
		quit(1)
		return
	if not _add_action_animations(frames):
		quit(1)
		return
	if not _save_frames(frames):
		quit(1)
		return

	print("Saved player SpriteFrames: %s" % OUTPUT_PATH)
	quit()


func _copy_walk_animations(frames: SpriteFrames) -> bool:
	var walk_frames := load(WALK_FRAMES_PATH) as SpriteFrames
	if walk_frames == null:
		push_error("Failed to load walk SpriteFrames: %s" % WALK_FRAMES_PATH)
		return false

	for animation_name in walk_frames.get_animation_names():
		var animation := str(animation_name)
		frames.add_animation(animation)
		frames.set_animation_loop(animation, walk_frames.get_animation_loop(animation))
		frames.set_animation_speed(animation, walk_frames.get_animation_speed(animation))
		for frame_index in range(walk_frames.get_frame_count(animation)):
			frames.add_frame(
				animation,
				walk_frames.get_frame_texture(animation, frame_index),
				walk_frames.get_frame_duration(animation, frame_index)
			)
	return true


func _add_action_animations(frames: SpriteFrames) -> bool:
	for action in ACTION_ORDER:
		var sheet_path := str(ACTION_SHEETS[action])
		var sheet := load(sheet_path) as Texture2D
		if sheet == null:
			push_error("Failed to load action sheet: %s" % sheet_path)
			return false
		var sheet_uid := ResourceLoader.get_resource_uid(sheet_path)
		if sheet_uid > 0:
			ResourceUID.set_id(sheet_uid, sheet_path)

		for row in range(DIRECTIONS.size()):
			var direction := str(DIRECTIONS[row])
			var animation := "%s_%s" % [action, direction]
			frames.add_animation(animation)
			frames.set_animation_loop(animation, false)
			frames.set_animation_speed(animation, ACTION_SPEED)
			for col in range(ACTION_FRAME_COUNT):
				var atlas_texture := AtlasTexture.new()
				atlas_texture.atlas = sheet
				atlas_texture.region = Rect2(col * CELL_WIDTH, row * CELL_HEIGHT, CELL_WIDTH, CELL_HEIGHT)
				atlas_texture.filter_clip = true
				frames.add_frame(animation, atlas_texture)
	return true


func _save_frames(frames: SpriteFrames) -> bool:
	var output_uid := ResourceLoader.get_resource_uid(OUTPUT_PATH)
	if output_uid <= 0:
		output_uid = ResourceUID.create_id()
	if FileAccess.file_exists(OUTPUT_PATH):
		ResourceSaver.set_uid(OUTPUT_PATH, output_uid)
	var error := ResourceSaver.save(frames, OUTPUT_PATH)
	if error != OK:
		push_error("Failed to save SpriteFrames: %s" % error_string(error))
		return false
	ResourceSaver.set_uid(OUTPUT_PATH, output_uid)
	return true
