class_name MainMenu
extends Control
## The main menu, shown once LoadingScreen has finished rendering the music. New Game
## opens character creation, which resets the game and drops the player into
## the open world once they've built their character; Continue loads
## SaveSystem's save instead and is only enabled when one actually exists. Settings/Credits are real
## screens, just placeholder content for now.

@onready var _continue_button: BaseButton = $Buttons/ContinueButton

func _ready() -> void:
	_continue_button.disabled = not SaveSystem.has_save()

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/character_creation.tscn")

func _on_continue_pressed() -> void:
	SaveSystem.load_game()
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/settings_screen.tscn")

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/credits_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
