@tool
class_name OilPump
extends StaticBody2D
## A nodding-donkey oil pumpjack, side on with the horsehead to the right. The
## crank turns a counterweight, the pitman arm rocks the walking beam on its
## A-frame and the horsehead dips the rod into the wellhead. Flat polygons,
## origin on the ground so it Y-sorts against the car. It creaks once a stroke.

const BEAM_COLOR := Color(0.76, 0.6, 0.22)
const FRAME := UiPalette.STEEL_DARK
const SKID := UiPalette.METAL_GREY

const PIVOT := Vector2(0.0, -118.0)
const BEAM_REAR := -90.0
const BEAM_FRONT := 80.0
const BEAM_THICKNESS := 14.0
const CRANK := Vector2(-70.0, -50.0)
const CRANK_RADIUS := 22.0
const WELL_X := 100.0
## Beam-local point the rod hangs from: the foot of the horsehead's arc.
const ROD_HANG := Vector2(WELL_X, 36.0)
const CREAK_HEARING_RANGE := 1000.0

## Seconds per full stroke.
@export var stroke_time: float = 3.2
## Fraction of a stroke this pump is ahead of the others, so a field of them
## doesn't nod in lockstep.
@export_range(0.0, 1.0) var phase_offset: float = 0.0:
	set(value):
		phase_offset = value
		queue_redraw()

var _time := 0.0
var _creak: AudioStreamPlayer2D

func _ready() -> void:
	if Engine.is_editor_hint():
		set_process(false)
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(240.0, 14.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(5.0, -7.0)
	add_child(collision)
	_creak = AudioStreamPlayer2D.new()
	_creak.stream = Sfx.stream(&"pumpjack_creak")
	_creak.bus = SoundLibrary.bus_for(&"pumpjack_creak")
	_creak.volume_db = -10.0
	_creak.max_distance = CREAK_HEARING_RANGE
	_creak.position = PIVOT
	add_child(_creak)

func _process(delta: float) -> void:
	var before := _stroke()
	_time += delta
	# The head bottoms out three quarters of the way round the crank.
	if fposmod(before - 0.75, 1.0) > fposmod(_stroke() - 0.75, 1.0):
		_creak.pitch_scale = randf_range(0.92, 1.08)
		_creak.play()
	queue_redraw()

func _stroke() -> float:
	return _time / stroke_time + phase_offset

func _draw() -> void:
	var crank_angle := TAU * _stroke()
	var pin := CRANK + Vector2.from_angle(crank_angle) * CRANK_RADIUS
	# The pitman arm keeps the beam's tail a fixed height above the crank pin.
	var beam_angle := asin(clampf((CRANK.y - pin.y) / -BEAM_REAR, -1.0, 1.0))
	var beam := Transform2D(beam_angle, PIVOT)
	var rear := beam * Vector2(BEAM_REAR, 0.0)
	var rod_top := beam * ROD_HANG

	draw_colored_polygon(FlatProps.octagon(Vector2(10.0, 0.0), 130.0, 10.0), UiPalette.SHADOW)
	draw_rect(Rect2(-112.0, -12.0, 236.0, 12.0), SKID)
	draw_rect(Rect2(WELL_X - 12.0, -32.0, 24.0, 22.0), SKID.darkened(0.2))
	draw_colored_polygon(FlatProps.sliver(Vector2(WELL_X, rod_top.y), Vector2(WELL_X, -30.0), 5.0), UiPalette.STEEL_LIGHT)
	var weight_direction := Vector2.from_angle(crank_angle)
	draw_colored_polygon(FlatProps.sliver(CRANK - weight_direction * 6.0, CRANK + weight_direction * (CRANK_RADIUS + 22.0), 40.0), SKID.darkened(0.2))
	draw_colored_polygon(FlatProps.sliver(pin, rear, 7.0), FRAME)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-30.0, -12.0), Vector2(-6.0, PIVOT.y), Vector2(6.0, PIVOT.y), Vector2(30.0, -12.0),
	]), FRAME)
	draw_colored_polygon(beam * PackedVector2Array([
		Vector2(BEAM_REAR, -BEAM_THICKNESS * 0.5), Vector2(BEAM_FRONT, -BEAM_THICKNESS * 0.5),
		Vector2(BEAM_FRONT, BEAM_THICKNESS * 0.5), Vector2(BEAM_REAR, BEAM_THICKNESS * 0.5),
	]), BEAM_COLOR.darkened(0.2))
	draw_colored_polygon(beam * PackedVector2Array([
		Vector2(BEAM_FRONT - 8.0, -14.0), Vector2(BEAM_FRONT + 14.0, -12.0), Vector2(BEAM_FRONT + 24.0, 6.0),
		Vector2(BEAM_FRONT + 22.0, 30.0), Vector2(BEAM_FRONT + 14.0, 40.0), Vector2(BEAM_FRONT + 2.0, 14.0),
	]), BEAM_COLOR)
