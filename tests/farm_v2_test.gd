extends Node

const FarmPlotScript := preload("res://scripts/world/farm_plot.gd")


func _ready() -> void:
	GameState.reset_game()
	var plot := Area2D.new()
	plot.set_script(FarmPlotScript)
	var visual := Sprite2D.new()
	visual.name = "Visual"
	plot.add_child(visual)
	var timer := Timer.new()
	timer.name = "GrowthTimer"
	plot.add_child(timer)
	add_child(plot)
	await get_tree().process_frame

	_assert_equal(plot.get("state"), "tilled", "新农田应从空耕地状态开始")

	GameState.set_current_tool(PrototypeConstants.TOOL_SEED)
	plot.call("interact", null)
	_assert_equal(plot.get("state"), "tilled", "背包有种子但快捷栏没选种子时不应播种")
	Hotbar.put_slot(3, {"item_id": PrototypeConstants.ITEM_APPLE_SEED, "count": 1})
	Hotbar.select_slot(3)
	plot.call("interact", null)
	_assert_equal(plot.get("state"), "seed_dry", "种子应把耕地变为种子无水状态")
	_assert_true(Hotbar.slots[3].is_empty(), "最后一颗快捷栏种子播种后应清空快捷栏格")

	GameState.set_current_tool(PrototypeConstants.TOOL_WATER)
	plot.call("interact", null)
	_assert_equal(plot.get("state"), "ready", "测试期 growth_days 为 0，浇水后作物应立即成熟")

	GameState.advance_farm_plots_for_new_day()
	_assert_equal(GameState.get_farm_plot_state("plot_1"), "ready", "已成熟作物睡觉后应保持成熟状态")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
