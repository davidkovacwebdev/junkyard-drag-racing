class_name Headlights
extends Node2D
## Switches the map car's lamps on at dusk and off at dawn, and draws their
## beams. A beam is drawn in the world as a child of the car, after its visual,
## so it y-sorts with the car: whatever stands in front of the car covers the
## beam, and the light stops at it. The beam doesn't paint colour itself (see
## headlight_beam.gdshader); it marks where light falls and the night overlay
## lifts the darkness there.
##
## The light travels to the overlay in the framebuffer's alpha, and the
## Compatibility renderer only keeps an alpha channel on a transparent viewport.
## So while the car is on the map the viewport is made transparent, with an
## opaque backdrop layer under the world so bare background never reads as lit.
##
## Which lamps exist comes from the body: every `HeadlightMount` it carries.

const BEAM_SHADER := preload("res://shaders/headlight_beam.gdshader")

## Beam reach in world pixels for a `beam_length_scale` of 1.
@export var beam_length: float = 560.0
## Half-angle of the cone, in radians.
@export_range(0.05, 1.2) var beam_spread: float = 0.32
## Radius of the glow around the lamp, as a fraction of the reach.
@export var glow_radius: float = 0.045
## Night factor the lamps switch on above and off below. Two values, so dusk
## hovering around one threshold can't make them chatter on and off.
@export_range(0.0, 1.0) var switch_on_night_factor: float = 0.25
@export_range(0.0, 1.0) var switch_off_night_factor: float = 0.18
## How long a lamp takes to warm up, stuttering on the way like an old bulb.
@export var warm_up_seconds: float = 0.35
@export var click_volume_db: float = -8.0

@export var car_view_path: NodePath = ^"../Visual"

var _on: bool = false
## 0 = dark, 1 = fully warmed up.
var _warmth: float = 0.0
var _time: float = 0.0
var _lamps: Array[HeadlightMount] = []
var _viewport_was_transparent: bool = false

@onready var _car_view: CarView = get_node(car_view_path) as CarView

func _ready() -> void:
	var beam_material := ShaderMaterial.new()
	beam_material.shader = BEAM_SHADER
	beam_material.set_shader_parameter("spread", beam_spread)
	beam_material.set_shader_parameter("glow_radius", glow_radius)
	material = beam_material
	_viewport_was_transparent = get_viewport().transparent_bg
	get_viewport().transparent_bg = true
	_add_opaque_backdrop()
	# Arriving on the map at night, the lights were already on — no click.
	_on = DayNightCycle.get_night_factor() > switch_on_night_factor
	_warmth = 1.0 if _on else 0.0

func _exit_tree() -> void:
	get_viewport().transparent_bg = _viewport_was_transparent

func _add_opaque_backdrop() -> void:
	var backdrop_layer := CanvasLayer.new()
	backdrop_layer.layer = -128
	var backdrop := ColorRect.new()
	backdrop.color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color")
	backdrop.color.a = 1.0
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop_layer.add_child(backdrop)
	add_child(backdrop_layer)

func _process(delta: float) -> void:
	_time += delta
	_lamps = _car_view.get_headlights()
	_update_switch()
	if _on:
		_warmth = minf(_warmth + delta / warm_up_seconds, 1.0)
	else:
		_warmth = 0.0
	queue_redraw()

func _update_switch() -> void:
	var night := DayNightCycle.get_night_factor()
	var want_on := night > switch_on_night_factor if not _on else night > switch_off_night_factor
	if want_on == _on:
		return
	_on = want_on
	if not _lamps.is_empty():
		Sfx.play(&"headlight_click", click_volume_db)

## One quad per lamp, from just behind it (room for the glow) to the end of the
## beam. UV is position along/across the beam over its reach, which is the
## space the shader draws the cone in.
func _draw() -> void:
	if _warmth <= 0.0:
		return
	var to_local := get_global_transform().affine_inverse()
	for lamp in _lamps:
		var lamp_transform := to_local * lamp.get_global_transform()
		var aim := lamp_transform.x.normalized()
		var side := aim.orthogonal()
		var reach := beam_length * lamp.beam_length_scale
		var back := glow_radius
		var half_width := 0.02 + tan(beam_spread) + glow_radius
		var corners := [Vector2(-back, -half_width), Vector2(1.0, -half_width),
				Vector2(1.0, half_width), Vector2(-back, half_width)]
		var points := PackedVector2Array()
		var uvs := PackedVector2Array()
		for corner: Vector2 in corners:
			points.append(lamp_transform.origin + (aim * corner.x + side * corner.y) * reach)
			uvs.append(corner)
		var power := lamp.power * _warm_up_stutter() * _flicker(lamp)
		var colors := PackedColorArray()
		colors.resize(4)
		colors.fill(Color(1, 1, 1, power))
		draw_polygon(points, colors, uvs)

## Blinks a couple of times while warming up, then holds steady.
func _warm_up_stutter() -> float:
	if _warmth >= 1.0:
		return 1.0
	return _warmth if fmod(_warmth * 7.0, 2.0) < 1.4 else 0.15

## A loose wire: mostly on, with short random dropouts that come and go.
func _flicker(lamp: HeadlightMount) -> float:
	if lamp.flicker <= 0.0:
		return 1.0
	var wobble := sin(_time * 13.0) * sin(_time * 3.7 + 1.3) * sin(_time * 29.0 + lamp.position.x)
	return 0.2 if wobble > 1.0 - lamp.flicker * 0.9 else 1.0
