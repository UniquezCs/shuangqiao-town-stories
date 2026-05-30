extends Area2D

@export var plot_id := "plot_1"

const STATE_TEXTURES := {
	"empty": preload("res://assets/generated/sprites/farm/farm_empty_64.png"),
	"tilled": preload("res://assets/generated/sprites/farm/farm_seeded_64.png"),
	"seeded": preload("res://assets/generated/sprites/farm/farm_growing_64.png"),
	"watered": preload("res://assets/generated/sprites/farm/farm_growing_64.png"),
	"ready": preload("res://assets/generated/sprites/farm/farm_ready_64.png"),
}

var state := "empty"
var crop_id := ""
var days_grown := 0
var fertilized := false

@onready var growth_timer: Timer = $GrowthTimer
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	add_to_group("interactable")
	if growth_timer != null:
		growth_timer.stop()
	_load_state()
	_refresh_visual()


func get_prompt() -> String:
	match state:
		"empty":
			return "用锄头开垦"
		"tilled":
			return "用种子播种"
		"seeded":
			return "用水壶浇水"
		"watered":
			return "明天再来看"
		"ready":
			return "收获作物"
	return ""


func interact(_player: Node) -> void:
	match state:
		"empty":
			_try_till()
		"tilled":
			_try_seed()
		"seeded":
			_try_water_or_fertilize()
		"watered":
			SignalBus.sale_feedback.emit("已经浇过水，睡觉后会继续生长", global_position)
		"ready":
			_harvest()


func _try_till() -> void:
	if GameState.current_tool != PrototypeConstants.TOOL_HOE:
		SignalBus.sale_feedback.emit("先按 1 选择锄头", global_position)
		return
	_set_data({"state": "tilled"})
	GameState.set_objective("按 2 选择种子，在耕地上播种")


func _try_seed() -> void:
	if GameState.current_tool != PrototypeConstants.TOOL_SEED:
		SignalBus.sale_feedback.emit("先按 2 选择种子", global_position)
		return
	var seed_item_id := _first_available_seed()
	if seed_item_id.is_empty():
		SignalBus.sale_feedback.emit("背包里没有种子", global_position)
		return
	if not Inventory.remove_item(seed_item_id, 1):
		return
	crop_id = ConfigLoader.get_crop_for_seed(seed_item_id)
	if crop_id.is_empty():
		crop_id = PrototypeConstants.ITEM_APPLE
	_set_data({
		"state": "seeded",
		"crop_id": crop_id,
		"days_grown": 0,
		"fertilized": false,
	})
	GameState.set_objective("按 3 选择水壶，给作物浇水")


func _try_water_or_fertilize() -> void:
	if GameState.current_tool == PrototypeConstants.TOOL_FERTILIZER:
		_try_fertilize()
		return
	if GameState.current_tool != PrototypeConstants.TOOL_WATER:
		SignalBus.sale_feedback.emit("先按 3 选择水壶", global_position)
		return
	_set_data({
		"state": "watered",
		"crop_id": crop_id,
		"days_grown": days_grown,
		"fertilized": fertilized,
	})
	GameState.set_objective("晚上回屋睡觉，第二天作物会继续成长")


func _try_fertilize() -> void:
	if fertilized:
		SignalBus.sale_feedback.emit("这块地已经施肥", global_position)
		return
	if not Inventory.remove_item(PrototypeConstants.ITEM_FERTILIZER, 1):
		SignalBus.sale_feedback.emit("没有肥料", global_position)
		return
	fertilized = true
	_set_data({
		"state": state,
		"crop_id": crop_id,
		"days_grown": days_grown,
		"fertilized": fertilized,
	})
	SignalBus.sale_feedback.emit("施肥完成", global_position)


func _harvest() -> void:
	if GameState.current_tool != PrototypeConstants.TOOL_SICKLE:
		SignalBus.sale_feedback.emit("先按 4 选择镰刀收获", global_position)
		return
	var crop := ConfigLoader.get_crop(crop_id)
	if crop.is_empty():
		crop = ConfigLoader.get_crop(PrototypeConstants.ITEM_APPLE)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var amount := rng.randi_range(int(crop.get("yield_min", 3)), int(crop.get("yield_max", 5)))
	if fertilized:
		amount += int(crop.get("fertilizer_bonus", 1))
	var harvest_item_id := str(crop.get("harvest_item_id", PrototypeConstants.ITEM_APPLE))
	if not Inventory.add_item(harvest_item_id, amount):
		SignalBus.sale_feedback.emit("背包装不下全部作物", global_position)
		return
	else:
		SignalBus.sale_feedback.emit("收获 %s x%d" % [ConfigLoader.get_item_name(harvest_item_id), amount], global_position)
	_set_data({"state": "empty"})
	GameState.set_objective("带着作物去镇街摆摊")
	if GameState.sales_count > 0:
		GameState.complete_prototype()


func _first_available_seed() -> String:
	for slot in Inventory.slots:
		var item_id := str(slot.get("item_id", ""))
		if ConfigLoader.get_crop_for_seed(item_id) != "" and int(slot.get("count", 0)) > 0:
			return item_id
	return ""


func _load_state() -> void:
	var data := GameState.get_farm_plot_data(plot_id)
	state = str(data.get("state", "empty"))
	crop_id = str(data.get("crop_id", PrototypeConstants.ITEM_APPLE))
	days_grown = int(data.get("days_grown", 0))
	fertilized = bool(data.get("fertilized", false))


func _set_data(data: Dictionary) -> void:
	var saved := GameState.get_farm_plot_data(plot_id)
	var next_data := saved.duplicate(true)
	for key in data.keys():
		next_data[key] = data[key]
	state = str(next_data.get("state", "empty"))
	crop_id = str(next_data.get("crop_id", ""))
	days_grown = int(next_data.get("days_grown", 0))
	fertilized = bool(next_data.get("fertilized", false))
	next_data.merge({
		"state": state,
		"crop_id": crop_id,
		"days_grown": days_grown,
		"fertilized": fertilized,
	}, true)
	GameState.set_farm_plot_data(plot_id, next_data)
	_refresh_visual()


func _refresh_visual() -> void:
	visual.texture = STATE_TEXTURES.get(state, STATE_TEXTURES["empty"])
