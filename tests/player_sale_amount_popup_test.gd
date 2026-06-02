extends Node

const PLAYER_SCENE := preload("res://scenes/player.tscn")


func _ready() -> void:
	var player := PLAYER_SCENE.instantiate()
	add_child(player)
	await get_tree().process_frame

	SignalBus.sale_completed.emit("pear", 4, 0)
	await get_tree().process_frame

	var popup := player.get_node_or_null("SaleAmountPopup") as Label
	_assert_true(popup != null, "成交后玩家头顶应生成金额飘字 Label")
	_assert_equal(popup.text, "+4 元", "金额飘字应显示本次成交金额")
	_assert_true(popup.position.y < 0.0, "金额飘字应出现在玩家头顶")

	player.queue_free()
	await get_tree().process_frame
	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
