@tool
extends Node2D

@export var endpoint_id := ""
@export var marker_path := NodePath("EndpointMarker")
@export var visual_texture: Texture2D:
	set(value):
		visual_texture = value
		_apply_visual_texture()

@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	add_to_group("npc_endpoint")
	_apply_visual_texture()


func get_endpoint_position() -> Vector2:
	var marker := get_node_or_null(marker_path) as Node2D
	if marker != null:
		return marker.global_position
	return global_position


func _apply_visual_texture() -> void:
	var visual_node := get_node_or_null("Visual") as Sprite2D
	if visual_node != null:
		visual_node.texture = visual_texture
