extends Node

const SHEETS := {
	"student": {
		"path": "res://assets/generated/sprites/characters/student_walk_4dir_6f_48x64.png",
		"cols": 6,
		"standing_loop": false,
	},
	"worker": {
		"path": "res://assets/generated/sprites/characters/worker_walk_4dir_6f_48x64.png",
		"cols": 6,
		"standing_loop": false,
	},
	"youth_female": {
		"path": "res://assets/generated/sprites/characters/youth_female_walk_4dir_6f_48x64.png",
		"cols": 6,
		"standing_loop": false,
		"magenta_clean": true,
	},
	"elder_male": {
		"path": "res://assets/generated/sprites/characters/elder_male_walk_4dir_6f_48x64.png",
		"cols": 6,
		"standing_loop": false,
		"magenta_clean": true,
		"max_significant_components": 2,
	},
	"female_elder": {
		"path": "res://assets/generated/sprites/characters/female_elder_walk_4dir_6f_48x64.png",
		"cols": 6,
		"standing_loop": false,
	},
	"female_middle": {
		"path": "res://assets/generated/sprites/characters/female_middle_walk_4dir_6f_48x64.png",
		"cols": 6,
		"standing_loop": false,
	},
}
const FRAMESETS := {
	"student": preload("res://assets/generated/sprites/characters/student_walk_spriteframes_48x64.tres"),
	"worker": preload("res://assets/generated/sprites/characters/worker_walk_spriteframes_48x64.tres"),
	"youth_female": preload("res://assets/generated/sprites/characters/youth_female_walk_spriteframes_48x64.tres"),
	"elder_male": preload("res://assets/generated/sprites/characters/elder_male_walk_spriteframes_48x64.tres"),
	"female_elder": preload("res://assets/generated/sprites/characters/female_elder_walk_spriteframes_48x64.tres"),
	"female_middle": preload("res://assets/generated/sprites/characters/female_middle_walk_spriteframes_48x64.tres"),
}
const ANIMATIONS := ["walk_down", "walk_left", "walk_right", "walk_up"]
const CELL_SIZE := Vector2i(48, 64)
const ROWS := 4


func _ready() -> void:
	for key in SHEETS.keys():
		_assert_spriteframes(key)
		_assert_sheet_quality(key, str(SHEETS[key]["path"]))
	get_tree().quit()


func _assert_spriteframes(key: String) -> void:
	var frames: SpriteFrames = FRAMESETS[key]
	var cols := int(SHEETS[key]["cols"])
	for animation in ANIMATIONS:
		_assert_true(frames.has_animation(animation), "%s 缺少动画：%s" % [key, animation])
		_assert_equal(frames.get_frame_count(animation), cols, "%s/%s 必须有 %d 帧" % [key, animation, cols])
		_assert_true(frames.get_animation_loop(animation), "%s/%s 必须循环播放" % [key, animation])


func _assert_sheet_quality(key: String, path: String) -> void:
	var cols := int(SHEETS[key]["cols"])
	var requires_standing_loop := bool(SHEETS[key]["standing_loop"])
	var requires_magenta_cleanup := bool(SHEETS[key].get("magenta_clean", false))
	var min_adjacent_frame_diff := int(SHEETS[key].get("min_adjacent_frame_diff", 0))
	var max_significant_components := int(SHEETS[key].get("max_significant_components", 1))
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	_assert_equal(error, OK, "%s sheet 应可加载：%s" % [key, path])
	_assert_equal(image.get_size(), Vector2i(cols * CELL_SIZE.x, ROWS * CELL_SIZE.y), "%s sheet 尺寸必须是 %dx256" % [key, cols * CELL_SIZE.x])
	if requires_magenta_cleanup:
		_assert_equal(_magenta_like_pixel_count(image), 0, "%s sheet 不应残留紫色抠底噪点" % key)

	for row in range(ROWS):
		var first := Rect2i(0, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
		var last := Rect2i((cols - 1) * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
		if requires_standing_loop:
			_assert_cells_equal(image, first, last, "%s 第 %d 行首尾帧必须是同一个站立帧" % [key, row + 1])
		else:
			_assert_cells_different(image, first, last, "%s 第 %d 行不应包含首尾重复站立帧" % [key, row + 1])

		var expected_bottom := -1
		var min_top := 999
		var max_top := -1
		for col in range(cols):
			var rect := Rect2i(col * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
			var bbox := _alpha_bbox(image, rect)
			_assert_true(bbox.has_area(), "%s 第 %d 行第 %d 帧不能为空" % [key, row + 1, col + 1])
			_assert_true(bbox.size.y >= 44, "%s 第 %d 行第 %d 帧人物高度过低，可能存在削头或错误缩放" % [key, row + 1, col + 1])
			min_top = mini(min_top, bbox.position.y - rect.position.y)
			max_top = maxi(max_top, bbox.position.y - rect.position.y)
			_assert_true(bbox.position.x > rect.position.x, "%s 第 %d 行第 %d 帧左侧贴边" % [key, row + 1, col + 1])
			_assert_true(bbox.position.y > rect.position.y, "%s 第 %d 行第 %d 帧顶部贴边" % [key, row + 1, col + 1])
			_assert_true(bbox.end.x < rect.end.x, "%s 第 %d 行第 %d 帧右侧贴边" % [key, row + 1, col + 1])
			_assert_true(bbox.end.y < rect.end.y, "%s 第 %d 行第 %d 帧底部贴边" % [key, row + 1, col + 1])
			_assert_true(_significant_component_count(image, rect) <= max_significant_components, "%s 第 %d 行第 %d 帧不应有漂浮发片、阴影或 detached noise" % [key, row + 1, col + 1])
			if expected_bottom == -1:
				expected_bottom = bbox.end.y
			_assert_equal(bbox.end.y, expected_bottom, "%s 第 %d 行脚底基线必须一致" % [key, row + 1])
			if min_adjacent_frame_diff > 0 and col > 0:
				var previous_rect := Rect2i((col - 1) * CELL_SIZE.x, row * CELL_SIZE.y, CELL_SIZE.x, CELL_SIZE.y)
				_assert_true(
					_frame_pixel_difference(image, previous_rect, rect) >= min_adjacent_frame_diff,
					"%s 第 %d 行第 %d/%d 帧步伐差异过小" % [key, row + 1, col, col + 1]
				)
		_assert_true(max_top - min_top <= 2, "%s 第 %d 行头顶高度波动过大，可能存在削头或切片错误" % [key, row + 1])


func _alpha_bbox(image: Image, rect: Rect2i) -> Rect2i:
	var min_x := rect.end.x
	var min_y := rect.end.y
	var max_x := rect.position.x
	var max_y := rect.position.y
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if image.get_pixel(x, y).a > 0.01:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x + 1)
				max_y = maxi(max_y, y + 1)
	if max_x <= min_x or max_y <= min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x, max_y - min_y)


func _assert_cells_equal(image: Image, a: Rect2i, b: Rect2i, message: String) -> void:
	if not _cells_equal(image, a, b):
		push_error(message)
		get_tree().quit(1)


func _assert_cells_different(image: Image, a: Rect2i, b: Rect2i, message: String) -> void:
	if _cells_equal(image, a, b):
		push_error(message)
		get_tree().quit(1)


func _cells_equal(image: Image, a: Rect2i, b: Rect2i) -> bool:
	for y in range(CELL_SIZE.y):
		for x in range(CELL_SIZE.x):
			if image.get_pixel(a.position.x + x, a.position.y + y) != image.get_pixel(b.position.x + x, b.position.y + y):
				return false
	return true


func _significant_component_count(image: Image, rect: Rect2i) -> int:
	var visited := {}
	var count := 0
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var key := Vector2i(x, y)
			if visited.has(key) or image.get_pixel(x, y).a <= 0.01:
				continue
			var area := _flood_component_area(image, rect, key, visited)
			if area > 12:
				count += 1
	return count


func _flood_component_area(image: Image, rect: Rect2i, start: Vector2i, visited: Dictionary) -> int:
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	var area := 0
	while not queue.is_empty():
		var current := queue.pop_back() as Vector2i
		area += 1
		for oy in range(-1, 2):
			for ox in range(-1, 2):
				if ox == 0 and oy == 0:
					continue
				var next := current + Vector2i(ox, oy)
				if not rect.has_point(next) or visited.has(next):
					continue
				if image.get_pixelv(next).a <= 0.01:
					continue
				visited[next] = true
				queue.append(next)
	return area


func _magenta_like_pixel_count(image: Image) -> int:
	var count := 0
	for y in range(image.get_height()):
		for x in range(image.get_width()):
			var color := image.get_pixel(x, y)
			if color.a <= 0.01:
				continue
			var red := int(round(color.r * 255.0))
			var green := int(round(color.g * 255.0))
			var blue := int(round(color.b * 255.0))
			if red > 40 and blue > 45 and green < 55 and abs(red - blue) < 80 and mini(red, blue) - green > 10:
				count += 1
	return count


func _frame_pixel_difference(image: Image, a: Rect2i, b: Rect2i) -> int:
	var difference := 0
	for y in range(CELL_SIZE.y):
		for x in range(CELL_SIZE.x):
			if image.get_pixel(a.position.x + x, a.position.y + y) != image.get_pixel(b.position.x + x, b.position.y + y):
				difference += 1
	return difference


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)
