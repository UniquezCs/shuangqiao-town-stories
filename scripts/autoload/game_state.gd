extends Node

var cash := 0
var current_scene := PrototypeConstants.SCENE_HOUSE
var current_time_window := PrototypeConstants.WINDOW_PREP
var current_game_minute := 0
var day_clock_started := false
var objective := ""
var prototype_completed := false
var day_index := 1
var backpack_level := 1
var stall_level := 1
var current_tool := PrototypeConstants.TOOL_HOE

var sales_count := 0
var rejected_count := 0
var customer_count := 0
var chengguan_caught_count := 0
var chengguan_fine_total := 0
var total_sales_income := 0
var used_spots: Array[String] = []
var farm_plot_states := {}
var yesterday_summary := {}
var seed_shop_apple_price := PrototypeConstants.SHOP_APPLE_PRICE_MIN
var seed_shop_apple_stock := 0


func reset_game() -> void:
	cash = 0
	current_scene = PrototypeConstants.SCENE_HOUSE
	current_game_minute = 0
	day_clock_started = false
	current_time_window = PrototypeConstants.WINDOW_PREP
	prototype_completed = false
	day_index = 1
	backpack_level = 1
	stall_level = 1
	current_tool = PrototypeConstants.TOOL_HOE
	_reset_daily_stats()
	used_spots = []
	farm_plot_states = {}
	yesterday_summary = {}
	refresh_seed_shop_goods()
	Inventory.reset_items()
	SignalBus.cash_changed.emit(cash)
	SignalBus.game_time_changed.emit(current_game_minute, format_game_time(current_game_minute))
	SignalBus.current_tool_changed.emit(current_tool)
	set_time_window(PrototypeConstants.WINDOW_PREP)
	set_objective("出门整理农田，或去镇街做买卖")


func to_save_data() -> Dictionary:
	return {
		"cash": cash,
		"current_scene": current_scene,
		"current_time_window": current_time_window,
		"current_game_minute": current_game_minute,
		"day_clock_started": day_clock_started,
		"objective": objective,
		"prototype_completed": prototype_completed,
		"day_index": day_index,
		"backpack_level": backpack_level,
		"stall_level": stall_level,
		"current_tool": current_tool,
		"used_spots": used_spots.duplicate(),
		"farm_plot_states": farm_plot_states.duplicate(true),
		"yesterday_summary": yesterday_summary.duplicate(true),
		"seed_shop_apple_price": seed_shop_apple_price,
		"seed_shop_apple_stock": seed_shop_apple_stock,
	}


func apply_save_data(data: Dictionary) -> void:
	cash = int(data.get("cash", 0))
	current_scene = str(data.get("current_scene", PrototypeConstants.SCENE_HOUSE))
	current_time_window = str(data.get("current_time_window", PrototypeConstants.WINDOW_MORNING))
	current_game_minute = int(data.get("current_game_minute", PrototypeConstants.DAY_START_MINUTE))
	day_clock_started = bool(data.get("day_clock_started", true))
	objective = str(data.get("objective", "新的一天开始了，先看看背包和农田"))
	prototype_completed = bool(data.get("prototype_completed", false))
	day_index = maxi(1, int(data.get("day_index", 1)))
	backpack_level = maxi(1, int(data.get("backpack_level", 1)))
	stall_level = maxi(1, int(data.get("stall_level", 1)))
	current_tool = str(data.get("current_tool", PrototypeConstants.TOOL_HOE))
	used_spots = []
	for spot in data.get("used_spots", []):
		used_spots.append(str(spot))
	var saved_plots: Variant = data.get("farm_plot_states", {})
	farm_plot_states = saved_plots.duplicate(true) if typeof(saved_plots) == TYPE_DICTIONARY else {}
	var saved_summary: Variant = data.get("yesterday_summary", {})
	yesterday_summary = saved_summary.duplicate(true) if typeof(saved_summary) == TYPE_DICTIONARY else {}
	seed_shop_apple_price = int(data.get("seed_shop_apple_price", PrototypeConstants.SHOP_APPLE_PRICE_MIN))
	seed_shop_apple_stock = int(data.get("seed_shop_apple_stock", 0))
	_reset_daily_stats()
	SignalBus.cash_changed.emit(cash)
	SignalBus.game_time_changed.emit(current_game_minute, format_game_time(current_game_minute))
	SignalBus.current_tool_changed.emit(current_tool)
	set_time_window(current_time_window)
	set_objective(objective)


func set_objective(text: String) -> void:
	objective = text
	SignalBus.objective_changed.emit(text)


func add_cash(amount: int) -> void:
	if amount <= 0:
		return
	cash += amount
	SignalBus.cash_changed.emit(cash)


func spend_cash(amount: int) -> bool:
	if amount < 0:
		return false
	if cash < amount:
		return false
	cash -= amount
	SignalBus.cash_changed.emit(cash)
	return true


func deduct_cash(amount: int) -> int:
	if amount <= 0:
		return 0
	var deducted := mini(cash, amount)
	cash -= deducted
	SignalBus.cash_changed.emit(cash)
	return deducted


func refresh_seed_shop_goods(rng: RandomNumberGenerator = null) -> void:
	var active_rng := rng
	if active_rng == null:
		active_rng = RandomNumberGenerator.new()
		active_rng.randomize()
	seed_shop_apple_price = active_rng.randi_range(
		PrototypeConstants.SHOP_APPLE_PRICE_MIN,
		PrototypeConstants.SHOP_APPLE_PRICE_MAX
	)
	seed_shop_apple_stock = active_rng.randi_range(
		PrototypeConstants.SHOP_APPLE_STOCK_MIN,
		PrototypeConstants.SHOP_APPLE_STOCK_MAX
	)
	SignalBus.seed_shop_goods_changed.emit(seed_shop_apple_price, seed_shop_apple_stock)


func set_time_window(window_id: String) -> void:
	current_time_window = window_id
	SignalBus.time_window_changed.emit(window_id)


func start_day_clock(start_minute: int) -> void:
	if day_clock_started:
		return
	day_clock_started = true
	set_game_time_minute(start_minute)


func start_new_day(start_minute: int = PrototypeConstants.DAY_START_MINUTE) -> void:
	day_clock_started = true
	set_game_time_minute(start_minute)
	set_time_window(PrototypeConstants.WINDOW_MORNING)


func set_game_time_minute(total_minutes: int) -> void:
	current_game_minute = total_minutes
	SignalBus.game_time_changed.emit(current_game_minute, format_game_time(current_game_minute))


func format_game_time(total_minutes: int) -> String:
	var hour := (total_minutes / 60) % 24
	var minute := total_minutes % 60
	return "%02d:%02d" % [hour, minute]


func set_farm_plot_state(plot_id: String, state: String) -> void:
	farm_plot_states[plot_id] = state
	SignalBus.farm_plot_state_changed.emit(plot_id, state)


func set_farm_plot_data(plot_id: String, data: Dictionary) -> void:
	farm_plot_states[plot_id] = data.duplicate(true)
	SignalBus.farm_plot_state_changed.emit(plot_id, str(data.get("state", "empty")))


func get_farm_plot_state(plot_id: String) -> String:
	var value: Variant = farm_plot_states.get(plot_id, "empty")
	if typeof(value) == TYPE_DICTIONARY:
		return str(value.get("state", "empty"))
	return str(value)


func get_farm_plot_data(plot_id: String) -> Dictionary:
	var value: Variant = farm_plot_states.get(plot_id, {})
	if typeof(value) == TYPE_DICTIONARY:
		return value.duplicate(true)
	return {"state": str(value)}


func record_stall_use(spot_id: String) -> void:
	if not used_spots.has(spot_id):
		used_spots.append(spot_id)


func record_sale(price: int) -> void:
	sales_count += 1
	total_sales_income += price
	add_cash(price)


func record_rejection() -> void:
	rejected_count += 1


func record_customer_served() -> void:
	customer_count += 1


func record_chengguan_penalty(amount: int) -> int:
	var deducted := deduct_cash(amount)
	chengguan_caught_count += 1
	chengguan_fine_total += deducted
	SignalBus.chengguan_penalty.emit(deducted)
	return deducted


func set_current_tool(tool_id: String) -> void:
	if current_tool == tool_id:
		return
	current_tool = tool_id
	SignalBus.current_tool_changed.emit(current_tool)


func get_backpack_slot_count() -> int:
	var entry := ConfigLoader.get_upgrade_entry("backpack", backpack_level)
	return int(entry.get("slots", 8))


func get_stall_slot_count() -> int:
	var entry := ConfigLoader.get_upgrade_entry("stall", stall_level)
	return int(entry.get("stall_slots", 4))


func get_stall_influence_radius() -> float:
	var entry := ConfigLoader.get_upgrade_entry("stall", stall_level)
	return float(entry.get("influence_radius", 160))


func upgrade_backpack() -> bool:
	var next_entry := ConfigLoader.get_next_upgrade_entry("backpack", backpack_level)
	if next_entry.is_empty():
		SignalBus.sale_feedback.emit("背包已经最大", Vector2.ZERO)
		return false
	var price := int(next_entry.get("price", 0))
	if not spend_cash(price):
		SignalBus.sale_feedback.emit("钱不够升级背包", Vector2.ZERO)
		return false
	backpack_level = int(next_entry.get("level", backpack_level + 1))
	Inventory.configure_slot_count(get_backpack_slot_count())
	SignalBus.sale_feedback.emit("背包升级到 %d 级" % backpack_level, Vector2.ZERO)
	return true


func upgrade_stall() -> bool:
	var next_entry := ConfigLoader.get_next_upgrade_entry("stall", stall_level)
	if next_entry.is_empty():
		SignalBus.sale_feedback.emit("摊位已经最大", Vector2.ZERO)
		return false
	var price := int(next_entry.get("price", 0))
	if not spend_cash(price):
		SignalBus.sale_feedback.emit("钱不够升级摊位", Vector2.ZERO)
		return false
	stall_level = int(next_entry.get("level", stall_level + 1))
	SignalBus.sale_feedback.emit("摊位升级到 %d 级" % stall_level, Vector2.ZERO)
	return true


func end_day(reason := "sleep") -> Dictionary:
	yesterday_summary = {
		"day": day_index,
		"reason": reason,
		"income": total_sales_income,
		"sales": sales_count,
		"customers": customer_count,
		"missed_or_rejected": rejected_count,
		"chengguan_caught": chengguan_caught_count,
		"chengguan_fines": chengguan_fine_total,
		"cash": cash,
	}
	day_index += 1
	advance_farm_plots_for_new_day()
	refresh_seed_shop_goods()
	_reset_daily_stats()
	SignalBus.daily_summary_ready.emit(yesterday_summary)
	set_objective("新的一天开始了，先看看背包和农田")
	return yesterday_summary


func advance_farm_plots_for_new_day() -> void:
	for plot_id in farm_plot_states.keys():
		var data := get_farm_plot_data(str(plot_id))
		var days_grown := int(data.get("days_grown", 0))
		var state := _normalize_farm_plot_state(str(data.get("state", "tilled")), days_grown)
		data["state"] = state
		if not ["seed_watered", "growing_watered"].has(state):
			continue
		var crop_id := str(data.get("crop_id", PrototypeConstants.ITEM_APPLE))
		var crop := ConfigLoader.get_crop(crop_id)
		days_grown += 1
		data["days_grown"] = days_grown
		if days_grown >= int(crop.get("growth_days", 1)):
			data["state"] = "ready"
		else:
			data["state"] = "growing_dry"
		set_farm_plot_data(str(plot_id), data)


func _normalize_farm_plot_state(raw_state: String, days_grown: int) -> String:
	match raw_state:
		"empty":
			return "tilled"
		"seeded":
			return "growing_dry" if days_grown > 0 else "seed_dry"
		"watered":
			return "growing_watered" if days_grown > 0 else "seed_watered"
	return raw_state


func build_settlement(remaining_apples: int) -> Dictionary:
	var average_price := 0.0
	if sales_count > 0:
		average_price = float(total_sales_income) / float(sales_count)
	return {
		"cash": cash,
		"income": total_sales_income,
		"sales": sales_count,
		"average_price": average_price,
		"rejections": rejected_count,
		"customers": customer_count,
		"chengguan_caught": chengguan_caught_count,
		"chengguan_fines": chengguan_fine_total,
		"remaining_apples": remaining_apples,
		"used_spots": used_spots.duplicate(),
		"completed": prototype_completed,
		"rating": _rating_for(remaining_apples),
	}


func request_day_settlement(remaining_apples: int) -> void:
	SignalBus.day_settlement_requested.emit()
	SignalBus.settlement_ready.emit(build_settlement(remaining_apples))


func complete_prototype() -> void:
	prototype_completed = true
	var result := build_settlement(Inventory.get_count(PrototypeConstants.ITEM_APPLE))
	result["completed"] = true
	result["rating"] = "完成闭环"
	SignalBus.prototype_completed.emit(result)
	SignalBus.settlement_ready.emit(result)


func _rating_for(remaining_apples: int) -> String:
	if sales_count >= 5 and used_spots.has(PrototypeConstants.SPOT_FACTORY) and total_sales_income >= 16:
		return "会做生意"
	if sales_count >= 5 or remaining_apples == 0:
		return "今天不错"
	if sales_count >= 3:
		return "小赚一笔"
	if cash >= PrototypeConstants.SEED_PRICE:
		return "勉强开张"
	return "还在摸索"


func _reset_daily_stats() -> void:
	sales_count = 0
	rejected_count = 0
	customer_count = 0
	chengguan_caught_count = 0
	chengguan_fine_total = 0
	total_sales_income = 0
