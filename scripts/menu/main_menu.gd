class_name MainMenu
extends Control
## The main menu, shown once LoadingScreen has finished rendering the music. Play
## opens the save slots screen (load a profile, or start a new game in an empty
## one). Settings/Credits are real
## screens, just placeholder content for now.

func _on_play_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/save_slots_screen.tscn")

func _on_settings_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/settings_screen.tscn")

func _on_credits_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/menu/credits_screen.tscn")

func _on_quit_pressed() -> void:
	get_tree().quit()
