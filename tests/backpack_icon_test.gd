extends Node

const BackpackPanelScript := preload("res://scripts/ui/backpack_panel.gd")
const APPLE_ICON_PATH := "res://assets/generated/assistant_art_2026_05_29/crop_icons/items/apple_32.png"


func _ready() -> void:
	ConfigLoader.load_all()
	_assert_equal(ConfigLoader.get_item_icon(PrototypeConstants.ITEM_APPLE), APPLE_ICON_PATH, "苹果配置应指向新切出的图标")
	_assert_true(ResourceLoader.exists(APPLE_ICON_PATH), "苹果图标资源应存在")

	GameState.reset_game()
	Inventory.set_count(PrototypeConstants.ITEM_APPLE_SEED, 0)
	Inventory.set_count(PrototypeConstants.ITEM_APPLE, 3)

	var backpack := CanvasLayer.new()
	backpack.set_script(BackpackPanelScript)
	add_child(backpack)
	await get_tree().process_frame
	backpack.call("open")
	await get_tree().process_frame

	_assert_true(_has_icon(backpack, APPLE_ICON_PATH), "背包苹果格应显示苹果图标")
	_assert_true(not _has_label_text(backpack, "苹果"), "背包苹果格不应再用文字显示物品名")
	get_tree().quit()


func _has_icon(root: Node, texture_path: String) -> bool:
	for child in root.find_children("", "TextureRect", true, false):
		var rect := child as TextureRect
		if rect.texture != null and rect.texture.resource_path == texture_path:
			return true
	return false


func _has_label_text(root: Node, text: String) -> bool:
	for child in root.find_children("", "Label", true, false):
		var label := child as Label
		if label.text.contains(text):
			return true
	return false


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
