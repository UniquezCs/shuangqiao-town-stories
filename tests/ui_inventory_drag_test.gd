extends Node

const BackpackPanelScript := preload("res://scripts/ui/backpack_panel.gd")
const StallSetupPanelScript := preload("res://scripts/ui/stall_setup_panel.gd")
const InventorySlotControl := preload("res://scripts/ui/inventory_slot_control.gd")


func _ready() -> void:
	var backpack_slot := InventorySlotControl.new()
	backpack_slot.setup(self, "backpack", 0, {})
	add_child(backpack_slot)
	await get_tree().process_frame
	_assert_slot_texture(backpack_slot, "res://assets/generated/sprites/ui/slots/backpack_slot_78x72.png", "背包格应使用背包 UI 贴图")

	var stall_slot := InventorySlotControl.new()
	stall_slot.setup(self, "stall", 0, {})
	add_child(stall_slot)
	await get_tree().process_frame
	_assert_slot_texture(stall_slot, "res://assets/generated/sprites/ui/slots/stall_slot_78x72.png", "摊位格应使用摊位 UI 贴图")

	var backpack_panel := CanvasLayer.new()
	backpack_panel.set_script(BackpackPanelScript)
	add_child(backpack_panel)
	await get_tree().process_frame
	var backpack_position: Vector2 = backpack_panel.call("get_panel_position")
	backpack_panel.call("move_panel_by", Vector2(32, 18))
	_assert_equal(backpack_panel.call("get_panel_position"), backpack_position + Vector2(32, 18), "背包面板应能被拖动改变位置")
	_assert_panel_texture(
		backpack_panel.get("_panel") as Control,
		"res://assets/generated/sprites/ui/panels/backpack_panel_360x420.png",
		"背包面板应使用背包背景 UI 贴图"
	)

	var stall_panel := CanvasLayer.new()
	stall_panel.set_script(StallSetupPanelScript)
	add_child(stall_panel)
	await get_tree().process_frame
	stall_panel.call("open_for_stall", null)
	var setup_backpack_position: Vector2 = stall_panel.call("get_backpack_panel_position")
	var setup_stall_position: Vector2 = stall_panel.call("get_stall_panel_position")
	stall_panel.call("move_backpack_panel_by", Vector2(-24, 36))
	_assert_equal(stall_panel.call("get_backpack_panel_position"), setup_backpack_position + Vector2(-24, 36), "摆摊准备里的背包面板应能独立拖动")
	_assert_equal(stall_panel.call("get_stall_panel_position"), setup_stall_position, "拖动摆摊准备里的背包面板不应移动摊位面板")
	stall_panel.call("move_stall_panel_by", Vector2(42, -12))
	_assert_equal(stall_panel.call("get_stall_panel_position"), setup_stall_position + Vector2(42, -12), "摆摊准备里的摊位面板应能独立拖动")
	_assert_panel_texture(
		stall_panel.get("_setup_backpack_panel") as Control,
		"res://assets/generated/sprites/ui/panels/backpack_panel_360x420.png",
		"摆摊准备里的背包面板应使用背包背景 UI 贴图"
	)
	_assert_panel_texture(
		stall_panel.get("_stall_panel") as Control,
		"res://assets/generated/sprites/ui/panels/stall_panel_420x520.png",
		"摆摊准备里的摊位面板应使用摊位背景 UI 贴图"
	)
	_assert_equal((stall_panel.get("_amount_label") as Label).text, "数量", "上架弹窗的第一个数字应标注为数量")
	_assert_equal((stall_panel.get("_price_label") as Label).text, "单价", "上架弹窗的第二个数字应标注为单价")

	get_tree().quit()


func _assert_slot_texture(slot: Control, expected_path: String, message: String) -> void:
	var stylebox := slot.get_theme_stylebox("panel") as StyleBoxTexture
	if stylebox == null:
		push_error("%s：没有 StyleBoxTexture" % message)
		get_tree().quit(1)
		return
	var texture := stylebox.texture
	if texture == null or texture.resource_path != expected_path:
		push_error("%s。实际：%s，期望：%s" % [message, texture.resource_path if texture != null else "null", expected_path])
		get_tree().quit(1)


func _assert_panel_texture(panel: Control, expected_path: String, message: String) -> void:
	if panel == null:
		push_error("%s：面板不存在" % message)
		get_tree().quit(1)
		return
	var stylebox := panel.get_theme_stylebox("panel") as StyleBoxTexture
	if stylebox == null:
		push_error("%s：没有 StyleBoxTexture" % message)
		get_tree().quit(1)
		return
	var texture := stylebox.texture
	if texture == null or texture.resource_path != expected_path:
		push_error("%s。实际：%s，期望：%s" % [message, texture.resource_path if texture != null else "null", expected_path])
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
