extends Node2D

const StallInventory := preload("res://scripts/world/stall_inventory.gd")
const StallRuntimeNodes := preload("res://scripts/world/stall_runtime_nodes.gd")
const StallSalesPolicy := preload("res://scripts/world/stall_sales_policy.gd")
const GameplayDebugLog := preload("res://scripts/debug/gameplay_debug_log.gd")
const STALL_EMPTY_TEXTURE := preload("res://assets/generated/sprites/props/stall/01_stall_empty.png")
const STOCK_ICON_SPACING := 20.0
const STOCK_ICON_SIZE := Vector2(18, 18)

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
var _stock_overlay: Node2D = null

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
	GameplayDebugLog.log("stall", "open", {
		"spot_id": spot_id,
		"stock": stock,
		"slots": _visible_stall_slots(),
	})
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
	GameplayDebugLog.log("stall", "close", {
		"spot_id": spot_id,
		"returned": returned,
	})
	GameState.set_objective("可以换点摆摊，或回家买种子")
	_remove_influence_area()
	_remove_inspection_target()
	_remove_player_boundary()
	_refresh_visual()
	return true


func can_sell_to(customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	return StallSalesPolicy.can_sell_to(is_open, stock, stall_slots, current_item_id, price, customer_type, customer_profile)


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
	GameplayDebugLog.log("stall", "customer_decision", {
		"customer_type": customer_type,
		"bought": bool(decision["bought"]),
		"reason": str(decision["reason"]),
		"item_id": str(decision.get("item_id", "")),
		"price": int(decision.get("price", 0)),
		"stock": stock,
	})
	SignalBus.customer_decision.emit(customer_type, bool(decision["bought"]), str(decision["reason"]))
	return decision


func _create_influence_area() -> void:
	if _influence_area != null and is_instance_valid(_influence_area):
		return
	_influence_area = StallRuntimeNodes.create_influence_area(self, influence_radius, _on_influence_body_entered, _on_influence_body_exited)


func _remove_influence_area() -> void:
	if _influence_area == null or not is_instance_valid(_influence_area):
		_influence_area = null
		return
	StallRuntimeNodes.remove_runtime_node(_influence_area)
	_influence_area = null


func _create_inspection_target() -> void:
	if _inspection_target != null and is_instance_valid(_inspection_target):
		return
	_inspection_target = StallRuntimeNodes.create_inspection_target(self, influence_radius)


func _remove_inspection_target() -> void:
	if _inspection_target == null or not is_instance_valid(_inspection_target):
		_inspection_target = null
		return
	StallRuntimeNodes.remove_runtime_node(_inspection_target)
	_inspection_target = null


func _create_player_boundary() -> void:
	if _player_boundary != null and is_instance_valid(_player_boundary):
		return
	_player_boundary = StallRuntimeNodes.create_player_boundary(self)


func _remove_player_boundary() -> void:
	if _player_boundary == null or not is_instance_valid(_player_boundary):
		_player_boundary = null
		return
	StallRuntimeNodes.remove_runtime_node(_player_boundary)
	_player_boundary = null


func _on_influence_body_entered(body: Node) -> void:
	if is_open and body.has_method("enter_stall_influence"):
		body.call("enter_stall_influence", self)


func _on_influence_body_exited(body: Node) -> void:
	if body.has_method("exit_stall_influence"):
		body.call("exit_stall_influence", self)


func _refresh_visual() -> void:
	visual.texture = STALL_EMPTY_TEXTURE
	_refresh_stock_overlay()


func _refresh_stock_overlay() -> void:
	var overlay := _ensure_stock_overlay()
	for child in overlay.get_children():
		child.free()
	var display_entries := _stock_display_entries()
	overlay.visible = is_open and not display_entries.is_empty()
	if not overlay.visible:
		return
	for index in range(display_entries.size()):
		_add_stock_overlay_item(overlay, display_entries[index], Vector2(index * STOCK_ICON_SPACING, 0))


func _ensure_stock_overlay() -> Node2D:
	if _stock_overlay != null and is_instance_valid(_stock_overlay):
		return _stock_overlay
	_stock_overlay = Node2D.new()
	_stock_overlay.name = "StockOverlay"
	_stock_overlay.position = visual.position + Vector2(-30, 8)
	_stock_overlay.z_index = visual.z_index
	add_child(_stock_overlay)
	return _stock_overlay


func _stock_display_entries() -> Array[Dictionary]:
	var totals := {}
	var order: Array[String] = []
	for slot in stall_slots:
		if slot.is_empty():
			continue
		var item_id := str(slot.get("item_id", ""))
		var count := int(slot.get("count", 0))
		if item_id.is_empty() or count <= 0:
			continue
		if not totals.has(item_id):
			totals[item_id] = 0
			order.append(item_id)
		totals[item_id] = int(totals[item_id]) + count
	var result: Array[Dictionary] = []
	for item_id in order:
		result.append({"item_id": item_id, "count": int(totals[item_id])})
	return result


func _add_stock_overlay_item(parent: Node2D, entry: Dictionary, local_position: Vector2) -> void:
	var item_root := Node2D.new()
	item_root.name = "StockItem%d" % parent.get_child_count()
	item_root.position = local_position
	parent.add_child(item_root)

	var item_id := str(entry.get("item_id", ""))
	var icon_texture := _load_item_icon(item_id)
	if icon_texture != null:
		var icon := Sprite2D.new()
		icon.name = "Icon"
		icon.texture = icon_texture
		icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var texture_size := icon_texture.get_size()
		if texture_size.x > 0 and texture_size.y > 0:
			icon.scale = Vector2(STOCK_ICON_SIZE.x / texture_size.x, STOCK_ICON_SIZE.y / texture_size.y)
		item_root.add_child(icon)

	var count_label := Label.new()
	count_label.name = "CountLabel"
	count_label.text = "x%d" % int(entry.get("count", 0))
	count_label.position = Vector2(-12, 9)
	count_label.size = Vector2(24, 14)
	count_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	count_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	count_label.add_theme_font_size_override("font_size", 10)
	item_root.add_child(count_label)


func _load_item_icon(item_id: String) -> Texture2D:
	var icon_path := ConfigLoader.get_item_icon(item_id)
	if icon_path.is_empty() or not ResourceLoader.exists(icon_path):
		return null
	return load(icon_path) as Texture2D


func _reset_stall_slots() -> void:
	stall_slots = StallInventory.reset_slots(GameState.get_stall_slot_count())


func _sanitize_prepared_slots(prepared_slots: Array) -> Array[Dictionary]:
	return StallInventory.sanitize_prepared_slots(prepared_slots, GameState.get_stall_slot_count())


func _stock_total(slots_to_count: Array) -> int:
	return StallInventory.stock_total(slots_to_count)


func _first_stock_slot() -> Dictionary:
	return StallInventory.first_stock_slot(stall_slots)


func _is_valid_stall_slot(index: int) -> bool:
	return index >= 0 and index < stall_slots.size() and not stall_slots[index].is_empty()


func _visible_stall_slots() -> Array:
	return StallInventory.visible_slots(stall_slots)


func _can_return_all_stock() -> bool:
	return StallInventory.can_return_all_stock(stall_slots, Inventory.get_slots_with_empty())
