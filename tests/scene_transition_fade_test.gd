extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	main.call("set_scene_transition_seconds_for_test", 0.05)
	SignalBus.scene_change_requested.emit(PrototypeConstants.SCENE_HOME, "default")
	await get_tree().process_frame

	var fade_rect := main.get_node("SleepTransitionLayer/SleepFade") as ColorRect
	var player := main.get_node("Player") as CharacterBody2D
	_assert_true(bool(main.call("is_scene_transition_running")), "地图切换后应进入黑屏淡入淡出状态")
	_assert_true(fade_rect.visible, "地图切换期间黑屏遮罩应显示")
	_assert_true(not player.is_physics_processing(), "地图切换期间应临时锁定玩家移动")

	await get_tree().create_timer(0.12).timeout
	_assert_true(not bool(main.call("is_scene_transition_running")), "地图切换淡入淡出完成后应退出转场状态")
	_assert_true(not fade_rect.visible, "地图切换淡入淡出完成后黑屏遮罩应隐藏")
	_assert_true(player.is_physics_processing(), "地图切换淡入淡出完成后应恢复玩家移动")
	_assert_equal(GameState.current_scene, PrototypeConstants.SCENE_HOME, "地图切换完成后应进入目标场景")
	_assert_vector_close(
		main.call("get_player_camera_screen_center_for_test"),
		player.global_position,
		0.5,
		"地图切换完成后相机应立即贴到玩家出生点，不能继续从旧位置平滑滑入"
	)

	main.queue_free()
	PopulationFlow.reset_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_vector_close(actual: Vector2, expected: Vector2, tolerance: float, message: String) -> void:
	if actual.distance_to(expected) > tolerance:
		push_error("%s。实际：%s，期望：%s，容差：%s" % [message, str(actual), str(expected), str(tolerance)])
		get_tree().quit(1)
