class_name PauseMenu
extends CanvasLayer
## Escape pauses the open world and shows this menu; Escape again (or
## Resume) unpauses. process_mode ALWAYS is what lets this keep working
## while paused — everything else (PlayerCar, WorldState, ...) has the
## default inherited mode, so Godot's pause system stops them exactly
## like we want without any changes on their end.

@onready var _panel: Control = $Panel

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_panel.visible = false

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		_toggle_pause()

func _toggle_pause() -> void:
	get_tree().paused = not get_tree().paused
	_panel.visible = get_tree().paused

func _on_resume_pressed() -> void:
	_toggle_pause()

func _on_settings_pressed() -> void:
	_leave_to("res://scenes/menu/settings_screen.tscn")

func _on_return_to_menu_pressed() -> void:
	_leave_to("res://scenes/menu/main_menu.tscn")

## get_tree().paused is a SceneTree-wide flag that survives a scene
## change — without clearing it first, whatever we switch to would load
## already paused/frozen (its buttons included).
func _leave_to(scene_path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(scene_path)

func _on_quit_pressed() -> void:
	get_tree().quit()
