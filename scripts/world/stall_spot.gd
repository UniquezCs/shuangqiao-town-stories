extends Area2D

@export var spot_id := PrototypeConstants.SPOT_SCHOOL
@export var label := "学校门口"
@export var can_open_stall := true
@export var interaction_size := Vector2(1152, 255)
@export var interaction_offset := Vector2.ZERO

var _last_interacting_player: Node2D = null

@onready var stall: Node2D = $Stall
@onready var collision_shape: CollisionShape2D = $CollisionShape2D


func _ready() -> void:
	if can_open_stall:
		add_to_group("interactable")
	if stall != null:
		stall.visible = false
	_configure_interaction_shape()


func get_prompt() -> String:
	if not can_open_stall:
		return ""
	var typed_stall := stall as Node
	if typed_stall and typed_stall.get("is_open"):
		return "收摊"
	return "在%s摆摊" % label


func interact(player: Node) -> void:
	if not can_open_stall:
		return
	_last_interacting_player = player as Node2D
	if stall.get("is_open"):
		stall.call("close")
	else:
		SignalBus.stall_setup_requested.emit(self)


func open_stall(price: int) -> void:
	stall.call("open", spot_id, price, _last_interacting_player)


func open_stall_with_slots(prepared_slots: Array) -> bool:
	return bool(stall.call("open_with_slots", spot_id, prepared_slots, _last_interacting_player))


func get_active_stall() -> Node:
	if stall.get("is_open"):
		return stall
	return null


func _configure_interaction_shape() -> void:
	if collision_shape == null:
		return
	collision_shape.position = interaction_offset
	var rectangle := RectangleShape2D.new()
	collision_shape.shape = rectangle
	rectangle.size = interaction_size
