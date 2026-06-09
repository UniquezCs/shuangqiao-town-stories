extends Area2D

@export var collision_shape_path := NodePath("CollisionShape2D")


func _ready() -> void:
	add_to_group("camera_bounds")


func apply_to_camera(camera: Camera2D) -> void:
	if camera == null:
		return
	var rect := get_bounds_rect()
	if rect.size == Vector2.ZERO:
		return
	camera.limit_left = int(floorf(rect.position.x))
	camera.limit_top = int(floorf(rect.position.y))
	camera.limit_right = int(ceilf(rect.position.x + rect.size.x))
	camera.limit_bottom = int(ceilf(rect.position.y + rect.size.y))


func get_bounds_rect() -> Rect2:
	var collision_shape := get_node_or_null(collision_shape_path) as CollisionShape2D
	if collision_shape == null:
		return Rect2()
	var rectangle := collision_shape.shape as RectangleShape2D
	if rectangle == null:
		return Rect2()

	var shape_scale := Vector2(
		absf(collision_shape.global_scale.x),
		absf(collision_shape.global_scale.y)
	)
	var size := rectangle.size * shape_scale
	return Rect2(collision_shape.global_position - size * 0.5, size)
