extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")


func _ready() -> void:
	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	var checked_count := 0
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if not node is Node2D or not town.is_ancestor_of(node):
			continue
		checked_count += 1
		_assert_true(node is Area2D, "%s 应作为 Area2D 建筑节点，便于统一交互区域" % node.name)
		var visual := node.get_node_or_null("Visual") as Sprite2D
		_assert_true(visual != null, "%s 应保留 Visual 子节点" % node.name)
		_assert_true(visual.texture != null, "%s 的 Visual 应保留地图显示纹理" % node.name)
		_assert_true(visual.visible, "%s 的 Visual 应可见" % node.name)
		_assert_true(visual.is_visible_in_tree(), "%s 的 Visual 应在场景树中可见" % node.name)
		_assert_true(node.get_node_or_null("EndpointMarker") is Marker2D, "%s 应保留 EndpointMarker 作为 NPC 出现/消失坐标" % node.name)
		_assert_true(_has_collision_shape(node, "CollisionShape2D"), "%s 应提供 CollisionShape2D 作为可互动区域" % node.name)
		_assert_true(node.get_node_or_null("StaticBody2D") is StaticBody2D, "%s 应提供 StaticBody2D 作为实体碰撞区" % node.name)
		_assert_true(_has_collision_shape(node, "StaticBody2D/CollisionShape2D"), "%s 的 StaticBody2D 下应有独立 CollisionShape2D" % node.name)

	_assert_true(checked_count >= 3, "TownScene 应至少保留学校、工厂和住宅 NPC endpoint")
	var seed_shop := town.get_node_or_null("Buildings/SeedShop")
	_assert_true(seed_shop is Area2D, "SeedShop 应纳入建筑范围并保持 Area2D 根节点")
	if seed_shop is Area2D:
		_assert_true(seed_shop.is_in_group("building"), "SeedShop 应加入 building 分组")
		_assert_true(seed_shop.is_in_group("npc_endpoint"), "SeedShop 根节点应作为 NPC endpoint 参与建筑点位系统")
		_assert_equal(_script_path(seed_shop), "res://scripts/world/npc_endpoint.gd", "SeedShop 根节点应复用 NpcEndpoint 场景脚本")
		_assert_true(seed_shop.get_node_or_null("Visual") is Sprite2D, "SeedShop 应保留 Visual 子节点")
		_assert_true(seed_shop.get_node_or_null("EndpointMarker") is Marker2D, "SeedShop 应新增 EndpointMarker，便于作为建筑点位")
		_assert_true(seed_shop.has_method("get_endpoint_position"), "SeedShop 应提供建筑门口坐标接口")
		_assert_true(_has_collision_shape(seed_shop, "CollisionShape2D"), "SeedShop 应保留 CollisionShape2D 作为可互动区域")
		_assert_true(seed_shop.get_node_or_null("StaticBody2D") is StaticBody2D, "SeedShop 应新增 StaticBody2D 作为实体碰撞区")
		_assert_true(_has_collision_shape(seed_shop, "StaticBody2D/CollisionShape2D"), "SeedShop 的 StaticBody2D 下应有独立 CollisionShape2D")
		var shop_interaction := seed_shop.get_node_or_null("ShopInteraction")
		_assert_true(shop_interaction is Area2D, "SeedShop 应通过 ShopInteraction 子节点组合商店交互能力")
		if shop_interaction is Area2D:
			_assert_true(shop_interaction.is_in_group("interactable"), "ShopInteraction 应作为玩家可交互区域")
			_assert_equal(_script_path(shop_interaction), "res://scripts/world/seed_shop.gd", "ShopInteraction 应挂载 SeedShop 商店脚本")
			_assert_true(shop_interaction.has_method("buy_seed"), "ShopInteraction 应提供买种子能力")
			_assert_true(shop_interaction.has_method("buy_apple"), "ShopInteraction 应提供买苹果能力")
			_assert_true(_has_collision_shape(shop_interaction, "CollisionShape2D"), "ShopInteraction 应提供独立交互碰撞区")

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _has_collision_shape(parent: Node, path: String) -> bool:
	var collision_shape := parent.get_node_or_null(path) as CollisionShape2D
	return collision_shape != null and collision_shape.shape != null


func _script_path(node: Node) -> String:
	var script := node.get_script() as Script
	if script == null:
		return ""
	return script.resource_path
