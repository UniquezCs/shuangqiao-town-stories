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

	GameState.set_current_tool(PrototypeConstants.TOOL_HOE)
	plot.call("interact", null)
	_assert_equal(plot.get("state"), "tilled", "锄头应把空地变为耕地")

	GameState.set_current_tool(PrototypeConstants.TOOL_SEED)
	plot.call("interact", null)
	_assert_equal(plot.get("state"), "seeded", "种子应把耕地变为已播种")

	GameState.set_current_tool(PrototypeConstants.TOOL_WATER)
	plot.call("interact", null)
	_assert_equal(plot.get("state"), "watered", "水壶应把已播种变为已浇水")

	GameState.advance_farm_plots_for_new_day()
	_assert_true(["seeded", "ready"].has(GameState.get_farm_plot_state("plot_1")), "睡觉后应推进作物成长")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
