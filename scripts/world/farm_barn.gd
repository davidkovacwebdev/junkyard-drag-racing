@tool
class_name FarmBarn
extends Obstacle
## The farm's red barn, gable end on: plank walls under a gambrel roof, a white
## X-braced door, a hay loft poking straw out and a little cupola. Flat polygons
## only, drawn centred on the origin like RegistrationBooth.

const WALL := Color(0.62, 0.2, 0.16)
const ROOF := Color(0.3, 0.28, 0.27)
const TRIM := UiPalette.TRIM_OFF_WHITE
const STRAW := Color(0.86, 0.72, 0.36)

const PLANK_WIDTH := 16.0
const SHADE_W := 18.0
const SKIRT_H := 8.0
const EAVE_Y := -20.0
const KNEE_Y := -62.0
const RIDGE_Y := -92.0
const KNEE_INSET := 30.0
const DOOR := Rect2(-40.0, 20.0, 80.0, 80.0)
const LOFT := Rect2(-18.0, -52.0, 36.0, 32.0)

func _draw() -> void:
	var half := size / 2.0
	_draw_shadow(half)
	_draw_walls(half)
	_draw_roof_edge(half)
	_draw_loft()
	_draw_door(half)
	_draw_cupola()

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
	var x := -half.x + PLANK_WIDTH
	while x < half.x - SHADE_W:
		var top := _roof_y_at(half, x)
		draw_rect(Rect2(x, top, 2.0, half.y - top), WALL.darkened(0.14))
		x += PLANK_WIDTH
	draw_colored_polygon(PackedVector2Array([
		Vector2(half.x - SHADE_W, _roof_y_at(half, half.x - SHADE_W)), Vector2(half.x, EAVE_Y),
		Vector2(half.x, half.y), Vector2(half.x - SHADE_W, half.y),
	]), WALL.darkened(0.2))
	draw_rect(Rect2(-half.x, half.y - SKIRT_H, size.x, SKIRT_H), WALL.darkened(0.32))
	draw_colored_polygon(PackedVector2Array([
		Vector2(-half.x + 8.0, half.y - SKIRT_H), Vector2(-half.x + 16.0, half.y - 34.0),
		Vector2(-half.x + 30.0, half.y - 24.0), Vector2(-half.x + 36.0, half.y - SKIRT_H),
	]), UiPalette.RUST)

## Wall top at `x`, following the gambrel roof line.
func _roof_y_at(half: Vector2, x: float) -> float:
	var ax := absf(x)
	var knee_x := half.x - KNEE_INSET
	if ax >= knee_x:
		return lerpf(KNEE_Y, EAVE_Y, (ax - knee_x) / KNEE_INSET)
	return lerpf(RIDGE_Y, KNEE_Y, ax / knee_x)

## The roof seen edge-on: a thick shingled band over the gable, overhanging it.
func _draw_roof_edge(half: Vector2) -> void:
	var outer := _gable(half, 12.0)
	var inner := _gable(half, 0.0)
	for i in outer.size() - 1:
		draw_colored_polygon(PackedVector2Array([outer[i], outer[i + 1], inner[i + 1], inner[i]]),
				ROOF if i < 2 else ROOF.darkened(0.15))
	for i in inner.size() - 1:
		draw_colored_polygon(FlatProps.sliver(inner[i], inner[i + 1], 4.0), TRIM)

func _draw_loft() -> void:
	draw_rect(LOFT.grow(4.0), TRIM)
	draw_rect(LOFT, UiPalette.VOID)
	draw_colored_polygon(PackedVector2Array([
		LOFT.position + Vector2(0.0, LOFT.size.y), LOFT.position + Vector2(4.0, LOFT.size.y - 12.0),
		LOFT.position + Vector2(12.0, LOFT.size.y - 16.0), LOFT.position + Vector2(22.0, LOFT.size.y - 10.0),
		LOFT.position + Vector2(32.0, LOFT.size.y - 14.0), LOFT.end,
	]), STRAW)
	draw_colored_polygon(PackedVector2Array([
		LOFT.position + Vector2(8.0, LOFT.size.y), LOFT.position + Vector2(2.0, LOFT.size.y + 10.0),
		LOFT.position + Vector2(12.0, LOFT.size.y),
	]), STRAW)
	draw_rect(Rect2(LOFT.position.x - 4.0, LOFT.position.y - 14.0, LOFT.size.x + 8.0, 5.0), UiPalette.POST_GREY)

func _draw_door(half: Vector2) -> void:
	var door := Rect2(DOOR.position, Vector2(DOOR.size.x, half.y - DOOR.position.y))
	draw_rect(door.grow_individual(5.0, 5.0, 5.0, 0.0), TRIM)
	draw_rect(door, WALL.darkened(0.25))
	draw_rect(Rect2(door.get_center().x - 1.5, door.position.y, 3.0, door.size.y), TRIM.darkened(0.2))
	for leaf in [Rect2(door.position, Vector2(door.size.x / 2.0, door.size.y)),
			Rect2(door.position + Vector2(door.size.x / 2.0, 0.0), Vector2(door.size.x / 2.0, door.size.y))]:
		draw_colored_polygon(FlatProps.sliver(leaf.position, leaf.end, 4.0), TRIM)
		draw_colored_polygon(FlatProps.sliver(Vector2(leaf.position.x, leaf.end.y), Vector2(leaf.end.x, leaf.position.y), 4.0), TRIM)
	draw_rect(Rect2(door.end.x - 8.0, door.position.y, 8.0, door.size.y), WALL.darkened(0.35))

func _draw_cupola() -> void:
	var base := Rect2(-10.0, RIDGE_Y - 26.0, 20.0, 16.0)
	draw_rect(base, WALL)
	draw_rect(Rect2(base.end.x - 5.0, base.position.y, 5.0, base.size.y), WALL.darkened(0.2))
	draw_rect(Rect2(base.position.x + 5.0, base.position.y + 4.0, 8.0, 8.0), UiPalette.VOID)
	draw_colored_polygon(PackedVector2Array([
		Vector2(base.position.x - 5.0, base.position.y), Vector2(0.0, base.position.y - 12.0),
		Vector2(base.end.x + 5.0, base.position.y),
	]), ROOF)
	draw_rect(Rect2(-1.0, base.position.y - 26.0, 2.0, 14.0), UiPalette.METAL_GREY)
	draw_colored_polygon(PackedVector2Array([
		Vector2(-8.0, base.position.y - 24.0), Vector2(6.0, base.position.y - 28.0), Vector2(10.0, base.position.y - 22.0),
		Vector2(-4.0, base.position.y - 20.0),
	]), UiPalette.INK)
