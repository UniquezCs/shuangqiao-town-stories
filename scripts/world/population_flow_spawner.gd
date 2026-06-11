extends Node

const CUSTOMER_SCENE := preload("res://scenes/customer.tscn")

@export var enabled := true
@export_range(1, 12, 1) var max_visible_per_event := 4
@export_range(1, 60, 1) var spread_window_game_minutes := 10

@onready var route_world: Node = _world_node()

var _rng := RandomNumberGenerator.new()
var _pending_spawns: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	SignalBus.flow_event_created.connect(_on_flow_event_created)
	_spawn_recent_flow_events.call_deferred()


func _on_flow_event_created(event: Dictionary) -> void:
	if not enabled:
		return
	var source := _endpoint_for_event(event, "source", "source_key")
	var target := _endpoint_for_event(event, "target", "target_key")
	if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
		return
	var visible_count := mini(max_visible_per_event, int(event.get("visible_count", 0)))
	for _index in range(visible_count):
		_schedule_customer_for_event(event, source, target)


func debug_pending_spawn_count() -> int:
	return _pending_spawns.size()


func debug_spawn_next_pending() -> void:
	if _pending_spawns.is_empty():
		return
	var request: Dictionary = _pending_spawns.pop_front()
	_spawn_customer_for_request(request)


func _spawn_recent_flow_events() -> void:
	if not enabled or route_world == null or not PopulationFlow.has_method("get_recent_flow_events"):
		return
	var recent_events: Array = PopulationFlow.call("get_recent_flow_events", spread_window_game_minutes, GameState.current_game_minute)
	for event in recent_events:
		var source := _endpoint_for_event(event, "source", "source_key")
		var target := _endpoint_for_event(event, "target", "target_key")
		if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
			continue
		var visible_count := mini(max_visible_per_event, int(event.get("visible_count", 0)))
		for _index in range(visible_count):
			_spawn_customer_for_recent_event(event, source, target)


func _schedule_customer_for_event(event: Dictionary, source: Node2D, target: Node2D) -> void:
	var request := {
		"event": event.duplicate(true),
		"source": source,
		"target": target,
	}
	_pending_spawns.append(request)
	var timer := Timer.new()
	timer.one_shot = true
	timer.wait_time = _random_delay_seconds()
	timer.timeout.connect(_on_spawn_timer_timeout.bind(timer, request))
	add_child(timer)
	timer.start()


func _on_spawn_timer_timeout(timer: Timer, request: Dictionary) -> void:
	if is_instance_valid(timer):
		timer.queue_free()
	_pending_spawns.erase(request)
	_spawn_customer_for_request(request)


func _spawn_customer_for_request(request: Dictionary) -> void:
	var event: Dictionary = request.get("event", {})
	var source := request.get("source") as Node2D
	var target := request.get("target") as Node2D
	if source == null or target == null or not is_instance_valid(source) or not is_instance_valid(target):
		return
	_spawn_customer_for_event(event, source, target)


func _spawn_customer_for_event(event: Dictionary, source: Node2D, target: Node2D) -> void:
	var route := _route_for_positions(_endpoint_position(source), _endpoint_position(target))
	if route.is_empty():
		return
	_spawn_customer_on_route(event, route)


func _spawn_customer_for_recent_event(event: Dictionary, source: Node2D, target: Node2D) -> void:
	var route := _route_for_positions(_endpoint_position(source), _endpoint_position(target))
	if route.is_empty():
		return
	var progress := _event_route_progress(event)
	_spawn_customer_on_route(event, _route_from_progress(route, progress))


func _spawn_customer_on_route(event: Dictionary, route: Dictionary) -> void:
	var age_group := str(event.get("age_group", PrototypeConstants.CUSTOMER_AGE_MIDDLE))
	var gender := str(event.get("gender", _random_gender()))
	var customer := CUSTOMER_SCENE.instantiate()
	customer.call(
		"setup",
		_customer_type_for_age(age_group),
		_player_stall_spot(),
		route["start"],
		route["end"],
		route["points"],
		_visual_variant(age_group, gender),
		age_group,
		gender
	)
	if route_world != null:
		route_world.add_child(customer)
	else:
		get_tree().current_scene.add_child(customer)


func _event_route_progress(event: Dictionary) -> float:
	var event_minute := int(event.get("minute", GameState.current_game_minute))
	var elapsed_minutes := maxi(0, GameState.current_game_minute - event_minute)
	var base_progress := float(elapsed_minutes) / float(maxi(1, spread_window_game_minutes))
	return clampf(base_progress + _rng.randf_range(-0.12, 0.12), 0.08, 0.92)


func _route_from_progress(route: Dictionary, progress: float) -> Dictionary:
	var full_path: Array[Vector2] = [route["start"] as Vector2]
	for point in route.get("points", []):
		full_path.append(point as Vector2)
	full_path.append(route["end"] as Vector2)
	if full_path.size() < 2:
		return route
	var total_distance := 0.0
	for index in range(full_path.size() - 1):
		total_distance += full_path[index].distance_to(full_path[index + 1])
	if total_distance <= 0.0:
		return route
	var target_distance := total_distance * clampf(progress, 0.0, 0.95)
	var walked_distance := 0.0
	for index in range(full_path.size() - 1):
		var from_point := full_path[index]
		var to_point := full_path[index + 1]
		var segment_distance := from_point.distance_to(to_point)
		if walked_distance + segment_distance >= target_distance:
			var segment_progress := 0.0 if segment_distance <= 0.0 else (target_distance - walked_distance) / segment_distance
			var start_point := from_point.lerp(to_point, segment_progress)
			var remaining_points: Array[Vector2] = []
			for point_index in range(index + 1, full_path.size() - 1):
				remaining_points.append(full_path[point_index])
			return {
				"start": start_point,
				"end": full_path.back(),
				"points": remaining_points,
			}
		walked_distance += segment_distance
	return route


func _route_for_positions(start: Vector2, end: Vector2) -> Dictionary:
	var navigator := _road_navigator()
	if navigator != null and navigator.has_method("find_randomized_path"):
		var road_path: Array = navigator.call("find_randomized_path", start, end, _rng)
		if road_path.size() < 2 and navigator.has_method("find_path"):
			road_path = navigator.call("find_path", start, end)
		if road_path.size() >= 2:
			return _route_from_path(road_path, start, end)
	return {
		"start": start,
		"end": end,
		"points": _fallback_route_points(start, end),
	}


func _route_from_path(path: Array, start: Vector2, end: Vector2) -> Dictionary:
	var points: Array[Vector2] = []
	for index in range(path.size()):
		points.append(path[index] as Vector2)
	return {
		"start": start,
		"end": end,
		"points": points,
	}


func _fallback_route_points(start: Vector2, end: Vector2) -> Array[Vector2]:
	var midpoint := start.lerp(end, _rng.randf_range(0.42, 0.58))
	return [midpoint + Vector2(_rng.randf_range(-80.0, 80.0), _rng.randf_range(-64.0, 64.0))]


func _endpoint_position(endpoint: Node2D) -> Vector2:
	if endpoint.has_method("get_endpoint_position"):
		return endpoint.call("get_endpoint_position")
	return endpoint.global_position


func _customer_type_for_age(age_group: String) -> String:
	if age_group == PrototypeConstants.CUSTOMER_AGE_YOUTH:
		return PrototypeConstants.CUSTOMER_STUDENT
	return PrototypeConstants.CUSTOMER_WORKER


func _visual_variant(age_group: String, gender: String) -> String:
	if age_group == PrototypeConstants.CUSTOMER_AGE_YOUTH:
		return PrototypeConstants.CUSTOMER_VISUAL_YOUTH_FEMALE if gender == PrototypeConstants.CUSTOMER_GENDER_FEMALE else PrototypeConstants.CUSTOMER_VISUAL_YOUTH_MALE
	if age_group == PrototypeConstants.CUSTOMER_AGE_ELDER:
		return PrototypeConstants.CUSTOMER_VISUAL_ELDER_FEMALE if gender == PrototypeConstants.CUSTOMER_GENDER_FEMALE else PrototypeConstants.CUSTOMER_VISUAL_ELDER_MALE
	return PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_FEMALE if gender == PrototypeConstants.CUSTOMER_GENDER_FEMALE else PrototypeConstants.CUSTOMER_VISUAL_MIDDLE_MALE


func _random_gender() -> String:
	return PrototypeConstants.CUSTOMER_GENDER_MALE if _rng.randf() < 0.5 else PrototypeConstants.CUSTOMER_GENDER_FEMALE


func _endpoint_for_event(event: Dictionary, node_field: String, key_field: String) -> Node2D:
	var direct := event.get(node_field) as Node2D
	if direct != null and is_instance_valid(direct) and _node_belongs_to_world(direct, route_world):
		return direct
	var key := str(event.get(key_field, ""))
	if not key.is_empty():
		for endpoint in _available_world_endpoints():
			if _endpoint_key(endpoint) == key:
				return endpoint
	var endpoint_id := str(event.get("%s_id" % node_field, ""))
	if not endpoint_id.is_empty():
		for endpoint in _available_world_endpoints():
			if str(endpoint.get("endpoint_id")) == endpoint_id:
				return endpoint
	return null


func _available_world_endpoints() -> Array[Node2D]:
	var endpoints: Array[Node2D] = []
	if route_world == null:
		return endpoints
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if node is Node2D and node.is_inside_tree() and _node_belongs_to_world(node, route_world):
			endpoints.append(node)
	return endpoints


func _endpoint_key(endpoint: Node) -> String:
	if route_world != null and route_world.is_ancestor_of(endpoint):
		return str(route_world.get_path_to(endpoint))
	return str(endpoint.get_path())


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
		if node.is_inside_tree() and _node_belongs_to_world(node, route_world):
			return node
	return null


func _world_node() -> Node:
	var parent_node := get_parent()
	if parent_node == null:
		return get_tree().current_scene
	if parent_node.get_parent() != null:
		return parent_node.get_parent()
	return parent_node


func _node_belongs_to_world(node: Node, world: Node) -> bool:
	return world != null and (node == world or world.is_ancestor_of(node))


func _random_delay_seconds() -> float:
	var window_seconds := float(spread_window_game_minutes) * PrototypeConstants.REAL_SECONDS_PER_GAME_MINUTE
	return _rng.randf_range(0.2, max(0.2, window_seconds))
