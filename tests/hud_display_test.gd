extends Node


func _ready() -> void:
	var hud_script: Script = load("res://scripts/ui/hud.gd")
	var hud := CanvasLayer.new()
	hud.set_script(hud_script)
	add_child(hud)
	await get_tree().process_frame

	var label_texts := _collect_label_texts(hud)
	_assert_true(not _contains_text(label_texts, "背包苹果"), "HUD 左上角不应显示背包苹果数量")
	_assert_true(not _contains_text(label_texts, "苹果种子"), "HUD 左上角不应显示苹果种子数量")
	_assert_true(not _contains_text(label_texts, "当前手持"), "HUD 不应再显示当前手持文案")
	_assert_hud_mouse_passthrough(hud)
	SignalBus.interaction_prompt_changed.emit("左键：开垦土地")
	await get_tree().process_frame
	label_texts = _collect_label_texts(hud)
	_assert_true(_contains_text(label_texts, "左键：开垦土地"), "鼠标农作提示不应被 HUD 自动加上 E 前缀")

	hud.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _collect_label_texts(root: Node) -> Array[String]:
	var result: Array[String] = []
	for child in root.find_children("*", "Label", true, false):
		var label := child as Label
		result.append(label.text)
	return result


func _contains_text(texts: Array[String], pattern: String) -> bool:
	for text in texts:
		if text.contains(pattern):
			return true
	return false


func _assert_hud_mouse_passthrough(root: Node) -> void:
	for child in root.find_children("*", "Control", true, false):
		var control := child as Control
		if str(control.name).begins_with("Hotbar"):
			continue
		_assert_true(control.mouse_filter == Control.MOUSE_FILTER_IGNORE, "%s 不应拦截鼠标事件" % control.name)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
