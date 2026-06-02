extends Node

const CHENGGUAN_SCENE := preload("res://scenes/chengguan.tscn")
const CHENGGUAN_FRAMES := preload("res://assets/generated/sprites/characters/chengguan_walk_spriteframes_48x64.tres")


func _ready() -> void:
	var chengguan := CHENGGUAN_SCENE.instantiate()
	add_child(chengguan)
	await get_tree().process_frame

	var visual := chengguan.get_node_or_null("Visual") as AnimatedSprite2D
	_assert_true(visual != null, "城管 Visual 应使用 AnimatedSprite2D")
	_assert_equal(visual.sprite_frames, CHENGGUAN_FRAMES, "城管应使用专用四方向 SpriteFrames")
	_assert_spriteframes_are_visible(CHENGGUAN_FRAMES)
	_assert_direction_animation(chengguan, visual, Vector2(100, 0), "walk_right")
	_assert_direction_animation(chengguan, visual, Vector2(-100, 0), "walk_left")
	_assert_direction_animation(chengguan, visual, Vector2(0, -100), "walk_up")
	_assert_direction_animation(chengguan, visual, Vector2(0, 100), "walk_down")

	get_tree().quit()


func _assert_direction_animation(chengguan: Node, visual: AnimatedSprite2D, target: Vector2, expected_animation: String) -> void:
	chengguan.global_position = Vector2.ZERO
	chengguan.call("_move_towards", target, 1.0)
	_assert_equal(str(visual.animation), expected_animation, "城管移动方向应播放 %s" % expected_animation)
	_assert_true(visual.is_playing(), "城管移动时动画应播放")


func _assert_spriteframes_are_visible(frames: SpriteFrames) -> void:
	for animation in ["walk_down", "walk_left", "walk_right", "walk_up"]:
		_assert_true(frames.has_animation(animation), "城管缺少动画：%s" % animation)
		_assert_equal(frames.get_frame_count(animation), 6, "城管 %s 必须有 6 帧" % animation)
		for index in range(frames.get_frame_count(animation)):
			var texture := frames.get_frame_texture(animation, index)
			_assert_true(texture != null, "城管 %s 第 %d 帧 texture 不应为空" % [animation, index + 1])
			_assert_equal(texture.get_size(), Vector2(48, 64), "城管 %s 第 %d 帧尺寸必须是 48x64" % [animation, index + 1])
			var image := texture.get_image()
			_assert_true(image != null, "城管 %s 第 %d 帧 image 不应为空" % [animation, index + 1])
			_assert_true(_visible_pixel_count(image) > 0, "城管 %s 第 %d 帧不应是全透明空白图" % [animation, index + 1])


func _visible_pixel_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			if image.get_pixel(x, y).a > 0.01:
				count += 1
	return count


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
