extends Area2D

@export var spot_id := PrototypeConstants.SPOT_SCHOOL
@export var label := "学校门口"

@onready var stall: Node2D = $Stall


func _ready() -> void:
	add_to_group("interactable")
	stall.visible = false


func get_prompt() -> String:
	var typed_stall := stall as Node
	if typed_stall and typed_stall.get("is_open"):
		return "收摊"
	return "在%s摆摊" % label


func interact(_player: Node) -> void:
	if stall.get("is_open"):
		stall.call("close")
	else:
		SignalBus.price_panel_requested.emit(self)


func open_stall(price: int) -> void:
	stall.call("open", spot_id, price)


func get_active_stall() -> Node:
	if stall.get("is_open"):
		return stall
	return null
