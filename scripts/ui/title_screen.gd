extends Control

const MAIN_SCENE_PATH := "res://scenes/main.tscn"
const INTRO_SLIDE_SECONDS := 4.5
const INTRO_IMAGES := [
	"res://assets/generated/sprites/ui/intro/story_01_factory_layoff_1920x1080.png",
	"res://assets/generated/sprites/ui/intro/story_02_family_pressure_1920x1080.png",
	"res://assets/generated/sprites/ui/intro/story_03_hometown_stall_1920x1080.png",
]
const INTRO_CAPTIONS := [
	"1998 年，国企改制的风吹到厂门口。干了半辈子的岗位没了，手里的通知轻得像纸，日子却一下重了起来。",
	"家里的账本摊在桌上，米钱、药钱、孩子的学费，一样都等不得。没了工资，也得想办法把日子撑下去。",
	"老家的田荒了好些年，靠几块地已经撑不起一家人的日子。他看着田埂尽头的镇街，决定走出去，靠卖水果和蔬菜重新开张。"
]

@export var title_text := "双桥镇往事"

@onready var load_button: Button = $UI/Menu/LoadButton
@onready var confirm_new_game_dialog: ConfirmationDialog = $UI/ConfirmNewGameDialog

var _intro_index := 0
var _intro_running := false
var _intro_layer: Control = null
var _intro_texture: TextureRect = null
var _intro_caption: Label = null
var _intro_hint: Label = null
var _intro_timer: Timer = null


func _ready() -> void:
	refresh_save_state()
	$UI/Title.text = title_text
	$UI/Menu/NewGameButton.pressed.connect(_on_new_game_pressed)
	load_button.pressed.connect(_on_load_game_pressed)
	$UI/Menu/QuitButton.pressed.connect(_on_quit_pressed)
	confirm_new_game_dialog.confirmed.connect(_start_new_game)


func refresh_save_state() -> void:
	load_button.disabled = not SaveManager.has_save()


func _on_new_game_pressed() -> void:
	if SaveManager.has_save():
		confirm_new_game_dialog.popup_centered()
	else:
		_start_new_game()


func _on_load_game_pressed() -> void:
	var save_data := SaveManager.load_autosave()
	if save_data.is_empty():
		refresh_save_state()
		return
	SaveManager.set_pending_load(save_data)
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _start_new_game() -> void:
	SaveManager.set_pending_load({})
	_start_intro_sequence()


func _start_intro_sequence() -> void:
	_intro_index = 0
	_intro_running = true
	$UI.visible = false
	_build_intro_layer()
	_show_intro_slide()


func _finish_intro_sequence() -> void:
	_intro_running = false
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if not _intro_running:
		return
	if (
		event.is_action_pressed("ui_accept")
		or event.is_action_pressed("interact")
		or event is InputEventMouseButton and (event as InputEventMouseButton).pressed
	):
		_advance_intro_slide()
		get_viewport().set_input_as_handled()


func _build_intro_layer() -> void:
	if _intro_layer != null:
		return
	_intro_layer = Control.new()
	_intro_layer.name = "IntroLayer"
	_intro_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_intro_layer)

	_intro_texture = TextureRect.new()
	_intro_texture.name = "StoryImage"
	_intro_texture.set_anchors_preset(Control.PRESET_FULL_RECT)
	_intro_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_intro_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_intro_layer.add_child(_intro_texture)

	var caption_panel := PanelContainer.new()
	caption_panel.name = "CaptionPanel"
	caption_panel.anchor_left = 0.08
	caption_panel.anchor_top = 0.76
	caption_panel.anchor_right = 0.92
	caption_panel.anchor_bottom = 0.93
	_intro_layer.add_child(caption_panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_top", 20)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_bottom", 18)
	caption_panel.add_child(margin)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	margin.add_child(column)

	_intro_caption = Label.new()
	_intro_caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_intro_caption.add_theme_font_size_override("font_size", 30)
	_intro_caption.add_theme_color_override("font_color", Color(1.0, 0.94, 0.78, 1.0))
	_intro_caption.add_theme_color_override("font_shadow_color", Color(0.02, 0.01, 0.0, 0.95))
	_intro_caption.add_theme_constant_override("shadow_offset_x", 2)
	_intro_caption.add_theme_constant_override("shadow_offset_y", 2)
	column.add_child(_intro_caption)

	_intro_hint = Label.new()
	_intro_hint.text = "按空格 / 回车 / 点击继续"
	_intro_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_intro_hint.add_theme_font_size_override("font_size", 20)
	_intro_hint.add_theme_color_override("font_color", Color(0.92, 0.82, 0.62, 0.9))
	column.add_child(_intro_hint)

	_intro_timer = Timer.new()
	_intro_timer.name = "IntroTimer"
	_intro_timer.one_shot = true
	_intro_timer.timeout.connect(_advance_intro_slide)
	_intro_layer.add_child(_intro_timer)


func _show_intro_slide() -> void:
	if _intro_index >= INTRO_IMAGES.size():
		_finish_intro_sequence()
		return
	if _intro_texture != null:
		_intro_texture.texture = load(str(INTRO_IMAGES[_intro_index]))
	if _intro_caption != null:
		_intro_caption.text = str(INTRO_CAPTIONS[_intro_index])
	if _intro_timer != null:
		_intro_timer.start(INTRO_SLIDE_SECONDS)


func _advance_intro_slide() -> void:
	if not _intro_running:
		return
	if _intro_timer != null:
		_intro_timer.stop()
	_intro_index += 1
	_show_intro_slide()
