extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")


func _ready() -> void:
	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	_assert_true(town.get_node_or_null("ReferenceTownLayout") == null, "TownScene 不应再依赖 ReferenceTownLayout 生成地图")

	var map_layers := town.get_node_or_null("MapLayers") as Node2D
	_assert_true(map_layers != null, "TownScene 应包含 MapLayers 父节点集中管理地图层")

	var expected_layers := {
		"GroundLayer": -40,
		"WaterLayer": -35,
		"FieldLayer": -34,
		"RoadLayer": -30,
		"DecorationLayer": -20,
		"TreeLayer": -5,
		"AbovePlayerLayer": 10,
		"CollisionMarkerLayer": 20,
		"StallAreaLayer": -18,
	}

	_assert_true(map_layers.get_node_or_null("BuildingLayer") == null, "MapLayers 不应再包含 BuildingLayer，建筑由独立建筑节点表达")

	for layer_name in expected_layers.keys():
		_assert_true(town.get_node_or_null(layer_name) == null, "%s 不应直接挂在 TownScene 根节点下" % layer_name)
		var layer := map_layers.get_node_or_null(layer_name) as TileMapLayer
		_assert_true(layer != null, "MapLayers 应包含 %s" % layer_name)
		_assert_true(layer.tile_set != null, "%s 应绑定城镇 tileset，方便编辑器继续绘制" % layer_name)
		_assert_equal(layer.z_index, expected_layers[layer_name], "%s 的 z_index 应符合地图层级约定" % layer_name)

	var town_script := FileAccess.get_file_as_string("res://scripts/scenes/town_scene.gd")
	_assert_true(not town_script.begins_with("@tool"), "TownScene 脚本不能使用 @tool，避免编辑器打开时改写 TileMapLayer")
	_assert_true(not town_script.contains("set_cell("), "TownScene 脚本不能写入 TileMapLayer，地图内容必须由编辑器绘制保存")
	_assert_true(not town_script.contains("paint_placeholder"), "TownScene 脚本不能包含自动回填地图占位图块逻辑")

	for spot in get_tree().get_nodes_in_group("generated_stall_area_spot"):
		_assert_true(spot.get_parent() == town, "StallAreaLayer 生成的摆摊交互节点应挂在 TownScene 下，而不是 MapLayers 下")

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
