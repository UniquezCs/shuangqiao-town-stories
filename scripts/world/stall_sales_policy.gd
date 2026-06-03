extends RefCounted

const StallInventory := preload("res://scripts/world/stall_inventory.gd")


static func can_sell_to(is_open: bool, stock: int, stall_slots: Array, current_item_id: String, current_price: int, customer_type: String, customer_profile: Dictionary = {}) -> Dictionary:
	if not is_open or stock <= 0:
		return {"bought": false, "reason": "没货了"}
	if not customer_profile.is_empty():
		return _profile_decision(stall_slots, current_item_id, customer_type, customer_profile)
	var cheapest_slot := StallInventory.cheapest_stock_slot(stall_slots)
	var item_name := ConfigLoader.get_item_name(str(cheapest_slot.get("item_id", current_item_id)))
	var slot_price := int(cheapest_slot.get("price", current_price))
	if customer_type == PrototypeConstants.CUSTOMER_STUDENT:
		if slot_price <= 2:
			return _decision_for_slot(cheapest_slot, current_item_id, current_price, "学生买下%s" % item_name)
		if slot_price == 3:
			return {"bought": false, "reason": "学生觉得有点贵"}
		return {"bought": false, "reason": "学生买不起"}
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		if slot_price <= 4:
			return _decision_for_slot(cheapest_slot, current_item_id, current_price, "工人买下%s" % item_name)
		return {"bought": false, "reason": "工人觉得贵"}
	return {"bought": false, "reason": "顾客离开"}


static func _profile_decision(stall_slots: Array, current_item_id: String, customer_type: String, customer_profile: Dictionary) -> Dictionary:
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
		return _decision_for_slot(best_slot, current_item_id, ConfigLoader.get_base_sell_price(item_id), "%s买下%s" % [customer_label, ConfigLoader.get_item_name(item_id)])
	if not wanted_any:
		return {"bought": false, "reason": "%s暂时不想买这些商品" % customer_label}
	if StallInventory.cheapest_price(stall_slots) > budget:
		return {"bought": false, "reason": "%s预算不够" % customer_label}
	return {"bought": false, "reason": "%s觉得不划算" % customer_label}


static func _default_budget_for(customer_type: String) -> int:
	if customer_type == PrototypeConstants.CUSTOMER_WORKER:
		return 4
	return 2


static func _decision_for_slot(slot: Dictionary, current_item_id: String, current_price: int, reason: String) -> Dictionary:
	return {
		"bought": true,
		"reason": reason,
		"item_id": str(slot.get("item_id", current_item_id)),
		"price": int(slot.get("price", current_price)),
		"slot_index": int(slot.get("slot_index", 0)),
	}
