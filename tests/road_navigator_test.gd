extends Node

const RoadNavigator := preload("res://scripts/world/road_navigator.gd")

const TILESET_PATH := "res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres"


func _ready() -> void:
	var world := Node2D.new()
	add_child(world)

	var map_layers := Node2D.new()
	map_layers.name = "MapLayers"
	world.add_child(map_layers)

	var road_layer := TileMapLayer.new()
	road_layer.name = "RoadLayer"
	road_layer.tile_set = load(TILESET_PATH)
	map_layers.add_child(road_layer)

	var road_cells := [
		Vector2i(0, 0),
		Vector2i(1, 0),
		Vector2i(2, 0),
		Vector2i(2, 1),
		Vector2i(2, 2),
		Vector2i(3, 2),
	]
	for cell in road_cells:
		road_layer.set_cell(cell, 0, Vector2i(0, 0))

	var navigator := RoadNavigator.new()
	navigator.name = "RoadNavigator"
	navigator.road_layer_path = NodePath("../MapLayers/RoadLayer")
	world.add_child(navigator)
	await get_tree().process_frame

	var start := road_layer.to_global(road_layer.map_to_local(Vector2i(0, -1)))
	var end := road_layer.to_global(road_layer.map_to_local(Vector2i(4, 2)))
	var path: Array[Vector2] = navigator.find_path(start, end)

	_assert_true(path.size() >= 2, "RoadNavigator 应能把道路外的起止点吸附到最近道路并生成路径")
	for point in path:
		var cell := road_layer.local_to_map(road_layer.to_local(point))
		_assert_true(road_cells.has(cell), "NPC 路径点必须都落在 RoadLayer 已绘制道路 tile 上：%s" % str(cell))

	var first_cell := road_layer.local_to_map(road_layer.to_local(path.front()))
	var last_cell := road_layer.local_to_map(road_layer.to_local(path.back()))
	_assert_equal(first_cell, Vector2i(0, 0), "起点应吸附到最近道路 tile")
	_assert_equal(last_cell, Vector2i(3, 2), "终点应吸附到最近道路 tile")

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
