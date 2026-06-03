extends RefCounted


static func reset_slots(slot_count: int) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for _index in range(slot_count):
		slots.append({})
	return slots


static func sanitize_prepared_slots(prepared_slots: Array, max_slots: int) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
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


static func stock_total(slots_to_count: Array) -> int:
	var total := 0
	for slot in slots_to_count:
		if typeof(slot) == TYPE_DICTIONARY:
			total += int((slot as Dictionary).get("count", 0))
	return total


static func first_stock_slot(stall_slots: Array) -> Dictionary:
	for index in range(stall_slots.size()):
		var slot: Dictionary = stall_slots[index]
		if not slot.is_empty() and int(slot.get("count", 0)) > 0:
			var copy := slot.duplicate()
			copy["slot_index"] = index
			return copy
	return {}


static func cheapest_stock_slot(stall_slots: Array) -> Dictionary:
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


static func cheapest_price(stall_slots: Array) -> int:
	var cheapest := cheapest_stock_slot(stall_slots)
	if cheapest.is_empty():
		return 0
	return int(cheapest.get("price", 0))


static func visible_slots(stall_slots: Array) -> Array:
	var result := []
	for slot in stall_slots:
		result.append(slot.duplicate() if typeof(slot) == TYPE_DICTIONARY else {})
	return result


static func can_return_all_stock(stall_slots: Array, inventory_slots: Array) -> bool:
	var simulated_slots: Array[Dictionary] = []
	for slot in inventory_slots:
		if typeof(slot) == TYPE_DICTIONARY:
			simulated_slots.append((slot as Dictionary).duplicate())
	for slot in stall_slots:
		if typeof(slot) != TYPE_DICTIONARY or (slot as Dictionary).is_empty():
			continue
		if not _simulate_insert_all(simulated_slots, str((slot as Dictionary).get("item_id", "")), int((slot as Dictionary).get("count", 0))):
			return false
	return true


static func _simulate_insert_all(simulated_slots: Array[Dictionary], item_id: String, amount: int) -> bool:
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
