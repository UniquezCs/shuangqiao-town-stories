extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	SaveManager.set_pending_load({
		"game_state": {
			"current_scene": PrototypeConstants.SCENE_TOWN,
			"current_time_window": PrototypeConstants.WINDOW_FACTORY,
			"current_game_minute": 17 * 60 + 30,
			"day_clock_started": true,
			"objective": "读取镇街存档",
		},
		"inventory": {},
	})
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame

	_assert_equal(GameState.current_scene, PrototypeConstants.SCENE_TOWN, "读档进入主场景时应恢复保存的当前场景")
	_assert_equal(GameState.current_time_window, PrototypeConstants.WINDOW_FACTORY, "读档应保留保存的时间窗口")
	_assert_equal(GameState.objective, "读取镇街存档", "读档应保留保存的当前目标文本")
	var world_root := main.get_node("WorldRoot")
	_assert_equal(world_root.get_child_count(), 1, "主场景应只加载一个世界实例")
	_assert_equal(world_root.get_child(0).name, "TownScene", "保存场景为 town 时应直接加载镇街")

	SaveManager.set_pending_load({})
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
