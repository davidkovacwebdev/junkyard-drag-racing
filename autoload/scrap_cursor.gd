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

var _pointer: Node2D
var _squash_tween: Tween

func _ready() -> void:
	layer = 128
	process_mode = Node.PROCESS_MODE_ALWAYS
	_pointer = _CursorArt.new()
	_pointer.scale = Vector2.ONE * BASE_SCALE
	add_child(_pointer)
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func _notification(what: int) -> void:
	# Leaving the window shows the OS pointer on its own; don't leave a frozen
	# scrap arrow stuck at the edge where the mouse left.
	if _pointer == null:
		return
	if what == NOTIFICATION_WM_MOUSE_EXIT:
		_pointer.visible = false
	elif what == NOTIFICATION_WM_MOUSE_ENTER:
		_pointer.visible = true

func _process(delta: float) -> void:
	var viewport := get_viewport()
	_pointer.position = viewport.get_mouse_position()
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
