extends Area2D

var customer: Node = null


func _ready() -> void:
	add_to_group("interactable")


func get_prompt() -> String:
	return "确认卖苹果"


func interact(player: Node) -> void:
	if customer != null and is_instance_valid(customer) and customer.has_method("confirm_purchase"):
		customer.call("confirm_purchase", player)
