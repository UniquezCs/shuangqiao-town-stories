extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const STUDENT_FRAMES := preload("res://assets/generated/sprites/characters/student_walk_spriteframes_48x64.tres")
const WORKER_FRAMES := preload("res://assets/generated/sprites/characters/worker_walk_spriteframes_48x64.tres")
const YOUTH_FEMALE_FRAMES := preload("res://assets/generated/sprites/characters/youth_female_walk_spriteframes_48x64.tres")
const ELDER_MALE_FRAMES := preload("res://assets/generated/sprites/characters/elder_male_walk_spriteframes_48x64.tres")
const FEMALE_ELDER_FRAMES := preload("res://assets/generated/sprites/characters/female_elder_walk_spriteframes_48x64.tres")
const FEMALE_MIDDLE_FRAMES := preload("res://assets/generated/sprites/characters/female_middle_walk_spriteframes_48x64.tres")


func _ready() -> void:
	var customer := CUSTOMER_SCENE.instantiate()
	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2.ZERO, Vector2(100, 0), [])
	add_child(customer)
	await get_tree().process_frame

	var visual := customer.get_node_or_null("Visual") as AnimatedSprite2D
	_assert_true(visual != null, "顾客 Visual 应使用 AnimatedSprite2D")

	_assert_equal(visual.sprite_frames, STUDENT_FRAMES, "学生顾客应使用学生四方向 SpriteFrames")
	_assert_direction_animation(customer, visual, Vector2(100, 0), "walk_right")
	_assert_direction_animation(customer, visual, Vector2(-100, 0), "walk_left")
	_assert_direction_animation(customer, visual, Vector2(0, -100), "walk_up")
	_assert_direction_animation(customer, visual, Vector2(0, 100), "walk_down")

	customer.call("setup", PrototypeConstants.CUSTOMER_WORKER, null, Vector2.ZERO, Vector2(100, 0), [])
	_assert_equal(visual.sprite_frames, WORKER_FRAMES, "工人顾客应使用工人四方向 SpriteFrames")

	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_YOUTH_MALE)
	_assert_equal(visual.sprite_frames, STUDENT_FRAMES, "少年男性外观应使用学生 6 帧四方向 SpriteFrames")

	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_YOUTH_FEMALE)
	_assert_equal(visual.sprite_frames, YOUTH_FEMALE_FRAMES, "少年女性外观应使用 6 帧四方向 SpriteFrames")

	customer.call("setup", PrototypeConstants.CUSTOMER_WORKER, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_MALE)
	_assert_equal(visual.sprite_frames, WORKER_FRAMES, "中年男性外观应使用工人 6 帧四方向 SpriteFrames")

	customer.call("setup", PrototypeConstants.CUSTOMER_WORKER, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_FEMALE)
	_assert_equal(visual.sprite_frames, FEMALE_MIDDLE_FRAMES, "中年女性外观应使用 6 帧四方向 SpriteFrames")

	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_ELDER_MALE)
	_assert_equal(visual.sprite_frames, ELDER_MALE_FRAMES, "老年男性外观应使用 6 帧四方向 SpriteFrames")

	customer.call("setup", PrototypeConstants.CUSTOMER_STUDENT, null, Vector2.ZERO, Vector2(100, 0), [], PrototypeConstants.CUSTOMER_VISUAL_ELDER_FEMALE)
	_assert_equal(visual.sprite_frames, FEMALE_ELDER_FRAMES, "老年女性外观应使用 6 帧四方向 SpriteFrames")

	get_tree().quit()


func _assert_direction_animation(customer: Node, visual: AnimatedSprite2D, target: Vector2, expected_animation: String) -> void:
	customer.global_position = Vector2.ZERO
	customer.call("_move_towards", target)
	_assert_equal(str(visual.animation), expected_animation, "顾客移动方向应播放 %s" % expected_animation)
	_assert_true(visual.is_playing(), "顾客移动时动画应播放")


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
