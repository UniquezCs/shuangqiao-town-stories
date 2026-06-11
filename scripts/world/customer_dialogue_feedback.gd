extends Node

const CustomerDialogueLines := preload("res://scripts/world/customer_dialogue_lines.gd")
const CustomerDialogueBubble := preload("res://scripts/world/customer_dialogue_bubble.gd")

var _host: Node = null
var _customer_profile: Dictionary = {}
var _rng: RandomNumberGenerator = null
var _dialogue_bubble: Node2D = null
var _seen_stall_dialogue_ids := {}
var _dialogue_chance_overrides := {}


func configure(host: Node, customer_profile: Dictionary, rng: RandomNumberGenerator) -> void:
	_host = host
	_customer_profile = customer_profile
	_rng = rng


func set_customer_profile(customer_profile: Dictionary) -> void:
	_customer_profile = customer_profile


func show_dialogue(event: String, item_id: String, price: int, reason: String) -> void:
	if not _should_trigger(event):
		return
	var normalized_item_id := item_id
	if normalized_item_id.is_empty():
		normalized_item_id = PrototypeConstants.ITEM_APPLE
	var bubble := _ensure_bubble()
	if bubble == null:
		return
	var text := CustomerDialogueLines.line_for(event, _customer_profile, normalized_item_id, price, reason, _rng)
	if bubble.has_method("show_line"):
		bubble.call("show_line", text)


func maybe_show_stall_seen(stall: Node, item: Dictionary) -> void:
	if stall == null or not is_instance_valid(stall) or item.is_empty():
		return
	var stall_id := stall.get_instance_id()
	if _seen_stall_dialogue_ids.has(stall_id):
		return
	_seen_stall_dialogue_ids[stall_id] = true
	show_dialogue(CustomerDialogueLines.EVENT_SEE_STALL, str(item.get("item_id", "")), int(item.get("price", 0)), "")


func get_current_text() -> String:
	if _dialogue_bubble == null or not is_instance_valid(_dialogue_bubble) or not _dialogue_bubble.has_method("get_text"):
		return ""
	return str(_dialogue_bubble.call("get_text"))


func set_chance_override(event: String, chance: float) -> void:
	_dialogue_chance_overrides[event] = clampf(chance, 0.0, 1.0)


func _should_trigger(event: String) -> bool:
	var chance := float(_dialogue_chance_overrides.get(event, CustomerDialogueLines.trigger_chance_for(event)))
	if _rng == null:
		return chance >= 1.0
	return _rng.randf() <= clampf(chance, 0.0, 1.0)


func _ensure_bubble() -> Node2D:
	if _dialogue_bubble != null and is_instance_valid(_dialogue_bubble):
		return _dialogue_bubble
	if _host == null or not is_instance_valid(_host):
		return null
	_dialogue_bubble = Node2D.new()
	_dialogue_bubble.name = "DialogueBubble"
	_dialogue_bubble.set_script(CustomerDialogueBubble)
	_host.add_child(_dialogue_bubble)
	return _dialogue_bubble
