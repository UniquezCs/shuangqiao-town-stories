extends Node

const RoadNavigator := preload("res://scripts/world/road_navigator.gd")
const TownRandomCustomerSpawner := preload("res://scripts/world/town_random_customer_spawner.gd")
const TILESET_PATH := "res://assets/generated/tilesets/rural_town_32/rural_town_tileset_32.tres"


func _ready() -> void:
	_assert_random_customer_plan_has_default_safety_cap()
	await _assert_road_candidate_lookup_stays_bounded()
	get_tree().quit()


func _assert_random_customer_plan_has_default_safety_cap() -> void:
	var spawner := TownRandomCustomerSpawner.new()
	spawner._rng.seed = 20260602

	var plan: Array = spawner.call("_build_daily_spawn_plan")

	_assert_true(
		plan.size() <= spawner.max_daily_customer_count,
		"随机客流默认计划人数应受 max_daily_customer_count 保护，当前为 %d，上限为 %d" % [plan.size(), spawner.max_daily_customer_count]
	)
	spawner.free()


func _assert_road_candidate_lookup_stays_bounded() -> void:
	var world := Node2D.new()
	add_child(world)

	var map_layers := Node2D.new()
	map_layers.name = "MapLayers"
	world.add_child(map_layers)

	var road_layer := TileMapLayer.new()
	road_layer.name = "RoadLayer"
	road_layer.tile_set = load(TILESET_PATH)
	map_layers.add_child(road_layer)

	for x in range(30):
		for y in range(12):
			road_layer.set_cell(Vector2i(x, y), 0, Vector2i(0, 0))

	var navigator := RoadNavigator.new()
	navigator.name = "RoadNavigator"
	navigator.road_layer_path = NodePath("../MapLayers/RoadLayer")
	navigator.endpoint_candidate_radius_tiles = 8
	navigator.endpoint_candidate_limit = 6
	world.add_child(navigator)
	await get_tree().process_frame

	var origin := road_layer.to_global(road_layer.map_to_local(Vector2i(12, 5)))
	var candidates: Array = navigator.call("_candidate_cells", origin)

	_assert_equal(candidates.size(), navigator.endpoint_candidate_limit, "道路候选点数量应被 endpoint_candidate_limit 限制")
	world.queue_free()
	await get_tree().process_frame


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
