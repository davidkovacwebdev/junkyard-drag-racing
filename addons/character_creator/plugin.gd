@tool
extends EditorPlugin
## Registers the Character Creator dock. Enable with
## Project > Project Settings > Plugins, then use the dock on the bottom
## right (rename it by hand if it's tucked in with other docks).

const DockScript := preload("res://addons/character_creator/character_creator_dock.gd")

var _dock: Control

func _enter_tree() -> void:
	_dock = DockScript.new()
	_dock.name = "Character Creator"
	add_control_to_dock(DOCK_SLOT_RIGHT_BL, _dock)

func _exit_tree() -> void:
	if _dock != null:
		remove_control_from_docks(_dock)
		_dock.queue_free()
		_dock = null
