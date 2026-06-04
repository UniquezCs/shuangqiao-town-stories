extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const WAYPOINT_ROUTE_JITTER := Vector2(120, 90)

@export var enabled := true
@export var daily_customer_count_range := Vector2i(300, 500)
@export_range(1, 200, 1) var max_daily_customer_count: int = 100
@export var start_minute := 6 * 60
@export var end_minute := 21 * 60
@export var customer_type_pool: Array[String] = [
	PrototypeConstants.CUSTOMER_STUDENT,
	PrototypeConstants.CUSTOMER_WORKER,
]
@export var allowed_endpoint_types: Array[String] = []

@onready var route_world: Node = _world_node()

var _spawn_plan: Array[Dictionary] = []
var _spawn_index := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_spawn_plan = _build_daily_spawn_plan()
	SignalBus.game_time_changed.connect(_on_game_time_changed)
	_catch_up_to_current_time.call_deferred()


func _catch_up_to_current_time() -> void:
	if not is_inside_tree():
		return
	_on_game_time_changed(GameState.current_game_minute, GameState.format_game_time(GameState.current_game_minute))


func _on_game_time_changed(total_minutes: int, _clock_text: String) -> void:
	if not enabled:
		return
	while _spawn_index < _spawn_plan.size() and int(_spawn_plan[_spawn_index]["minute"]) <= total_minutes:
		_spawn_random_customer()
		_spawn_index += 1


func build_random_route() -> Dictionary:
	var endpoints := _available_endpoints()
	if endpoints.size() < 2:
		return {}

	for _attempt in range(maxi(12, endpoints.size() * 2)):
		var start_endpoint := _pick_weighted_endpoint(endpoints)
		var end_endpoint := _pick_weighted_endpoint(endpoints)
		var retry_count := 0
		while end_endpoint == start_endpoint and retry_count < 12:
			end_endpoint = _pick_weighted_endpoint(endpoints)
			retry_count += 1

		if end_endpoint == start_endpoint:
			for endpoint in endpoints:
				if endpoint != start_endpoint:
					end_endpoint = endpoint
					break

		var start := _endpoint_position(start_endpoint)
		var end := _endpoint_position(end_endpoint)
		var route := _route_for_positions(start, end)
		if route.is_empty():
			continue
		route.merge({
			"start_endpoint": start_endpoint,
			"end_endpoint": end_endpoint,
		})
		return route
	return {}


func _build_daily_spawn_plan() -> Array[Dictionary]:
	var plan: Array[Dictionary] = []
	var lower_bound: int = min(daily_customer_count_range.x, daily_customer_count_range.y)
	var upper_bound: int = max(daily_customer_count_range.x, daily_customer_count_range.y)
	var capped_upper_bound: int = min(upper_bound, max_daily_customer_count)
	var capped_lower_bound: int = min(max(0, lower_bound), capped_upper_bound)
	var count := _rng.randi_range(capped_lower_bound, capped_upper_bound)
	for _index in range(count):
		plan.append({"minute": _rng.randi_range(start_minute, end_minute - 1)})
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["minute"]) < int(b["minute"])
	)
	return plan


func _spawn_random_customer() -> void:
	var route := build_random_route()
	if route.is_empty():
		return
	var customer := CUSTOMER_SCENE.instantiate()
	customer.call("setup", _random_customer_type(), _player_stall_spot(), route["start"], route["end"], route["points"], _random_visual_variant())
	if route_world != null:
		route_world.add_child(customer)
	else:
		get_tree().current_scene.add_child(customer)


func _available_endpoints() -> Array[Node2D]:
	var endpoints: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if not node is Node2D or not node.is_inside_tree():
			continue
		if route_world != null and not _belongs_to_route_world(node):
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
	if allowed_endpoint_types.is_empty():
		return true
	var endpoint_type := ""
	if endpoint.has_method("get_endpoint_type"):
		endpoint_type = str(endpoint.call("get_endpoint_type"))
	else:
		endpoint_type = str(endpoint.get("endpoint_type"))
	return allowed_endpoint_types.has(endpoint_type)


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


func _random_route_points(start: Vector2, end: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var first_ratio := _rng.randf_range(0.28, 0.44)
	points.append(start.lerp(end, first_ratio) + _random_jitter())
	if _rng.randf() > 0.35:
		var second_ratio := _rng.randf_range(0.56, 0.78)
		points.append(start.lerp(end, second_ratio) + _random_jitter())
	return points


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


func _random_jitter() -> Vector2:
	return Vector2(
		_rng.randf_range(-WAYPOINT_ROUTE_JITTER.x, WAYPOINT_ROUTE_JITTER.x),
		_rng.randf_range(-WAYPOINT_ROUTE_JITTER.y, WAYPOINT_ROUTE_JITTER.y)
	)


func _random_customer_type() -> String:
	if customer_type_pool.is_empty():
		return PrototypeConstants.CUSTOMER_STUDENT
	return customer_type_pool[_rng.randi_range(0, customer_type_pool.size() - 1)]


func _random_visual_variant() -> String:
	var variants: Array = PrototypeConstants.RANDOM_CUSTOMER_VISUAL_VARIANTS
	if variants.is_empty():
		return ""
	return str(variants[_rng.randi_range(0, variants.size() - 1)])


func _player_stall_spot() -> Node:
	var world := route_world
	if world == null:
		return self
	var fallback: Node = null
	for node in get_tree().get_nodes_in_group("player_stall_spot"):
		if node.is_inside_tree() and _node_belongs_to_world(node, world):
			if fallback == null:
				fallback = node
			if node.has_method("get_active_stall") and node.call("get_active_stall") != null:
				return node
	return fallback if fallback != null else self


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


func _belongs_to_route_world(node: Node) -> bool:
	return _node_belongs_to_world(node, route_world)


func _node_belongs_to_world(node: Node, world: Node) -> bool:
	return world != null and (node == world or world.is_ancestor_of(node))
