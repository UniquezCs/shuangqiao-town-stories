extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const TOWN_SCENE := preload("res://scenes/town_scene.tscn")
const CAMERA_BOUNDS_SCRIPT := "res://scripts/world/camera_bounds.gd"


func _ready() -> void:
	_assert_true(ResourceLoader.exists(CAMERA_BOUNDS_SCRIPT), "应新增相机范围脚本")

	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	var bounds := town.get_node_or_null("CameraBounds") as Area2D
	_assert_true(bounds != null, "TownScene 应包含 CameraBounds 节点")
	_assert_equal(_script_path(bounds), CAMERA_BOUNDS_SCRIPT, "CameraBounds 应挂载相机范围脚本")
	_assert_true(bounds.is_in_group("camera_bounds"), "CameraBounds 应加入 camera_bounds 分组，便于 Main 自动发现")
	_assert_true(_has_rectangle_shape(bounds), "CameraBounds 应使用 RectangleShape2D 定义镜头范围")
	_assert_true(bounds.collision_layer != 0, "CameraBounds 应保留非零碰撞层，避免 Godot 节点配置警告")
	_assert_equal(bounds.collision_mask, 0, "CameraBounds 不应主动扫描物理对象")
	_assert_equal(bounds.monitoring, false, "CameraBounds 只用于相机范围，不应监视物理对象")
	_assert_equal(bounds.monitorable, false, "CameraBounds 只用于相机范围，不应被物理区域监视")

	var test_camera := Camera2D.new()
	add_child(test_camera)
	bounds.call("apply_to_camera", test_camera)
	var rect := bounds.call("get_bounds_rect") as Rect2
	_assert_camera_matches_rect(test_camera, rect, "CameraBounds 应能把矩形范围写入 Camera2D limit")

	SaveManager.set_pending_load({
		"game_state": {
			"current_scene": PrototypeConstants.SCENE_TOWN,
			"current_game_minute": PrototypeConstants.DAY_START_MINUTE,
		},
		"inventory": {},
		"hotbar": {},
	})
	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().physics_frame

	var player_camera := main.get_node("Player/Camera2D") as Camera2D
	var loaded_bounds := main.get_node_or_null("WorldRoot/TownScene/CameraBounds")
	_assert_true(loaded_bounds != null, "Main 启动到城镇后应加载 CameraBounds")
	if loaded_bounds != null:
		var loaded_rect := loaded_bounds.call("get_bounds_rect") as Rect2
		_assert_camera_matches_rect(player_camera, loaded_rect, "Main 加载城镇后应自动应用 CameraBounds")

	town.queue_free()
	main.queue_free()
	test_camera.queue_free()
	PopulationFlow.reset_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _assert_camera_matches_rect(camera: Camera2D, rect: Rect2, message: String) -> void:
	_assert_equal(camera.limit_left, int(floorf(rect.position.x)), "%s：left" % message)
	_assert_equal(camera.limit_top, int(floorf(rect.position.y)), "%s：top" % message)
	_assert_equal(camera.limit_right, int(ceilf(rect.position.x + rect.size.x)), "%s：right" % message)
	_assert_equal(camera.limit_bottom, int(ceilf(rect.position.y + rect.size.y)), "%s：bottom" % message)


func _has_rectangle_shape(bounds: Area2D) -> bool:
	var collision_shape := bounds.get_node_or_null("CollisionShape2D") as CollisionShape2D
	return collision_shape != null and collision_shape.shape is RectangleShape2D


func _script_path(node: Node) -> String:
	var script := node.get_script() as Script
	if script == null:
		return ""
	return script.resource_path


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
