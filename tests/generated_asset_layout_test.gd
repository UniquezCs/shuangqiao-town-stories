extends Node

const GENERATED_DIR := "res://assets/generated"
const CONFIG_DIR := "res://configs"
const ALLOWED_TOP_LEVEL_DIRS := ["sprites", "tilesets"]
const ALLOWED_EXTENSIONS := ["import", "png", "tres"]
const DISALLOWED_DIR_NAMES := ["raw", "processed", "references", "direction_gifs", "direction_strips"]
const DISALLOWED_FILE_NAMES := [".DS_Store", "manifest.json", "contact_sheet.png"]
const REQUIRED_CROP_TEXTURE_STATES := ["tilled", "seed_dry", "seed_watered", "growing_dry", "growing_watered", "ready"]


func _ready() -> void:
	_assert_config_json_files_parse()
	_assert_generated_top_level_is_clean()
	_assert_generated_files_are_final_assets(GENERATED_DIR)
	_assert_generated_assets_are_registered()
	_assert_registered_resource_paths_exist()
	_assert_registered_map_assets_have_stage()
	_assert_non_runtime_map_assets_are_not_wired_into_scenes()
	_assert_configured_item_icons_exist()
	_assert_seed_shop_crop_textures_exist()
	get_tree().quit()


func _assert_config_json_files_parse() -> void:
	var dir := DirAccess.open(CONFIG_DIR)
	_assert_true(dir != null, "configs 目录必须存在")

	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir() and entry.ends_with(".json"):
			var path := "%s/%s" % [CONFIG_DIR, entry]
			var text := FileAccess.get_file_as_string(path)
			var parser := JSON.new()
			var error := parser.parse(text)
			_assert_equal(error, OK, "配置 JSON 必须可解析：%s，%s" % [path, parser.get_error_message()])
			_assert_equal(typeof(parser.data), TYPE_DICTIONARY, "配置 JSON 顶层必须是 Dictionary：%s" % path)
		entry = dir.get_next()
	dir.list_dir_end()


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


func _assert_generated_assets_are_registered() -> void:
	var registered_paths := {}
	_collect_generated_paths(ConfigLoader.assets, registered_paths)
	var missing := []
	_collect_unregistered_generated_assets(GENERATED_DIR, registered_paths, missing)
	missing.sort()
	_assert_true(missing.is_empty(), "generated 中存在未写入 configs/assets.json 的最终资源：%s" % str(missing))


func _assert_registered_resource_paths_exist() -> void:
	var paths := {}
	_collect_res_paths(ConfigLoader.assets, paths)
	var missing := []
	for path in paths.keys():
		if not _resource_or_directory_exists(str(path)):
			missing.append(path)
	missing.sort()
	_assert_true(missing.is_empty(), "configs/assets.json 中存在无效 res:// 路径：%s" % str(missing))


func _assert_registered_map_assets_have_stage() -> void:
	var missing_stage := []
	var invalid_stage := []
	_collect_map_asset_stage_issues(ConfigLoader.assets, missing_stage, invalid_stage)
	missing_stage.sort()
	invalid_stage.sort()
	_assert_true(missing_stage.is_empty(), "地图资源必须登记 map_stage：%s" % str(missing_stage))
	_assert_true(invalid_stage.is_empty(), "地图资源 map_stage 只能是 runtime/candidate/trial：%s" % str(invalid_stage))


func _assert_non_runtime_map_assets_are_not_wired_into_scenes() -> void:
	var non_runtime_paths := {}
	_collect_non_runtime_map_paths(ConfigLoader.assets, non_runtime_paths)
	if non_runtime_paths.is_empty():
		return

	var scene_files := _collect_files_with_extension("res://scenes", "tscn")
	var scene_text_by_path := {}
	for scene_path in scene_files:
		scene_text_by_path[scene_path] = FileAccess.get_file_as_string(scene_path)

	var wired := []
	for path in non_runtime_paths.keys():
		for scene_path in scene_files:
			if str(scene_text_by_path[scene_path]).contains(str(path)):
				wired.append("%s -> %s" % [path, scene_path])
	wired.sort()
	_assert_true(wired.is_empty(), "candidate/trial 地图资源不能直接挂载到场景：%s" % str(wired))


func _collect_generated_paths(value: Variant, out_paths: Dictionary) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for child in (value as Dictionary).values():
				_collect_generated_paths(child, out_paths)
		TYPE_ARRAY:
			for child in value:
				_collect_generated_paths(child, out_paths)
		TYPE_STRING:
			var path := str(value)
			if path.begins_with("res://assets/generated/"):
				out_paths[path] = true


func _collect_res_paths(value: Variant, out_paths: Dictionary) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for child in (value as Dictionary).values():
				_collect_res_paths(child, out_paths)
		TYPE_ARRAY:
			for child in value:
				_collect_res_paths(child, out_paths)
		TYPE_STRING:
			var path := str(value)
			if path.begins_with("res://"):
				out_paths[path] = true


func _collect_map_asset_stage_issues(value: Variant, missing_stage: Array, invalid_stage: Array) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var dict := value as Dictionary
	var path := str(dict.get("path", ""))
	if path.begins_with("res://assets/generated/sprites/map/"):
		var stage := str(dict.get("map_stage", ""))
		if stage.is_empty():
			missing_stage.append(path)
		elif not ["runtime", "candidate", "trial"].has(stage):
			invalid_stage.append("%s: %s" % [path, stage])
	for child in dict.values():
		_collect_map_asset_stage_issues(child, missing_stage, invalid_stage)


func _collect_non_runtime_map_paths(value: Variant, out_paths: Dictionary) -> void:
	if typeof(value) != TYPE_DICTIONARY:
		return
	var dict := value as Dictionary
	for key in dict.keys():
		var child = dict[key]
		if typeof(child) != TYPE_DICTIONARY:
			_collect_non_runtime_map_paths(child, out_paths)
			continue
		var child_dict := child as Dictionary
		var stage := str(child_dict.get("map_stage", ""))
		if not stage.is_empty() and stage != "runtime":
			var path := str(child_dict.get("path", ""))
			if path.begins_with("res://assets/generated/sprites/map/"):
				out_paths[path] = true
		_collect_non_runtime_map_paths(child_dict, out_paths)


func _collect_unregistered_generated_assets(dir_path: String, registered_paths: Dictionary, missing: Array) -> void:
	var dir := DirAccess.open(dir_path)
	_assert_true(dir != null, "无法读取目录：%s" % dir_path)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			_collect_unregistered_generated_assets(path, registered_paths, missing)
		elif ["png", "tres"].has(entry.get_extension()):
			if not registered_paths.has(path):
				missing.append(path)
		entry = dir.get_next()
	dir.list_dir_end()


func _collect_files_with_extension(dir_path: String, extension: String) -> Array:
	var files := []
	var dir := DirAccess.open(dir_path)
	_assert_true(dir != null, "无法读取目录：%s" % dir_path)
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		var path := "%s/%s" % [dir_path, entry]
		if dir.current_is_dir():
			files.append_array(_collect_files_with_extension(path, extension))
		elif entry.get_extension() == extension:
			files.append(path)
		entry = dir.get_next()
	dir.list_dir_end()
	return files


func _assert_resource_path_exists(path: String, message: String) -> void:
	_assert_true(path.begins_with("res://"), "%s：%s 不是 res:// 路径" % [message, path])
	_assert_true(_resource_or_directory_exists(path), "%s：%s" % [message, path])


func _resource_or_directory_exists(path: String) -> bool:
	return FileAccess.file_exists(path) or ResourceLoader.exists(path) or DirAccess.open(path) != null


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
