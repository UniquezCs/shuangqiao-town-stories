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


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
