extends Node
## Ctrl+1 … Ctrl+0, Ctrl+- and Ctrl+= stand in for F1 … F12 (autoload
## `FunctionKeyAliases`), for keyboards without function keys. The Ctrl
## press is swapped for the F key's own event, so every F-key shortcut works
## through it unchanged. Ctrl+Shift+number stays free for the save-slot switch.

const ALIASES := {
	KEY_1: KEY_F1,
	KEY_2: KEY_F2,
	KEY_3: KEY_F3,
	KEY_4: KEY_F4,
	KEY_5: KEY_F5,
	KEY_6: KEY_F6,
	KEY_7: KEY_F7,
	KEY_8: KEY_F8,
	KEY_9: KEY_F9,
	KEY_0: KEY_F10,
	KEY_MINUS: KEY_F11,
	KEY_EQUAL: KEY_F12,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	var key_event := event as InputEventKey
	if key_event == null or not key_event.is_command_or_control_pressed() \
			or key_event.shift_pressed or key_event.alt_pressed \
			or not ALIASES.has(key_event.physical_keycode):
		return
	get_viewport().set_input_as_handled()
	var function_key := InputEventKey.new()
	function_key.physical_keycode = ALIASES[key_event.physical_keycode]
	function_key.keycode = function_key.physical_keycode
	function_key.pressed = key_event.pressed
	function_key.echo = key_event.echo
	Input.parse_input_event(function_key)
