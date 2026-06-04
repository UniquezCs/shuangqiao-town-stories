extends Area2D

@export var plot_id := "plot_1"

const STATE_TEXTURES := {
	"tilled": preload("res://assets/generated/sprites/farm/crops/apple/apple_empty_tilled_32.png"),
	"seed_dry": preload("res://assets/generated/sprites/farm/crops/apple/apple_seed_dry_32.png"),
	"seed_watered": preload("res://assets/generated/sprites/farm/crops/apple/apple_seed_watered_32.png"),
	"growing_dry": preload("res://assets/generated/sprites/farm/crops/apple/apple_growing_dry_32.png"),
	"growing_watered": preload("res://assets/generated/sprites/farm/crops/apple/apple_growing_watered_32.png"),
	"ready": preload("res://assets/generated/sprites/farm/crops/apple/apple_mature_32.png"),
}

var state := "tilled"
var crop_id := ""
var days_grown := 0
var fertilized := false

@onready var growth_timer: Timer = $GrowthTimer
@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	add_to_group("farm_plot")
	if growth_timer != null:
		growth_timer.stop()
	_load_state()
	_refresh_visual()


func get_prompt() -> String:
	match state:
		"tilled":
			return "用种子播种"
		"seed_dry", "growing_dry":
			return "用水壶浇水"
		"seed_watered", "growing_watered":
			return "明天再来看"
		"ready":
			return "收获作物"
	return ""


func interact(player: Node) -> void:
	match state:
		"tilled":
			_try_seed()
		"seed_dry", "growing_dry":
			_try_water_or_fertilize(player)
		"seed_watered", "growing_watered":
			SignalBus.sale_feedback.emit("已经浇过水，睡觉后会继续生长", global_position)
		"ready":
			_harvest(player)


func click_interact(_world_position: Vector2, player: Node) -> bool:
	if state == "tilled":
		return _try_seed()
	interact(player)
	return true


func _try_till() -> void:
	if GameState.current_tool != PrototypeConstants.TOOL_HOE:
		SignalBus.sale_feedback.emit("先按 1 选择锄头", global_position)
		return
	_set_data({"state": "tilled"})
	GameState.set_objective("按 2 选择种子，在耕地上播种")


func _try_seed() -> bool:
	if GameState.current_tool != PrototypeConstants.TOOL_SEED:
		SignalBus.sale_feedback.emit("先按 2 选择种子", global_position)
		return false
	var seed_item_id := Hotbar.get_selected_item_id()
	if ConfigLoader.get_crop_for_seed(seed_item_id).is_empty():
		seed_item_id = ""
	if seed_item_id.is_empty():
		SignalBus.sale_feedback.emit("先把种子放到快捷栏并选中", global_position)
		return false
	var removed_seed := Hotbar.remove_from_selected(1)
	if int(removed_seed.get("count", 0)) != 1:
		return false
	crop_id = ConfigLoader.get_crop_for_seed(seed_item_id)
	if crop_id.is_empty():
		crop_id = PrototypeConstants.ITEM_APPLE
	_set_data({
		"state": "seed_dry",
		"crop_id": crop_id,
		"days_grown": 0,
		"fertilized": false,
	})
	GameState.set_objective("选择水壶，点击作物浇水")
	return true


func _try_water_or_fertilize(player: Node) -> void:
	if GameState.current_tool == PrototypeConstants.TOOL_FERTILIZER:
		_try_fertilize()
		return
	if GameState.current_tool != PrototypeConstants.TOOL_WATER:
		SignalBus.sale_feedback.emit("先按 3 选择水壶", global_position)
		return
	var crop := ConfigLoader.get_crop(crop_id)
	var next_state := "ready" if int(crop.get("growth_days", 1)) <= 0 else _watered_state_for_growth()
	_set_data({
		"state": next_state,
		"crop_id": crop_id,
		"days_grown": days_grown,
		"fertilized": fertilized,
	})
	_play_player_farming_action(player, "water")
	GameState.set_objective("作物成熟了，按 4 选择镰刀，点击成熟作物收获" if next_state == "ready" else "晚上回屋睡觉，第二天作物会继续成长")


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


func _harvest(player: Node) -> void:
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
	_play_player_farming_action(player, "harvest")
	_set_data({
		"state": "tilled",
		"crop_id": "",
		"days_grown": 0,
		"fertilized": false,
	})
	GameState.set_objective("带着作物去镇街摆摊")
	if GameState.sales_count > 0:
		GameState.complete_prototype()


func _load_state() -> void:
	var data := GameState.get_farm_plot_data(plot_id)
	state = _normalize_state(str(data.get("state", "tilled")), int(data.get("days_grown", 0)))
	crop_id = str(data.get("crop_id", PrototypeConstants.ITEM_APPLE))
	days_grown = int(data.get("days_grown", 0))
	fertilized = bool(data.get("fertilized", false))


func _set_data(data: Dictionary) -> void:
	var saved := GameState.get_farm_plot_data(plot_id)
	var next_data := saved.duplicate(true)
	for key in data.keys():
		next_data[key] = data[key]
	state = _normalize_state(str(next_data.get("state", "tilled")), int(next_data.get("days_grown", 0)))
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
	var state_texture_path := ConfigLoader.get_crop_state_texture(_visual_crop_id(), state)
	if not state_texture_path.is_empty() and ResourceLoader.exists(state_texture_path):
		visual.texture = load(state_texture_path) as Texture2D
	else:
		visual.texture = STATE_TEXTURES.get(state, STATE_TEXTURES["tilled"])


func _watered_state_for_growth() -> String:
	return "growing_watered" if days_grown > 0 else "seed_watered"


func _visual_crop_id() -> String:
	return crop_id if not crop_id.is_empty() else PrototypeConstants.ITEM_APPLE


func _normalize_state(raw_state: String, saved_days_grown: int) -> String:
	match raw_state:
		"empty":
			return "tilled"
		"seeded":
			return "growing_dry" if saved_days_grown > 0 else "seed_dry"
		"watered":
			return "growing_watered" if saved_days_grown > 0 else "seed_watered"
	return raw_state


func _play_player_farming_action(player: Node, action_id: String) -> void:
	if player != null and player.has_method("play_farming_action"):
		player.call("play_farming_action", action_id)
