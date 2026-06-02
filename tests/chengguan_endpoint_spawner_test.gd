extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")
const POLICE_STATION_TEXTURE := "res://assets/generated/sprites/locations/police_station_256x128.png"


func _ready() -> void:
	GameState.reset_game()
	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var police_station := town.get_node_or_null("PoliceStation") as Node2D
	_assert_true(police_station != null, "TownScene 应新增 PoliceStation 建筑 endpoint")
	if police_station == null:
		return
	_assert_true(police_station.is_in_group("npc_endpoint"), "PoliceStation 应复用 NPC endpoint 场景")
	_assert_equal(str(police_station.get("endpoint_id")), "police_station", "PoliceStation endpoint_id 应为 police_station")
	_assert_equal(str(police_station.get("endpoint_type")), "police", "PoliceStation endpoint_type 应为 police")
	_assert_true(not bool(police_station.get("can_spawn_customer")), "普通随机 NPC 不应从警察局生成")
	var visual := police_station.get_node_or_null("Visual") as Sprite2D
	_assert_true(visual != null and visual.texture != null, "PoliceStation 应显示警察局美术素材")
	if visual != null and visual.texture != null:
		_assert_equal(visual.texture.resource_path, POLICE_STATION_TEXTURE, "PoliceStation 应使用新增警察局素材")

	var spawner := town.get_node_or_null("ChengguanSpawner")
	_assert_true(spawner != null, "TownScene 应保留 ChengguanSpawner")
	if spawner == null:
		return
	_assert_true(town.get_node_or_null("MapLayers/PoliceRoadConnectionLayer") == null, "警察局 NPC 应直接复用主 RoadLayer，不应新增专用连接道路层")
	var road_navigator := town.get_node_or_null("RoadNavigator")
	_assert_true(road_navigator != null, "TownScene 应保留 RoadNavigator")
	if road_navigator != null:
		_assert_true(not ("extra_road_layer_paths" in road_navigator), "RoadNavigator 不应再依赖额外道路层配置")
	_assert_equal(int(spawner.get("morning_daily_count")), 10, "城管上午应随机刷新 10 个")
	_assert_equal(int(spawner.get("afternoon_daily_count")), 10, "城管下午应随机刷新 10 个")

	var spawn_plan: Array = spawner.call("debug_get_spawn_plan")
	_assert_equal(spawn_plan.size(), 20, "城管每日刷新计划应包含上午 10 个和下午 10 个")
	_assert_equal(_count_entries_in_window(spawn_plan, int(spawner.get("morning_start_minute")), int(spawner.get("morning_end_minute"))), 10, "上午刷新计划数量应为 10")
	_assert_equal(_count_entries_in_window(spawn_plan, int(spawner.get("afternoon_start_minute")), int(spawner.get("afternoon_end_minute"))), 10, "下午刷新计划数量应为 10")
	_assert_true(_is_sorted_by_minute(spawn_plan), "城管刷新计划应按游戏分钟排序")

	var route: Dictionary = spawner.call("build_chengguan_route")
	_assert_true(not route.is_empty(), "城管应能通过 NPC endpoint 和 RoadNavigator 生成巡逻路线")
	if route.is_empty():
		return
	var police_position: Vector2 = police_station.call("get_endpoint_position")
	_assert_true(_is_near_position(route["start"], police_position), "城管路线应从警察局门口附近开始")
	_assert_true(_is_near_position(route["return_end"], police_position), "城管返程路线应回到警察局门口附近")
	_assert_true(_is_near_position(route["start"], police_position, 192.0), "警察局门口应能吸附到主 RoadLayer 可走道路")
	_assert_true(_is_near_position(route["return_end"], police_position, 192.0), "警察局返程终点应吸附到主 RoadLayer 可走道路")
	_assert_true(route["destination_endpoint"] != police_station, "城管出巡终点不应仍是警察局")

	var before_count := _chengguan_count(town)
	spawner.call("_spawn_chengguan")
	await get_tree().process_frame
	var chengguan_nodes := town.find_children("Chengguan", "CharacterBody2D", true, false)
	_assert_equal(chengguan_nodes.size(), before_count + 1, "手动触发刷新后应在 TownScene 下生成一个城管")
	var chengguan := chengguan_nodes.back() as Node2D
	_assert_true(_is_near_position(chengguan.global_position, police_position), "城管生成时应直接出现在警察局门口，不能先在默认点闪现")
	_assert_true((chengguan.get("route_points") as Array).size() >= 1, "城管应带有出巡路线点")
	_assert_true((chengguan.get("_return_route_points") as Array).size() >= 1, "城管应带有返程路线点")

	get_tree().quit()


func _count_entries_in_window(plan: Array, start_minute: int, end_minute: int) -> int:
	var count := 0
	for entry in plan:
		var minute := int(entry["minute"])
		if minute >= start_minute and minute < end_minute:
			count += 1
	return count


func _is_sorted_by_minute(plan: Array) -> bool:
	var previous := -1
	for entry in plan:
		var minute := int(entry["minute"])
		if minute < previous:
			return false
		previous = minute
	return true


func _chengguan_count(town: Node) -> int:
	return town.find_children("Chengguan", "CharacterBody2D", true, false).size()


func _is_near_position(position: Vector2, expected: Vector2, max_distance := 192.0) -> bool:
	return position.distance_to(expected) <= max_distance


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
