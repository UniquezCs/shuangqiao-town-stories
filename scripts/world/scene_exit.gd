extends Area2D

@export var target_scene := PrototypeConstants.SCENE_TOWN
@export var spawn_id := "default"
@export var prompt := "前往镇街"


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return prompt


func interact(_player: Node) -> void:
	SignalBus.scene_change_requested.emit(target_scene, spawn_id)
