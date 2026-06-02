extends Node2D

@export var radius := 24.0
@export var ring_width := 4.0

var remaining_fraction := 1.0


func set_icon_texture(texture: Texture2D) -> void:
	var icon := get_node_or_null("Icon") as Sprite2D
	if icon == null:
		icon = Sprite2D.new()
		icon.name = "Icon"
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		icon.scale = Vector2(0.75, 0.75)
		add_child(icon)
	icon.texture = texture


func set_remaining_fraction(value: float) -> void:
	remaining_fraction = clampf(value, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(0.05, 0.05, 0.05, 0.55), ring_width, true)
	draw_arc(
		Vector2.ZERO,
		radius,
		-PI * 0.5,
		-PI * 0.5 + TAU * remaining_fraction,
		64,
		Color(1.0, 0.86, 0.25, 1.0),
		ring_width,
		true
	)
