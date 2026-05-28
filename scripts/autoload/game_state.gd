extends Node

var cash := 0
var current_scene := PrototypeConstants.SCENE_HOME
var current_time_window := PrototypeConstants.WINDOW_PREP
var current_game_minute := 0
var day_clock_started := false
var objective := ""
var prototype_completed := false

var sales_count := 0
var rejected_count := 0
var total_sales_income := 0
var used_spots: Array[String] = []
var farm_plot_states := {}
var seed_shop_apple_price := PrototypeConstants.SHOP_APPLE_PRICE_MIN
var seed_shop_apple_stock := 0


func reset_game() -> void:
	cash = 0
	current_scene = PrototypeConstants.SCENE_HOME
	current_game_minute = 0
	day_clock_started = false
	current_time_window = PrototypeConstants.WINDOW_PREP
	prototype_completed = false
	sales_count = 0
	rejected_count = 0
	total_sales_income = 0
	used_spots = []
	farm_plot_states = {}
	refresh_seed_shop_goods()
	Inventory.reset_items()
	SignalBus.cash_changed.emit(cash)
	SignalBus.game_time_changed.emit(current_game_minute, format_game_time(current_game_minute))
	set_time_window(PrototypeConstants.WINDOW_PREP)
	set_objective("在家里播种苹果种子")


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


func get_farm_plot_state(plot_id: String) -> String:
	return str(farm_plot_states.get(plot_id, "empty"))


func record_stall_use(spot_id: String) -> void:
	if not used_spots.has(spot_id):
		used_spots.append(spot_id)


func record_sale(price: int) -> void:
	sales_count += 1
	total_sales_income += price
	add_cash(price)


func record_rejection() -> void:
	rejected_count += 1


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
