extends CanvasLayer

const InventorySlotControl := preload("res://scripts/ui/inventory_slot_control.gd")
const BACKPACK_PANEL_TEXTURE_PATH := "res://assets/generated/sprites/ui/panels/backpack_panel_360x420.png"
const STALL_PANEL_TEXTURE_PATH := "res://assets/generated/sprites/ui/panels/stall_panel_420x520.png"

var _panel: Control
var _setup_backpack_panel: PanelContainer
var _stall_panel: PanelContainer
var _backpack_grid: GridContainer
var _stall_grid: GridContainer
var _title: Label
var _summary: Label
var _dialog: PanelContainer
var _dialog_title: Label
var _amount_label: Label
var _amount_spin: SpinBox
var _price_label: Label
var _price_spin: SpinBox
var _dragging_backpack := false
var _dragging_stall := false

var _stall_spot: Node = null
var _stall_slots: Array[Dictionary] = []
var _pending_transfer: Dictionary = {}


func _ready() -> void:
	_build_ui()
	SignalBus.backpack_changed.connect(_on_backpack_changed)
	hide_panel()


func _unhandled_input(event: InputEvent) -> void:
	if _panel.visible and event.is_action_pressed("ui_cancel"):
		cancel_setup()
		get_viewport().set_input_as_handled()


func open_for_stall(stall_spot: Node) -> void:
	if _panel.visible:
		if not cancel_setup():
			return
	_stall_spot = stall_spot
	_stall_slots = []
	for _index in range(GameState.get_stall_slot_count()):
		_stall_slots.append({})
	_panel.visible = true
	_dialog.visible = false
	_refresh()


func hide_panel() -> void:
	if _panel != null:
		_panel.visible = false
	if _dialog != null:
		_dialog.visible = false


func cancel_setup() -> bool:
	if not _return_all_stall_slots():
		return false
	hide_panel()
	return true


func can_drop_slot_data(data: Variant, target_container: String, target_index: int) -> bool:
	if typeof(data) != TYPE_DICTIONARY:
		return false
	var drag_data: Dictionary = data
	var source := str(drag_data.get("source", ""))
	if target_container == "backpack":
		if source == "backpack":
			return true
		if source == "stall":
			var backpack_slot: Dictionary = drag_data.get("slot", {})
			return Inventory.can_insert_to_slot(target_index, str(backpack_slot.get("item_id", "")), int(backpack_slot.get("count", 0)))
		return false
	if target_container != "stall":
		return false
	if target_index < 0 or target_index >= _stall_slots.size():
		return false
	if source == "backpack":
		var slot: Dictionary = drag_data.get("slot", {})
		return _stall_slots[target_index].is_empty() and ConfigLoader.is_sellable_item(str(slot.get("item_id", "")))
	return source == "stall"


func handle_slot_drop(data: Variant, target_container: String, target_index: int) -> void:
	if not can_drop_slot_data(data, target_container, target_index):
		return
	var drag_data: Dictionary = data
	var source := str(drag_data.get("source", ""))
	if source == "backpack" and target_container == "backpack":
		Inventory.move_slot(int(drag_data.get("slot_index", -1)), target_index)
		_refresh()
	elif source == "backpack" and target_container == "stall":
		_begin_backpack_to_stall_transfer(drag_data, target_index)
	elif source == "stall" and target_container == "backpack":
		_move_stall_to_backpack(int(drag_data.get("slot_index", -1)), target_index)
	elif source == "stall" and target_container == "stall":
		_move_stall_slot(int(drag_data.get("slot_index", -1)), target_index)


func start_stall() -> void:
	if _stock_total(_stall_slots) <= 0:
		SignalBus.sale_feedback.emit("摊位上没有商品", Vector2.ZERO)
		return
	if _stall_spot == null or not is_instance_valid(_stall_spot):
		if _return_all_stall_slots():
			hide_panel()
		return
	if _stall_spot.has_method("open_stall_with_slots") and bool(_stall_spot.call("open_stall_with_slots", _stall_slots)):
		hide_panel()


func _build_ui() -> void:
	_panel = Control.new()
	_panel.name = "StallSetupRoot"
	add_child(_panel)

	_build_setup_backpack_panel()
	_build_stall_goods_panel()
	_build_transfer_dialog()


func _build_setup_backpack_panel() -> void:
	_setup_backpack_panel = PanelContainer.new()
	_setup_backpack_panel.name = "SetupBackpackPanel"
	_setup_backpack_panel.position = Vector2(300, 76)
	_setup_backpack_panel.custom_minimum_size = Vector2(360, 420)
	_apply_panel_style(_setup_backpack_panel, BACKPACK_PANEL_TEXTURE_PATH)
	_panel.add_child(_setup_backpack_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	_setup_backpack_panel.add_child(margin)

	var backpack_box := VBoxContainer.new()
	margin.add_child(backpack_box)

	var backpack_title := Label.new()
	backpack_title.text = "背包"
	backpack_title.mouse_filter = Control.MOUSE_FILTER_STOP
	backpack_title.gui_input.connect(_on_backpack_drag_handle_gui_input)
	backpack_box.add_child(backpack_title)

	_backpack_grid = GridContainer.new()
	_backpack_grid.columns = 4
	backpack_box.add_child(_backpack_grid)


func _build_stall_goods_panel() -> void:
	_stall_panel = PanelContainer.new()
	_stall_panel.name = "StallGoodsPanel"
	_stall_panel.position = Vector2(700, 76)
	_stall_panel.custom_minimum_size = Vector2(420, 520)
	_apply_panel_style(_stall_panel, STALL_PANEL_TEXTURE_PATH)
	_panel.add_child(_stall_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	_stall_panel.add_child(margin)

	var root_box := VBoxContainer.new()
	root_box.add_theme_constant_override("separation", 8)
	margin.add_child(root_box)

	_title = Label.new()
	_title.text = "摆摊准备"
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.gui_input.connect(_on_stall_drag_handle_gui_input)
	root_box.add_child(_title)

	_stall_grid = GridContainer.new()
	_stall_grid.columns = 4
	root_box.add_child(_stall_grid)

	_summary = Label.new()
	_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root_box.add_child(_summary)

	var buttons := HBoxContainer.new()
	root_box.add_child(buttons)

	var start_button := Button.new()
	start_button.text = "开始营业"
	start_button.pressed.connect(start_stall)
	buttons.add_child(start_button)

	var cancel_button := Button.new()
	cancel_button.text = "取消"
	cancel_button.pressed.connect(cancel_setup)
	buttons.add_child(cancel_button)


func _build_transfer_dialog() -> void:
	_dialog = PanelContainer.new()
	_dialog.position = Vector2(690, 210)
	_dialog.custom_minimum_size = Vector2(260, 190)
	add_child(_dialog)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	_dialog.add_child(margin)

	var box := VBoxContainer.new()
	margin.add_child(box)
	_dialog_title = Label.new()
	box.add_child(_dialog_title)

	_amount_label = Label.new()
	_amount_label.text = "数量"
	box.add_child(_amount_label)
	_amount_spin = SpinBox.new()
	_amount_spin.min_value = 1
	_amount_spin.step = 1
	box.add_child(_amount_spin)

	_price_label = Label.new()
	_price_label.text = "单价"
	box.add_child(_price_label)
	_price_spin = SpinBox.new()
	_price_spin.min_value = PrototypeConstants.MIN_APPLE_PRICE
	_price_spin.max_value = PrototypeConstants.MAX_APPLE_PRICE
	_price_spin.step = 1
	box.add_child(_price_spin)

	var buttons := HBoxContainer.new()
	box.add_child(buttons)
	var confirm := Button.new()
	confirm.text = "确认"
	confirm.pressed.connect(_confirm_transfer)
	buttons.add_child(confirm)
	var cancel := Button.new()
	cancel.text = "取消"
	cancel.pressed.connect(func() -> void:
		_pending_transfer = {}
		_dialog.visible = false
	)
	buttons.add_child(cancel)


func _refresh() -> void:
	_title.text = "摆摊准备：%d 件" % _stock_total(_stall_slots)
	_summary.text = "拖拽背包农产品到摊位格，选择数量和单价后开始营业；摊位等级决定商品格数"
	for child in _backpack_grid.get_children():
		child.queue_free()
	for child in _stall_grid.get_children():
		child.queue_free()

	var backpack_slots := Inventory.get_slots_with_empty()
	for index in range(backpack_slots.size()):
		var slot := InventorySlotControl.new()
		slot.setup(self, "backpack", index, backpack_slots[index])
		_backpack_grid.add_child(slot)

	for index in range(_stall_slots.size()):
		var slot := InventorySlotControl.new()
		slot.setup(self, "stall", index, _stall_slots[index])
		_stall_grid.add_child(slot)


func _on_backpack_changed(_slots: Array, _slot_count: int) -> void:
	if _panel != null and _panel.visible:
		_refresh()


func get_panel_position() -> Vector2:
	return _panel.position if _panel != null else Vector2.ZERO


func move_panel_by(delta: Vector2) -> void:
	move_backpack_panel_by(delta)
	move_stall_panel_by(delta)
	if _dialog != null:
		_dialog.position += delta


func get_backpack_panel_position() -> Vector2:
	return _setup_backpack_panel.position if _setup_backpack_panel != null else Vector2.ZERO


func get_stall_panel_position() -> Vector2:
	return _stall_panel.position if _stall_panel != null else Vector2.ZERO


func move_backpack_panel_by(delta: Vector2) -> void:
	if _setup_backpack_panel == null:
		return
	_setup_backpack_panel.position += delta


func move_stall_panel_by(delta: Vector2) -> void:
	if _stall_panel == null:
		return
	_stall_panel.position += delta


func _on_backpack_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_backpack = event.pressed
		get_viewport().set_input_as_handled()
	elif _dragging_backpack and event is InputEventMouseMotion:
		move_backpack_panel_by(event.relative)
		get_viewport().set_input_as_handled()


func _on_stall_drag_handle_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		_dragging_stall = event.pressed
		get_viewport().set_input_as_handled()
	elif _dragging_stall and event is InputEventMouseMotion:
		move_stall_panel_by(event.relative)
		get_viewport().set_input_as_handled()


func _apply_panel_style(panel: PanelContainer, texture_path: String) -> void:
	if panel == null or not ResourceLoader.exists(texture_path):
		return
	var texture := load(texture_path) as Texture2D
	if texture == null:
		return
	var stylebox := StyleBoxTexture.new()
	stylebox.texture = texture
	panel.add_theme_stylebox_override("panel", stylebox)


func _begin_backpack_to_stall_transfer(drag_data: Dictionary, target_index: int) -> void:
	var source_index := int(drag_data.get("slot_index", -1))
	var source_slot: Dictionary = drag_data.get("slot", {})
	var item_id := str(source_slot.get("item_id", ""))
	var max_amount := int(source_slot.get("count", 0))
	if source_index < 0 or max_amount <= 0:
		return
	_pending_transfer = {
		"source_index": source_index,
		"target_index": target_index,
		"item_id": item_id,
	}
	_dialog_title.text = "上架 %s" % ConfigLoader.get_item_name(item_id)
	_amount_spin.max_value = max_amount
	_amount_spin.value = max_amount
	_price_spin.value = ConfigLoader.get_base_sell_price(item_id)
	_dialog.visible = true


func _confirm_transfer() -> void:
	if _pending_transfer.is_empty():
		return
	var source_index := int(_pending_transfer.get("source_index", -1))
	var target_index := int(_pending_transfer.get("target_index", -1))
	var item_id := str(_pending_transfer.get("item_id", ""))
	var amount := int(_amount_spin.value)
	var price := int(_price_spin.value)
	var removed := Inventory.remove_from_slot(source_index, amount)
	if int(removed.get("count", 0)) != amount:
		if int(removed.get("count", 0)) > 0:
			Inventory.add_item(str(removed.get("item_id", "")), int(removed.get("count", 0)))
		_pending_transfer = {}
		_dialog.visible = false
		return
	_stall_slots[target_index] = {
		"item_id": item_id,
		"count": amount,
		"price": price,
	}
	_pending_transfer = {}
	_dialog.visible = false
	_refresh()


func _move_stall_to_backpack(source_index: int, target_index: int) -> void:
	if source_index < 0 or source_index >= _stall_slots.size():
		return
	var slot: Dictionary = _stall_slots[source_index]
	if slot.is_empty():
		return
	if not Inventory.insert_to_slot(target_index, str(slot.get("item_id", "")), int(slot.get("count", 0))):
		SignalBus.sale_feedback.emit("这个背包格放不下", Vector2.ZERO)
		return
	_stall_slots[source_index] = {}
	_refresh()


func _move_stall_slot(source_index: int, target_index: int) -> void:
	if source_index < 0 or target_index < 0 or source_index >= _stall_slots.size() or target_index >= _stall_slots.size():
		return
	if source_index == target_index:
		return
	var source: Dictionary = _stall_slots[source_index]
	if source.is_empty():
		return
	var target: Dictionary = _stall_slots[target_index]
	if target.is_empty():
		_stall_slots[target_index] = source
		_stall_slots[source_index] = {}
	elif str(source.get("item_id", "")) == str(target.get("item_id", "")) and int(source.get("price", 0)) == int(target.get("price", 0)):
		target["count"] = int(target.get("count", 0)) + int(source.get("count", 0))
		_stall_slots[target_index] = target
		_stall_slots[source_index] = {}
	else:
		_stall_slots[target_index] = source
		_stall_slots[source_index] = target
	_refresh()


func _return_all_stall_slots() -> bool:
	var returned_all := true
	for index in range(_stall_slots.size()):
		var slot: Dictionary = _stall_slots[index]
		if slot.is_empty():
			continue
		if Inventory.add_item(str(slot.get("item_id", "")), int(slot.get("count", 0))):
			_stall_slots[index] = {}
		else:
			returned_all = false
	if not returned_all:
		SignalBus.sale_feedback.emit("背包空间不够，无法全部退回", Vector2.ZERO)
		_refresh()
	return returned_all


func _stock_total(slots_to_count: Array) -> int:
	var total := 0
	for slot in slots_to_count:
		if typeof(slot) == TYPE_DICTIONARY:
			total += int((slot as Dictionary).get("count", 0))
	return total
