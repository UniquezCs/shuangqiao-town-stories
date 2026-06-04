extends Node

var slot_count := 9
var slots: Array[Dictionary] = []
var selected_index := 0


func reset_slots() -> void:
	selected_index = 0
	slots = []
	for _index in range(slot_count):
		slots.append({})
	slots[0] = {"item_id": PrototypeConstants.ITEM_WATERING_CAN, "count": 1}
	slots[1] = {"item_id": PrototypeConstants.ITEM_HOE, "count": 1}
	slots[2] = {"item_id": PrototypeConstants.ITEM_SICKLE, "count": 1}
	_apply_selected_item()
	_emit_changed()


func to_save_data() -> Dictionary:
	return {
		"slot_count": slot_count,
		"selected_index": selected_index,
		"slots": get_slots_with_empty(),
	}


func apply_save_data(data: Dictionary) -> void:
	if data.is_empty():
		reset_slots()
		return
	slot_count = maxi(1, int(data.get("slot_count", 9)))
	selected_index = clampi(int(data.get("selected_index", 0)), 0, slot_count - 1)
	slots = []
	var saved_slots: Variant = data.get("slots", [])
	if typeof(saved_slots) == TYPE_ARRAY:
		for saved_slot in saved_slots:
			if typeof(saved_slot) != TYPE_DICTIONARY:
				slots.append({})
				continue
			var slot: Dictionary = saved_slot
			var item_id := str(slot.get("item_id", ""))
			var count := int(slot.get("count", 0))
			if item_id.is_empty() or count <= 0:
				slots.append({})
			else:
				slots.append({"item_id": item_id, "count": count})
	_ensure_slot_array()
	_apply_selected_item()
	_emit_changed()


func get_slots_with_empty() -> Array[Dictionary]:
	_ensure_slot_array()
	var result: Array[Dictionary] = []
	for slot in slots:
		result.append(slot.duplicate())
	return result


func select_slot(index: int) -> bool:
	if not _is_valid_slot_index(index):
		return false
	if selected_index == index:
		_apply_selected_item()
		_emit_changed()
		return true
	selected_index = index
	_apply_selected_item()
	_emit_changed()
	return true


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
	if target.is_empty():
		slots[to_index] = source
		slots[from_index] = {}
	elif str(source.get("item_id", "")) == str(target.get("item_id", "")):
		var item_id := str(source.get("item_id", ""))
		var stack_size := ConfigLoader.get_stack_size(item_id)
		var space := stack_size - int(target.get("count", 0))
		if space <= 0:
			return false
		var moved := mini(space, int(source.get("count", 0)))
		target["count"] = int(target.get("count", 0)) + moved
		source["count"] = int(source.get("count", 0)) - moved
		slots[to_index] = target
		slots[from_index] = source if int(source.get("count", 0)) > 0 else {}
	else:
		slots[to_index] = source
		slots[from_index] = target
	if selected_index == from_index:
		selected_index = to_index
	elif selected_index == to_index:
		selected_index = from_index
	_apply_selected_item()
	_emit_changed()
	return true


func take_slot(index: int) -> Dictionary:
	_ensure_slot_array()
	if not _is_valid_slot_index(index):
		return {}
	var slot: Dictionary = slots[index]
	if slot.is_empty():
		return {}
	slots[index] = {}
	_apply_selected_item()
	_emit_changed()
	return slot.duplicate()


func get_selected_slot() -> Dictionary:
	_ensure_slot_array()
	return slots[selected_index].duplicate()


func get_selected_item_id() -> String:
	var slot := get_selected_slot()
	return str(slot.get("item_id", ""))


func remove_from_selected(amount: int) -> Dictionary:
	_ensure_slot_array()
	if amount <= 0:
		return {}
	var slot: Dictionary = slots[selected_index]
	if slot.is_empty():
		return {}
	var removed := mini(int(slot.get("count", 0)), amount)
	var item_id := str(slot.get("item_id", ""))
	slot["count"] = int(slot.get("count", 0)) - removed
	slots[selected_index] = slot if int(slot.get("count", 0)) > 0 else {}
	_apply_selected_item()
	_emit_changed()
	return {"item_id": item_id, "count": removed}


func put_slot(index: int, incoming_slot: Dictionary) -> Dictionary:
	_ensure_slot_array()
	if not _is_valid_slot_index(index) or incoming_slot.is_empty():
		return incoming_slot.duplicate()
	var incoming := incoming_slot.duplicate()
	var incoming_item := str(incoming.get("item_id", ""))
	var incoming_count := int(incoming.get("count", 0))
	if incoming_item.is_empty() or incoming_count <= 0:
		return {}
	var target: Dictionary = slots[index]
	if target.is_empty():
		slots[index] = {"item_id": incoming_item, "count": incoming_count}
		_apply_selected_item()
		_emit_changed()
		return {}
	if str(target.get("item_id", "")) == incoming_item:
		var stack_size := ConfigLoader.get_stack_size(incoming_item)
		var space := stack_size - int(target.get("count", 0))
		if space <= 0:
			return incoming
		var moved := mini(space, incoming_count)
		target["count"] = int(target.get("count", 0)) + moved
		incoming_count -= moved
		slots[index] = target
		_apply_selected_item()
		_emit_changed()
		if incoming_count <= 0:
			return {}
		incoming["count"] = incoming_count
		return incoming
	slots[index] = {"item_id": incoming_item, "count": incoming_count}
	_apply_selected_item()
	_emit_changed()
	return target.duplicate()


func transfer_inventory_to_hotbar(inventory_index: int, hotbar_index: int) -> bool:
	var source := Inventory.take_slot(inventory_index)
	if source.is_empty():
		return false
	var returned := put_slot(hotbar_index, source)
	if not returned.is_empty():
		Inventory.put_slot(inventory_index, returned)
	return true


func transfer_hotbar_to_inventory(hotbar_index: int, inventory_index: int) -> bool:
	var source := take_slot(hotbar_index)
	if source.is_empty():
		return false
	var returned := Inventory.put_slot(inventory_index, source)
	if not returned.is_empty():
		put_slot(hotbar_index, returned)
	return true


func _ensure_slot_array() -> void:
	while slots.size() < slot_count:
		slots.append({})
	while slots.size() > slot_count:
		slots.pop_back()
	selected_index = clampi(selected_index, 0, slot_count - 1)


func _is_valid_slot_index(index: int) -> bool:
	return index >= 0 and index < slot_count


func _apply_selected_item() -> void:
	_ensure_slot_array()
	var slot: Dictionary = slots[selected_index]
	var item_id := str(slot.get("item_id", ""))
	var tool_id := "" if item_id.is_empty() else ConfigLoader.get_tool_for_item(item_id)
	GameState.set_current_tool(tool_id)


func _emit_changed() -> void:
	SignalBus.hotbar_changed.emit(get_slots_with_empty(), selected_index)
