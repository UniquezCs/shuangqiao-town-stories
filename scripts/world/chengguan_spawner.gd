extends Node

const CHENGGUAN_SCENE := preload("res://scenes/chengguan.tscn")
const GameplayDebugLog := preload("res://scripts/debug/gameplay_debug_log.gd")
const WAYPOINT_ROUTE_JITTER := Vector2(90, 75)

@export var police_endpoint_id := "police_station"
@export var morning_daily_count := 10
@export var afternoon_daily_count := 10
@export var morning_start_minute := 6 * 60
@export var morning_end_minute := 12 * 60
@export var afternoon_start_minute := 13 * 60
@export var afternoon_end_minute := 19 * 60
@export var allowed_destination_endpoint_types: Array[String] = []

@onready var route_world: Node = _world_node()

var _spawn_plan: Array[Dictionary] = []
var _spawn_index := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_rebuild_daily_spawn_plan(GameState.current_game_minute)
	SignalBus.game_time_changed.connect(_on_game_time_changed)
	SignalBus.daily_summary_ready.connect(_on_daily_summary_ready)


func debug_get_spawn_plan() -> Array:
	return _spawn_plan.duplicate(true)


func build_chengguan_route() -> Dictionary:
	var police_endpoint := _police_endpoint()
	if police_endpoint == null:
		return {}
	var destination_endpoints := _available_destination_endpoints(police_endpoint)
	if destination_endpoints.is_empty():
		return {}

	var police_position := _endpoint_position(police_endpoint)
	for _attempt in range(maxi(1, destination_endpoints.size() * 2)):
		var destination_endpoint := _pick_weighted_endpoint(destination_endpoints)
		if destination_endpoint == null:
			continue
		var destination_position := _endpoint_position(destination_endpoint)
		var outbound_route := _route_for_positions(police_position, destination_position)
		var return_route := _route_for_positions(destination_position, police_position)
		if outbound_route.is_empty() or return_route.is_empty():
			continue

		outbound_route.merge({
			"start_endpoint": police_endpoint,
			"destination_endpoint": destination_endpoint,
			"return_start": return_route["start"],
			"return_end": return_route["end"],
			"return_points": return_route["points"],
		})
		return outbound_route
	return {}


func _on_game_time_changed(total_minutes: int, _clock_text: String) -> void:
	while _spawn_index < _spawn_plan.size() and int(_spawn_plan[_spawn_index]["minute"]) <= total_minutes:
		_spawn_chengguan()
		_spawn_index += 1


func _spawn_chengguan() -> void:
	var route := build_chengguan_route()
	if route.is_empty():
		GameplayDebugLog.log("patrol", "spawn_skipped_empty_route")
		return
	var chengguan := CHENGGUAN_SCENE.instantiate()
	chengguan.call("setup", route["start"], _route_points_with_end(route), _route_points_with_end({
		"points": route["return_points"],
		"end": route["return_end"],
	}))
	if route_world != null:
		route_world.add_child(chengguan)
	else:
		get_tree().current_scene.add_child(chengguan)
	GameplayDebugLog.log("patrol", "spawned_chengguan", {
		"start": str(route["start"]),
		"end": str(route["end"]),
		"points": route.get("points", []).size(),
	})


func _on_daily_summary_ready(_result: Dictionary) -> void:
	_rebuild_daily_spawn_plan(GameState.current_game_minute)


func _rebuild_daily_spawn_plan(skip_before_minute := 0) -> void:
	_spawn_plan = _build_daily_spawn_plan()
	_spawn_index = 0
	while _spawn_index < _spawn_plan.size() and int(_spawn_plan[_spawn_index]["minute"]) < skip_before_minute:
		_spawn_index += 1
	GameplayDebugLog.log("patrol", "spawn_plan_rebuilt", {
		"entries": _spawn_plan.size(),
		"next_index": _spawn_index,
		"skip_before_minute": skip_before_minute,
	})


func _build_daily_spawn_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	_append_random_window_entries(plan, morning_daily_count, morning_start_minute, morning_end_minute, "morning")
	_append_random_window_entries(plan, afternoon_daily_count, afternoon_start_minute, afternoon_end_minute, "afternoon")
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["minute"]) < int(b["minute"])
	)
	return plan


func _append_random_window_entries(plan: Array[Dictionary], count: int, start_minute: int, end_minute: int, window_id: String) -> void:
	var safe_count: int = maxi(0, count)
	var safe_start: int = mini(start_minute, end_minute - 1)
	var safe_end: int = maxi(end_minute, safe_start + 1)
	for _index in range(safe_count):
		plan.append({
			"minute": _rng.randi_range(safe_start, safe_end - 1),
			"window": window_id,
		})


func _police_endpoint() -> Node2D:
	if route_world == null:
		return null
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if node is Node2D and node.is_inside_tree() and _belongs_to_route_world(node):
			if str(node.get("endpoint_id")) == police_endpoint_id:
				return node
	return null


func _pick_destination_endpoint(police_endpoint: Node2D) -> Node2D:
	var endpoints := _available_destination_endpoints(police_endpoint)
	if endpoints.is_empty():
		return null
	return _pick_weighted_endpoint(endpoints)


func _available_destination_endpoints(police_endpoint: Node2D) -> Array[Node2D]:
	var endpoints: Array[Node2D] = []
	if route_world == null:
		return endpoints
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if not node is Node2D or not node.is_inside_tree():
			continue
		if not _belongs_to_route_world(node) or node == police_endpoint:
			continue
		if node.get("can_spawn_customer") == false:
			continue
		if _endpoint_spawn_weight(node) <= 0.0:
			continue
		if not _endpoint_type_allowed(node):
			continue
		endpoints.append(node)
	return endpoints


func _endpoint_type_allowed(endpoint: Node) -> bool:
	if allowed_destination_endpoint_types.is_empty():
		return true
	var endpoint_type := ""
	if endpoint.has_method("get_endpoint_type"):
		endpoint_type = str(endpoint.call("get_endpoint_type"))
	else:
		endpoint_type = str(endpoint.get("endpoint_type"))
	return allowed_destination_endpoint_types.has(endpoint_type)


func _pick_weighted_endpoint(endpoints: Array[Node2D]) -> Node2D:
	var total_weight := 0.0
	for endpoint in endpoints:
		total_weight += max(0.0, _endpoint_spawn_weight(endpoint))

	if total_weight <= 0.0:
		return endpoints[_rng.randi_range(0, endpoints.size() - 1)]

	var roll := _rng.randf_range(0.0, total_weight)
	for endpoint in endpoints:
		roll -= max(0.0, _endpoint_spawn_weight(endpoint))
		if roll <= 0.0:
			return endpoint
	return endpoints.back()


func _endpoint_spawn_weight(endpoint: Node) -> float:
	var raw_weight: Variant = endpoint.get("spawn_weight")
	if raw_weight == null:
		return 0.0
	return raw_weight


func _endpoint_position(endpoint: Node2D) -> Vector2:
	if endpoint.has_method("get_endpoint_position"):
		return endpoint.call("get_endpoint_position")
	return endpoint.global_position


func _route_for_positions(start: Vector2, end: Vector2) -> Dictionary:
	var navigator := _road_navigator()
	if navigator != null and navigator.has_method("find_randomized_path"):
		var road_path: Array = navigator.call("find_randomized_path", start, end, _rng)
		if road_path.size() < 2 and navigator.has_method("find_path"):
			road_path = navigator.call("find_path", start, end)
		if road_path.size() < 2:
			return {"start": start, "end": end, "points": _random_route_points(start, end)}
		return _route_from_path(road_path)
	return {"start": start, "end": end, "points": _random_route_points(start, end)}


func _route_from_path(path: Array) -> Dictionary:
	var points: Array[Vector2] = []
	for index in range(1, path.size() - 1):
		points.append(path[index] as Vector2)
	return {
		"start": path.front() as Vector2,
		"end": path.back() as Vector2,
		"points": points,
	}


func _route_points_with_end(route: Dictionary) -> Array[Vector2]:
	var points: Array[Vector2] = []
	for point in route.get("points", []):
		points.append(point as Vector2)
	points.append(route["end"] as Vector2)
	return points


func _random_route_points(start: Vector2, end: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var first_ratio := _rng.randf_range(0.32, 0.48)
	points.append(start.lerp(end, first_ratio) + _random_jitter())
	if _rng.randf() > 0.45:
		var second_ratio := _rng.randf_range(0.56, 0.72)
		points.append(start.lerp(end, second_ratio) + _random_jitter())
	return points


func _random_jitter() -> Vector2:
	return Vector2(
		_rng.randf_range(-WAYPOINT_ROUTE_JITTER.x, WAYPOINT_ROUTE_JITTER.x),
		_rng.randf_range(-WAYPOINT_ROUTE_JITTER.y, WAYPOINT_ROUTE_JITTER.y)
	)


func _road_navigator() -> Node:
	if route_world == null:
		return null
	var navigator := route_world.get_node_or_null("RoadNavigator")
	if navigator != null:
		return navigator
	for node in get_tree().get_nodes_in_group("road_navigator"):
		if node.is_inside_tree() and node.get_parent() == route_world:
			return node
	return null


func _belongs_to_route_world(node: Node) -> bool:
	return route_world != null and (node == route_world or route_world.is_ancestor_of(node))


func _world_node() -> Node:
	var parent_node := get_parent()
	if parent_node == null:
		return get_tree().current_scene
	if _has_endpoint_child(parent_node):
		return parent_node
	if parent_node.get_parent() != null:
		return parent_node.get_parent()
	return parent_node


func _has_endpoint_child(node: Node) -> bool:
	for child in node.get_children():
		if child.is_in_group("npc_endpoint"):
			return true
		if _has_endpoint_child(child):
			return true
	return false
