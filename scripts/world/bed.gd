extends Area2D


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return "睡觉到第二天"


func interact(_player: Node) -> void:
	SignalBus.day_settlement_requested.emit()
	GameState.end_day("sleep")
	GameState.start_new_day(PrototypeConstants.DAY_START_MINUTE)
	SignalBus.scene_change_requested.emit(PrototypeConstants.SCENE_HOUSE, "bed_spawn")
