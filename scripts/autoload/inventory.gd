extends Node

var slot_count := 8
var slots: Array[Dictionary] = []


func reset_items() -> void:
	slot_count = _configured_slot_count()
	slots = []
	_ensure_slot_array()
	add_item(PrototypeConstants.ITEM_APPLE_SEED, 1)
	add_item(PrototypeConstants.ITEM_APPLE, 1)
	add_item(PrototypeConstants.ITEM_PEAR, 1)
	_emit_backpack_changed()
	_emit_known_item_counts()


func to_save_data() -> Dictionary:
	return {
		"slot_count": slot_count,
		"slots": get_slots_with_empty(),
	}


func apply_save_data(data: Dictionary) -> void:
	slot_count = maxi(1, int(data.get("slot_count", _configured_slot_count())))
	slots = []
	var saved_slots: Variant = data.get("slots", [])
	if typeof(saved_slots) == TYPE_ARRAY:
		for saved_slot in saved_slots:
			if typeof(saved_slot) == TYPE_DICTIONARY:
				var item_id := str((saved_slot as Dictionary).get("item_id", ""))
				var count := int((saved_slot as Dictionary).get("count", 0))
				if not item_id.is_empty() and count > 0:
					slots.append({"item_id": item_id, "count": count})
				else:
					slots.append({})
	_ensure_slot_array()
	_emit_backpack_changed()
	_emit_known_item_counts()


func configure_slot_count(count: int) -> void:
	slot_count = maxi(1, count)
	while slots.size() > slot_count:
		var overflow: Dictionary = slots.pop_back()
		if int(overflow.get("count", 0)) > 0:
			push_warning("背包缩小时丢弃了物品：%s x%s" % [overflow.get("item_id", ""), overflow.get("count", 0)])
	_ensure_slot_array()
	_emit_backpack_changed()


func get_count(item_id: String) -> int:
	var total := 0
	for slot in slots:
		if str(slot.get("item_id", "")) == item_id:
			total += int(slot.get("count", 0))
	return total


func add_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	_ensure_slot_array()
	if not can_add_item(item_id, amount):
		return false
	var remaining := amount
	var stack_size := ConfigLoader.get_stack_size(item_id)
	for index in range(slots.size()):
		var slot: Dictionary = slots[index]
		if str(slot.get("item_id", "")) == item_id and int(slot.get("count", 0)) < stack_size:
			var space := stack_size - int(slot.get("count", 0))
			var added := mini(space, remaining)
			slot["count"] = int(slot.get("count", 0)) + added
			slots[index] = slot
			remaining -= added
			if remaining <= 0:
				_emit_item_changed(item_id)
				return true
	for index in range(slots.size()):
		if remaining <= 0:
			break
		if not slots[index].is_empty():
			continue
		var added := mini(stack_size, remaining)
		slots[index] = {"item_id": item_id, "count": added}
		remaining -= added
	if remaining > 0:
		_emit_item_changed(item_id)
		return false
	_emit_item_changed(item_id)
	return true


func can_add_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	_ensure_slot_array()
	var remaining := amount
	var stack_size := ConfigLoader.get_stack_size(item_id)
	for slot in slots:
		if str(slot.get("item_id", "")) == item_id:
			remaining -= maxi(0, stack_size - int(slot.get("count", 0)))
			if remaining <= 0:
				return true
	var empty_slots := 0
	for slot in slots:
		if slot.is_empty():
			empty_slots += 1
	remaining -= empty_slots * stack_size
	return remaining <= 0


func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_count(item_id) < amount:
		return false
	var remaining := amount
	for index in range(slots.size() - 1, -1, -1):
		var slot: Dictionary = slots[index]
		if str(slot.get("item_id", "")) != item_id:
			continue
		var removed := mini(int(slot.get("count", 0)), remaining)
		slot["count"] = int(slot.get("count", 0)) - removed
		remaining -= removed
		if int(slot.get("count", 0)) <= 0:
			slots[index] = {}
		else:
			slots[index] = slot
		if remaining <= 0:
			break
	_emit_item_changed(item_id)
	return true


func set_count(item_id: String, amount: int) -> void:
	for index in range(slots.size() - 1, -1, -1):
		if str(slots[index].get("item_id", "")) == item_id:
			slots[index] = {}
	if amount > 0:
		add_item(item_id, amount)
	else:
		_emit_item_changed(item_id)


func get_slots_with_empty() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	_ensure_slot_array()
	for slot in slots:
		result.append(slot.duplicate())
	return result


func occupied_slot_count() -> int:
	var count := 0
	for slot in slots:
		if not slot.is_empty():
			count += 1
	return count


func move_slot(from_index: int, to_index: int) -> bool:
	_ensure_slot_array()
	if not _is_valid_slot_index(from_index) or not _is_valid_slot_index(to_index):
		return false
	if from_index == to_index:
		return true
	var source: Dictionary = slots[from_index]
	if source.is_empty():
		return false
	var target: Dictionary = slots[to_index]
	var changed_items: Array[String] = [str(source.get("item_id", ""))]
	if target.is_empty():
		slots[to_index] = source
		slots[from_index] = {}
		_emit_items_changed(changed_items)
		return true

	var source_item := str(source.get("item_id", ""))
	var target_item := str(target.get("item_id", ""))
	if not changed_items.has(target_item):
		changed_items.append(target_item)

	if source_item == target_item:
		var stack_size := ConfigLoader.get_stack_size(source_item)
		var space := stack_size - int(target.get("count", 0))
		if space <= 0:
			return false
		var moved := mini(space, int(source.get("count", 0)))
		target["count"] = int(target.get("count", 0)) + moved
		source["count"] = int(source.get("count", 0)) - moved
		slots[to_index] = target
		slots[from_index] = source if int(source.get("count", 0)) > 0 else {}
		_emit_items_changed(changed_items)
		return true

	slots[from_index] = target
	slots[to_index] = source
	_emit_items_changed(changed_items)
	return true


func remove_from_slot(index: int, amount: int) -> Dictionary:
	_ensure_slot_array()
	if amount <= 0 or not _is_valid_slot_index(index):
		return {}
	var slot: Dictionary = slots[index]
	if slot.is_empty():
		return {}
	var item_id := str(slot.get("item_id", ""))
	var removed := mini(int(slot.get("count", 0)), amount)
	slot["count"] = int(slot.get("count", 0)) - removed
	slots[index] = slot if int(slot.get("count", 0)) > 0 else {}
	_emit_item_changed(item_id)
	return {"item_id": item_id, "count": removed}


func can_insert_to_slot(index: int, item_id: String, amount: int) -> bool:
	_ensure_slot_array()
	if amount <= 0 or not _is_valid_slot_index(index):
		return false
	var slot: Dictionary = slots[index]
	if slot.is_empty():
		return true
	if str(slot.get("item_id", "")) != item_id:
		return false
	return int(slot.get("count", 0)) + amount <= ConfigLoader.get_stack_size(item_id)


func insert_to_slot(index: int, item_id: String, amount: int) -> bool:
	_ensure_slot_array()
	if amount <= 0 or not _is_valid_slot_index(index):
		return false
	var slot: Dictionary = slots[index]
	if slot.is_empty():
		slots[index] = {"item_id": item_id, "count": amount}
		_emit_item_changed(item_id)
		return true
	if str(slot.get("item_id", "")) == item_id:
		var stack_size := ConfigLoader.get_stack_size(item_id)
		if int(slot.get("count", 0)) + amount > stack_size:
			return false
		slot["count"] = int(slot.get("count", 0)) + amount
		slots[index] = slot
		_emit_item_changed(item_id)
		return true
	return false


func get_first_sellable_item_id() -> String:
	for slot in slots:
		var item_id := str(slot.get("item_id", ""))
		if ConfigLoader.is_sellable_item(item_id) and int(slot.get("count", 0)) > 0:
			return item_id
	return ""


func _configured_slot_count() -> int:
	if Engine.has_singleton("GameState"):
		return GameState.get_backpack_slot_count()
	var entry := ConfigLoader.get_upgrade_entry("backpack", 1)
	return int(entry.get("slots", 8))


func _ensure_slot_array() -> void:
	while slots.size() < slot_count:
		slots.append({})
	while slots.size() > slot_count:
		slots.pop_back()


func _is_valid_slot_index(index: int) -> bool:
	return index >= 0 and index < slot_count


func _emit_item_changed(item_id: String) -> void:
	SignalBus.inventory_changed.emit(item_id, get_count(item_id))
	_emit_backpack_changed()


func _emit_items_changed(item_ids: Array[String]) -> void:
	var emitted := {}
	for item_id in item_ids:
		if item_id.is_empty() or emitted.has(item_id):
			continue
		emitted[item_id] = true
		SignalBus.inventory_changed.emit(item_id, get_count(item_id))
	_emit_backpack_changed()


func _emit_backpack_changed() -> void:
	SignalBus.backpack_changed.emit(get_slots_with_empty(), slot_count)


func _emit_known_item_counts() -> void:
	for item_id in ConfigLoader.items.keys():
		SignalBus.inventory_changed.emit(str(item_id), get_count(str(item_id)))
