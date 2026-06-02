extends SceneTree

const DEFAULT_ANIMATIONS := ["walk_down", "walk_left", "walk_right", "walk_up"]


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var sheet_path := str(args.get("sheet", ""))
	var output_path := str(args.get("out", ""))
	var cols := int(args.get("cols", 6))
	var rows := int(args.get("rows", 4))
	var cell_width := int(args.get("cell-width", 48))
	var cell_height := int(args.get("cell-height", 64))
	var speed := float(args.get("speed", 6.0))
	var animations := str(args.get("animations", ",".join(DEFAULT_ANIMATIONS))).split(",", false)

	if sheet_path.is_empty() or output_path.is_empty():
		push_error("Usage: --sheet <res://sheet.png> --out <res://frames.tres>")
		quit(1)
		return
	if rows != animations.size():
		push_error("Animation count must match row count.")
		quit(1)
		return

	var sheet := load(sheet_path) as Texture2D
	if sheet == null:
		push_error("Failed to load sheet: %s" % sheet_path)
		quit(1)
		return
	var sheet_uid := ResourceLoader.get_resource_uid(sheet_path)
	if sheet_uid > 0:
		ResourceUID.set_id(sheet_uid, sheet_path)

	var frames := SpriteFrames.new()
	if frames.has_animation("default"):
		frames.remove_animation("default")

	for row in range(rows):
		var animation := animations[row]
		frames.add_animation(animation)
		frames.set_animation_loop(animation, true)
		frames.set_animation_speed(animation, speed)
		for col in range(cols):
			var atlas_texture := AtlasTexture.new()
			atlas_texture.atlas = sheet
			atlas_texture.region = Rect2(col * cell_width, row * cell_height, cell_width, cell_height)
			atlas_texture.filter_clip = true
			frames.add_frame(animation, atlas_texture)

	var output_uid := ResourceLoader.get_resource_uid(output_path)
	if output_uid <= 0:
		output_uid = ResourceUID.create_id()
	ResourceSaver.set_uid(output_path, output_uid)
	var error := ResourceSaver.save(frames, output_path)
	if error != OK:
		push_error("Failed to save SpriteFrames: %s" % error_string(error))
		quit(1)
		return
	ResourceSaver.set_uid(output_path, output_uid)
	print("Saved SpriteFrames: %s" % output_path)
	quit()


func _parse_args(args: PackedStringArray) -> Dictionary:
	var parsed := {}
	var index := 0
	while index < args.size():
		var key := args[index]
		if key.begins_with("--") and index + 1 < args.size():
			parsed[key.substr(2)] = args[index + 1]
			index += 2
		else:
			index += 1
	return parsed
