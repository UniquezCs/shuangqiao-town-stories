extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")


func _ready() -> void:
	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	var checked_count := 0
	for node in get_tree().get_nodes_in_group("npc_endpoint"):
		if not node is Node2D or node.get_parent() != town:
			continue
		checked_count += 1
		var visual := node.get_node_or_null("Visual") as Sprite2D
		_assert_true(visual != null, "%s 应保留 Visual 子节点" % node.name)
		_assert_true(visual.texture != null, "%s 的 Visual 应保留地图显示纹理" % node.name)
		_assert_true(visual.visible, "%s 的 Visual 应可见" % node.name)
		_assert_true(visual.is_visible_in_tree(), "%s 的 Visual 应在场景树中可见" % node.name)

	_assert_true(checked_count >= 3, "TownScene 应至少保留学校、工厂和住宅 NPC endpoint")

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
