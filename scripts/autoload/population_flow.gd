extends Node

const GameplayDebugLog := preload("res://scripts/debug/gameplay_debug_log.gd")

const ENDPOINT_TYPES := ["residential", "shop", "school", "factory", "public"]
const AGE_GROUPS := [
	PrototypeConstants.CUSTOMER_AGE_YOUTH,
	PrototypeConstants.CUSTOMER_AGE_MIDDLE,
	PrototypeConstants.CUSTOMER_AGE_ELDER,
]

var _world: Node = null
var _visible_world: Node = null
var _endpoints: Array[Node2D] = []
var _last_tick_minute := -1
var _rng := RandomNumberGenerator.new()
var _weather_override := ""
var _day_tag_override := ""
var _recent_events: Array[Dictionary] = []


func _ready() -> void:
	_rng.randomize()
	SignalBus.game_time_changed.connect(_on_game_time_changed)


func initialize_for_world(world: Node, reset_population := false) -> void:
	if world == null:
		return
	_visible_world = world
	if _world == null or reset_population:
		_release_detached_world()
		_world = world
		reset_population = true
	_collect_endpoints()
	if reset_population:
		_initialize_population()
	if _last_tick_minute < 0:
		_last_tick_minute = _aligned_tick_minute(GameState.current_game_minute)
	SignalBus.population_initialized.emit(get_population_snapshot())


func initialize_from_scene(town_scene: PackedScene, reset_population := false) -> void:
	if town_scene == null:
		return
	if _world != null and not reset_population:
		return
	_release_detached_world()
	_world = town_scene.instantiate()
	_world.name = "PopulationFlowTownTemplate"
	_visible_world = null
	_collect_endpoints()
	_initialize_population()
	_recent_events.clear()
	_last_tick_minute = _aligned_tick_minute(GameState.current_game_minute) - _flow_interval_minutes()
	_run_due_tick_for_minute(GameState.current_game_minute)
	SignalBus.population_initialized.emit(get_population_snapshot())


func reset_for_tests() -> void:
	_release_detached_world()
	_world = null
	_visible_world = null
	_endpoints.clear()
	_last_tick_minute = -1
	_weather_override = ""
	_day_tag_override = ""
	_recent_events.clear()
	_rng.seed = 12345


func set_weather_for_tests(weather_id: String) -> void:
	_weather_override = weather_id


func is_initialized_for_world(world: Node) -> bool:
	return (_world == world or _visible_world == world) and not _endpoints.is_empty()


func is_background_initialized() -> bool:
	return _world != null and not _endpoints.is_empty()


func get_recent_flow_events(window_minutes := 10, current_minute := -1) -> Array:
	var now := GameState.current_game_minute if current_minute < 0 else current_minute
	var start_minute := now - maxi(1, window_minutes)
	var result := []
	for event in _recent_events:
		var minute := int(event.get("minute", -1))
		if minute >= start_minute and minute <= now:
			result.append(event.duplicate(true))
	return result


func get_population_snapshot() -> Dictionary:
	var snapshot := {}
	for endpoint in _endpoints:
		if not is_instance_valid(endpoint):
			continue
		snapshot[_endpoint_key(endpoint)] = {
			"node_path": _endpoint_key(endpoint),
			"endpoint_id": str(endpoint.get("endpoint_id")),
			"endpoint_type": _endpoint_type(endpoint),
			"population": _endpoint_population(endpoint),
			"capacity": _endpoint_capacity(endpoint),
			"attraction_bias": _endpoint_attraction(endpoint),
		}
	return snapshot


func get_population_debug_summary() -> Dictionary:
	_collect_endpoints()
	var by_type := {}
	var total_population := 0
	var total_capacity := 0
	for endpoint_type in ENDPOINT_TYPES:
		by_type[endpoint_type] = {
			"endpoint_count": 0,
			"population": 0,
			"capacity": 0,
		}
	for endpoint in _endpoints:
		if not is_instance_valid(endpoint):
			continue
		var endpoint_type := _endpoint_type(endpoint)
		var type_summary: Dictionary = by_type[endpoint_type]
		var population := _population_total(_endpoint_population(endpoint))
		var capacity := _endpoint_capacity(endpoint)
		type_summary["endpoint_count"] = int(type_summary["endpoint_count"]) + 1
		type_summary["population"] = int(type_summary["population"]) + population
		type_summary["capacity"] = int(type_summary["capacity"]) + capacity
		total_population += population
		total_capacity += capacity
	return {
		"endpoint_count": _endpoints.size(),
		"total_population": total_population,
		"total_capacity": total_capacity,
		"by_type": by_type,
	}


func run_flow_tick(total_minutes: int) -> Dictionary:
	_collect_endpoints()
	var starting_populations := {}
	for endpoint in _endpoints:
		if is_instance_valid(endpoint):
			starting_populations[_endpoint_key(endpoint)] = _endpoint_population(endpoint)
	var summary := {
		"minute": total_minutes,
		"time_block": _time_block(total_minutes),
		"events": [],
		"visible_total": 0,
		"modifier_debug": _modifier_debug(),
	}
	for source in _endpoints:
		if not is_instance_valid(source):
			continue
		var source_population: Dictionary = starting_populations.get(_endpoint_key(source), _empty_population())
		for age_group in AGE_GROUPS:
			var available := int(source_population.get(age_group, 0))
			if available <= 0:
				continue
			var moving_count := _moving_count(available, age_group, total_minutes)
			if moving_count <= 0:
				continue
			var allocations := _allocate_targets(source, age_group, moving_count, total_minutes)
			for target in allocations.keys():
				var count := int(allocations[target])
				if count <= 0:
					continue
				_move_population(source, target, age_group, count)
				var visible_count := _visible_count(count)
				var event := _flow_event(source, target, age_group, count, visible_count, total_minutes)
				summary["events"].append(event)
				summary["visible_total"] = int(summary["visible_total"]) + visible_count
				_store_recent_event(event)
				SignalBus.flow_event_created.emit(event)
	SignalBus.flow_tick_completed.emit(total_minutes, summary)
	_log_flow_summary(summary)
	return summary


func _on_game_time_changed(total_minutes: int, _clock_text: String) -> void:
	if _world == null or _endpoints.is_empty():
		return
	_run_due_tick_for_minute(total_minutes)


func _run_due_tick_for_minute(total_minutes: int) -> void:
	if total_minutes < PrototypeConstants.DAY_START_MINUTE:
		return
	var interval := _flow_interval_minutes()
	var tick_minute := (total_minutes / interval) * interval
	if tick_minute <= _last_tick_minute:
		return
	_last_tick_minute = tick_minute
	run_flow_tick(tick_minute)


func _collect_endpoints() -> void:
	_endpoints.clear()
	if _world == null:
		return
	for node in _world.find_children("*", "Node2D", true, false):
		if node is Node2D and _is_endpoint_node(node):
			_endpoints.append(node)


func _initialize_population() -> void:
	for endpoint in _endpoints:
		_set_endpoint_population(endpoint, _empty_population())
	var residential_endpoints := _endpoints_by_type("residential")
	if residential_endpoints.is_empty():
		return
	var population_config := ConfigLoader.get_population_config()
	var total_population := int(population_config.get("total_population", 1000))
	var age_distribution: Dictionary = population_config.get("age_distribution", {})
	for age_group in AGE_GROUPS:
		var group_count := int(round(total_population * _number(age_distribution.get(age_group, 0.0), 0.0)))
		_distribute_group_to_residences(age_group, group_count, residential_endpoints)


func _distribute_group_to_residences(age_group: String, group_count: int, residences: Array[Node2D]) -> void:
	if group_count <= 0:
		return
	var total_capacity := 0
	for endpoint in residences:
		total_capacity += _endpoint_capacity(endpoint)
	var remaining := group_count
	for index in range(residences.size()):
		var endpoint := residences[index]
		var amount := remaining
		if index < residences.size() - 1 and total_capacity > 0:
			amount = int(floor(float(group_count) * float(_endpoint_capacity(endpoint)) / float(total_capacity)))
			amount = clampi(amount, 0, remaining)
		var population := _endpoint_population(endpoint)
		population[age_group] = int(population.get(age_group, 0)) + amount
		_set_endpoint_population(endpoint, population)
		remaining -= amount


func _moving_count(available: int, age_group: String, total_minutes: int) -> int:
	var block := _time_block(total_minutes)
	var mobility_config: Dictionary = ConfigLoader.get_population_config().get("mobility_rate", {})
	var block_config: Dictionary = mobility_config.get(block, {})
	var rate := _number(block_config.get(age_group, 0.06), 0.06)
	return clampi(int(round(float(available) * rate)), 0, available)


func _allocate_targets(source: Node2D, age_group: String, moving_count: int, total_minutes: int) -> Dictionary:
	var scores: Array[Dictionary] = []
	var total_score := 0.0
	for target in _endpoints:
		if not is_instance_valid(target) or target == source:
			continue
		var score := _flow_score(source, target, age_group, total_minutes)
		if score <= 0.0:
			continue
		scores.append({"target": target, "score": score})
		total_score += score
	var result := {}
	if scores.is_empty() or total_score <= 0.0:
		return result
	var allocation_entries: Array[Dictionary] = []
	var assigned := 0
	for entry in scores:
		var exact_count := float(moving_count) * float(entry["score"]) / total_score
		var base_count := int(floor(exact_count))
		allocation_entries.append({
			"target": entry["target"],
			"count": base_count,
			"remainder": exact_count - float(base_count),
			"score": entry["score"],
		})
		assigned += base_count
	var remaining := moving_count - assigned
	allocation_entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if is_equal_approx(float(a["remainder"]), float(b["remainder"])):
			return float(a["score"]) > float(b["score"])
		return float(a["remainder"]) > float(b["remainder"])
	)
	for index in range(mini(remaining, allocation_entries.size())):
		allocation_entries[index]["count"] = int(allocation_entries[index]["count"]) + 1
	for entry in allocation_entries:
		var target: Node2D = entry["target"]
		var count := int(entry["count"])
		if count > 0:
			result[target] = count
	return result


func _flow_score(source: Node2D, target: Node2D, age_group: String, total_minutes: int) -> float:
	var target_type := _endpoint_type(target)
	var block := _time_block(total_minutes)
	var preferences := ConfigLoader.get_flow_preferences_config()
	var base_preference: Dictionary = preferences.get("base_preference", {})
	var group_base: Dictionary = base_preference.get(age_group, {})
	var score := _number(group_base.get(target_type, 0.0), 0.0)
	score *= _time_modifier(age_group, target_type, block)
	score *= _time_curve_modifier(age_group, target_type, total_minutes)
	score *= _weather_modifier(target_type)
	score *= _holiday_modifier(age_group, target_type)
	score *= _endpoint_attraction(target)
	score *= _distance_decay(source, target)
	score *= _capacity_factor(target)
	return max(0.0, score)


func _time_modifier(age_group: String, endpoint_type: String, block: String) -> float:
	var root: Dictionary = ConfigLoader.get_flow_preferences_config().get("time_modifier", {})
	var block_entry: Dictionary = root.get(block, {})
	var group_entry: Dictionary = block_entry.get(age_group, {})
	return _number(group_entry.get(endpoint_type, 1.0), 1.0)


func _time_curve_modifier(age_group: String, endpoint_type: String, total_minutes: int) -> float:
	var root: Dictionary = ConfigLoader.get_flow_preferences_config().get("time_curves", {})
	var group_entry: Dictionary = root.get(age_group, {})
	var raw_points: Variant = group_entry.get(endpoint_type, [])
	if typeof(raw_points) != TYPE_ARRAY:
		return 1.0
	var points: Array[Dictionary] = []
	for raw_point in raw_points:
		if typeof(raw_point) == TYPE_DICTIONARY:
			points.append(raw_point)
	if points.is_empty():
		return 1.0
	points.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("minute", 0)) < int(b.get("minute", 0))
	)

	var minute := total_minutes % (24 * 60)
	var previous_point := {}
	for point in points:
		var point_minute := int(point.get("minute", -1))
		if point_minute < 0:
			continue
		if minute == point_minute:
			return _number(point.get("value", 1.0), 1.0)
		if minute < point_minute:
			if previous_point.is_empty():
				return 1.0
			var previous_minute := int(previous_point.get("minute", point_minute))
			var previous_value := _number(previous_point.get("value", 1.0), 1.0)
			var next_value := _number(point.get("value", 1.0), 1.0)
			var span := maxi(1, point_minute - previous_minute)
			var progress := float(minute - previous_minute) / float(span)
			return lerpf(previous_value, next_value, progress)
		previous_point = point
	return 1.0


func _weather_modifier(endpoint_type: String) -> float:
	var root: Dictionary = ConfigLoader.get_flow_preferences_config().get("weather_modifier", {})
	var weather_entry: Dictionary = root.get(_current_weather(), {})
	return _number(weather_entry.get(endpoint_type, 1.0), 1.0)


func _holiday_modifier(age_group: String, endpoint_type: String) -> float:
	var root: Dictionary = ConfigLoader.get_flow_preferences_config().get("holiday_modifier", {})
	var day_entry: Dictionary = root.get(_current_day_tag(), {})
	var group_entry: Dictionary = day_entry.get(age_group, {})
	return _number(group_entry.get(endpoint_type, 1.0), 1.0)


func _distance_decay(source: Node2D, target: Node2D) -> float:
	var preferences: Dictionary = ConfigLoader.get_flow_preferences_config()
	var decay_tiles: float = _number(preferences.get("distance_decay_tiles", 60.0), 60.0)
	var decay_pixels: float = max(32.0, decay_tiles * 32.0)
	var distance: float = source.global_position.distance_to(target.global_position)
	return 1.0 / (1.0 + distance / decay_pixels)


func _capacity_factor(target: Node2D) -> float:
	var capacity: int = max(1, _endpoint_capacity(target))
	var population_total: int = _population_total(_endpoint_population(target))
	var vacancy: float = max(0.0, float(capacity - population_total) / float(capacity))
	return 0.35 + vacancy * 0.65


func _move_population(source: Node2D, target: Node2D, age_group: String, count: int) -> void:
	var source_population := _endpoint_population(source)
	var target_population := _endpoint_population(target)
	var actual := mini(int(source_population.get(age_group, 0)), count)
	source_population[age_group] = int(source_population.get(age_group, 0)) - actual
	target_population[age_group] = int(target_population.get(age_group, 0)) + actual
	_set_endpoint_population(source, source_population)
	_set_endpoint_population(target, target_population)
	SignalBus.population_changed.emit(_endpoint_key(source), source_population)
	SignalBus.population_changed.emit(_endpoint_key(target), target_population)


func _visible_count(count: int) -> int:
	if count <= 0:
		return 0
	var sample_rate := _number(ConfigLoader.get_population_config().get("visibility_sample_rate", 0.08), 0.08)
	return clampi(maxi(1, int(round(float(count) * sample_rate))), 1, count)


func _flow_event(source: Node2D, target: Node2D, age_group: String, count: int, visible_count: int, minute: int) -> Dictionary:
	return {
		"source": source,
		"target": target,
		"source_key": _endpoint_key(source),
		"target_key": _endpoint_key(target),
		"source_id": str(source.get("endpoint_id")),
		"target_id": str(target.get("endpoint_id")),
		"source_type": _endpoint_type(source),
		"target_type": _endpoint_type(target),
		"age_group": age_group,
		"gender": _random_gender(),
		"count": count,
		"visible_count": visible_count,
		"minute": minute,
		"time_block": _time_block(minute),
		"weather": _current_weather(),
		"day_tag": _current_day_tag(),
		"flow_reason": "%s_to_%s" % [_endpoint_type(source), _endpoint_type(target)],
	}


func _time_block(total_minutes: int) -> String:
	var minute := total_minutes % (24 * 60)
	if minute >= 5 * 60 and minute < 7 * 60:
		return "early_morning"
	if minute >= 7 * 60 and minute < 9 * 60:
		return "morning_peak"
	if minute >= 9 * 60 and minute < 16 * 60:
		return "daytime"
	if minute >= 16 * 60 and minute < 18 * 60:
		return "after_school"
	if minute >= 17 * 60 and minute < 20 * 60:
		return "evening_market"
	if minute >= 20 * 60 and minute < 24 * 60:
		return "night"
	return "late_night"


func _current_weather() -> String:
	if not _weather_override.is_empty():
		return _weather_override
	var calendar := ConfigLoader.get_calendar_config()
	var days: Dictionary = calendar.get("days", {})
	var day_entry: Dictionary = days.get(str(GameState.day_index), {})
	return str(day_entry.get("weather", calendar.get("default_weather", "sunny")))


func _current_day_tag() -> String:
	if not _day_tag_override.is_empty():
		return _day_tag_override
	var calendar := ConfigLoader.get_calendar_config()
	var days: Dictionary = calendar.get("days", {})
	var day_entry: Dictionary = days.get(str(GameState.day_index), {})
	return str(day_entry.get("day_tag", calendar.get("default_day_tag", "normal")))


func _modifier_debug() -> Dictionary:
	return {
		"residential_weather": _weather_modifier("residential"),
		"shop_weather": _weather_modifier("shop"),
		"school_weather": _weather_modifier("school"),
		"factory_weather": _weather_modifier("factory"),
		"public_weather": _weather_modifier("public"),
	}


func _log_flow_summary(summary: Dictionary) -> void:
	GameplayDebugLog.log("population_flow", "tick_summary", {
		"minute": int(summary.get("minute", -1)),
		"time_block": str(summary.get("time_block", "")),
		"event_count": (summary.get("events", []) as Array).size(),
		"visible_total": int(summary.get("visible_total", 0)),
		"population": get_population_debug_summary(),
	})


func _endpoints_by_type(endpoint_type: String) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for endpoint in _endpoints:
		if _endpoint_type(endpoint) == endpoint_type:
			result.append(endpoint)
	return result


func _endpoint_type(endpoint: Node) -> String:
	var raw_type := ""
	if endpoint.has_method("get_endpoint_type"):
		raw_type = str(endpoint.call("get_endpoint_type"))
	else:
		raw_type = str(endpoint.get("endpoint_type"))
	if ENDPOINT_TYPES.has(raw_type):
		return raw_type
	return "public"


func _endpoint_capacity(endpoint: Node) -> int:
	var raw_capacity: Variant = endpoint.get("capacity")
	if raw_capacity == null:
		var default_capacity: Dictionary = ConfigLoader.get_population_config().get("default_capacity", {})
		return int(default_capacity.get(_endpoint_type(endpoint), 100))
	return max(1, int(raw_capacity))


func _endpoint_attraction(endpoint: Node) -> float:
	var raw_bias: Variant = endpoint.get("attraction_bias")
	if raw_bias == null:
		return 1.0
	return _number(raw_bias, 1.0)


func _endpoint_population(endpoint: Node) -> Dictionary:
	if endpoint.has_method("get_population"):
		return endpoint.call("get_population")
	var raw_population: Variant = endpoint.get("population")
	if typeof(raw_population) == TYPE_DICTIONARY:
		return (raw_population as Dictionary).duplicate(true)
	return _empty_population()


func _set_endpoint_population(endpoint: Node, population: Dictionary) -> void:
	var normalized := _empty_population()
	for age_group in AGE_GROUPS:
		normalized[age_group] = maxi(0, int(population.get(age_group, 0)))
	if endpoint.has_method("set_population"):
		endpoint.call("set_population", normalized)
	else:
		endpoint.set("population", normalized)


func _empty_population() -> Dictionary:
	return {
		PrototypeConstants.CUSTOMER_AGE_YOUTH: 0,
		PrototypeConstants.CUSTOMER_AGE_MIDDLE: 0,
		PrototypeConstants.CUSTOMER_AGE_ELDER: 0,
	}


func _population_total(population: Dictionary) -> int:
	return int(population.get(PrototypeConstants.CUSTOMER_AGE_YOUTH, 0)) + int(population.get(PrototypeConstants.CUSTOMER_AGE_MIDDLE, 0)) + int(population.get(PrototypeConstants.CUSTOMER_AGE_ELDER, 0))


func _endpoint_key(endpoint: Node) -> String:
	if _world != null and endpoint == _world:
		return "."
	if _world != null and _world.is_ancestor_of(endpoint):
		return str(_world.get_path_to(endpoint))
	if endpoint.is_inside_tree():
		return str(endpoint.get_path())
	return str(endpoint.name)


func _is_endpoint_node(node: Node) -> bool:
	if node.has_method("get_endpoint_type"):
		return true
	for property in node.get_property_list():
		if str(property.get("name", "")) == "endpoint_id":
			return not str(node.get("endpoint_id")).is_empty()
	return false


func _store_recent_event(event: Dictionary) -> void:
	_recent_events.append(event.duplicate(true))
	_trim_recent_events(int(event.get("minute", GameState.current_game_minute)))


func _trim_recent_events(current_minute: int) -> void:
	var keep_after := current_minute - maxi(30, _flow_interval_minutes() * 4)
	_recent_events = _recent_events.filter(func(event: Dictionary) -> bool:
		return int(event.get("minute", -1)) >= keep_after
	)


func _release_detached_world() -> void:
	if _world != null and is_instance_valid(_world) and not _world.is_inside_tree():
		_world.free()


func _flow_interval_minutes() -> int:
	return maxi(1, int(ConfigLoader.get_population_config().get("flow_interval_minutes", 10)))


func _aligned_tick_minute(total_minutes: int) -> int:
	var interval := _flow_interval_minutes()
	return (total_minutes / interval) * interval


func _random_gender() -> String:
	return PrototypeConstants.CUSTOMER_GENDER_MALE if _rng.randf() < 0.5 else PrototypeConstants.CUSTOMER_GENDER_FEMALE


func _number(value: Variant, fallback: float) -> float:
	if typeof(value) == TYPE_INT or typeof(value) == TYPE_FLOAT:
		return value
	return fallback
