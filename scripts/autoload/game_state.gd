extends Node

var cash := 0
var current_scene := PrototypeConstants.SCENE_HOME
var current_time_window := PrototypeConstants.WINDOW_PREP
var objective := ""
var prototype_completed := false

var sales_count := 0
var rejected_count := 0
var total_sales_income := 0
var used_spots: Array[String] = []


func reset_game() -> void:
	cash = 0
	current_scene = PrototypeConstants.SCENE_HOME
	current_time_window = PrototypeConstants.WINDOW_PREP
	prototype_completed = false
	sales_count = 0
	rejected_count = 0
	total_sales_income = 0
	used_spots = []
	Inventory.reset_items()
	SignalBus.cash_changed.emit(cash)
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


func set_time_window(window_id: String) -> void:
	current_time_window = window_id
	SignalBus.time_window_changed.emit(window_id)


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
