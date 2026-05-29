extends Node

const TOWN_SCENE := preload("res://scenes/town_scene.tscn")


func _ready() -> void:
	var town := TOWN_SCENE.instantiate()
	add_child(town)
	await get_tree().process_frame

	for endpoint_name in ["ResidentialArea", "SchoolSpot", "FactorySpot"]:
		var visual := town.get_node("%s/Visual" % endpoint_name) as Sprite2D
		_assert_true(visual.texture != null, "%s 的 Visual 应保留地图显示纹理" % endpoint_name)
		_assert_true(visual.visible, "%s 的 Visual 应可见" % endpoint_name)
		_assert_true(visual.is_visible_in_tree(), "%s 的 Visual 应在场景树中可见" % endpoint_name)

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
