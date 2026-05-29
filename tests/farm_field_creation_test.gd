extends Node

const FarmFieldScript := preload("res://scripts/world/farm_field.gd")


func _ready() -> void:
	GameState.reset_game()
	var field := Area2D.new()
	field.set_script(FarmFieldScript)
	add_child(field)
	await get_tree().process_frame
	GameState.set_current_tool(PrototypeConstants.TOOL_WATER)
	await get_tree().process_frame
	_assert_equal(field.is_in_group("interactable"), false, "非锄头状态不应检测锄地交互")

	var player := Node2D.new()
	player.global_position = Vector2(65, 65)
	add_child(player)

	GameState.set_current_tool(PrototypeConstants.TOOL_HOE)
	await get_tree().process_frame
	_assert_equal(field.is_in_group("interactable"), true, "装备锄头时才应检测锄地交互")
	field.call("interact", player)
	await get_tree().process_frame

	var plots := get_tree().get_nodes_in_group("farm_plot")
	_assert_equal(plots.size(), 1, "装备锄头时应在脚下生成新农田")
	var plot := plots[0] as Node2D
	_assert_equal(plot.global_position, Vector2(80, 80), "新农田应吸附到 32x32 Tile 中心")
	_assert_equal(plot.get("state"), "tilled", "开垦生成的新农田应直接进入可播种状态")
	var shape_node := plot.get_node("CollisionShape2D") as CollisionShape2D
	var rectangle := shape_node.shape as RectangleShape2D
	_assert_equal(rectangle.size, Vector2(32, 32), "新农田碰撞范围应是 1x1 个 32 像素格")

	field.call("interact", player)
	await get_tree().process_frame
	_assert_equal(get_tree().get_nodes_in_group("farm_plot").size(), 1, "同一格不应重复开垦")

	for node in get_tree().get_nodes_in_group("farm_plot"):
		node.queue_free()
	field.queue_free()
	await get_tree().process_frame

	var restored_field := Area2D.new()
	restored_field.set_script(FarmFieldScript)
	add_child(restored_field)
	await get_tree().process_frame
	await get_tree().process_frame
	var restored_plots := get_tree().get_nodes_in_group("farm_plot")
	_assert_equal(restored_plots.size(), 1, "重新进入家场景时应恢复已开垦农田")
	var restored_plot := restored_plots[0] as Node2D
	_assert_equal(restored_plot.global_position, Vector2(80, 80), "恢复的农田应保持原 tile 位置")
	_assert_equal(restored_plot.get("state"), "tilled", "恢复的农田应保持开垦状态")
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
