class_name MainMenu
extends Control
## The game's entry point (see project.godot's run/main_scene). New Game
## drops the player into the open world. Continue is genuinely disabled
## (set on the button itself) rather than wired to a no-op — there's no
## save/load yet, so there's nothing to continue from. Settings/Credits
## are real screens, just placeholder content for now.

func _on_new_game_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/world/main.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/settings_screen.tscn")

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/credits_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
