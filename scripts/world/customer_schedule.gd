extends RefCounted

const ROUTE_HOME_TO_DESTINATION := "home_to_destination"
const ROUTE_DESTINATION_TO_HOME := "destination_to_home"
const ROUTE_NONE := "none"
const REAL_SECONDS_PER_GAME_MINUTE := 5.0
const STUDENT_MORNING_COUNT_RANGE := Vector2i(60, 80)
const STUDENT_AFTERNOON_COUNT_RANGE := Vector2i(60, 80)
const WORKER_MORNING_COUNT_RANGE := Vector2i(100, 110)
const WORKER_AFTERNOON_COUNT_RANGE := Vector2i(100, 110)


static func real_seconds_to_game_minutes(seconds: float) -> int:
	return int(floor(seconds / REAL_SECONDS_PER_GAME_MINUTE))


static func route_mode_for_time(customer_type: String, total_minutes: int) -> String:
	if customer_type == "student":
		if total_minutes >= 6 * 60 and total_minutes < 8 * 60:
			return ROUTE_HOME_TO_DESTINATION
		if total_minutes >= 16 * 60 and total_minutes < 18 * 60:
			return ROUTE_DESTINATION_TO_HOME
	if customer_type == "worker":
		if total_minutes >= 7 * 60 and total_minutes < 9 * 60:
			return ROUTE_HOME_TO_DESTINATION
		if total_minutes >= 17 * 60 and total_minutes < 19 * 60:
			return ROUTE_DESTINATION_TO_HOME
	return ROUTE_NONE


static func build_daily_spawn_plan(customer_type: String, rng: RandomNumberGenerator) -> Array:
	var plan := []
	if customer_type == "student":
		_append_random_spawn_window(plan, rng.randi_range(STUDENT_MORNING_COUNT_RANGE.x, STUDENT_MORNING_COUNT_RANGE.y), 6 * 60, 8 * 60, ROUTE_HOME_TO_DESTINATION, rng)
		_append_random_spawn_window(plan, rng.randi_range(STUDENT_AFTERNOON_COUNT_RANGE.x, STUDENT_AFTERNOON_COUNT_RANGE.y), 16 * 60, 18 * 60, ROUTE_DESTINATION_TO_HOME, rng)
	elif customer_type == "worker":
		_append_random_spawn_window(plan, rng.randi_range(WORKER_MORNING_COUNT_RANGE.x, WORKER_MORNING_COUNT_RANGE.y), 7 * 60, 9 * 60, ROUTE_HOME_TO_DESTINATION, rng)
		_append_random_spawn_window(plan, rng.randi_range(WORKER_AFTERNOON_COUNT_RANGE.x, WORKER_AFTERNOON_COUNT_RANGE.y), 17 * 60, 19 * 60, ROUTE_DESTINATION_TO_HOME, rng)
	plan.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["minute"]) < int(b["minute"])
	)
	return plan


static func _append_random_spawn_window(plan: Array, count: int, start_minute: int, end_minute: int, mode: String, rng: RandomNumberGenerator) -> void:
	for index in range(count):
		plan.append({"minute": rng.randi_range(start_minute, end_minute - 1), "mode": mode})
