@tool
class_name FarmBarn
extends Obstacle
## The farm's red barn, gable end on: a red gable under a gambrel roof, a
## dark door with a white X brace and a black hay loft. Flat polygons only,
## drawn centred on the origin like RegistrationBooth.

const WALL := Color(0.62, 0.2, 0.16)
const ROOF := Color(0.3, 0.28, 0.27)
const TRIM := UiPalette.TRIM_OFF_WHITE

const SHADE_W := 18.0
const EAVE_Y := -20.0
const KNEE_Y := -62.0
const RIDGE_Y := -92.0
const KNEE_INSET := 30.0
const ROOF_THICKNESS := 12.0
const DOOR := Rect2(-40.0, 20.0, 80.0, 80.0)
const LOFT := Rect2(-18.0, -52.0, 36.0, 30.0)

func _draw() -> void:
	var half := size / 2.0
	_draw_shadow(half)
	_draw_walls(half)
	_draw_roof_edge(half)
	draw_rect(LOFT, UiPalette.VOID)
	_draw_door(half)

func _gable(half: Vector2, grow: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(-half.x - grow, EAVE_Y), Vector2(-half.x + KNEE_INSET - grow, KNEE_Y - grow),
		Vector2(0.0, RIDGE_Y - grow), Vector2(half.x - KNEE_INSET + grow, KNEE_Y - grow),
		Vector2(half.x + grow, EAVE_Y),
	])

func _draw_shadow(half: Vector2) -> void:
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x + 8.0, half.y - 10.0), Vector2(half.x + 6.0, half.y - 10.0),
		Vector2(half.x + 24.0, half.y + 10.0), Vector2(-half.x + 22.0, half.y + 10.0),
	]), UiPalette.SHADOW)

func _draw_walls(half: Vector2) -> void:
	var outline := _gable(half, 0.0)
	outline.append(Vector2(half.x, half.y))
	outline.append(Vector2(-half.x, half.y))
	outline.reverse()
	draw_colored_polygon(outline, WALL)
	draw_colored_polygon(PackedVector2Array([
		Vector2(half.x - SHADE_W, lerpf(KNEE_Y, EAVE_Y, 1.0 - SHADE_W / KNEE_INSET)), Vector2(half.x, EAVE_Y),
		Vector2(half.x, half.y), Vector2(half.x - SHADE_W, half.y),
	]), WALL.darkened(0.2))

## The roof seen edge-on: one thick band over the gable, overhanging it.
func _draw_roof_edge(half: Vector2) -> void:
	var outer := _gable(half, ROOF_THICKNESS)
	var inner := _gable(half, 0.0)
	var band := PackedVector2Array(outer)
	for i in range(inner.size() - 1, -1, -1):
		band.append(inner[i])
	draw_colored_polygon(band, ROOF)

func _draw_door(half: Vector2) -> void:
	var door := Rect2(DOOR.position, Vector2(DOOR.size.x, half.y - DOOR.position.y))
	draw_rect(door, WALL.darkened(0.3))
	draw_colored_polygon(FlatProps.sliver(door.position + Vector2(6.0, 6.0), door.end - Vector2(6.0, 4.0), 6.0), TRIM)
	draw_colored_polygon(FlatProps.sliver(Vector2(door.end.x - 6.0, door.position.y + 6.0), Vector2(door.position.x + 6.0, door.end.y - 4.0), 6.0), TRIM)
