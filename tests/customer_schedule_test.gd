extends SceneTree

const CustomerSchedule := preload("res://scripts/world/customer_schedule.gd")


func _init() -> void:
	_assert_equal(CustomerSchedule.real_seconds_to_game_minutes(25.0), 5, "25 秒应等于游戏内 5 分钟")

	_assert_equal(
		CustomerSchedule.route_mode_for_time("student", 6 * 60),
		"home_to_destination",
		"学生 6 点应从居民区去学校"
	)
	_assert_equal(
		CustomerSchedule.route_mode_for_time("student", 16 * 60),
		"destination_to_home",
		"学生 16 点应从学校回居民区"
	)
	_assert_equal(
		CustomerSchedule.route_mode_for_time("worker", 7 * 60),
		"home_to_destination",
		"工人 7 点应从居民区去工厂"
	)
	_assert_equal(
		CustomerSchedule.route_mode_for_time("worker", 17 * 60),
		"destination_to_home",
		"工人 17 点应从工厂回居民区"
	)
	_assert_equal(
		CustomerSchedule.route_mode_for_time("student", 12 * 60),
		"none",
		"学生中午不应通勤刷新"
	)

	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var plan: Array = CustomerSchedule.build_daily_spawn_plan("student", rng)
	var min_student_count = CustomerSchedule.STUDENT_MORNING_COUNT_RANGE.x + CustomerSchedule.STUDENT_AFTERNOON_COUNT_RANGE.x
	var max_student_count = CustomerSchedule.STUDENT_MORNING_COUNT_RANGE.y + CustomerSchedule.STUDENT_AFTERNOON_COUNT_RANGE.y
	_assert_true(
		plan.size() >= min_student_count and plan.size() <= max_student_count,
		"学生每天刷新总数应有限，当前为 %d" % plan.size()
	)
	_assert_true(_contains_multiple_spawns_in_one_minute(plan), "人数大于窗口分钟数时，同一分钟应允许生成多个 NPC")
	_assert_true(_contains_varied_intervals(plan), "刷新间隔应不固定")
	for entry in plan:
		var minute := int(entry["minute"])
		var mode := str(entry["mode"])
		_assert_true(
			(minute >= 6 * 60 and minute < 8 * 60 and mode == "home_to_destination")
			or (minute >= 16 * 60 and minute < 18 * 60 and mode == "destination_to_home"),
			"学生刷新时间必须落在上下学窗口"
		)

	quit()


func _contains_varied_intervals(plan: Array) -> bool:
	var previous := -1
	var intervals := {}
	for entry in plan:
		var minute := int(entry["minute"])
		if previous >= 0:
			intervals[minute - previous] = true
		previous = minute
	return intervals.size() >= 2


func _contains_multiple_spawns_in_one_minute(plan: Array) -> bool:
	var counts := {}
	for entry in plan:
		var minute := int(entry["minute"])
		counts[minute] = int(counts.get(minute, 0)) + 1
		if int(counts[minute]) > 1:
			return true
	return false


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)
