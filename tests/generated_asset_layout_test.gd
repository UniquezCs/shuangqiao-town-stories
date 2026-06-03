extends Node

const GENERATED_DIR := "res://assets/generated"
const ALLOWED_TOP_LEVEL_DIRS := ["sprites", "tilesets"]
const ALLOWED_EXTENSIONS := ["import", "png", "tres"]
const DISALLOWED_DIR_NAMES := ["raw", "processed", "references", "direction_gifs", "direction_strips"]
const DISALLOWED_FILE_NAMES := [".DS_Store", "manifest.json", "contact_sheet.png"]
const REQUIRED_CROP_TEXTURE_STATES := ["tilled", "seed_dry", "seed_watered", "growing_dry", "growing_watered", "ready"]


func _ready() -> void:
	_assert_generated_top_level_is_clean()
	_assert_generated_files_are_final_assets(GENERATED_DIR)
	_assert_configured_item_icons_exist()
	_assert_seed_shop_crop_textures_exist()
	get_tree().quit()


func _assert_generated_top_level_is_clean() -> void:
	var dir := DirAccess.open(GENERATED_DIR)
	_assert_true(dir != null, "assets/generated 目录必须存在")

	var top_level_files := []
	var top_level_dirs := []
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.begins_with(".") and entry != ".DS_Store":
			entry = dir.get_next()
			continue
		if dir.current_is_dir():
			top_level_dirs.append(entry)
		else:
			top_level_files.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()

	top_level_dirs.sort()
	_assert_equal(top_level_dirs, ALLOWED_TOP_LEVEL_DIRS, "assets/generated 顶层只能保留 sprites 和 tilesets 两个目录")
	_assert_true(top_level_files.is_empty(), "assets/generated 顶层不应保留文件：%s" % str(top_level_files))


func _assert_generated_files_are_final_assets(dir_path: String) -> void:
	var dir := DirAccess.open(dir_path)
	_assert_true(dir != null, "无法读取目录：%s" % dir_path)

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_assert_true(not DISALLOWED_DIR_NAMES.has(entry), "generated 中不应保留中间过程目录：%s" % path)
			_assert_generated_files_are_final_assets(path)
		else:
			_assert_true(not DISALLOWED_FILE_NAMES.has(entry), "generated 中不应保留中间过程文件：%s" % path)
			_assert_true(not entry.ends_with(".json"), "generated 中不应保留生成清单或临时 JSON：%s" % path)
			_assert_true(not entry.ends_with(".txt"), "generated 中不应保留生成提示或临时文本：%s" % path)
			_assert_true(not entry.ends_with(".gif"), "generated 中不应保留预览 GIF：%s" % path)
			_assert_true(ALLOWED_EXTENSIONS.has(entry.get_extension()), "generated 中只保留可直接用于游戏的 PNG/TRES 及 Godot import 元数据：%s" % path)
		entry = dir.get_next()
	dir.list_dir_end()


func _assert_configured_item_icons_exist() -> void:
	for item_id in ConfigLoader.items.keys():
		var icon_path := ConfigLoader.get_item_icon(str(item_id))
		_assert_true(not icon_path.is_empty(), "物品 %s 必须配置 icon，避免 UI 静默缺图" % item_id)
		_assert_resource_path_exists(icon_path, "物品 %s 的 icon 路径无效" % item_id)


func _assert_seed_shop_crop_textures_exist() -> void:
	for crop_id in ConfigLoader.crops.keys():
		var crop: Dictionary = ConfigLoader.crops[crop_id]
		if not bool(crop.get("seed_shop_enabled", false)):
			continue
		var textures: Dictionary = crop.get("state_textures", {})
		for state in REQUIRED_CROP_TEXTURE_STATES:
			var texture_path := str(textures.get(state, ""))
			_assert_true(not texture_path.is_empty(), "种子商店作物 %s 必须配置 %s 状态贴图，避免回退到苹果" % [crop_id, state])
			_assert_resource_path_exists(texture_path, "种子商店作物 %s 的 %s 状态贴图路径无效" % [crop_id, state])


func _assert_resource_path_exists(path: String, message: String) -> void:
	_assert_true(path.begins_with("res://"), "%s：%s 不是 res:// 路径" % [message, path])
	_assert_true(FileAccess.file_exists(path) or ResourceLoader.exists(path), "%s：%s" % [message, path])


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
