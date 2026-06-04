extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")


func _ready() -> void:
	PopulationFlow.reset_for_tests()
	PopulationFlow.initialize_from_scene(TOWN_SCENE, true)
	var background_summary: Dictionary = PopulationFlow.run_flow_tick(7 * 60)
	_assert_true(int(background_summary.get("visible_total", 0)) > 0, "后台人流应能在玩家进城前产生可见抽样事件")
	GameState.set_game_time_minute(7 * 60 + 5)

	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame
	await get_tree().process_frame

	var spawner := town.get_node_or_null("NpcRouteSpawners/PopulationFlowSpawner")
	_assert_true(spawner != null, "TownScene 应接入 PopulationFlowSpawner")
	_assert_true(PopulationFlow.is_initialized_for_world(town), "TownScene ready 后应初始化 PopulationFlow")
	var existing_customers := _customer_nodes(town)
	_assert_true(existing_customers.size() > 0, "玩家进入城镇时，应从后台正在进行的人流中恢复路上的可见 NPC")
	_assert_true(_has_customer_not_at_any_endpoint(town, existing_customers), "恢复的 NPC 应已经在路上，而不是全部从建筑门口重新出现")
	var existing_customer_count := existing_customers.size()
	var existing_customer_ids := _customer_instance_ids(existing_customers)

	var pair := _endpoint_pair_with_route(town, "residential", "school")
	var residential: Node2D = null
	var school: Node2D = null
	if pair.size() >= 2:
		residential = pair[0] as Node2D
		school = pair[1] as Node2D
	_assert_true(residential != null and school != null, "测试需要住宅与学校 endpoint")
	if residential == null or school == null:
		return

	var event := {
		"source": residential,
		"target": school,
		"source_id": str(residential.get("endpoint_id")),
		"target_id": str(school.get("endpoint_id")),
		"source_type": "residential",
		"target_type": "school",
		"age_group": PrototypeConstants.CUSTOMER_AGE_YOUTH,
		"count": 12,
		"visible_count": 2,
		"minute": 7 * 60,
	}
	spawner.call("_on_flow_event_created", event)
	await get_tree().process_frame

	var customers := _customer_nodes(town)
	_assert_equal(customers.size(), existing_customer_count, "PopulationFlowSpawner 收到 10 分钟 tick 的事件后不应瞬间生成新增 NPC")
	_assert_equal(int(spawner.call("debug_pending_spawn_count")), 2, "PopulationFlowSpawner 应把可见 NPC 分散排入接下来 10 分钟的队列")
	spawner.call("debug_spawn_next_pending")
	await get_tree().process_frame
	customers = _customer_nodes(town)
	_assert_true(customers.size() >= existing_customer_count + 1, "PopulationFlowSpawner 应能按队列逐步生成可见 Customer")
	var customer := _first_new_customer(customers, existing_customer_ids)
	_assert_true(customer != null, "PopulationFlowSpawner 应能生成新的 Customer 节点")
	if customer == null:
		return
	_assert_equal(str(customer.get("age_group")), PrototypeConstants.CUSTOMER_AGE_YOUTH, "人流生成的 Customer 应带上年龄组")
	_assert_true(customer.global_position.distance_to(residential.call("get_endpoint_position")) <= 192.0, "Customer 应从 source endpoint 附近出现")

	get_tree().quit()


func _endpoint_by_type(town: Node, endpoint_type: String) -> Node2D:
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if node is Node2D and town.is_ancestor_of(node) and str(node.call("get_endpoint_type")) == endpoint_type:
			return node
	return null


func _endpoint_pair_with_route(town: Node, source_type: String, target_type: String) -> Array:
	var navigator := town.get_node_or_null("RoadNavigator")
	if navigator == null or not navigator.has_method("find_randomized_path"):
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for source in _endpoints_by_type(town, source_type):
		for target in _endpoints_by_type(town, target_type):
			var path: Array = navigator.call(
				"find_randomized_path",
				source.call("get_endpoint_position"),
				target.call("get_endpoint_position"),
				rng
			)
			if path.size() >= 2:
				return [source, target]
	return []


func _endpoints_by_type(town: Node, endpoint_type: String) -> Array[Node2D]:
	var endpoints: Array[Node2D] = []
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if node is Node2D and town.is_ancestor_of(node) and str(node.call("get_endpoint_type")) == endpoint_type:
			endpoints.append(node)
	return endpoints


func _has_customer_not_at_any_endpoint(town: Node, customers: Array) -> bool:
	var endpoint_positions: Array[Vector2] = []
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if node is Node2D and town.is_ancestor_of(node):
			var endpoint := node as Node2D
			if endpoint.has_method("get_endpoint_position"):
				endpoint_positions.append(endpoint.call("get_endpoint_position"))
			else:
				endpoint_positions.append(endpoint.global_position)
	for customer in customers:
		var customer_node := customer as Node2D
		if customer_node == null:
			continue
		var near_endpoint := false
		for position in endpoint_positions:
			if customer_node.global_position.distance_to(position) <= 96.0:
				near_endpoint = true
				break
		if not near_endpoint:
			return true
	return false


func _customer_nodes(town: Node) -> Array:
	var customers := []
	for node in town.find_children("*", "CharacterBody2D", true, false):
		var script: Resource = (node as Node).get_script() as Resource
		if script != null and str(script.resource_path) == "res://scripts/world/customer.gd":
			customers.append(node)
	return customers


func _customer_instance_ids(customers: Array) -> Dictionary:
	var result := {}
	for customer in customers:
		if customer is Node:
			result[(customer as Node).get_instance_id()] = true
	return result


func _first_new_customer(customers: Array, existing_ids: Dictionary) -> Node2D:
	for customer in customers:
		if customer is Node2D and not existing_ids.has((customer as Node).get_instance_id()):
			return customer
	return null


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
