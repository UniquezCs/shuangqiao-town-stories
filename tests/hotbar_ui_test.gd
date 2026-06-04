extends Node

const HotbarPanelScript := preload("res://scripts/ui/hotbar_panel.gd")


func _ready() -> void:
	GameState.reset_game()
	var panel := HotbarPanelScript.new()
	add_child(panel)
	await get_tree().process_frame

	var slots := panel.find_children("HotbarSlot*", "PanelContainer", true, false)
	_assert_equal(slots.size(), 9, "快捷栏 HUD 应显示 9 个格子")
	_assert_equal(_slot_key_text(slots[0] as Node), "1", "第一个快捷栏格左上角应显示数字 1")
	_assert_equal(_slot_key_text(slots[8] as Node), "9", "第九个快捷栏格左上角应显示数字 9")
	_assert_true(_slot_has_green_border(slots[0] as Control), "当前选中的第 1 格应显示绿色边框")
	_assert_true(not _slot_has_count_label(slots[0] as Node), "数量为 1 的工具不应显示数量")

	Hotbar.put_slot(4, {"item_id": PrototypeConstants.ITEM_APPLE_SEED, "count": 4})
	await get_tree().process_frame
	slots = panel.find_children("HotbarSlot*", "PanelContainer", true, false)
	_assert_equal(_slot_count_text(slots[4] as Node), "4", "数量大于 1 的快捷栏物品应在右下角显示数量")

	Hotbar.select_slot(4)
	await get_tree().process_frame
	slots = panel.find_children("HotbarSlot*", "PanelContainer", true, false)
	_assert_true(_slot_has_green_border(slots[4] as Control), "按数字选中后对应快捷栏格应显示绿色边框")

	get_tree().quit()


func _slot_key_text(slot: Node) -> String:
	var label := slot.get_node_or_null("HotbarKeyLabel") as Label
	return "" if label == null else label.text


func _slot_count_text(slot: Node) -> String:
	var label := slot.get_node_or_null("HotbarCountLabel") as Label
	return "" if label == null else label.text


func _slot_has_count_label(slot: Node) -> bool:
	return slot.get_node_or_null("HotbarCountLabel") != null


func _slot_has_green_border(slot: Control) -> bool:
	var stylebox := slot.get_theme_stylebox("panel") as StyleBoxFlat
	if stylebox == null:
		return false
	return stylebox.border_color.g > 0.8 and stylebox.border_color.r < 0.4


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
