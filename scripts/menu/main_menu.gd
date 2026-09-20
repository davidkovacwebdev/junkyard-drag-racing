class_name MainMenu
extends Control
## The game's entry point (see project.godot's run/main_scene). New Game
## resets Inventory/WorldState to a fresh start and drops the player
## into the open world; Continue loads SaveSystem's save instead and is
## only enabled when one actually exists. Settings/Credits are real
## screens, just placeholder content for now.

@onready var _continue_button: Button = $ContinueButton

func _ready() -> void:
	_continue_button.disabled = not SaveSystem.has_save()

func _on_new_game_pressed() -> void:
	Inventory.reset()
	WorldState.clear()
	SaveSystem.delete_save()
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")

func _on_continue_pressed() -> void:
	SaveSystem.load_game()
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/settings_screen.tscn")

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/credits_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
