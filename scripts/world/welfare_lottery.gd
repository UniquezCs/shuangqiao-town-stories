extends Area2D

@export var ticket_path := NodePath("../LotteryTicket")


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	var ticket := _ticket_node()
	if ticket != null and ticket.has_method("get_prompt_text"):
		return str(ticket.call("get_prompt_text"))
	return "彩票店"


func interact(_player: Node) -> void:
	var ticket := _ticket_node()
	if ticket == null:
		SignalBus.sale_feedback.emit("彩票店还没开张", global_position)
		return
	if ticket.has_method("resolve_pending_if_due"):
		ticket.call("resolve_pending_if_due")
	SignalBus.lottery_panel_requested.emit(ticket)


func _ticket_node() -> Node:
	return get_node_or_null(ticket_path)
