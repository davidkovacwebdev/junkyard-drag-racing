class_name BackButton
extends Button
## Plain-text "leave here" control — flat, no background, just a
## font-color change on hover. Defaults to the open world (what every
## building interior wants — the player lands back at the exact spot
## they entered from because PlayerCar/WorldState handle that, not this
## button), but menu screens override target_scene to go back to the
## main menu instead.

@export_file("*.tscn") var target_scene: String = "res://scenes/world/main.tscn"

func _pressed() -> void:
	# No-ops if there's no active session (e.g. Settings reached straight
	# from the main menu) — see SaveSystem's own guard.
	SaveSystem.save_game()
	get_tree().change_scene_to_file(target_scene)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_pressed()
