@tool
class_name ForgeBuilding
extends Obstacle
## The scrap forge's smelter house: a brick shed under a tin lean-to roof, a
## furnace mouth glowing in the front wall and a chimney puffing smoke.
## Flat polygons only, drawn centred on the origin like FarmBarn. The glow
## flickers and the smoke drifts, so it redraws every frame.

const BRICK := Color(0.45, 0.26, 0.19)
const BRICK_DARK := Color(0.36, 0.2, 0.15)
const TIN := Color(0.52, 0.54, 0.56)
const FLAME := Color(0.98, 0.62, 0.12)
const FLAME_CORE := Color(1.0, 0.86, 0.4)
const SMOKE := Color(0.42, 0.41, 0.4, 0.75)

const ROOF_Y := -40.0
const ROOF_RISE := 26.0
const MOUTH := Rect2(-44.0, 18.0, 88.0, 66.0)
const CHIMNEY := Rect2(62.0, -150.0, 34.0, 110.0)
const SMOKE_PUFFS := 3
const SMOKE_RISE := 120.0
const SMOKE_CYCLE := 4.0

## How far off the furnace's roar carries, in world pixels.
const FURNACE_HEARING_RANGE := 900.0

var _time := 0.0

func _ready() -> void:
	super()
	add_to_group(OffscreenCuller.GROUP)
	if Engine.is_editor_hint():
		return
	var furnace := SustainedSound.new()
	furnace.sound_name = &"furnace_loop"
	furnace.base_volume_db = -8.0
	furnace.fade_in_time = 1.0
	furnace.position = MOUTH.get_center() + art_origin()
	furnace.max_distance = FURNACE_HEARING_RANGE
	add_child(furnace)
	furnace.set_active(true)

func _process(delta: float) -> void:
	_time += delta
	queue_redraw()

func _draw() -> void:
	draw_set_transform(art_origin())
	var half := size / 2.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x + 8.0, half.y - 10.0), Vector2(half.x + 6.0, half.y - 10.0),
		Vector2(half.x + 24.0, half.y + 10.0), Vector2(-half.x + 22.0, half.y + 10.0),
	]), UiPalette.SHADOW)
	_draw_chimney()
	_draw_walls(half)
	_draw_roof(half)
	_draw_mouth()
	_draw_smoke()

func _draw_walls(half: Vector2) -> void:
	draw_rect(Rect2(-half.x, ROOF_Y, size.x, half.y - ROOF_Y), BRICK)
	draw_rect(Rect2(half.x - 18.0, ROOF_Y, 18.0, half.y - ROOF_Y), BRICK_DARK)

func _draw_roof(half: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x - 14.0, ROOF_Y - ROOF_RISE), Vector2(half.x + 14.0, ROOF_Y - ROOF_RISE * 0.3),
		Vector2(half.x + 14.0, ROOF_Y + 6.0), Vector2(-half.x - 14.0, ROOF_Y + 6.0),
	]), TIN)

func _draw_chimney() -> void:
	draw_rect(CHIMNEY, BRICK)
	draw_rect(Rect2(CHIMNEY.end.x - 8.0, CHIMNEY.position.y, 8.0, CHIMNEY.size.y), BRICK_DARK)

## The furnace mouth: an arched hole with a flickering fire heaped in it.
func _draw_mouth() -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(MOUTH.position.x, MOUTH.end.y), Vector2(MOUTH.position.x, MOUTH.position.y + 18.0),
		Vector2(MOUTH.position.x + 16.0, MOUTH.position.y), Vector2(MOUTH.end.x - 16.0, MOUTH.position.y),
		Vector2(MOUTH.end.x, MOUTH.position.y + 18.0), Vector2(MOUTH.end.x, MOUTH.end.y),
	]), UiPalette.VOID)
	var flicker := 0.5 + 0.5 * sin(_time * 11.0) * sin(_time * 7.3 + 1.0)
	_draw_flames(FLAME, 34.0 + flicker * 8.0, 0.9, 3)
	_draw_flames(FLAME_CORE, 14.0 + flicker * 6.0, 0.45, 1)

## A row of `tongues` flame tongues along the bottom of the mouth, `height`
## tall and `width_fraction` of the mouth wide.
func _draw_flames(color: Color, height: float, width_fraction: float, tongues: int) -> void:
	var width := MOUTH.size.x * width_fraction
	var left := MOUTH.get_center().x - width / 2.0
	var bottom := MOUTH.end.y
	var points := PackedVector2Array([Vector2(left, bottom)])
	for i in tongues:
		var x := left + width * (i + 0.5) / tongues
		var sway := sin(_time * 9.0 + i * 1.7) * 3.0
		points.append(Vector2(x + sway, bottom - height * (0.8 + 0.2 * sin(_time * 13.0 + i))))
		if i < tongues - 1:
			points.append(Vector2(x + width / tongues * 0.5, bottom - height * 0.4))
	points.append(Vector2(left + width, bottom))
	draw_colored_polygon(points, color)

func _draw_smoke() -> void:
	var top := Vector2(CHIMNEY.get_center().x, CHIMNEY.position.y - 10.0)
	for i in SMOKE_PUFFS:
		var t := fposmod(_time / SMOKE_CYCLE + float(i) / SMOKE_PUFFS, 1.0)
		var center := top + Vector2(sin(t * 5.0 + i) * 10.0 + t * 30.0, -t * SMOKE_RISE)
		var color := SMOKE
		color.a *= 1.0 - t
		draw_colored_polygon(FlatProps.octagon(center, 10.0 + t * 18.0, 9.0 + t * 14.0), color)
