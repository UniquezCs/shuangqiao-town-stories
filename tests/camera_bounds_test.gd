extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HOME_SCENE := preload("res://scenes/home_scene.tscn")
const TOWN_SCENE := preload("res://scenes/town_scene.tscn")
const BACK_MOUNTAIN_SCENE := preload("res://scenes/back_mountain_scene.tscn")
const CAMERA_BOUNDS_SCRIPT := "res://scripts/world/camera_bounds.gd"


func _ready() -> void:
	_assert_true(ResourceLoader.exists(CAMERA_BOUNDS_SCRIPT), "应新增相机范围脚本")

	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	var bounds := _assert_scene_has_camera_bounds(town, "TownScene")
	_assert_true(town.get_node_or_null("Wall") == null, "TownScene 不应再保留独立 Wall 节点，边界墙应由 CameraBounds 统一生成")
	_assert_boundary_walls_match_bounds(bounds, "TownScene")

	var test_camera := Camera2D.new()
	add_child(test_camera)
	bounds.call("apply_to_camera", test_camera)
	var rect := bounds.call("get_bounds_rect") as Rect2
	_assert_camera_matches_rect(test_camera, rect, "CameraBounds 应能把矩形范围写入 Camera2D limit")

	var home := HOME_SCENE.instantiate()
	add_child(home)
	await get_tree().process_frame
	_assert_scene_has_camera_bounds(home, "HomeScene")

	var back_mountain := BACK_MOUNTAIN_SCENE.instantiate()
	add_child(back_mountain)
	await get_tree().process_frame
	_assert_scene_has_camera_bounds(back_mountain, "BackMountainScene")

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
	home.queue_free()
	back_mountain.queue_free()
	main.queue_free()
	test_camera.queue_free()
	PopulationFlow.reset_for_tests()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit()


func _assert_scene_has_camera_bounds(scene: Node, scene_name: String) -> Area2D:
	var bounds := scene.get_node_or_null("CameraBounds") as Area2D
	_assert_true(bounds != null, "%s 应包含 CameraBounds 节点" % scene_name)
	if bounds == null:
		return null
	_assert_equal(_script_path(bounds), CAMERA_BOUNDS_SCRIPT, "%s 的 CameraBounds 应挂载相机范围脚本" % scene_name)
	_assert_true(bounds.is_in_group("camera_bounds"), "%s 的 CameraBounds 应加入 camera_bounds 分组，便于 Main 自动发现" % scene_name)
	_assert_true(_has_rectangle_shape(bounds), "%s 的 CameraBounds 应使用 RectangleShape2D 定义镜头范围" % scene_name)
	_assert_true(bounds.collision_layer != 0, "%s 的 CameraBounds 应保留非零碰撞层，避免 Godot 节点配置警告" % scene_name)
	_assert_equal(bounds.collision_mask, 0, "%s 的 CameraBounds 不应主动扫描物理对象" % scene_name)
	_assert_equal(bounds.monitoring, false, "%s 的 CameraBounds 只用于相机范围，不应监视物理对象" % scene_name)
	_assert_equal(bounds.monitorable, false, "%s 的 CameraBounds 只用于相机范围，不应被物理区域监视" % scene_name)
	return bounds


func _assert_boundary_walls_match_bounds(bounds: Area2D, scene_name: String) -> void:
	_assert_true(bool(bounds.get("create_boundary_walls")), "%s 的 CameraBounds 应启用边界墙生成" % scene_name)
	var walls := bounds.get_node_or_null("BoundaryWalls") as StaticBody2D
	_assert_true(walls != null, "%s 的 CameraBounds 应生成 BoundaryWalls" % scene_name)
	if walls == null:
		return
	_assert_equal(walls.collision_layer, 1, "%s 的 BoundaryWalls 应位于世界碰撞层" % scene_name)
	_assert_equal(walls.collision_mask, 0, "%s 的 BoundaryWalls 不需要主动扫描对象" % scene_name)

	var expected_names := ["TopWall", "RightWall", "BottomWall", "LeftWall"]
	for wall_name in expected_names:
		var collision_shape := walls.get_node_or_null(wall_name) as CollisionShape2D
		_assert_true(collision_shape != null, "%s 应生成 %s" % [scene_name, wall_name])
		if collision_shape != null:
			_assert_true(collision_shape.shape is SegmentShape2D, "%s/%s 应使用 SegmentShape2D" % [scene_name, wall_name])

	var local_rect := _get_local_bounds_rect(bounds)
	var left := local_rect.position.x
	var top := local_rect.position.y
	var right := local_rect.position.x + local_rect.size.x
	var bottom := local_rect.position.y + local_rect.size.y
	_assert_segment(walls, "TopWall", Vector2(left, top), Vector2(right, top), "%s TopWall 应贴合 CameraBounds 顶边" % scene_name)
	_assert_segment(walls, "RightWall", Vector2(right, top), Vector2(right, bottom), "%s RightWall 应贴合 CameraBounds 右边" % scene_name)
	_assert_segment(walls, "BottomWall", Vector2(right, bottom), Vector2(left, bottom), "%s BottomWall 应贴合 CameraBounds 底边" % scene_name)
	_assert_segment(walls, "LeftWall", Vector2(left, bottom), Vector2(left, top), "%s LeftWall 应贴合 CameraBounds 左边" % scene_name)


func _get_local_bounds_rect(bounds: Area2D) -> Rect2:
	var collision_shape := bounds.get_node_or_null("CollisionShape2D") as CollisionShape2D
	_assert_true(collision_shape != null, "CameraBounds 应有 CollisionShape2D")
	if collision_shape == null:
		return Rect2()
	var rectangle := collision_shape.shape as RectangleShape2D
	_assert_true(rectangle != null, "CameraBounds 的 CollisionShape2D 应使用 RectangleShape2D")
	if rectangle == null:
		return Rect2()
	var size := rectangle.size * Vector2(absf(collision_shape.scale.x), absf(collision_shape.scale.y))
	return Rect2(collision_shape.position - size * 0.5, size)


func _assert_segment(walls: StaticBody2D, wall_name: String, expected_a: Vector2, expected_b: Vector2, message: String) -> void:
	var collision_shape := walls.get_node_or_null(wall_name) as CollisionShape2D
	if collision_shape == null:
		return
	var segment := collision_shape.shape as SegmentShape2D
	if segment == null:
		return
	_assert_vector_close(segment.a, expected_a, "%s：a" % message)
	_assert_vector_close(segment.b, expected_b, "%s：b" % message)


func _assert_camera_matches_rect(camera: Camera2D, rect: Rect2, message: String) -> void:
	_assert_equal(camera.limit_left, int(floorf(rect.position.x)), "%s：left" % message)
	_assert_equal(camera.limit_top, int(floorf(rect.position.y)), "%s：top" % message)
	_assert_equal(camera.limit_right, int(ceilf(rect.position.x + rect.size.x)), "%s：right" % message)
	_assert_equal(camera.limit_bottom, int(ceilf(rect.position.y + rect.size.y)), "%s：bottom" % message)


func _assert_vector_close(actual: Vector2, expected: Vector2, message: String) -> void:
	_assert_true(actual.distance_to(expected) < 0.001, "%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])


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
