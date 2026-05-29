extends Node

var slot_count := 8
var slots: Array[Dictionary] = []


func reset_items() -> void:
	slot_count = _configured_slot_count()
	slots = []
	add_item(PrototypeConstants.ITEM_APPLE_SEED, 1)
	_emit_backpack_changed()
	_emit_known_item_counts()


func configure_slot_count(count: int) -> void:
	slot_count = maxi(1, count)
	while slots.size() > slot_count:
		var overflow: Dictionary = slots.pop_back()
		if int(overflow.get("count", 0)) > 0:
			push_warning("背包缩小时丢弃了物品：%s x%s" % [overflow.get("item_id", ""), overflow.get("count", 0)])
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
	if not can_add_item(item_id, amount):
		return false
	var remaining := amount
	var stack_size := ConfigLoader.get_stack_size(item_id)
	for slot in slots:
		if str(slot.get("item_id", "")) == item_id and int(slot.get("count", 0)) < stack_size:
			var space := stack_size - int(slot.get("count", 0))
			var added := mini(space, remaining)
			slot["count"] = int(slot.get("count", 0)) + added
			remaining -= added
			if remaining <= 0:
				_emit_item_changed(item_id)
				return true
	while remaining > 0 and slots.size() < slot_count:
		var added := mini(stack_size, remaining)
		slots.append({"item_id": item_id, "count": added})
		remaining -= added
	if remaining > 0:
		_emit_item_changed(item_id)
		return false
	_emit_item_changed(item_id)
	return true


func can_add_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	var remaining := amount
	var stack_size := ConfigLoader.get_stack_size(item_id)
	for slot in slots:
		if str(slot.get("item_id", "")) == item_id:
			remaining -= maxi(0, stack_size - int(slot.get("count", 0)))
			if remaining <= 0:
				return true
	var empty_slots := slot_count - slots.size()
	remaining -= empty_slots * stack_size
	return remaining <= 0


func remove_item(item_id: String, amount: int) -> bool:
	if amount <= 0:
		return true
	if get_count(item_id) < amount:
		return false
	var remaining := amount
	for index in range(slots.size() - 1, -1, -1):
		var slot := slots[index]
		if str(slot.get("item_id", "")) != item_id:
			continue
		var removed := mini(int(slot.get("count", 0)), remaining)
		slot["count"] = int(slot.get("count", 0)) - removed
		remaining -= removed
		if int(slot.get("count", 0)) <= 0:
			slots.remove_at(index)
		if remaining <= 0:
			break
	_emit_item_changed(item_id)
	return true


func set_count(item_id: String, amount: int) -> void:
	for index in range(slots.size() - 1, -1, -1):
		if str(slots[index].get("item_id", "")) == item_id:
			slots.remove_at(index)
	if amount > 0:
		add_item(item_id, amount)
	else:
		_emit_item_changed(item_id)


func get_slots_with_empty() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for slot in slots:
		result.append(slot.duplicate())
	for _index in range(maxi(0, slot_count - slots.size())):
		result.append({})
	return result


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


func _emit_item_changed(item_id: String) -> void:
	SignalBus.inventory_changed.emit(item_id, get_count(item_id))
	_emit_backpack_changed()


func _emit_backpack_changed() -> void:
	SignalBus.backpack_changed.emit(get_slots_with_empty(), slot_count)


func _emit_known_item_counts() -> void:
	for item_id in ConfigLoader.items.keys():
		SignalBus.inventory_changed.emit(str(item_id), get_count(str(item_id)))
