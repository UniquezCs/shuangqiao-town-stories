@tool
extends Polygon2D

@export var source_sprite_path := NodePath(""):
	set(value):
		source_sprite_path = value
		_refresh_deferred()
@export var force_opaque_white := true:
	set(value):
		force_opaque_white = value
		_refresh_deferred()
@export var sync_in_editor := true:
	set(value):
		sync_in_editor = value
		set_process(Engine.is_editor_hint() and sync_in_editor)


func _ready() -> void:
	refresh_occluder()
	call_deferred("refresh_occluder")
	set_process(Engine.is_editor_hint() and sync_in_editor)


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() and sync_in_editor:
		refresh_occluder()


func refresh_occluder() -> void:
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
	if is_inside_tree():
		call_deferred("refresh_occluder")


func _get_source_sprite() -> Sprite2D:
	if not source_sprite_path.is_empty():
		var configured_sprite := get_node_or_null(source_sprite_path) as Sprite2D
		if configured_sprite != null:
			return configured_sprite

	var tree := get_tree()
	if tree == null:
		return null

	var scene_root := tree.edited_scene_root if Engine.is_editor_hint() else owner
	if scene_root == null:
		scene_root = tree.current_scene
	if scene_root == null:
		return null

	for path in [
		NodePath("MapLayers/Visual"),
		NodePath("MapLayers/Sprite2D"),
	]:
		var map_sprite := scene_root.get_node_or_null(path) as Sprite2D
		if map_sprite != null:
			return map_sprite
	return null
