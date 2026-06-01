extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")
const CustomerSchedule := preload("res://scripts/world/customer_schedule.gd")

const WAYPOINT_ROUTE_JITTER := Vector2(90, 75)

@export var spot_id := PrototypeConstants.SPOT_SCHOOL
@export var customer_type := PrototypeConstants.CUSTOMER_STUDENT
@export var home_endpoint_id := "residential"
@export var destination_endpoint_id := "school_gate"
@export var spawn_offset := Vector2(-260, 0)
@export var exit_offset := Vector2(260, 0)
@export var route_anchor_offset := Vector2(0, 42)

@onready var timer: Timer = $Timer
@onready var route_world: Node = _world_node()

var _spawn_plan: Array = []
var _spawn_index := 0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()
	_spawn_plan = CustomerSchedule.build_daily_spawn_plan(customer_type, _rng)
	SignalBus.game_time_changed.connect(_on_game_time_changed)
	_on_game_time_changed(GameState.current_game_minute, GameState.format_game_time(GameState.current_game_minute))


func _on_game_time_changed(total_minutes: int, _clock_text: String) -> void:
	while _spawn_index < _spawn_plan.size() and int(_spawn_plan[_spawn_index]["minute"]) <= total_minutes:
		_spawn_customer(str(_spawn_plan[_spawn_index]["mode"]))
		_spawn_index += 1


func _spawn_customer(route_mode: String) -> void:
	if route_mode == CustomerSchedule.ROUTE_NONE:
		return
	var route := _route_for_mode(route_mode)
	if route.is_empty():
		return
	var customer := CUSTOMER_SCENE.instantiate()
	customer.call("setup", customer_type, _player_stall_spot(), route["start"], route["end"], route["points"], _random_visual_variant_for_customer_type())
	if route_world != null:
		route_world.add_child(customer)
	else:
		get_tree().current_scene.add_child(customer)


func _route_for_mode(route_mode: String) -> Dictionary:
	var residence := _residential_position()
	var destination := _destination_position()
	if route_mode == CustomerSchedule.ROUTE_HOME_TO_DESTINATION:
		return _route_for_positions(residence, destination)
	return _route_for_positions(destination, residence)


func _residential_position() -> Vector2:
	if route_world != null:
		var endpoint := _endpoint_by_id(route_world, home_endpoint_id)
		if endpoint != null:
			return _endpoint_position(endpoint)
	return _fallback_position() + spawn_offset


func _destination_position() -> Vector2:
	var endpoint := _destination_endpoint()
	if endpoint != null:
		return _endpoint_position(endpoint)
	return _fallback_position() + route_anchor_offset


func _destination_endpoint() -> Node2D:
	if route_world != null:
		var endpoint := _endpoint_by_id(route_world, destination_endpoint_id)
		if endpoint != null:
			return endpoint
	var parent_node := get_parent() as Node2D
	if parent_node != null and parent_node.is_in_group("npc_endpoint"):
		return parent_node
	return null


func _endpoint_by_id(world: Node, endpoint_id: String) -> Node2D:
	var endpoints := _endpoints_by_id(world, endpoint_id)
	if endpoints.is_empty():
		return null
	return endpoints[_rng.randi_range(0, endpoints.size() - 1)]


func _endpoints_by_id(world: Node, endpoint_id: String) -> Array[Node2D]:
	var endpoints: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if node is Node2D and node.is_inside_tree() and node.get_parent() == world:
			if str(node.get("endpoint_id")) == endpoint_id:
				endpoints.append(node)
	return endpoints


func _endpoint_position(endpoint: Node2D) -> Vector2:
	if endpoint != null and endpoint.has_method("get_endpoint_position"):
		return endpoint.call("get_endpoint_position")
	return endpoint.global_position + route_anchor_offset


func _fallback_position() -> Vector2:
	var parent_node := get_parent() as Node2D
	if parent_node != null:
		return parent_node.global_position
	return Vector2.ZERO


func _world_node() -> Node:
	var parent_node := get_parent()
	if parent_node == null:
		return get_tree().current_scene
	if parent_node.is_in_group("npc_endpoint"):
		return parent_node.get_parent()
	if _has_endpoint_child(parent_node):
		return parent_node
	if parent_node.get_parent() != null:
		return parent_node.get_parent()
	return parent_node


func _has_endpoint_child(node: Node) -> bool:
	for child in node.get_children():
		if child.is_in_group("npc_endpoint"):
			return true
	return false


func _random_route_points(start: Vector2, end: Vector2) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var first_ratio := _rng.randf_range(0.32, 0.48)
	var first := start.lerp(end, first_ratio) + Vector2(
		_rng.randf_range(-WAYPOINT_ROUTE_JITTER.x, WAYPOINT_ROUTE_JITTER.x),
		_rng.randf_range(-WAYPOINT_ROUTE_JITTER.y, WAYPOINT_ROUTE_JITTER.y)
	)
	points.append(first)
	if _rng.randf() > 0.45:
		var second_ratio := _rng.randf_range(0.56, 0.72)
		var second := start.lerp(end, second_ratio) + Vector2(
			_rng.randf_range(-WAYPOINT_ROUTE_JITTER.x, WAYPOINT_ROUTE_JITTER.x),
			_rng.randf_range(-WAYPOINT_ROUTE_JITTER.y, WAYPOINT_ROUTE_JITTER.y)
		)
		points.append(second)
	return points


func _route_for_positions(start: Vector2, end: Vector2) -> Dictionary:
	var navigator := _road_navigator()
	if navigator != null and navigator.has_method("find_randomized_path"):
		var road_path: Array = navigator.call("find_randomized_path", start, end, _rng)
		if road_path.size() < 2:
			return {}
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


func _player_stall_spot() -> Node:
	var world := route_world
	if world == null:
		return self
	var fallback: Node = null
	for node in get_tree().get_nodes_in_group("player_stall_spot"):
		if node.is_inside_tree() and node.get_parent() == world:
			if fallback == null:
				fallback = node
			if node.has_method("get_active_stall") and node.call("get_active_stall") != null:
				return node
	var destination := _destination_endpoint()
	return fallback if fallback != null else destination


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


func _random_visual_variant_for_customer_type() -> String:
	var variants: Array = PrototypeConstants.STUDENT_CUSTOMER_VISUAL_VARIANTS
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		variants = PrototypeConstants.WORKER_CUSTOMER_VISUAL_VARIANTS
	if variants.is_empty():
		return ""
	return str(variants[_rng.randi_range(0, variants.size() - 1)])
