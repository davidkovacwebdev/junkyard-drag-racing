class_name PlayerCar
extends CharacterBody2D
## Side-view movement, not top-down: A/D (or Left/Right) move the car
## horizontally and flip it to face that direction; W/S (or Up/Down) move
## it vertically with no flip and no rotation at all. Two independent
## axes, no steering/turning-radius physics — there's no "reverse
## steers backwards" case here since the car never rotates.

@export var max_speed: float = 420.0
@export var acceleration: float = 1800.0
@export var friction: float = 1800.0

var _facing_right: bool = true

func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING

const _DRIVE_KEYS := [KEY_W, KEY_A, KEY_S, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]

func _notification(what: int) -> void:
	# If the window loses OS focus while a key is held, no key-up event
	# ever arrives — Input keeps reporting that key pressed forever after.
	# Force every drive key released whenever focus drops.
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		for keycode in _DRIVE_KEYS:
			var ev := InputEventKey.new()
			ev.keycode = keycode
			ev.physical_keycode = keycode
			ev.pressed = false
			Input.parse_input_event(ev)
		velocity = Vector2.ZERO

func _physics_process(delta: float) -> void:
	var input_dir := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
		input_dir.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
		input_dir.x += 1.0
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
		input_dir.y -= 1.0
	if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
		input_dir.y += 1.0

	if input_dir.x > 0.0:
		_facing_right = true
	elif input_dir.x < 0.0:
		_facing_right = false
	$Visual.scale.x = 1.0 if _facing_right else -1.0

	var target_velocity := Vector2.ZERO
	if input_dir != Vector2.ZERO:
		target_velocity = input_dir.normalized() * max_speed
	var accel_rate := acceleration if input_dir != Vector2.ZERO else friction
	velocity = velocity.move_toward(target_velocity, accel_rate * delta)
	move_and_slide()
