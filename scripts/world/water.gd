@tool
class_name Water
extends Node2D
## The ocean the world map floats on. Everything on the map that isn't island
## terrain (see `terrain.gd`) is water, so this node paints the deep fill plus
## a slow drift of lighter ripple strokes across it. Flat shapes, a couple of
## values, barely-there motion — the same stepped, cell-shaded look the
## building parts are drawn in. **Purely cosmetic**: the car drives over it
## like any other ground, and if it drives off the island it just keeps going.
##
## **Draw order.** Water goes behind the terrain, which goes behind everything
## else: park it as the first child of the map and give it a very negative
## `z_index` (the map uses `-1000` for the water and `-900` for the terrain).
##
## Only the slice of ocean the camera can actually see is drawn, so the map can
## be as big as it likes without the redraw getting more expensive. Ripples are
## laid out on a grid in world space and wrapped, so they read as an endless
## surface instead of a patch that travels with the car.

@export_group("Surface")
## Deep water. The whole visible area is flooded with this first.
@export var deep_color: Color = Color("2f6f8f")
## The drifting ripple strokes. Kept faint on purpose — this is a suggestion of
## movement, not a texture.
@export var ripple_color: Color = Color(0.8, 0.93, 0.95, 0.2)
@export var ripple_width: float = 5.0
@export var ripple_length: float = 96.0
## Grid pitch between ripples. Bigger = sparser water.
@export var ripple_spacing: float = 260.0
## Extra pitch applied to every other row, so the strokes come out in a brick
## pattern instead of neat columns.
@export_range(0.0, 1.0) var ripple_row_offset: float = 0.5

@export_group("Motion")
## Pixels per second the ripples travel sideways.
@export var drift_speed: float = 22.0
## Wave speed and height of the ripples' own bob. Both are deliberately slow.
@export var bob_speed: float = 0.9
@export var bob_height: float = 16.0
## Drawn past the viewport edge, so a stroke never pops in mid-screen.
@export var view_margin: float = 420.0

## Fallback patch of ocean, used when there's no camera to measure (and as a
## safety net in the editor if the viewport transform comes back degenerate).
const FALLBACK_RECT := Rect2(-6000.0, -4000.0, 12000.0, 8000.0)

var _time: float = 0.0

func _ready() -> void:
	_time = 0.0
	set_process(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	var rect := _visible_rect()
	draw_rect(rect, deep_color)
	_draw_ripples(rect)

## The part of this node's own space the camera can see, in local coordinates,
## grown by `view_margin` on every side.
func _visible_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return FALLBACK_RECT
	# Local -> viewport, i.e. through this node's transform *and* the active
	# camera. Inverting it and pushing the viewport rect through gives us the
	# world rect on screen, whatever the camera's zoom happens to be.
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var vp := viewport.get_visible_rect()
	var corner_a := to_local * vp.position
	var corner_b := to_local * vp.end
	var rect := Rect2(corner_a, corner_b - corner_a).abs()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return FALLBACK_RECT
	return rect.grow(view_margin)

## One pass of the ripple grid, snapped to whole cells so the pattern is
## identical wherever the camera happens to be looking.
func _draw_ripples(rect: Rect2) -> void:
	var spacing := maxf(ripple_spacing, 32.0)
	var drift := fposmod(_time * drift_speed, spacing)
	var first_row := int(floor(rect.position.y / spacing))
	var first_col := int(floor(rect.position.x / spacing))
	var rows := int(ceil(rect.size.y / spacing)) + 2
	var cols := int(ceil(rect.size.x / spacing)) + 2
	for r in rows:
		var row := first_row + r
		var offset := spacing * ripple_row_offset * float(row & 1)
		for c in cols:
			var col := first_col + c
			var bob := sin(_time * bob_speed + float(row) * 1.7 + float(col) * 0.8)
			var head := Vector2(float(col) * spacing + offset + drift, float(row) * spacing + bob * bob_height)
			draw_line(head, head + Vector2(ripple_length, 0.0), ripple_color, ripple_width, true)
