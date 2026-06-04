extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")
const PricePanel := preload("res://scripts/ui/price_panel.gd")


func _ready() -> void:
	var price_panel := PricePanel.new()
	add_child(price_panel)
	await get_tree().process_frame
	price_panel.open(2)
	_assert_true(not get_tree().paused, "打开定价面板时不应暂停游戏")
	price_panel.hide_panel()
	price_panel.queue_free()

	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var residential_endpoints := _endpoints_by_id(town, "residential")
	var school_endpoint := _endpoint_by_name(town, "SchoolSpot")
	var factory_endpoint := _endpoint_by_name(town, "FactorySpot")
	_assert_true(residential_endpoints.size() >= 2, "TownScene 应提供多个 residential endpoint 作为住宅出生点池")
	for endpoint in residential_endpoints + [school_endpoint, factory_endpoint]:
		_assert_true(endpoint.is_in_group("npc_endpoint"), "%s 应复用 NPC 出现/消失点场景" % endpoint.name)
		_assert_true(endpoint.has_method("get_endpoint_position"), "%s 应提供统一的 NPC 出现/消失坐标接口" % endpoint.name)
		_assert_equal(endpoint.get_node_or_null("CustomerSpawner"), null, "%s 只负责 NPC 点位，不应挂路线生成器" % endpoint.name)
	var route_spawners := town.get_node_or_null("NpcRouteSpawners")
	_assert_true(route_spawners != null, "TownScene 应集中提供 NpcRouteSpawners 容器")
	if route_spawners == null:
		return
	var random_spawner := route_spawners.get_node_or_null("TownRandomCustomerSpawner")
	var population_spawner := route_spawners.get_node_or_null("PopulationFlowSpawner")
	_assert_equal(route_spawners.get_node_or_null("StudentCommuteSpawner"), null, "学生固定通勤应迁移到 PopulationFlow，不再保留专用生成器")
	_assert_equal(route_spawners.get_node_or_null("WorkerCommuteSpawner"), null, "工人固定通勤应迁移到 PopulationFlow，不再保留专用生成器")
	_assert_true(random_spawner != null, "普通城镇行人随机生成器应集中放在 NpcRouteSpawners 下")
	_assert_true(population_spawner != null, "PopulationFlowSpawner 应集中放在 NpcRouteSpawners 下")
	if population_spawner == null:
		return

	var stall_spots := _town_stall_spots(town)
	_assert_true(stall_spots.size() >= 1, "StallAreaLayer 应从地图标识生成至少 1 片可摆摊区域")
	if stall_spots.is_empty():
		return
	for stall_spot in stall_spots:
		_assert_true(stall_spot.is_in_group("interactable"), "%s 应可交互" % stall_spot.name)
		_assert_true(stall_spot.is_in_group("player_stall_spot"), "%s 应被顾客系统识别" % stall_spot.name)
	if stall_spots.size() >= 2:
		var upper_stall_spot := stall_spots[0] as Node2D
		var lower_stall_spot := stall_spots[1] as Node2D
		_assert_true(lower_stall_spot.get_node("CollisionShape2D").global_position.y >= upper_stall_spot.get_node("CollisionShape2D").global_position.y, "较后的摆摊区域应不高于较前区域")

	var active_stall_spot := stall_spots.back() as Node2D
	var stall := active_stall_spot.get_node("Stall") as Node2D
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 5)
	stall.global_position = Vector2.ZERO
	_assert_true(stall.call("open", str(active_stall_spot.get("spot_id")), 2), "应能打开玩家摊位")
	var influence_area := stall.get_node_or_null("InfluenceArea") as Area2D
	_assert_true(influence_area != null, "开摊后应生成一个 Area2D 影响范围")
	if influence_area == null:
		return
	var influence_shape := influence_area.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_assert_true(influence_shape != null and influence_shape.shape is CircleShape2D, "影响范围应使用圆形 CollisionShape2D")

	var residence_positions := _endpoint_positions(residential_endpoints)
	var destination_position: Vector2 = school_endpoint.call("get_endpoint_position")
	if random_spawner != null:
		var random_route: Dictionary = random_spawner.call("build_random_route")
		_assert_true(not random_route.is_empty(), "普通城镇行人应能从建筑 endpoint 池生成随机路线")
		_assert_true(random_route["start_endpoint"] != random_route["end_endpoint"], "随机行人路线的起点和终点必须是不同建筑")
		_assert_true(random_route["start"] != random_route["end"], "随机行人路线的起点和终点坐标必须不同")
		_assert_true(random_spawner.call("_available_endpoints").size() >= 6, "随机行人应能使用多个城镇建筑 endpoint")
	var event := {
		"source": residential_endpoints.front(),
		"target": school_endpoint,
		"source_id": "residential",
		"target_id": str(school_endpoint.get("endpoint_id")),
		"source_type": "residential",
		"target_type": "school",
		"age_group": PrototypeConstants.CUSTOMER_AGE_YOUTH,
		"count": 10,
		"visible_count": 1,
		"minute": 7 * 60,
	}
	population_spawner.call("_spawn_customer_for_event", event, residential_endpoints.front(), school_endpoint)
	await get_tree().process_frame

	var customers := find_children("Customer", "CharacterBody2D", true, false)
	_assert_equal(customers.size(), 1, "应该生成 1 个顾客")
	_assert_equal(customers[0].get_parent(), town, "顾客必须挂在 TownScene 下，切回家时才能随 TownScene 销毁")
	_assert_true(_is_near_any_position(customers[0].get("_tree_entered_position"), residence_positions), "顾客进入场景树时就应在住宅区附近道路点，不能先显示在默认位置再瞬移")
	_assert_equal(customers[0].call("_active_stall"), null, "顾客进入影响范围前不应考虑摊位")
	influence_area.body_entered.emit(customers[0])
	_assert_equal(customers[0].call("_active_stall"), stall, "顾客进入影响范围后才应考虑摊位")

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _town_stall_spots(town: Node) -> Array:
	var spots := []
	for node in get_tree().get_nodes_in_group("player_stall_spot"):
		if node is Node2D and _node_belongs_to_world(node, town):
			spots.append(node)
	spots.sort_custom(func(a: Node, b: Node) -> bool:
		return str(a.get("spot_id")) < str(b.get("spot_id"))
	)
	return spots


func _endpoints_by_id(town: Node, endpoint_id: String) -> Array:
	var endpoints := []
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if node is Node2D and _node_belongs_to_world(node, town) and str(node.get("endpoint_id")) == endpoint_id:
			endpoints.append(node)
	return endpoints


func _endpoint_by_name(town: Node, node_name: String) -> Node2D:
	var direct := town.get_node_or_null(node_name) as Node2D
	if direct != null:
		return direct
	return town.get_node_or_null("Buildings/%s" % node_name) as Node2D


func _node_belongs_to_world(node: Node, world: Node) -> bool:
	return world != null and (node == world or world.is_ancestor_of(node))


func _endpoint_positions(endpoints: Array) -> Array:
	var positions := []
	for endpoint in endpoints:
		positions.append(endpoint.call("get_endpoint_position"))
	return positions


func _is_near_any_position(position: Vector2, positions: Array, max_distance := 192.0) -> bool:
	for expected in positions:
		if _is_near_position(position, expected, max_distance):
			return true
	return false


func _is_near_position(position: Vector2, expected: Vector2, max_distance := 192.0) -> bool:
	return position.distance_to(expected) <= max_distance
