class_name DragTrackArt
extends Node2D
## The straight drag strip a race is run on: the asphalt, a white line down every
## lane boundary, the start line, and the checkered finish band. Plus a bit of
## character: a few repair patches, burnout marks, chunky cracks and oil puddles.
##
## Nothing here ever moves. This is the track the player sees, and it stays put —
## the harness that fakes cars weaving across lanes (single_lane_race_setup.gd)
## does that on the *cars* and leaves the road alone. So a car cutting across its
## neighbour is exactly that, and nothing about the track bends to meet it.
##
## Drawn in _draw() rather than authored as scene nodes because the checkered band
## alone is dozens of quads and every one of them is derived from the same couple
## of numbers: as nodes they'd be hundreds of hand-placed coordinates to keep in
## step with a lane height that's already an export here.
##
## Geometry is in the track's own coordinates. `top_lane_y` is the *centre* of the
## first lane, so the default (lanes 200 apart starting at y = 0) lines up with
## Slabs/SlabN and with where the harness drops its cars — nothing to work out.
##
## The one thing it has to agree with anything else about is `finish_x`: it's the
## same number the cars are judged against on the RaceController, so the line they
## cross is the line that counts.
##
## The wear is seeded (`wear_seed`), so the track looks identical every time it's
## drawn. Nothing random changes between frames or between runs.

## How many lanes are painted, and how far apart their centre lines are.
@export var lane_count := 5
@export var lane_height := 200.0
## Centre line of the first (top) lane. The rest follow below it.
@export var top_lane_y := 0.0

## --- Extent ---------------------------------------------------------------------

## How far the asphalt runs, along the track.
@export var left := -1600.0
@export var right := 6250.0
## Asphalt past the outermost lane boundaries. Cars drawn drifting up or down are
## drawn off their own lane line, so without this a car in the top or bottom lane
## could be drawn with its wheels hanging over the edge of the track.
@export var apron := 100.0
## Dirt laid out past the asphalt on every side, far enough that the race
## camera's widest view never shows the empty background.
@export var ground_margin := Vector2(3000.0, 2000.0)

## --- Markings -------------------------------------------------------------------

## Where the cars are judged to have finished. Keep it equal to the RaceController's
## finish_x for that race.
@export var finish_x := 5400.0
## Where the start line goes. Sits behind the staggered drop at the start of a race,
## so the cars are past it before they land.
@export var start_x := 0.0
@export var finish_cell := 48.0
## Columns of checkers across the band. Square cells are what make it read as a
## checkered flag rather than as stripes, so the band's width is this × finish_cell.
@export var finish_cells := 3

@export_group("Look")
## Dark asphalt with a cool blue cast: reads as tarmac, but sits nicely
## against warm-coloured cars.
@export var asphalt_color := Color(0.24, 0.29, 0.40, 1.0)
## Slightly blue-white so the lines don't look harsh against the tinted road.
@export var marking_color := Color(0.93, 0.96, 1.0, 0.95)
@export var marking_width := 10.0
@export var start_width := 18.0
@export var finish_light := Color(0.96, 0.98, 1.0, 1.0)
@export var finish_dark := Color(0.06, 0.08, 0.13, 1.0)

@export_group("Wear")
## Change this to reroll where everything lands. Same seed, same track.
@export var wear_seed := 7
@export var crack_count := 8
@export var puddle_count := 6
@export var patch_count := 8
## Cracks are a flat tone step darker than the road, chunky enough to read at
## race zoom. No hairlines.
@export var crack_color := Color(0.18, 0.22, 0.31, 1.0)
@export var crack_width := 7.0
@export var oil_color := Color(0.07, 0.07, 0.12, 1.0)
## One lighter step inside each oil puddle so it reads as wet.
@export var oil_shine := Color(0.17, 0.16, 0.27, 1.0)
## Burnout tracks off the start line.
@export var rubber_color := Color(0.04, 0.05, 0.09, 0.3)

@export_group("Ground")
@export var dirt_color := Color(0.62, 0.49, 0.35, 1.0)
## The packed gravel shoulder hugging both edges of the asphalt.
@export var shoulder_color := Color(0.50, 0.39, 0.28, 1.0)
@export var shoulder_width := 70.0
@export var dirt_patch_count := 7
@export var junk_pile_count := 8
@export var drum_color := Color(0.62, 0.22, 0.18, 1.0)

## Asphalt and markings are a fixed shape, so this only has to run once — but it's
## re-run whenever the scene is reloaded in the editor with different exports, which
## is the only way any of this changes.
func _draw() -> void:
	var top := _top_edge()
	var bottom := _bottom_edge()
	_draw_ground(top, bottom)
	draw_rect(Rect2(left, top, right - left, bottom - top), asphalt_color)

	# Wear goes under the paint, so the lane lines stay crisp over the cracks.
	_draw_patches(top, bottom)
	_draw_rubber()
	_draw_cracks(top, bottom)

	# A line down every boundary, the outermost included — those two are the edges
	# of the strip, and the rest divide it into lanes.
	for i in lane_count + 1:
		var y := top_lane_y - lane_height * 0.5 + lane_height * float(i)
		draw_rect(Rect2(left, y - marking_width * 0.5, right - left, marking_width), marking_color)

	# Oil sits on top of the lane lines, like it was spilled after they were painted.
	_draw_puddles(top, bottom)

	draw_rect(Rect2(start_x - start_width * 0.5, top, start_width, bottom - top), marking_color)
	_draw_finish(top, bottom)

func _top_edge() -> float:
	return top_lane_y - lane_height * 0.5 - apron

func _bottom_edge() -> float:
	return top_lane_y + lane_height * float(lane_count - 1) + lane_height * 0.5 + apron

## The checkered band: squares alternating light and dark, laid out from the top of
## the asphalt down. Rows are divided into the apron-to-apron height evenly rather
## than cut off at the far edge, so the band always reaches both edges of the track
## exactly — a ragged last row is the one thing that would read as a mistake.
func _draw_finish(top: float, bottom: float) -> void:
	var rows := maxi(2, int(round((bottom - top) / finish_cell)))
	var cell := Vector2(finish_cell, (bottom - top) / float(rows))
	var origin := Vector2(finish_x - cell.x * float(finish_cells) * 0.5, top)
	for row in rows:
		for column in finish_cells:
			var light := (row + column) % 2 == 0
			draw_rect(Rect2(origin + cell * Vector2(float(column), float(row)), cell),
					finish_light if light else finish_dark)

## --- Ground ---------------------------------------------------------------------

## Dirt all around the strip, a darker shoulder along each edge, a few bare
## patches and some tyre stacks and drums dumped well clear of the asphalt.
func _draw_ground(top: float, bottom: float) -> void:
	draw_rect(Rect2(left - ground_margin.x, top - ground_margin.y,
			right - left + ground_margin.x * 2.0, bottom - top + ground_margin.y * 2.0), dirt_color)
	draw_rect(Rect2(left, top - shoulder_width, right - left, shoulder_width), shoulder_color)
	draw_rect(Rect2(left, bottom, right - left, shoulder_width), shoulder_color)

	var rng := _rng(5)
	for n in dirt_patch_count:
		var center := Vector2(rng.randf_range(left - 1000.0, right + 1000.0), _off_track_y(rng, top, bottom, 200.0))
		draw_colored_polygon(_blob(rng, center, rng.randf_range(140.0, 260.0), 0.4), dirt_color.darkened(0.08))

	for n in junk_pile_count:
		var base := Vector2(rng.randf_range(left, right), _off_track_y(rng, top, bottom, 130.0))
		if n % 3 == 2:
			FlatProps.draw_drum(self, base, drum_color, 26.0, 64.0)
		else:
			FlatProps.draw_tire_stack(self, base, rng.randi_range(2, 4), 34.0, 18.0)

## A y on the dirt above or below the strip, at least `clearance` off the shoulder.
func _off_track_y(rng: RandomNumberGenerator, top: float, bottom: float, clearance: float) -> float:
	if rng.randf() < 0.5:
		return top - shoulder_width - rng.randf_range(clearance, clearance + 500.0)
	return bottom + shoulder_width + rng.randf_range(clearance, clearance + 500.0)

## --- Wear -----------------------------------------------------------------------

## One RNG per feature, so changing crack_count doesn't reshuffle the puddles.
func _rng(salt: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = wear_seed * 1000 + salt
	return rng

## Keeps wear off the start line and the checkered band so they stay clean.
func _clear_of_lines(x: float, margin: float) -> bool:
	var finish_half := finish_cell * float(finish_cells) * 0.5
	return absf(x - finish_x) > finish_half + margin \
			and absf(x - start_x) > start_width * 0.5 + margin

## Repaired sections: rectangles a shade lighter or darker than the road.
func _draw_patches(top: float, bottom: float) -> void:
	var rng := _rng(1)
	for n in patch_count:
		var size := Vector2(rng.randf_range(160.0, 320.0), rng.randf_range(60.0, 110.0))
		var pos := Vector2(rng.randf_range(left + 100.0, right - 100.0),
				rng.randf_range(top + 10.0, bottom - size.y - 10.0))
		var tone := rng.randf()
		if not _clear_of_lines(pos.x + size.x * 0.5, size.x * 0.5 + 10.0):
			continue
		draw_rect(Rect2(pos, size), asphalt_color.lightened(0.08) if tone < 0.5 else asphalt_color.darkened(0.12))

## Two flat wheel tracks per lane running off the start line.
func _draw_rubber() -> void:
	var rng := _rng(2)
	for lane in lane_count:
		var cy := top_lane_y + lane_height * float(lane)
		for side: float in [-1.0, 1.0]:
			var length := rng.randf_range(350.0, 800.0)
			var y := cy + side * 42.0 + rng.randf_range(-4.0, 4.0)
			draw_rect(Rect2(start_x + 30.0, y - 7.0, length, 14.0), rubber_color)

## A crack is a short zigzag of three chunky flat bars.
func _draw_cracks(top: float, bottom: float) -> void:
	var rng := _rng(3)
	for n in crack_count:
		var pos := Vector2(rng.randf_range(left + 100.0, right - 100.0),
				rng.randf_range(top + 40.0, bottom - 40.0))
		var heading := rng.randf_range(0.0, TAU)
		for s in 3:
			var to := pos + Vector2.from_angle(heading) * rng.randf_range(40.0, 70.0)
			if to.y < top or to.y > bottom or not _clear_of_lines(to.x, 20.0):
				break
			draw_colored_polygon(FlatProps.sliver(pos, to, crack_width), crack_color)
			heading += 1.1 if s % 2 == 0 else -1.1
			pos = to

## Oil: a dark eight-sided blob with one lighter, smaller blob inside it.
func _draw_puddles(top: float, bottom: float) -> void:
	var rng := _rng(4)
	for n in puddle_count:
		var radius := rng.randf_range(45.0, 100.0)
		var squish := rng.randf_range(0.45, 0.65)
		var center := Vector2(rng.randf_range(left + 200.0, right - 200.0),
				rng.randf_range(top + radius * 0.8, bottom - radius * 0.8))
		if not _clear_of_lines(center.x, radius * 1.3 + 15.0):
			continue
		var blob := _blob(rng, center, radius, squish)
		draw_colored_polygon(blob, oil_color)
		draw_colored_polygon(_shrunk(blob, center, 0.55, Vector2(-radius * 0.12, -radius * 0.05)), oil_shine)

## An irregular, squashed octagon, so it reads as a spill rather than a sign.
func _blob(rng: RandomNumberGenerator, center: Vector2, radius: float, squish: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	for i in 8:
		var a := TAU * (float(i) + 0.5) / 8.0
		var r := radius * rng.randf_range(0.85, 1.15)
		points.append(center + Vector2(cos(a) * r, sin(a) * r * squish))
	return points

## The same outline scaled toward its centre and nudged, for the shine.
func _shrunk(poly: PackedVector2Array, center: Vector2, factor: float, offset: Vector2) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in poly:
		out.append(center + (p - center) * factor + offset)
	return out
