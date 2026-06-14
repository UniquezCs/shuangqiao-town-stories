extends Node

const PopulationFlowSpawner := preload("res://scripts/world/population_flow_spawner.gd")


class CountingNavigator:
	extends Node

	var randomized_path_calls := 0

	func find_randomized_path(start: Vector2, end: Vector2, _rng: RandomNumberGenerator) -> Array[Vector2]:
		randomized_path_calls += 1
		return [start, end]


func _ready() -> void:
	await _assert_one_flow_event_reuses_route_for_visible_customers()
	get_tree().quit()


func _assert_one_flow_event_reuses_route_for_visible_customers() -> void:
	var world := Node2D.new()
	world.name = "World"
	add_child(world)

	var navigator := CountingNavigator.new()
	navigator.name = "RoadNavigator"
	world.add_child(navigator)

	var source := Node2D.new()
	source.name = "SourceEndpoint"
	source.position = Vector2(0, 0)
	source.set("endpoint_id", "source")
	source.add_to_group("npc_endpoint")
	world.add_child(source)

	var target := Node2D.new()
	target.name = "TargetEndpoint"
	target.position = Vector2(128, 0)
	target.set("endpoint_id", "target")
	target.add_to_group("npc_endpoint")
	world.add_child(target)

	var spawner := PopulationFlowSpawner.new()
	spawner.max_visible_per_event = 4
	spawner.spread_window_game_minutes = 1
	world.add_child(spawner)
	await get_tree().process_frame
	spawner.route_world = world

	spawner.call("_on_flow_event_created", {
		"source": source,
		"target": target,
		"source_id": "source",
		"target_id": "target",
		"visible_count": 4,
		"age_group": PrototypeConstants.CUSTOMER_AGE_MIDDLE,
		"gender": PrototypeConstants.CUSTOMER_GENDER_MALE,
		"minute": GameState.current_game_minute,
	})
	_assert_equal(spawner.debug_pending_spawn_count(), 4, "同一人流事件应排入 4 个可见顾客")

	for _index in range(4):
		spawner.debug_spawn_next_pending()

	_assert_equal(navigator.randomized_path_calls, 1, "同一人流事件的多个可见顾客应复用一次求路结果")
	world.queue_free()
	await get_tree().process_frame


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
