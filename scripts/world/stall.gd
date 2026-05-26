extends Node2D

const STALL_TEXTURES := [
	preload("res://assets/generated/props/street_stall_props_v2_cutouts/01_stall_empty.png"),
	preload("res://assets/generated/props/street_stall_props_v2_cutouts/04_stall_apple_1.png"),
	preload("res://assets/generated/props/street_stall_props_v2_cutouts/03_stall_apples_3.png"),
	preload("res://assets/generated/props/street_stall_props_v2_cutouts/02_stall_apples_6.png"),
]

var spot_id := ""
var is_open := false
var stock := 0
var price := 2

@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	_refresh_visual()


func open(spot: String, chosen_price: int, owner: Node2D = null) -> bool:
	if is_open:
		return false
	var available := Inventory.get_count(PrototypeConstants.ITEM_APPLE)
	if available <= 0:
		SignalBus.sale_feedback.emit("背包里没有苹果", global_position)
		return false
	if owner != null and is_instance_valid(owner):
		global_position = owner.global_position
	spot_id = spot
	price = clamp(chosen_price, PrototypeConstants.MIN_APPLE_PRICE, PrototypeConstants.MAX_APPLE_PRICE)
	stock = min(available, PrototypeConstants.APPLE_HARVEST_COUNT)
	Inventory.remove_item(PrototypeConstants.ITEM_APPLE, stock)
	is_open = true
	visible = true
	GameState.record_stall_use(spot_id)
	GameState.set_objective("等顾客来买苹果")
	SignalBus.stall_opened.emit(spot_id, price, stock)
	SignalBus.stall_stock_changed.emit(stock)
	SignalBus.price_changed.emit(price)
	_refresh_visual()
	return true


func close() -> void:
	if not is_open:
		return
	var returned := stock
	if returned > 0:
		Inventory.add_item(PrototypeConstants.ITEM_APPLE, returned)
	stock = 0
	is_open = false
	visible = false
	SignalBus.stall_closed.emit(spot_id, returned)
	SignalBus.stall_stock_changed.emit(stock)
	GameState.set_objective("可以换点摆摊，或回家买种子")
	_refresh_visual()


func can_sell_to(customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	if not is_open or stock <= 0:
		return {"bought": false, "reason": "没货了"}
	if not customer_profile.is_empty():
		return _profile_decision(customer_type, customer_profile)
	if customer_type == PrototypeConstants.CUSTOMER_STUDENT:
		if price <= 2:
			return {"bought": true, "reason": "学生买下苹果"}
		if price == 3:
			return {"bought": false, "reason": "学生觉得有点贵"}
		return {"bought": false, "reason": "学生买不起"}
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		if price <= 4:
			return {"bought": true, "reason": "工人买下苹果"}
		return {"bought": false, "reason": "工人觉得贵"}
	return {"bought": false, "reason": "顾客离开"}


func sell_one(customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	var decision := can_sell_to(customer_type, customer_profile)
	if bool(decision["bought"]):
		stock -= 1
		GameState.record_sale(price)
		SignalBus.stall_stock_changed.emit(stock)
		SignalBus.sale_completed.emit(PrototypeConstants.ITEM_APPLE, price, stock)
		SignalBus.sale_feedback.emit("+%d 元" % price, global_position)
		if stock <= 0:
			GameState.set_objective("苹果卖完了，回家买种子")
		_refresh_visual()
	else:
		GameState.record_rejection()
		SignalBus.sale_feedback.emit(str(decision["reason"]), global_position)
	SignalBus.customer_decision.emit(customer_type, bool(decision["bought"]), str(decision["reason"]))
	return decision


func _profile_decision(customer_type: String, customer_profile: Dictionary) -> Dictionary:
	var customer_label := "工人" if customer_type == PrototypeConstants.CUSTOMER_WORKER else "学生"
	var budget := int(customer_profile.get("budget", _default_budget_for(customer_type)))
	var preferences: Dictionary = customer_profile.get("preferences", {})
	var preference := float(preferences.get(PrototypeConstants.ITEM_APPLE, 0.0))
	if preference < 0.45:
		return {"bought": false, "reason": "%s暂时不想买苹果" % customer_label}

	var acceptable_price := clampi(int(floor(float(budget) * (0.55 + preference))), 1, budget)
	if price <= acceptable_price:
		return {"bought": true, "reason": "%s买下苹果" % customer_label}
	if price > budget:
		return {"bought": false, "reason": "%s预算不够" % customer_label}
	return {"bought": false, "reason": "%s觉得不划算" % customer_label}


func _default_budget_for(customer_type: String) -> int:
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		return 4
	return 2


func _refresh_visual() -> void:
	if stock <= 0:
		visual.texture = STALL_TEXTURES[0]
	elif stock == 1:
		visual.texture = STALL_TEXTURES[1]
	elif stock <= 3:
		visual.texture = STALL_TEXTURES[2]
	else:
		visual.texture = STALL_TEXTURES[3]
