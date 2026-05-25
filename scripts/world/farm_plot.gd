extends Area2D

@export var plot_id := "plot_1"

const STATE_TEXTURES := {
	"empty": preload("res://assets/generated/prototype_v1_32/objects/farm_empty_64.png"),
	"seeded": preload("res://assets/generated/prototype_v1_32/objects/farm_seeded_64.png"),
	"growing": preload("res://assets/generated/prototype_v1_32/objects/farm_growing_64.png"),
	"ready": preload("res://assets/generated/prototype_v1_32/objects/farm_ready_64.png"),
}

var state := "empty"

@onready var growth_timer: Timer = $GrowthTimer
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	add_to_group("interactable")
	growth_timer.timeout.connect(_on_growth_timer_timeout)
	_refresh_visual()


func get_prompt() -> String:
	match state:
		"empty":
			return "播种苹果种子"
		"seeded", "growing":
			return "苹果正在生长"
		"ready":
			return "收获 5 个苹果"
	return ""


func interact(_player: Node) -> void:
	match state:
		"empty":
			if Inventory.remove_item(PrototypeConstants.ITEM_APPLE_SEED, 1):
				_set_state("seeded")
				GameState.set_objective("等待苹果成熟")
				growth_timer.start(1.0)
				if GameState.sales_count > 0:
					GameState.complete_prototype()
			else:
				SignalBus.sale_feedback.emit("没有苹果种子", global_position)
		"ready":
			Inventory.add_item(PrototypeConstants.ITEM_APPLE, PrototypeConstants.APPLE_HARVEST_COUNT)
			_set_state("empty")
			GameState.set_objective("带着苹果去镇街摆摊")
		_:
			SignalBus.sale_feedback.emit("还没成熟", global_position)


func _on_growth_timer_timeout() -> void:
	if state == "seeded":
		_set_state("growing")
		growth_timer.start(1.0)
	elif state == "growing":
		_set_state("ready")
		GameState.set_objective("收获苹果")


func _set_state(next_state: String) -> void:
	state = next_state
	SignalBus.farm_plot_state_changed.emit(plot_id, state)
	_refresh_visual()


func _refresh_visual() -> void:
	visual.texture = STATE_TEXTURES.get(state, STATE_TEXTURES["empty"])
