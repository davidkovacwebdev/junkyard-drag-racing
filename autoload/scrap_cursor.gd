extends CanvasLayer
## The game's mouse cursor (autoload singleton "ScrapCursor"): a bent scrap of
## blue-grey steel drawn in the ui-style polygons, replacing the OS pointer.
## Clicking squashes it flat and it springs back; hovering anything clickable
## tips it over like it's pointing.
##
## Drawn in software on the top canvas layer so it can animate. The arrow's tip
## is the node's origin, so squashing and tilting never move the hotspot.

const BASE_SCALE := 1.4
const SQUASH_SCALE := Vector2(1.3, 0.62) * BASE_SCALE
const SQUASH_TIME := 0.06
const SPRING_TIME := 0.4
const HOVER_TILT := deg_to_rad(-14.0)
const TILT_RESPONSE := 18.0
## Driving is keyboard-only, so a mouse left sitting mid-screen is just
## clutter once the player's clearly not about to click anything. Only
## kicks in while the player's car exists (PlayerCar.GROUP) — menus and
## the garage still want the pointer up regardless of how still it sits.
const IDLE_HIDE_DELAY := 2.0

var _pointer: Node2D
var _squash_tween: Tween
var _mouse_in_window: bool = true
var _idle_time: float = 0.0
var _last_mouse_pos: Vector2 = Vector2.INF

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pointer = _CursorArt.new()
	_pointer.scale = Vector2.ONE * BASE_SCALE
	add_child(_pointer)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _notification(what: int) -> void:
	# Leaving the window: hide our drawn arrow and actually give the OS
	# pointer back (mouse_mode was forced HIDDEN in _ready, so without this
	# the real cursor never reappears outside the window either — nothing at
	# all would be visible to click a window control with).
	if _pointer == null:
		return
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_mouse_in_window = false
		_pointer.visible = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_mouse_in_window = true
		_idle_time = 0.0
		_pointer.visible = true
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _process(delta: float) -> void:
	var viewport := get_viewport()
	var mouse_pos := viewport.get_mouse_position()
	if mouse_pos != _last_mouse_pos:
		_last_mouse_pos = mouse_pos
		_idle_time = 0.0
	else:
		_idle_time += delta
	_pointer.position = mouse_pos

	var driving := get_tree().get_first_node_in_group(PlayerCar.GROUP) != null
	var idle_hidden := driving and _idle_time >= IDLE_HIDE_DELAY
	_pointer.visible = _mouse_in_window and not idle_hidden

	var hovered := viewport.gui_get_hovered_control()
	var over_clickable := hovered is BaseButton and not (hovered as BaseButton).disabled
	var target_tilt := HOVER_TILT if over_clickable else 0.0
	_pointer.rotation = lerp_angle(_pointer.rotation, target_tilt, 1.0 - exp(-TILT_RESPONSE * delta))

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and (event as InputEventMouseButton).pressed:
		_squash()

## Flatten fast, then spring back with an overshoot.
func _squash() -> void:
	if _squash_tween != null:
		_squash_tween.kill()
	_squash_tween = create_tween()
	_squash_tween.tween_property(_pointer, "scale", SQUASH_SCALE, SQUASH_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_squash_tween.tween_property(_pointer, "scale", Vector2.ONE * BASE_SCALE, SPRING_TIME) \
			.set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

## The arrow itself, a bent offcut of blue-grey steel: shadow, body, shade on
## the lower flank, one rivet, one highlight. No outline. Tip at the origin,
## pointing up-left.
class _CursorArt extends Node2D:
	const BODY := [Vector2(0, 0), Vector2(0, 25), Vector2(6, 19), Vector2(11, 30),
			Vector2(16, 28), Vector2(11, 17), Vector2(19, 17)]
	const TAIL := [Vector2(6, 19), Vector2(11, 30), Vector2(16, 28), Vector2(11, 17)]
	const HIGHLIGHT := [Vector2(2, 5), Vector2(4, 7), Vector2(4, 16), Vector2(2, 18)]
	const RIVET := [Vector2(6, 11), Vector2(9, 11), Vector2(9, 14), Vector2(6, 14)]
	const SHADOW_OFFSET := Vector2(3, 4)

	func _draw() -> void:
		var body := PackedVector2Array(BODY)
		var shadow := PackedVector2Array()
		for p in body:
			shadow.append(p + SHADOW_OFFSET)
		draw_colored_polygon(shadow, UiPalette.SHADOW)
		draw_colored_polygon(body, UiPalette.STEEL_BASE)
		draw_colored_polygon(PackedVector2Array(TAIL), UiPalette.STEEL_SHADE)
		draw_colored_polygon(PackedVector2Array(HIGHLIGHT), UiPalette.STEEL_LIGHT)
		draw_colored_polygon(PackedVector2Array(RIVET), UiPalette.STEEL_DARK)
