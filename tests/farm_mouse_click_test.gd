extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")
const FarmFieldScript := preload("res://scripts/world/farm_field.gd")


func _ready() -> void:
	GameState.reset_game()

	var field := Area2D.new()
	field.name = "FarmField"
	field.set_script(FarmFieldScript)
	var field_shape := CollisionShape2D.new()
	field_shape.name = "CollisionShape2D"
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(256, 256)
	field_shape.shape = rectangle
	field.add_child(field_shape)
	add_child(field)

	var player := PLAYER_SCENE.instantiate() as CharacterBody2D
	add_child(player)
	player.global_position = Vector2(80, 80)
	await get_tree().process_frame
	await get_tree().process_frame

	GameState.set_current_tool(PrototypeConstants.TOOL_HOE)
	var player_start := player.global_position
	_assert_true(await player.call("handle_farming_click", Vector2(112, 80)), "鼠标点击周围空地时应开垦农田")
	await get_tree().process_frame

	var plots := get_tree().get_nodes_in_group("farm_plot")
	_assert_equal(plots.size(), 1, "点击开垦应生成 1 个农田地块")
	var plot := plots[0] as Node2D
	_assert_equal(plot.global_position, Vector2(112, 80), "点击开垦应吸附到鼠标所在 32x32 tile 中心")
	_assert_true(not plot.is_in_group("interactable"), "农田地块不应再通过 E 键交互")
	_assert_equal(player.global_position, player_start, "点击周围地块时主角应原地操作，不应自动移动")

	player.set("_is_farming_action_playing", false)
	GameState.set_current_tool(PrototypeConstants.TOOL_SEED)
	_assert_true(await player.call("handle_farming_click", Vector2(112, 80)), "鼠标点击周围耕地时应播种")
	_assert_equal(plot.get("state"), "seed_dry", "播种后地块应变成种子无水状态")

	GameState.set_current_tool(PrototypeConstants.TOOL_WATER)
	_assert_true(await player.call("handle_farming_click", Vector2(112, 80)), "鼠标点击周围作物时应浇水")
	_assert_equal(plot.get("state"), "ready", "测试期作物浇水后应成熟")

	player.set("_is_farming_action_playing", false)
	player.global_position = Vector2(112, 80)
	_assert_true(not await player.call("handle_farming_click", Vector2(300, 300)), "鼠标没有点在农田地块附近时不应误触发最近农田")

	player.set("_is_farming_action_playing", false)
	GameState.set_current_tool(PrototypeConstants.TOOL_HOE)
	player.global_position = Vector2(0, 0)
	player_start = player.global_position
	_assert_true(not await player.call("handle_farming_click", Vector2(192, 192)), "鼠标点击距离主角太远的地块时不应触发农作")
	_assert_equal(get_tree().get_nodes_in_group("farm_plot").size(), 1, "距离太远的点击不应生成新农田")
	_assert_equal(player.global_position, player_start, "距离太远的点击不应移动主角")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
