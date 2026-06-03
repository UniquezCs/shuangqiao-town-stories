extends Area2D


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return "睡觉到第二天"


func interact(_player: Node) -> void:
	SignalBus.sleep_requested.emit()
