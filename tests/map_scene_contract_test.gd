extends Node

const SCENE_PATHS := [
	"res://scenes/home_scene.tscn",
	"res://scenes/house_scene.tscn",
	"res://scenes/town_scene.tscn",
	"res://scenes/back_mountain_scene.tscn",
]


func _ready() -> void:
	for scene_path in SCENE_PATHS:
		await _assert_map_scene_contract(scene_path)
	get_tree().quit()


func _assert_map_scene_contract(scene_path: String) -> void:
	var packed := load(scene_path) as PackedScene
	_assert_true(packed != null, "地图场景应可加载：%s" % scene_path)
	var scene := packed.instantiate()
	add_child(scene)
	await get_tree().process_frame

	_assert_true(scene is Node2D, "地图场景根节点应是 Node2D：%s" % scene_path)
	_assert_true(scene.get_node_or_null("Spawns/default") is Marker2D, "地图场景应提供 Spawns/default 出生点：%s" % scene_path)
	var bounds := scene.get_node_or_null("CameraBounds") as StaticBody2D
	_assert_true(bounds != null, "地图场景应提供 CameraBounds：%s" % scene_path)
	_assert_true(bounds.is_in_group("camera_bounds"), "CameraBounds 应加入 camera_bounds 分组：%s" % scene_path)

	for child in scene.get_children():
		if child is Area2D and child.has_method("get_prompt"):
			var collision := (child as Area2D).get_node_or_null("CollisionShape2D") as CollisionShape2D
			_assert_true(collision != null and collision.shape != null, "出口/交互 Area2D 应配置碰撞形状：%s/%s" % [scene_path, child.name])

	scene.queue_free()
	await get_tree().process_frame


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
