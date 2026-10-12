class_name EngineNoiseIndicator
extends Control
## "Graveyard Shift": you can hear the masked digger's pickup before you see
## it. While it's in earshot but off screen, a stack of chunky sound-wave
## chevrons sits on a ring around the player's car, on its side, pointing at
## it (clear of the HUD corners). Far off it's
## one faint chevron pulsing slowly; close in, three bright ones pulsing fast.
## Gone once the pickup is on screen. Made by NightDiggerTruck.
##
## Junk-toy style: each chevron is two bars (a ">"), at most three of them.

## Heard from this far away (world px); full strength from NEAR in, rising
## steeply only near the end (see `_strength()`).
const HEAR_RANGE := 5200.0
const NEAR := 700.0
## Arrows: three inside THREE_WITHIN, two inside TWO_WITHIN, else one.
const TWO_WITHIN := 2200.0
const THREE_WITHIN := 1100.0
## The ring around the car the stack sits on, as a share of the screen's
## shorter side.
const RING := 0.16
## A chevron: arm length, bar thickness, gap between chevrons.
const ARM := 7.0
const THICK := 4.0
const STEP := 7.0
## A warm warning red, light enough to read at night.
const COLOR := Color(0.86, 0.32, 0.26, 1)
const FAINT := 0.12
## The most see-through it gets, right next to him: a hint, not a marker.
const STRONG := 0.42
const PULSE_SLOW := 0.8
const PULSE_FAST := 3.0

var source: Node2D
var _time := 0.0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

## 0 out of earshot (or on screen, or not wanted), up to 1 right next to it.
func _strength(from: Vector2) -> float:
	if not is_instance_valid(source) or Cutscenes.is_active():
		return 0.0
	var distance := from.distance_to(source.global_position)
	var linear := 1.0 - clampf((distance - NEAR) / (HEAR_RANGE - NEAR), 0.0, 1.0)
	# Squared, so it stays faint and slow until he's actually close.
	return linear * linear

func _draw() -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null or not is_instance_valid(source):
		return
	var strength := _strength(car.global_position)
	if strength <= 0.0:
		return
	var view := get_viewport().get_canvas_transform()
	var screen := get_viewport_rect().size
	var target := view * source.global_position
	if Rect2(Vector2.ZERO, screen).grow(-20.0).has_point(target):
		return
	var center := view * car.global_position
	var direction := (target - center).normalized()
	var at := center + direction * minf(screen.x, screen.y) * RING
	var distance := car.global_position.distance_to(source.global_position)
	var count := 3 if distance < THREE_WITHIN else (2 if distance < TWO_WITHIN else 1)
	var speed := lerpf(PULSE_SLOW, PULSE_FAST, strength)
	var size := lerpf(0.9, 1.1, strength)
	for i in count:
		# The pulse runs outward along the stack, like a sound wave.
		var wave := fposmod(_time * speed - i * 0.3, 1.0)
		var lit := 1.0 - wave
		var alpha := lerpf(FAINT, STRONG, strength) * lerpf(0.6, 1.0, lit)
		var tip := at + direction * ((i - (count - 1) * 0.5) * STEP * size)
		_draw_chevron(tip, direction, size, Color(COLOR, alpha))

func _draw_chevron(tip: Vector2, direction: Vector2, size: float, color: Color) -> void:
	var back := -direction * ARM * size * 0.7
	var side := direction.orthogonal() * ARM * size
	draw_colored_polygon(FlatProps.sliver(tip + back + side, tip, THICK * size), color)
	draw_colored_polygon(FlatProps.sliver(tip + back - side, tip, THICK * size), color)
