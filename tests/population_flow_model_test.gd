extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")


func _ready() -> void:
	PopulationFlow.reset_for_tests()
	GameState.set_game_time_minute(PrototypeConstants.DAY_START_MINUTE)
	PopulationFlow.initialize_from_scene(TOWN_SCENE, true)
	var day_start_events: Array = PopulationFlow.get_recent_flow_events(1, PrototypeConstants.DAY_START_MINUTE)
	_assert_true(day_start_events.size() > 0, "PopulationFlow 在游戏开局 06:00 初始化时应立即生成人流，而不是等到 06:10")

	PopulationFlow.reset_for_tests()
	GameState.set_game_time_minute(0)
	PopulationFlow.initialize_from_scene(TOWN_SCENE, true)
	_assert_true(PopulationFlow.is_background_initialized(), "PopulationFlow 应能不依赖真实 TownScene 从游戏开始运行")
	GameState.set_game_time_minute(7 * 60)
	var background_events: Array = PopulationFlow.get_recent_flow_events(10, 7 * 60)
	_assert_true(background_events.size() > 0, "玩家不在城镇时，后台人流也应随游戏时间产生事件")

	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	PopulationFlow.reset_for_tests()
	PopulationFlow.initialize_for_world(town, true)

	var population_config: Dictionary = ConfigLoader.get_population_config()
	var expected_total := int(population_config.get("total_population", 1000))
	var age_distribution: Dictionary = population_config.get("age_distribution", {})
	var snapshot: Dictionary = PopulationFlow.get_population_snapshot()
	var debug_summary: Dictionary = PopulationFlow.get_population_debug_summary()
	_assert_equal(_total_population(snapshot), expected_total, "初始化后镇上总人口应来自 population.json")
	_assert_equal(int(debug_summary.get("total_population", 0)), expected_total, "PopulationFlow 调试摘要应暴露镇上总人口")
	_assert_true(int(debug_summary.get("endpoint_count", 0)) > 0, "PopulationFlow 调试摘要应暴露 endpoint 数量")
	_assert_true((debug_summary.get("by_type", {}) as Dictionary).has("residential"), "PopulationFlow 调试摘要应按 endpoint 类型分组")
	_assert_equal(_group_total(snapshot, PrototypeConstants.CUSTOMER_AGE_YOUTH), int(round(expected_total * float(age_distribution.get(PrototypeConstants.CUSTOMER_AGE_YOUTH, 0.0)))), "少年人口应符合配置比例")
	_assert_equal(_group_total(snapshot, PrototypeConstants.CUSTOMER_AGE_MIDDLE), int(round(expected_total * float(age_distribution.get(PrototypeConstants.CUSTOMER_AGE_MIDDLE, 0.0)))), "中年人口应符合配置比例")
	_assert_equal(_group_total(snapshot, PrototypeConstants.CUSTOMER_AGE_ELDER), int(round(expected_total * float(age_distribution.get(PrototypeConstants.CUSTOMER_AGE_ELDER, 0.0)))), "老年人口应符合配置比例")
	_assert_true(_only_residential_has_population(snapshot), "开局人口应只分配在住宅建筑内")
	_assert_true(ConfigLoader.get_flow_preferences_config().has("time_curves"), "人流偏好配置应提供目标吸引力时间曲线")

	PopulationFlow.reset_for_tests()
	PopulationFlow.initialize_for_world(town, true)
	var early_school_summary: Dictionary = PopulationFlow.run_flow_tick(6 * 60)
	PopulationFlow.reset_for_tests()
	PopulationFlow.initialize_for_world(town, true)
	var peak_school_summary: Dictionary = PopulationFlow.run_flow_tick(7 * 60 + 10)
	_assert_true(
		_flow_share_to_type(early_school_summary, "school", PrototypeConstants.CUSTOMER_AGE_YOUTH) < 0.12,
		"06:00 少年不应大量集中流向学校"
	)
	_assert_true(
		_flow_share_to_type(peak_school_summary, "school", PrototypeConstants.CUSTOMER_AGE_YOUTH) > _flow_share_to_type(early_school_summary, "school", PrototypeConstants.CUSTOMER_AGE_YOUTH) * 2.0,
		"7 点多学校吸引力应明显高于 06:00"
	)

	var before_total := _total_population(snapshot)
	var morning_summary: Dictionary = PopulationFlow.run_flow_tick(7 * 60)
	var after_morning: Dictionary = PopulationFlow.get_population_snapshot()
	_assert_equal(_total_population(after_morning), before_total, "人流 tick 后总人口应守恒")
	_assert_true(int(morning_summary.get("visible_total", 0)) > 0, "早高峰应产生可见 NPC 抽样事件")
	_assert_true(_flow_count_to_type(morning_summary, "school", PrototypeConstants.CUSTOMER_AGE_YOUTH) > 0, "早高峰少年应流向学校")
	_assert_true(_flow_count_to_type(morning_summary, "factory", PrototypeConstants.CUSTOMER_AGE_MIDDLE) > 0, "早高峰中年应流向工厂")

	PopulationFlow.set_weather_for_tests("rain")
	var rain_summary: Dictionary = PopulationFlow.run_flow_tick(12 * 60)
	_assert_true(float(rain_summary.get("modifier_debug", {}).get("residential_weather", 0.0)) > 1.0, "雨天住宅留存权重应上升")
	_assert_true(float(rain_summary.get("modifier_debug", {}).get("public_weather", 1.0)) < 1.0, "雨天公共建筑权重应下降")

	get_tree().quit()


func _total_population(snapshot: Dictionary) -> int:
	var total := 0
	for endpoint_id in snapshot.keys():
		total += _population_total(snapshot[endpoint_id].get("population", {}))
	return total


func _group_total(snapshot: Dictionary, group: String) -> int:
	var total := 0
	for endpoint_id in snapshot.keys():
		total += int(snapshot[endpoint_id].get("population", {}).get(group, 0))
	return total


func _only_residential_has_population(snapshot: Dictionary) -> bool:
	for endpoint_id in snapshot.keys():
		var entry: Dictionary = snapshot[endpoint_id]
		if _population_total(entry.get("population", {})) <= 0:
			continue
		if str(entry.get("endpoint_type", "")) != "residential":
			return false
	return true


func _population_total(population: Dictionary) -> int:
	return int(population.get(PrototypeConstants.CUSTOMER_AGE_YOUTH, 0)) + int(population.get(PrototypeConstants.CUSTOMER_AGE_MIDDLE, 0)) + int(population.get(PrototypeConstants.CUSTOMER_AGE_ELDER, 0))


func _flow_count_to_type(summary: Dictionary, target_type: String, age_group: String) -> int:
	var total := 0
	for event in summary.get("events", []):
		if str(event.get("target_type", "")) == target_type and str(event.get("age_group", "")) == age_group:
			total += int(event.get("count", 0))
	return total


func _flow_count_for_age(summary: Dictionary, age_group: String) -> int:
	var total := 0
	for event in summary.get("events", []):
		if str(event.get("age_group", "")) == age_group:
			total += int(event.get("count", 0))
	return total


func _flow_share_to_type(summary: Dictionary, target_type: String, age_group: String) -> float:
	var age_total := _flow_count_for_age(summary, age_group)
	if age_total <= 0:
		return 0.0
	return float(_flow_count_to_type(summary, target_type, age_group)) / float(age_total)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
