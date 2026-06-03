extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")


func _ready() -> void:
	SaveManager.SAVE_PATH = "user://test_sleep_autosave.json"
	SaveManager.delete_autosave()
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	main.call("set_sleep_transition_seconds_for_test", 0.05)
	GameState.record_sale(7)

	SignalBus.sleep_requested.emit()
	await get_tree().process_frame

	var summary_panel := main.get_node("DailySummaryPanel")
	_assert_true(bool(main.call("is_sleep_transition_running")), "睡觉后应先进入黑屏转场")
	_assert_true(not bool(summary_panel.get("_panel").visible), "睡觉转场期间不应立刻显示昨日总结")

	await get_tree().create_timer(0.12).timeout
	_assert_true(not bool(main.call("is_sleep_transition_running")), "睡觉黑屏与亮屏完成后应退出转场")
	_assert_true(bool(summary_panel.get("_panel").visible), "睡觉转场完成后才应显示昨日总结")
	_assert_equal(GameState.day_index, 2, "睡觉转场应推进到第二天")
	_assert_true(SaveManager.has_save(), "睡觉进入第二天后应自动写入本地存档")
	var autosave := SaveManager.load_autosave()
	_assert_equal(int((autosave.get("game_state", {}) as Dictionary).get("day_index", 0)), 2, "自动存档应保存进入第二天后的天数")
	SaveManager.delete_autosave()
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
