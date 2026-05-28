extends Area2D

@export var spot_id := PrototypeConstants.SPOT_SCHOOL
@export var label := "学校门口"
@export var can_open_stall := true

var _last_interacting_player: Node2D = null

@onready var stall: Node2D = $Stall


func _ready() -> void:
	if can_open_stall:
		add_to_group("interactable")
	if stall != null:
		stall.visible = false


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
		SignalBus.price_panel_requested.emit(self)


func open_stall(price: int) -> void:
	stall.call("open", spot_id, price, _last_interacting_player)


func get_active_stall() -> Node:
	if stall.get("is_open"):
		return stall
	return null
