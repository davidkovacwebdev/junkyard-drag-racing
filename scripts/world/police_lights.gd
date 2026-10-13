class_name PoliceLights
extends CanvasLayer
## The cops are after you: the whole screen washes red, then blue, then red,
## like a light bar's glow off everything (DinnerStory's run home). Flat
## colour over the world, under the HUD.

const LAYER := 3
const RED := Color(0.95, 0.12, 0.1)
const BLUE := Color(0.15, 0.3, 1.0)
## How strong the glow gets at its peak, and how fast it swaps colour.
const STRENGTH := 0.16
const SWAPS_PER_SECOND := 2.2

var _wash: ColorRect
var _time := 0.0

func _ready() -> void:
	layer = LAYER
	_wash = ColorRect.new()
	_wash.set_anchors_preset(Control.PRESET_FULL_RECT)
	_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_wash)

func _process(delta: float) -> void:
	_time += delta
	var phase := fmod(_time * SWAPS_PER_SECOND, 2.0)
	var colour := RED if phase < 1.0 else BLUE
	# Each flash swells and fades within its half.
	colour.a = STRENGTH * sin(fmod(phase, 1.0) * PI)
	_wash.color = colour
