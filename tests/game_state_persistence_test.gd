extends Node


func _ready() -> void:
	GameState.reset_game()

	GameState.set_farm_plot_state("plot_1", "ready")
	_assert_equal(GameState.get_farm_plot_state("plot_1"), "ready", "农田状态应该保存在 GameState")

	GameState.start_day_clock(6 * 60)
	GameState.set_game_time_minute(6 * 60 + 15)
	GameState.start_day_clock(6 * 60)
	_assert_equal(GameState.current_game_minute, 6 * 60 + 15, "已启动的游戏时间不应该因进入镇街而重置")
	_assert_true(GameState.day_clock_started, "游戏开始后时间系统应保持启动状态")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
