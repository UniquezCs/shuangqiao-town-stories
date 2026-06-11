extends Polygon2D

@export var source_sprite_path := NodePath("")
@export var force_opaque_white := true
@export var sync_in_editor := false


func _ready() -> void:
	if Engine.is_editor_hint():
		return
	refresh_occluder()
	call_deferred("refresh_occluder")


func _process(_delta: float) -> void:
	if not Engine.is_editor_hint() and sync_in_editor:
		refresh_occluder()


func refresh_occluder() -> void:
	if Engine.is_editor_hint():
		return
	var source_sprite := _get_source_sprite()
	if source_sprite == null or source_sprite.texture == null:
		return

	texture = source_sprite.texture
	texture_filter = source_sprite.texture_filter
	if force_opaque_white:
		color = Color.WHITE

	var next_uv := PackedVector2Array()
	for point in polygon:
		next_uv.append(_polygon_point_to_source_uv(source_sprite, point))
	uv = next_uv


func _polygon_point_to_source_uv(source_sprite: Sprite2D, polygon_point: Vector2) -> Vector2:
	var world_point := to_global(polygon_point)
	var sprite_local_point := source_sprite.to_local(world_point)
	return _sprite_local_to_texture_uv(source_sprite, sprite_local_point)


func _sprite_local_to_texture_uv(source_sprite: Sprite2D, sprite_local_point: Vector2) -> Vector2:
	var texture_size := source_sprite.texture.get_size()
	var region_position := Vector2.ZERO
	var draw_size := texture_size
	if source_sprite.region_enabled:
		region_position = source_sprite.region_rect.position
		draw_size = source_sprite.region_rect.size

	var draw_origin := source_sprite.offset
	if source_sprite.centered:
		draw_origin -= draw_size * 0.5

	var next_uv := sprite_local_point - draw_origin
	if source_sprite.flip_h:
		next_uv.x = draw_size.x - next_uv.x
	if source_sprite.flip_v:
		next_uv.y = draw_size.y - next_uv.y
	return region_position + next_uv


func _refresh_deferred() -> void:
	if not Engine.is_editor_hint() and is_inside_tree():
		call_deferred("refresh_occluder")


func _get_source_sprite() -> Sprite2D:
	if Engine.is_editor_hint():
		return null
	if not is_inside_tree():
		return null
	var scene_root := owner
	if scene_root == null or not scene_root.is_inside_tree():
		return null
	var parent_node := get_parent()
	if parent_node == null or not parent_node.is_inside_tree():
		return null

	if not source_sprite_path.is_empty():
		var configured_sprite := get_node_or_null(source_sprite_path) as Sprite2D
		if configured_sprite != null:
			return configured_sprite

	for path in [
		NodePath("MapLayers/Visual"),
		NodePath("MapLayers/Sprite2D"),
	]:
		var map_sprite := scene_root.get_node_or_null(path) as Sprite2D
		if map_sprite != null:
			return map_sprite
	return null
