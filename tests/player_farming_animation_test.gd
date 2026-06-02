extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const PLAYER_FRAMES_PATH := "res://assets/generated/sprites/characters/player_spriteframes_48x64.tres"
const ACTIONS := ["hoe", "water", "harvest"]
const DIRECTIONS := ["down", "left", "right", "up"]


func _ready() -> void:
	var frames := load(PLAYER_FRAMES_PATH) as SpriteFrames
	_assert_true(frames != null, "主角综合 SpriteFrames 应存在：%s" % PLAYER_FRAMES_PATH)
	_assert_action_frames_are_visible(frames)

	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame

	var visual := player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D
	_assert_true(visual != null, "Player 应使用 AnimatedSprite2D")
	_assert_equal(visual.sprite_frames, frames, "Player 应使用包含农活动作的综合 SpriteFrames")

	player.set("facing", "left")
	_assert_true(player.has_method("play_farming_action"), "Player 应提供 play_farming_action(action_id) 接口")
	player.call("play_farming_action", "hoe")
	_assert_equal(str(visual.animation), "hoe_left", "耕地动作应按当前朝向播放")
	_assert_true(visual.is_playing(), "农活动作播放时动画应处于播放状态")

	get_tree().quit()


func _assert_action_frames_are_visible(frames: SpriteFrames) -> void:
	for action in ACTIONS:
		for direction in DIRECTIONS:
			var animation := "%s_%s" % [action, direction]
			_assert_true(frames.has_animation(animation), "主角缺少动作动画：%s" % animation)
			_assert_equal(frames.get_frame_count(animation), 4, "%s 必须有 4 帧" % animation)
			for index in range(frames.get_frame_count(animation)):
				var texture := frames.get_frame_texture(animation, index)
				_assert_true(texture != null, "%s 第 %d 帧 texture 不应为空" % [animation, index + 1])
				_assert_equal(texture.get_size(), Vector2(48, 64), "%s 第 %d 帧必须是 48x64" % [animation, index + 1])
				var image := texture.get_image()
				_assert_true(image != null, "%s 第 %d 帧 image 不应为空" % [animation, index + 1])
				_assert_true(_visible_pixel_count(image) > 0, "%s 第 %d 帧不应是全透明空白图" % [animation, index + 1])


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
