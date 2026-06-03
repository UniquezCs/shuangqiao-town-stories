extends Control

const MAIN_SCENE_PATH := "res://scenes/main.tscn"

@export var title_text := "双桥镇往事"

@onready var load_button: Button = $UI/Menu/LoadButton
@onready var confirm_new_game_dialog: ConfirmationDialog = $UI/ConfirmNewGameDialog


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
	get_tree().change_scene_to_file(MAIN_SCENE_PATH)


func _on_quit_pressed() -> void:
	get_tree().quit()
