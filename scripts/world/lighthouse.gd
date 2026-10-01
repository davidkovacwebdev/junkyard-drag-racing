@tool
class_name Lighthouse
extends StaticBody2D
## A lighthouse on the coast: a tapering white tower with two red bands, a dark
## gallery, the lamp room and a red cap. Flat polygons, origin on the ground at
## the tower's foot so it Y-sorts against the car.
##
## At night the lamp sweeps two beams round and round. The beams don't paint
## colour; like the car's headlights they use headlight_beam.gdshader, which
## marks where light falls so the night overlay lifts the dark there.

const WHITE := Color(0.84, 0.82, 0.76)
const RED := Color(0.64, 0.2, 0.17)
const LAMP := UiPalette.ACCENT_YELLOW
const BEAM_SHADER := preload("res://shaders/headlight_beam.gdshader")

const TOWER_HEIGHT := 300.0
const BASE_HALF_WIDTH := 52.0
const TOP_HALF_WIDTH := 32.0
const RED_BANDS: Array[Vector2] = [Vector2(0.22, 0.36), Vector2(0.58, 0.72)]
const ROOM_HEIGHT := 40.0
const ROOM_HALF_WIDTH := 24.0
const LAMP_POINT := Vector2(0.0, -TOWER_HEIGHT - 10.0 - ROOM_HEIGHT * 0.5)

## World pixels the beams reach across the ground.
@export var beam_length: float = 1600.0
@export_range(0.02, 0.6) var beam_spread: float = 0.1
## Full turns per second.
@export var beam_turn_speed: float = 0.12
## Night factor the lamp needs before the beams show at all.
@export_range(0.0, 1.0) var light_on_night_factor: float = 0.2

var _beam_angle := 0.0
var _beam_power := 0.0
var _beam_canvas: Node2D

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(BASE_HALF_WIDTH * 2.0, 16.0)
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -8.0)
	add_child(collision)
	_beam_canvas = Node2D.new()
	var beam_material := ShaderMaterial.new()
	beam_material.shader = BEAM_SHADER
	beam_material.set_shader_parameter("spread", beam_spread)
	beam_material.set_shader_parameter("glow_radius", 0.03)
	_beam_canvas.material = beam_material
	_beam_canvas.draw.connect(_draw_beams)
	add_child(_beam_canvas)

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	_beam_angle = wrapf(_beam_angle + TAU * beam_turn_speed * delta, 0.0, TAU)
	_beam_power = 1.0 if DayNightCycle.get_night_factor() > light_on_night_factor else 0.0
	_beam_canvas.queue_redraw()

func _draw() -> void:
	draw_colored_polygon(FlatProps.octagon(Vector2(10.0, 0.0), BASE_HALF_WIDTH + 18.0, 12.0), UiPalette.SHADOW)
	draw_colored_polygon(_tower_slice(0.0, 1.0, -1.0, 1.0), WHITE)
	draw_colored_polygon(_tower_slice(0.0, 1.0, 0.45, 1.0), WHITE.darkened(0.2))
	for band in RED_BANDS:
		draw_colored_polygon(_tower_slice(band.x, band.y, -1.0, 1.0), RED)
	draw_rect(Rect2(-12.0, -42.0, 24.0, 42.0), UiPalette.VOID)
	draw_rect(Rect2(-TOP_HALF_WIDTH - 10.0, -TOWER_HEIGHT - 10.0, (TOP_HALF_WIDTH + 10.0) * 2.0, 10.0), UiPalette.INK)
	draw_rect(Rect2(-ROOM_HALF_WIDTH, -TOWER_HEIGHT - 10.0 - ROOM_HEIGHT, ROOM_HALF_WIDTH * 2.0, ROOM_HEIGHT), UiPalette.GLASS)
	draw_colored_polygon(FlatProps.octagon(LAMP_POINT, 12.0, 12.0), LAMP)
	var roof_y := -TOWER_HEIGHT - 10.0 - ROOM_HEIGHT
	draw_colored_polygon(PackedVector2Array([
		Vector2(-ROOM_HALF_WIDTH - 8.0, roof_y), Vector2(0.0, roof_y - 34.0), Vector2(ROOM_HALF_WIDTH + 8.0, roof_y),
	]), RED)

## A horizontal slice of the tapering tower, from `from`..`to` of its height,
## and across it from `left`..`right` (-1 is the left edge, 1 the right).
func _tower_slice(from: float, to: float, left: float, right: float) -> PackedVector2Array:
	var bottom_half := lerpf(BASE_HALF_WIDTH, TOP_HALF_WIDTH, from)
	var top_half := lerpf(BASE_HALF_WIDTH, TOP_HALF_WIDTH, to)
	return PackedVector2Array([
		Vector2(bottom_half * left, -TOWER_HEIGHT * from), Vector2(top_half * left, -TOWER_HEIGHT * to),
		Vector2(top_half * right, -TOWER_HEIGHT * to), Vector2(bottom_half * right, -TOWER_HEIGHT * from),
	])

## Two opposite beams, each one quad in the shader's beam space (see Headlights).
func _draw_beams() -> void:
	if _beam_power <= 0.0:
		return
	var half_width := 0.02 + tan(beam_spread) + 0.03
	var corners := [Vector2(-0.03, -half_width), Vector2(1.0, -half_width), Vector2(1.0, half_width), Vector2(-0.03, half_width)]
	var colors := PackedColorArray()
	colors.resize(4)
	colors.fill(Color(1, 1, 1, _beam_power))
	for side in 2:
		var aim := Vector2.from_angle(_beam_angle + PI * side)
		var across := aim.orthogonal()
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for corner: Vector2 in corners:
			points.append(LAMP_POINT + (aim * corner.x + across * corner.y) * beam_length)
			uvs.append(corner)
		_beam_canvas.draw_polygon(points, colors, uvs)
