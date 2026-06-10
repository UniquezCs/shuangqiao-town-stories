extends Node

const DEFAULT_FONT_PATH := "res://assets/fonts/NotoSansCJKsc-Regular.otf"
const REQUIRED_CHINESE_TEXT := "双桥镇往事背包金钱苹果"


func _ready() -> void:
	var configured_font := str(ProjectSettings.get_setting("gui/theme/custom_font", ""))
	_assert_equal(configured_font, DEFAULT_FONT_PATH, "项目必须配置全局中文 GUI 字体，避免中文文字乱码")
	_assert_true(ResourceLoader.exists(DEFAULT_FONT_PATH), "全局中文字体资源必须存在")

	var font := load(DEFAULT_FONT_PATH) as Font
	_assert_true(font != null, "全局中文字体必须能作为 Font 加载")
	for index in REQUIRED_CHINESE_TEXT.length():
		var char_code := REQUIRED_CHINESE_TEXT.unicode_at(index)
		_assert_true(font.has_char(char_code), "全局中文字体缺少必要中文字形：%s" % REQUIRED_CHINESE_TEXT[index])

	get_tree().quit()


func _assert_equal(actual: Variant, expected: Variant, message: String) -> void:
	if actual != expected:
		push_error("%s。实际：%s，期望：%s" % [message, str(actual), str(expected)])
		get_tree().quit(1)


func _assert_true(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		get_tree().quit(1)
