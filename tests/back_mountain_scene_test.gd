extends Node

const MAIN_SCENE := preload("res://scenes/main.tscn")
const HOME_SCENE := preload("res://scenes/home_scene.tscn")
const BACK_MOUNTAIN_SCENE_PATH := "res://scenes/back_mountain_scene.tscn"
const BACK_MOUNTAIN_ASSET_DIR := "res://assets/generated/sprites/locations/back_mountain"


func _ready() -> void:
	var scene_exists := ResourceLoader.exists(BACK_MOUNTAIN_SCENE_PATH)
	var full_map_exists := ResourceLoader.exists("%s/back_mountain_full_4096.png" % BACK_MOUNTAIN_ASSET_DIR)
	_assert_true(scene_exists, "应存在后山场景")
	_assert_true(full_map_exists, "应保留 4096 后山完整参考图")

	var expected_chunks := {
		"Chunk00": {
			"path": "%s/back_mountain_chunk_0_0_1024.png" % BACK_MOUNTAIN_ASSET_DIR,
			"position": Vector2(512, 512),
		},
		"Chunk10": {
			"path": "%s/back_mountain_chunk_1_0_1024.png" % BACK_MOUNTAIN_ASSET_DIR,
			"position": Vector2(1536, 512),
		},
		"Chunk01": {
			"path": "%s/back_mountain_chunk_0_1_1024.png" % BACK_MOUNTAIN_ASSET_DIR,
			"position": Vector2(512, 1536),
		},
		"Chunk11": {
			"path": "%s/back_mountain_chunk_1_1_1024.png" % BACK_MOUNTAIN_ASSET_DIR,
			"position": Vector2(1536, 1536),
		},
	}
	for chunk_name in expected_chunks.keys():
		_assert_true(ResourceLoader.exists(expected_chunks[chunk_name]["path"]), "应存在后山背景块：%s" % expected_chunks[chunk_name]["path"])
	if not scene_exists:
		return

	var back_scene := load(BACK_MOUNTAIN_SCENE_PATH) as PackedScene
	var back_mountain := back_scene.instantiate()
	add_child(back_mountain)
	await get_tree().process_frame

	var blocks := back_mountain.get_node_or_null("BackgroundBlocks") as Node2D
	_assert_true(blocks != null, "后山场景应包含 BackgroundBlocks")
	for chunk_name in expected_chunks.keys():
		var sprite := blocks.get_node_or_null(chunk_name) as Sprite2D
		_assert_true(sprite != null, "BackgroundBlocks 应包含 %s" % chunk_name)
		_assert_true(sprite.texture != null, "%s 应绑定背景块贴图" % chunk_name)
		_assert_equal(sprite.texture.resource_path, expected_chunks[chunk_name]["path"], "%s 应使用正确背景块资源" % chunk_name)
		_assert_equal(sprite.position, expected_chunks[chunk_name]["position"], "%s 应按 2x2 背景块位置拼接" % chunk_name)
		_assert_equal(sprite.scale, Vector2.ONE, "%s 应以原生 1024x1024 尺寸显示，不能缩放导致模糊或缩小" % chunk_name)
		_assert_equal(sprite.z_index, -100, "%s 应位于玩家和交互节点下方" % chunk_name)

	_assert_true(back_mountain.get_node_or_null("Spawns/from_home") != null, "后山应提供从 Home 进入的出生点")
	var to_home := back_mountain.get_node_or_null("ToHome")
	_assert_true(to_home != null, "后山应提供返回 Home 的传送点")
	_assert_equal(str(to_home.get("target_scene")), PrototypeConstants.SCENE_HOME, "后山出口应返回 Home")
	_assert_equal(str(to_home.get("spawn_id")), "back_mountain_spawn", "后山出口应回到 Home 上方入口")

	var home := HOME_SCENE.instantiate()
	add_child(home)
	await get_tree().process_frame
	var to_back_mountain := home.get_node_or_null("ToBackMountain")
	_assert_true(to_back_mountain != null, "Home 上方应提供前往后山的传送点")
	_assert_equal(str(to_back_mountain.get("target_scene")), PrototypeConstants.SCENE_BACK_MOUNTAIN, "Home 上方传送点应进入后山")
	_assert_equal(str(to_back_mountain.get("spawn_id")), "from_home", "Home 上方传送点应使用后山入口出生点")
	_assert_true(home.get_node_or_null("Spawns/back_mountain_spawn") != null, "Home 应提供后山返回出生点")

	var main := MAIN_SCENE.instantiate()
	add_child(main)
	await get_tree().process_frame
	var packed_scene := main.call("_scene_for_id", PrototypeConstants.SCENE_BACK_MOUNTAIN) as PackedScene
	_assert_true(packed_scene != null and packed_scene.resource_path == BACK_MOUNTAIN_SCENE_PATH, "Main 应能根据 back_mountain 加载后山场景")

	get_tree().quit()


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
