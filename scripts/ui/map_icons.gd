class_name MapIcons
## Landmark, HOME, player-arrow and quest-target icons shared by the HUD
## Minimap and the full WorldMap, drawn onto whatever canvas is passed in.

const MAP_COLOR := Color(0.29, 0.35, 0.34)
const ROAD_COLOR := Color(0.58, 0.62, 0.58)
const HOME_SHADE := Color(0.80, 0.62, 0.08)
const JUNK_COLOR := Color(0.55, 0.28, 0.14)
const JUNK_SHADE := Color(0.45, 0.22, 0.11)
const BARN_COLOR := Color(0.62, 0.2, 0.16)
const BARN_SHADE := Color(0.5, 0.16, 0.13)
const ANVIL_COLOR := Color(0.26, 0.26, 0.28)
const ANVIL_SHADE := Color(0.2, 0.2, 0.22)
const EMBER_COLOR := Color(0.98, 0.62, 0.12)
const RALLY_HILL := Color(0.45, 0.52, 0.31)
const RALLY_HILL_SHADE := Color(0.38, 0.44, 0.26)
const RALLY_PENNANT := Color(0.85, 0.45, 0.12)
const HILL_ROCK := Color(0.45, 0.43, 0.41)
const HILL_ROCK_SHADE := Color(0.37, 0.35, 0.34)
const HILL_SNOW := Color(0.88, 0.89, 0.90)
const HOME_ICON_SIZE := 7.0
const LANDMARK_ICON_SIZE := 6.0
const PLAYER_ARROW_SIZE := 7.0
## The quest-target glow: its size around an icon, and how fast it pulses.
const TARGET_GLOW_RADIUS := 10.0
## HOME's icon is already yellow, so its glow is drawn wider to show as a ring.
const HOME_GLOW_RADIUS := 15.0
const TARGET_PULSE_SPEED := 5.0
const TARGET_GLOW := Color(0.95, 0.75, 0.10, 0.55)

## The name of the place a marker sits on (its parent's display name).
static func marker_name(marker: MinimapMarker) -> String:
	var place := marker.get_parent()
	return String(place.get("display_name")) if place != null and place.get("display_name") != null else ""

static func draw_target_glow(canvas: CanvasItem, at: Vector2, radius: float = TARGET_GLOW_RADIUS) -> void:
	var pulse := 0.85 + 0.15 * sin(Time.get_ticks_msec() * 0.001 * TARGET_PULSE_SPEED)
	var disc := PackedVector2Array()
	for i in 8:
		disc.append(at + Vector2.from_angle(TAU * (i + 0.5) / 8.0) * radius * pulse)
	canvas.draw_colored_polygon(disc, TARGET_GLOW)

static func draw_player_arrow(canvas: CanvasItem, at: Vector2, heading: float) -> void:
	var forward := Vector2.from_angle(heading)
	var side := forward.orthogonal()
	var tip := at + forward * PLAYER_ARROW_SIZE
	var tail := at - forward * PLAYER_ARROW_SIZE * 0.4
	var left := at - forward * PLAYER_ARROW_SIZE * 0.7 + side * PLAYER_ARROW_SIZE * 0.7
	var right := at - forward * PLAYER_ARROW_SIZE * 0.7 - side * PLAYER_ARROW_SIZE * 0.7
	canvas.draw_colored_polygon(PackedVector2Array([tip, left, tail]), UiPalette.TEXT_LIGHT)
	canvas.draw_colored_polygon(PackedVector2Array([tip, tail, right]), UiPalette.TRIM_OFF_WHITE)

static func draw_home(canvas: CanvasItem, at: Vector2) -> void:
	var unit := HOME_ICON_SIZE
	var body := PackedVector2Array([
		at + Vector2(-unit, -unit * 0.1), at + Vector2(0, -unit), at + Vector2(unit, -unit * 0.1),
		at + Vector2(unit * 0.8, unit * 0.8), at + Vector2(-unit * 0.8, unit * 0.8),
	])
	var shade := PackedVector2Array([
		at + Vector2(0, -unit), at + Vector2(unit, -unit * 0.1), at + Vector2(unit * 0.8, unit * 0.8), at + Vector2(0, unit * 0.8),
	])
	canvas.draw_colored_polygon(body, UiPalette.ACCENT_YELLOW)
	canvas.draw_colored_polygon(shade, HOME_SHADE)
	draw_square(canvas, at + Vector2(0, unit * 0.45), unit * 0.3, UiPalette.INK)

static func draw_landmark(canvas: CanvasItem, kind: MinimapMarker.Kind, at: Vector2) -> void:
	var unit := LANDMARK_ICON_SIZE
	match kind:
		MinimapMarker.Kind.DRAG_STRIP:
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.7, -unit), at + Vector2(-unit * 0.4, -unit),
				at + Vector2(-unit * 0.4, unit), at + Vector2(-unit * 0.7, unit),
			]), UiPalette.POST_GREY)
			for row in 2:
				for column in 2:
					var cell_color := UiPalette.TEXT_LIGHT if (row + column) % 2 == 0 else UiPalette.INK
					var cell_center := at + Vector2(-unit * 0.1 + column * unit * 0.6, -unit * 0.7 + row * unit * 0.6)
					draw_square(canvas, cell_center, unit * 0.3, cell_color)
		MinimapMarker.Kind.JUNKYARD:
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, unit * 0.6), at + Vector2(-unit * 0.3, -unit * 0.7),
				at + Vector2(unit * 0.4, -unit * 0.4), at + Vector2(unit, unit * 0.6),
			]), JUNK_COLOR)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.4, -unit * 0.4), at + Vector2(unit, unit * 0.6), at + Vector2(unit * 0.2, unit * 0.6),
			]), JUNK_SHADE)
		MinimapMarker.Kind.RAMP:
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, unit * 0.6), at + Vector2(unit, -unit * 0.6), at + Vector2(unit, unit * 0.6),
			]), UiPalette.CARDBOARD_BASE)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.6, -unit * 0.36), at + Vector2(unit, -unit * 0.6), at + Vector2(unit, unit * 0.6), at + Vector2(unit * 0.6, unit * 0.6),
			]), UiPalette.CARDBOARD_DARK)
		MinimapMarker.Kind.FARM:
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.8, unit * 0.7), at + Vector2(-unit * 0.8, -unit * 0.2), at + Vector2(0, -unit * 0.9),
				at + Vector2(unit * 0.8, -unit * 0.2), at + Vector2(unit * 0.8, unit * 0.7),
			]), BARN_COLOR)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0, -unit * 0.9), at + Vector2(unit * 0.8, -unit * 0.2), at + Vector2(unit * 0.8, unit * 0.7), at + Vector2(unit * 0.4, unit * 0.7),
			]), BARN_SHADE)
			draw_square(canvas, at + Vector2(0, unit * 0.35), unit * 0.3, UiPalette.TRIM_OFF_WHITE)
		MinimapMarker.Kind.FORGE:
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, -unit * 0.5), at + Vector2(unit * 0.8, -unit * 0.5), at + Vector2(unit * 0.8, -unit * 0.1),
				at + Vector2(unit * 0.3, 0), at + Vector2(unit * 0.5, unit * 0.7), at + Vector2(-unit * 0.5, unit * 0.7),
				at + Vector2(-unit * 0.3, 0), at + Vector2(-unit * 0.5, -unit * 0.2),
			]), ANVIL_COLOR)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.3, 0), at + Vector2(unit * 0.5, unit * 0.7), at + Vector2(unit * 0.15, unit * 0.7), at + Vector2(0, 0),
			]), ANVIL_SHADE)
			draw_square(canvas, at + Vector2(unit * 0.1, -unit * 0.85), unit * 0.2, EMBER_COLOR)
		MinimapMarker.Kind.SHOP:
			# A price tag: pointed end left, string hole in it.
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, 0), at + Vector2(-unit * 0.4, -unit * 0.7), at + Vector2(unit, -unit * 0.7),
				at + Vector2(unit, unit * 0.7), at + Vector2(-unit * 0.4, unit * 0.7),
			]), UiPalette.CARDBOARD_LIGHT)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(unit * 0.6, -unit * 0.7), at + Vector2(unit, -unit * 0.7),
				at + Vector2(unit, unit * 0.7), at + Vector2(unit * 0.6, unit * 0.7),
			]), UiPalette.CARDBOARD_DARK)
			draw_square(canvas, at + Vector2(-unit * 0.4, 0), unit * 0.18, UiPalette.VOID)
		MinimapMarker.Kind.RALLY:
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, unit * 0.7), at + Vector2(-unit * 0.1, -unit * 0.3), at + Vector2(unit, unit * 0.7),
			]), RALLY_HILL)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.1, -unit * 0.3), at + Vector2(unit, unit * 0.7), at + Vector2(unit * 0.4, unit * 0.7),
			]), RALLY_HILL_SHADE)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.2, -unit * 0.3), at + Vector2(-unit * 0.2, -unit), at + Vector2(unit * 0.5, -unit * 0.75),
			]), RALLY_PENNANT)

		MinimapMarker.Kind.HILL_CLIMB:
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit, unit * 0.7), at + Vector2(0, -unit), at + Vector2(unit, unit * 0.7),
			]), HILL_ROCK)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(0, -unit), at + Vector2(unit, unit * 0.7), at + Vector2(unit * 0.35, unit * 0.7),
			]), HILL_ROCK_SHADE)
			canvas.draw_colored_polygon(PackedVector2Array([
				at + Vector2(-unit * 0.4, -unit * 0.2), at + Vector2(0, -unit), at + Vector2(unit * 0.4, -unit * 0.2),
			]), HILL_SNOW)
		MinimapMarker.Kind.DERBY:
			canvas.draw_colored_polygon(FlatProps.octagon(at, unit, unit * 0.8), FlatProps.RUBBER_TOP)
			canvas.draw_colored_polygon(FlatProps.octagon(at, unit * 0.45, unit * 0.36), UiPalette.DANGER_RED)

static func draw_square(canvas: CanvasItem, at: Vector2, half_size: float, color: Color) -> void:
	canvas.draw_colored_polygon(PackedVector2Array([
		at + Vector2(-half_size, -half_size), at + Vector2(half_size, -half_size),
		at + Vector2(half_size, half_size), at + Vector2(-half_size, half_size),
	]), color)
