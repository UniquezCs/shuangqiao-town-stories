extends Node2D

const STALL_TEXTURES := [
	preload("res://assets/generated/sprites/props/stall/01_stall_empty.png"),
	preload("res://assets/generated/sprites/props/stall/04_stall_apple_1.png"),
	preload("res://assets/generated/sprites/props/stall/03_stall_apples_3.png"),
	preload("res://assets/generated/sprites/props/stall/02_stall_apples_6.png"),
]

var spot_id := ""
var is_open := false
var stock := 0
var price := 2
var current_item_id := PrototypeConstants.ITEM_APPLE
var stall_slots: Array[Dictionary] = []
var influence_radius := 160.0

var _influence_area: Area2D = null
var _inspection_target: Area2D = null
var _player_boundary: StaticBody2D = null

@onready var visual: Sprite2D = $Visual


func _ready() -> void:
	_reset_stall_slots()
	_refresh_visual()


func open(spot: String, chosen_price: int, owner: Node2D = null) -> bool:
	if is_open:
		return false
	current_item_id = Inventory.get_first_sellable_item_id()
	if current_item_id.is_empty():
		current_item_id = PrototypeConstants.ITEM_APPLE
	var available := Inventory.get_count(current_item_id)
	if available <= 0:
		SignalBus.sale_feedback.emit("背包里没有可卖的商品", global_position)
		return false
	var prepared_stock := available
	if not Inventory.remove_item(current_item_id, prepared_stock):
		return false
	var prepared_slots: Array[Dictionary] = [
		{
			"item_id": current_item_id,
			"count": prepared_stock,
			"price": clampi(chosen_price, PrototypeConstants.MIN_APPLE_PRICE, PrototypeConstants.MAX_APPLE_PRICE),
		}
	]
	if not open_with_slots(spot, prepared_slots, owner):
		Inventory.add_item(current_item_id, prepared_stock)
		return false
	return true


func open_with_slots(spot: String, prepared_slots: Array, owner: Node2D = null) -> bool:
	if is_open:
		return false
	var sanitized_slots := _sanitize_prepared_slots(prepared_slots)
	var total_stock := _stock_total(sanitized_slots)
	if total_stock <= 0:
		SignalBus.sale_feedback.emit("摊位上没有可卖的商品", global_position)
		return false
	if owner != null and is_instance_valid(owner):
		global_position = owner.global_position
	_apply_upgrade_config()
	spot_id = spot
	stall_slots = sanitized_slots
	stock = total_stock
	var first_slot := _first_stock_slot()
	current_item_id = str(first_slot.get("item_id", PrototypeConstants.ITEM_APPLE))
	price = int(first_slot.get("price", ConfigLoader.get_base_sell_price(current_item_id)))
	is_open = true
	visible = true
	GameState.record_stall_use(spot_id)
	GameState.set_objective("等顾客来买%s" % ConfigLoader.get_item_name(current_item_id))
	SignalBus.stall_opened.emit(spot_id, price, stock)
	SignalBus.stall_stock_changed.emit(stock)
	SignalBus.stall_inventory_changed.emit(_visible_stall_slots(), stock)
	SignalBus.price_changed.emit(price)
	_create_influence_area()
	_create_inspection_target()
	_create_player_boundary()
	_refresh_visual()
	return true


func _apply_upgrade_config() -> void:
	influence_radius = GameState.get_stall_influence_radius()


func close() -> bool:
	if not is_open:
		return true
	var returned := stock
	if returned > 0 and not _can_return_all_stock():
		SignalBus.sale_feedback.emit("背包空间不够，无法收摊", global_position)
		return false
	SignalBus.stall_closed_node.emit(self)
	for slot in stall_slots:
		if slot.is_empty():
			continue
		Inventory.add_item(str(slot.get("item_id", "")), int(slot.get("count", 0)))
	stock = 0
	_reset_stall_slots()
	is_open = false
	visible = false
	SignalBus.stall_closed.emit(spot_id, returned)
	SignalBus.stall_stock_changed.emit(stock)
	SignalBus.stall_inventory_changed.emit(_visible_stall_slots(), stock)
	GameState.set_objective("可以换点摆摊，或回家买种子")
	_remove_influence_area()
	_remove_inspection_target()
	_remove_player_boundary()
	_refresh_visual()
	return true


func can_sell_to(customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	if not is_open or stock <= 0:
		return {"bought": false, "reason": "没货了"}
	if not customer_profile.is_empty():
		return _profile_decision(customer_type, customer_profile)
	var cheapest_slot := _cheapest_stock_slot()
	var item_name := ConfigLoader.get_item_name(str(cheapest_slot.get("item_id", current_item_id)))
	var slot_price := int(cheapest_slot.get("price", price))
	if customer_type == PrototypeConstants.CUSTOMER_STUDENT:
		if slot_price <= 2:
			return _decision_for_slot(cheapest_slot, "学生买下%s" % item_name)
		if slot_price == 3:
			return {"bought": false, "reason": "学生觉得有点贵"}
		return {"bought": false, "reason": "学生买不起"}
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		if slot_price <= 4:
			return _decision_for_slot(cheapest_slot, "工人买下%s" % item_name)
		return {"bought": false, "reason": "工人觉得贵"}
	return {"bought": false, "reason": "顾客离开"}


func sell_one(customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	var decision := can_sell_to(customer_type, customer_profile)
	if bool(decision["bought"]):
		var slot_index := int(decision.get("slot_index", -1))
		if not _is_valid_stall_slot(slot_index):
			return {"bought": false, "reason": "商品不在摊位上"}
		var sale_slot: Dictionary = stall_slots[slot_index]
		var sale_item_id := str(sale_slot.get("item_id", current_item_id))
		var sale_price := int(sale_slot.get("price", price))
		sale_slot["count"] = int(sale_slot.get("count", 0)) - 1
		stall_slots[slot_index] = sale_slot if int(sale_slot.get("count", 0)) > 0 else {}
		stock = _stock_total(stall_slots)
		GameState.record_sale(sale_price)
		GameState.record_customer_served()
		SignalBus.stall_stock_changed.emit(stock)
		SignalBus.stall_inventory_changed.emit(_visible_stall_slots(), stock)
		SignalBus.sale_completed.emit(sale_item_id, sale_price, stock)
		SignalBus.sale_feedback.emit("+%d 元" % sale_price, global_position)
		decision["item_id"] = sale_item_id
		decision["price"] = sale_price
		current_item_id = sale_item_id
		price = sale_price
		if stock <= 0:
			GameState.set_objective("商品卖完了，可以回家补货")
		_refresh_visual()
	else:
		GameState.record_rejection()
		GameState.record_customer_served()
		SignalBus.sale_feedback.emit(str(decision["reason"]), global_position)
	SignalBus.customer_decision.emit(customer_type, bool(decision["bought"]), str(decision["reason"]))
	return decision


func _create_influence_area() -> void:
	if _influence_area != null and is_instance_valid(_influence_area):
		return
	_influence_area = Area2D.new()
	_influence_area.name = "InfluenceArea"
	_influence_area.collision_layer = 0
	_influence_area.collision_mask = 4
	_influence_area.monitorable = false
	_influence_area.monitoring = true
	_influence_area.body_entered.connect(_on_influence_body_entered)
	_influence_area.body_exited.connect(_on_influence_body_exited)

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = influence_radius
	collision_shape.shape = circle
	_influence_area.add_child(collision_shape)
	add_child(_influence_area)


func _remove_influence_area() -> void:
	if _influence_area == null or not is_instance_valid(_influence_area):
		_influence_area = null
		return
	_influence_area.queue_free()
	_influence_area = null


func _create_inspection_target() -> void:
	if _inspection_target != null and is_instance_valid(_inspection_target):
		return
	_inspection_target = Area2D.new()
	_inspection_target.name = "InspectionTarget"
	_inspection_target.add_to_group("open_stall_inspection_target")
	_inspection_target.collision_layer = 8
	_inspection_target.collision_mask = 0
	_inspection_target.monitoring = false
	_inspection_target.monitorable = true

	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	var circle := CircleShape2D.new()
	circle.radius = influence_radius
	collision_shape.shape = circle
	_inspection_target.add_child(collision_shape)
	add_child(_inspection_target)


func _remove_inspection_target() -> void:
	if _inspection_target == null or not is_instance_valid(_inspection_target):
		_inspection_target = null
		return
	_inspection_target.queue_free()
	_inspection_target = null


func _create_player_boundary() -> void:
	if _player_boundary != null and is_instance_valid(_player_boundary):
		return
	_player_boundary = StaticBody2D.new()
	_player_boundary.name = "PlayerBoundary"
	_player_boundary.collision_layer = PrototypeConstants.PLAYER_BOUNDARY_COLLISION_LAYER
	_player_boundary.collision_mask = 0
	add_child(_player_boundary)

	var half_size := PrototypeConstants.STALL_PLAYER_BOUNDARY_HALF_SIZE
	var thickness := PrototypeConstants.STALL_PLAYER_BOUNDARY_WALL_THICKNESS
	_add_boundary_wall(Vector2(0, -half_size - thickness * 0.5), Vector2(half_size * 2.0 + thickness * 2.0, thickness))
	_add_boundary_wall(Vector2(0, half_size + thickness * 0.5), Vector2(half_size * 2.0 + thickness * 2.0, thickness))
	_add_boundary_wall(Vector2(-half_size - thickness * 0.5, 0), Vector2(thickness, half_size * 2.0))
	_add_boundary_wall(Vector2(half_size + thickness * 0.5, 0), Vector2(thickness, half_size * 2.0))


func _add_boundary_wall(local_position: Vector2, size: Vector2) -> void:
	var collision_shape := CollisionShape2D.new()
	collision_shape.name = "CollisionShape2D"
	collision_shape.position = local_position
	var rectangle := RectangleShape2D.new()
	rectangle.size = size
	collision_shape.shape = rectangle
	_player_boundary.add_child(collision_shape)


func _remove_player_boundary() -> void:
	if _player_boundary == null or not is_instance_valid(_player_boundary):
		_player_boundary = null
		return
	_player_boundary.queue_free()
	_player_boundary = null


func _on_influence_body_entered(body: Node) -> void:
	if is_open and body.has_method("enter_stall_influence"):
		body.call("enter_stall_influence", self)


func _on_influence_body_exited(body: Node) -> void:
	if body.has_method("exit_stall_influence"):
		body.call("exit_stall_influence", self)


func _profile_decision(customer_type: String, customer_profile: Dictionary) -> Dictionary:
	var customer_label := str(customer_profile.get("label", "工人" if customer_type == PrototypeConstants.CUSTOMER_WORKER else "学生"))
	var budget := int(customer_profile.get("budget", _default_budget_for(customer_type)))
	var preferences: Dictionary = customer_profile.get("preferences", {})
	var best_slot: Dictionary = {}
	var best_score := -INF
	var wanted_any := false
	for index in range(stall_slots.size()):
		var slot: Dictionary = stall_slots[index]
		if slot.is_empty():
			continue
		var item_id := str(slot.get("item_id", ""))
		var item_price := int(slot.get("price", ConfigLoader.get_base_sell_price(item_id)))
		var preference := float(preferences.get(item_id, preferences.get(PrototypeConstants.ITEM_APPLE, 0.0)))
		if preference < 0.45:
			continue
		wanted_any = true
		var acceptable_price := clampi(int(floor(float(budget) * (0.55 + preference))), 1, budget)
		if item_price > acceptable_price:
			continue
		var score := preference * 100.0 - float(item_price)
		if score > best_score:
			best_score = score
			best_slot = slot.duplicate()
			best_slot["slot_index"] = index

	if not best_slot.is_empty():
		var item_id := str(best_slot.get("item_id", current_item_id))
		return _decision_for_slot(best_slot, "%s买下%s" % [customer_label, ConfigLoader.get_item_name(item_id)])
	if not wanted_any:
		return {"bought": false, "reason": "%s暂时不想买这些商品" % customer_label}
	if _cheapest_price() > budget:
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


func _reset_stall_slots() -> void:
	stall_slots = []
	for _index in range(GameState.get_stall_slot_count()):
		stall_slots.append({})


func _sanitize_prepared_slots(prepared_slots: Array) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var max_slots := GameState.get_stall_slot_count()
	for entry in prepared_slots:
		if result.size() >= max_slots:
			break
		if typeof(entry) != TYPE_DICTIONARY:
			continue
		var slot: Dictionary = entry
		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))
		if item_id.is_empty() or count <= 0 or not ConfigLoader.is_sellable_item(item_id):
			continue
		result.append({
			"item_id": item_id,
			"count": count,
			"price": clampi(int(slot.get("price", ConfigLoader.get_base_sell_price(item_id))), PrototypeConstants.MIN_APPLE_PRICE, PrototypeConstants.MAX_APPLE_PRICE),
		})
	while result.size() < max_slots:
		result.append({})
	return result


func _stock_total(slots_to_count: Array) -> int:
	var total := 0
	for slot in slots_to_count:
		if typeof(slot) == TYPE_DICTIONARY:
			total += int((slot as Dictionary).get("count", 0))
	return total


func _first_stock_slot() -> Dictionary:
	for index in range(stall_slots.size()):
		var slot: Dictionary = stall_slots[index]
		if not slot.is_empty() and int(slot.get("count", 0)) > 0:
			var copy := slot.duplicate()
			copy["slot_index"] = index
			return copy
	return {}


func _cheapest_stock_slot() -> Dictionary:
	var best_slot: Dictionary = {}
	var best_price := INF
	for index in range(stall_slots.size()):
		var slot: Dictionary = stall_slots[index]
		if slot.is_empty() or int(slot.get("count", 0)) <= 0:
			continue
		var slot_price := int(slot.get("price", ConfigLoader.get_base_sell_price(str(slot.get("item_id", "")))))
		if slot_price < best_price:
			best_price = slot_price
			best_slot = slot.duplicate()
			best_slot["slot_index"] = index
	return best_slot


func _cheapest_price() -> int:
	var cheapest := _cheapest_stock_slot()
	if cheapest.is_empty():
		return 0
	return int(cheapest.get("price", 0))


func _decision_for_slot(slot: Dictionary, reason: String) -> Dictionary:
	return {
		"bought": true,
		"reason": reason,
		"item_id": str(slot.get("item_id", current_item_id)),
		"price": int(slot.get("price", price)),
		"slot_index": int(slot.get("slot_index", 0)),
	}


func _is_valid_stall_slot(index: int) -> bool:
	return index >= 0 and index < stall_slots.size() and not stall_slots[index].is_empty()


func _visible_stall_slots() -> Array:
	var result := []
	for slot in stall_slots:
		result.append(slot.duplicate() if typeof(slot) == TYPE_DICTIONARY else {})
	return result


func _can_return_all_stock() -> bool:
	var simulated_slots: Array[Dictionary] = []
	for slot in Inventory.get_slots_with_empty():
		simulated_slots.append(slot.duplicate())
	for slot in stall_slots:
		if slot.is_empty():
			continue
		if not _simulate_insert_all(simulated_slots, str(slot.get("item_id", "")), int(slot.get("count", 0))):
			return false
	return true


func _simulate_insert_all(simulated_slots: Array[Dictionary], item_id: String, amount: int) -> bool:
	var remaining := amount
	var stack_size := ConfigLoader.get_stack_size(item_id)
	for index in range(simulated_slots.size()):
		if remaining <= 0:
			return true
		var slot: Dictionary = simulated_slots[index]
		if str(slot.get("item_id", "")) != item_id:
			continue
		var space := stack_size - int(slot.get("count", 0))
		if space <= 0:
			continue
		var added := mini(space, remaining)
		slot["count"] = int(slot.get("count", 0)) + added
		simulated_slots[index] = slot
		remaining -= added
	for index in range(simulated_slots.size()):
		if remaining <= 0:
			return true
		if not simulated_slots[index].is_empty():
			continue
		var added := mini(stack_size, remaining)
		simulated_slots[index] = {"item_id": item_id, "count": added}
		remaining -= added
	return remaining <= 0
