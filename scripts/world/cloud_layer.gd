class_name CloudLayer
extends Node2D
## Clouds drifting over the map, and the flat shadows they drop on everything
## under them. How many are out comes straight off `Weather.get_cloud_cover()`:
## none on a clear day, a few on a fair one, the whole sky while it rains.
##
## Each cloud is one chunky polygon (a few octagon puffs merged with a flat
## base), from a handful of templates. Like `RainLayer`, one tile of clouds is
## laid out once and repeated across every tile the camera sees, so it covers
## the view at any zoom for the cost of one small tile.
##
## Kept cheap: each template is triangulated once, so a cloud is a single
## triangle array handed straight to the renderer. The drift moves the layers instead of redrawing them, and
## a layer only redraws when the view reaches a new tile or the weather visibly
## changes (and for the sky, when the car has moved far enough to shift where
## the clouds thin out).
##
## The shadows sit over the world (cars and buildings included) but under the
## rain. The clouds themselves only fade in once the camera is zoomed out past
## `sky_zoom_start` with the binoculars, so close up you just see shade
## drifting across the ground, and even then they thin out over the car.

@export_group("Clouds")
@export var clouds_per_tile: int = 14
@export var tile_size: Vector2 = Vector2(6400.0, 4400.0)
@export var cloud_scale: Vector2 = Vector2(0.5, 1.0)
## World px per second the whole sky drifts.
@export var drift: Vector2 = Vector2(-26.0, 6.0)
## How much cover it takes a cloud to go from gone to fully there, so clouds
## thicken in one by one as the sky clouds over.
@export var fade_band: float = 0.08

@export_group("Look")
@export var shadow_color: Color = Color(0.02, 0.04, 0.1, 0.14)
@export var cloud_color: Color = Color(0.93, 0.94, 0.91)
@export var rain_cloud_color: Color = Color(0.6, 0.62, 0.65)
@export var cloud_alpha: float = 0.75
## Where the cloud sits relative to its shadow: up and back toward the sun.
@export var sky_offset: Vector2 = Vector2(-140.0, -520.0)
## Camera zoom the clouds start showing at, and the zoom they're solid by.
@export var sky_zoom_start: float = 0.36
@export var sky_zoom_full: float = 0.27
## The sky thins out around the middle of the view (where the car is): clouds
## drop to `car_clear_alpha` of their opacity within this many world px of it,
## and are back to full past `+ car_clear_fade`.
@export var car_clear_radius: float = 1000.0
@export var car_clear_fade: float = 800.0
@export_range(0.0, 1.0) var car_clear_alpha: float = 0.35

@export_group("Draw order")
@export var shadow_z: int = 850
@export var sky_z: int = 950

const TEMPLATE_COUNT := 3
## The shade strip's tint against the cloud body, baked into the sky shapes.
const SHADE_TINT := Color(0.82, 0.82, 0.82)
## How far the view centre can move (world px) before the sky redraws to
## follow it.
const SKY_REDRAW_DISTANCE := 96.0
const FALLBACK_RECT := Rect2(-1400.0, -900.0, 2800.0, 1800.0)

## A template already cut into triangles: `tints` per vertex (the shade strip
## is darker), multiplied by the cloud's colour when it's drawn.
class CloudShape:
	var points := PackedVector2Array()
	var indices := PackedInt32Array()
	var tints := PackedColorArray()

	func append_to(batch: TriangleBatch, at: Vector2, scale: float, color: Color) -> void:
		var placed := PackedVector2Array()
		var colors := PackedColorArray()
		placed.resize(points.size())
		colors.resize(points.size())
		for i in points.size():
			placed[i] = at + points[i] * scale
			colors[i] = tints[i] * color
		batch.add_triangles(placed, colors, indices)

class Cloud:
	var position: Vector2
	var template: int
	var scale: float
	## The cover this cloud needs before it shows. Spread evenly, so the cover
	## value is roughly the share of clouds out.
	var rank: float

var _clouds: Array[Cloud] = []
var _shadow_shapes: Array[CloudShape] = []
var _sky_shapes: Array[CloudShape] = []
var _reach: float = 0.0
var _drifted: Vector2 = Vector2.ZERO
## What each layer was last drawn for; a layer redraws only when this changes.
var _shadow_key: Array = []
var _sky_key: Array = []
## Tiles and view centre the next redraw covers, in each layer's own space.
var _shadow_tiles: Rect2i
var _sky_tiles: Rect2i
var _sky_view_center: Vector2
var _shadow_layer := Node2D.new()
var _sky_layer := Node2D.new()

func _ready() -> void:
	top_level = true
	global_position = Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = 2207
	for i in TEMPLATE_COUNT:
		_build_template(rng)
	var ranks: Array[float] = []
	for i in clouds_per_tile:
		ranks.append((i + 0.5) / clouds_per_tile * (1.0 - fade_band))
	ranks.shuffle()
	for i in clouds_per_tile:
		var cloud := Cloud.new()
		cloud.position = Vector2(rng.randf() * tile_size.x, rng.randf() * tile_size.y)
		cloud.template = rng.randi() % TEMPLATE_COUNT
		cloud.scale = rng.randf_range(cloud_scale.x, cloud_scale.y)
		cloud.rank = ranks[i]
		_clouds.append(cloud)
	for layer: Node2D in [_shadow_layer, _sky_layer]:
		layer.z_as_relative = false
		add_child(layer)
	_shadow_layer.z_index = shadow_z
	_sky_layer.z_index = sky_z
	_shadow_layer.draw.connect(_draw_shadows)
	_sky_layer.draw.connect(_draw_sky)

func _process(delta: float) -> void:
	_drifted = Vector2(fposmod(_drifted.x + drift.x * delta, tile_size.x),
			fposmod(_drifted.y + drift.y * delta, tile_size.y))
	_shadow_layer.position = _drifted
	_sky_layer.position = _drifted + sky_offset
	var cover := snappedf(Weather.get_cloud_cover(), 0.01)
	var sky_fade := snappedf(_sky_fade(), 0.02)
	_shadow_layer.visible = cover > 0.0
	_sky_layer.visible = cover > 0.0 and sky_fade > 0.0
	var view := _visible_rect()
	if _shadow_layer.visible:
		_shadow_tiles = _tiles_under(view, _shadow_layer.position)
		var key := [_shadow_tiles, cover]
		if key != _shadow_key:
			_shadow_key = key
			_shadow_layer.queue_redraw()
	if _sky_layer.visible:
		_sky_tiles = _tiles_under(view, _sky_layer.position)
		var center := (view.get_center() - _sky_layer.position).snapped(Vector2.ONE * SKY_REDRAW_DISTANCE)
		var key := [_sky_tiles, cover, sky_fade, snappedf(Weather.get_rain_intensity(), 0.02), center]
		if key != _sky_key:
			_sky_key = key
			_sky_view_center = view.get_center() - _sky_layer.position
			_sky_layer.queue_redraw()

## The tiles a layer drifted to `layer_position` needs drawn to cover `view`,
## as (first x, first y, last x, last y).
func _tiles_under(view: Rect2, layer_position: Vector2) -> Rect2i:
	var local := Rect2(view.position - layer_position, view.size).grow(_reach)
	return Rect2i(floori(local.position.x / tile_size.x), floori(local.position.y / tile_size.y),
			floori(local.end.x / tile_size.x), floori(local.end.y / tile_size.y))

## One cloud outline: a flat squashed base with three or four puffs on top,
## merged into a single polygon, plus its bottom shade strip. Baked into a
## shadow shape (the outline) and a sky shape (body and shade strip, cut apart so
## the see-through cloud doesn't double up where they meet).
func _build_template(rng: RandomNumberGenerator) -> void:
	var outline := FlatProps.octagon(Vector2(0.0, 40.0), 470.0, 120.0)
	var puffs := rng.randi_range(3, 4)
	for i in puffs:
		var x := lerpf(-300.0, 300.0, float(i) / (puffs - 1)) + rng.randf_range(-40.0, 40.0)
		var radius := rng.randf_range(150.0, 250.0) * (1.15 if i in [1, 2] else 0.9)
		var puff := FlatProps.octagon(Vector2(x, 10.0 - radius * 0.8), radius, radius * 0.9)
		outline = _largest(Geometry2D.merge_polygons(outline, puff))
	var bounds := Rect2(outline[0], Vector2.ZERO)
	for point in outline:
		bounds = bounds.expand(point)
	var shade_top := bounds.end.y - bounds.size.y * 0.3
	var band := PackedVector2Array([
		Vector2(bounds.position.x - 10.0, shade_top), Vector2(bounds.end.x + 10.0, shade_top),
		Vector2(bounds.end.x + 10.0, bounds.end.y + 10.0), Vector2(bounds.position.x - 10.0, bounds.end.y + 10.0),
	])
	_shadow_shapes.append(_shape([[outline]], [Color.WHITE]))
	_sky_shapes.append(_shape([Geometry2D.clip_polygons(outline, band), Geometry2D.intersect_polygons(outline, band)],
			[Color.WHITE, SHADE_TINT]))
	_reach = maxf(_reach, maxf(bounds.size.x, bounds.size.y) * cloud_scale.y)

static func _largest(pieces: Array[PackedVector2Array]) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for piece in pieces:
		var area := 0.0
		for i in piece.size():
			area += piece[i].cross(piece[(i + 1) % piece.size()])
		if absf(area) > best_area:
			best_area = absf(area)
			best = piece
	return best

## Triangulated once: each list of polygons in `groups` is tinted by the
## matching `tints` entry, so the shade strip rides along in the same array.
static func _shape(groups: Array, tints: Array[Color]) -> CloudShape:
	var shape := CloudShape.new()
	for group in groups.size():
		for polygon: PackedVector2Array in groups[group]:
			var first := shape.points.size()
			for index in Geometry2D.triangulate_polygon(polygon):
				shape.indices.append(first + index)
			shape.points.append_array(polygon)
			for point in polygon:
				shape.tints.append(tints[group])
	return shape

func _draw_shadows() -> void:
	if _shadow_key.is_empty():
		return
	var cover: float = _shadow_key[1]
	var batch := TriangleBatch.new()
	for at_and_cloud in _clouds_in(_shadow_tiles, cover):
		var cloud: Cloud = at_and_cloud[1]
		var color := shadow_color
		color.a *= _strength(cloud, cover)
		_shadow_shapes[cloud.template].append_to(batch, at_and_cloud[0], cloud.scale, color)
	batch.commit(_shadow_layer)

func _draw_sky() -> void:
	if _sky_key.is_empty():
		return
	var cover: float = _sky_key[1]
	var sky_fade: float = _sky_key[2]
	var body := cloud_color.lerp(rain_cloud_color, _sky_key[3])
	var batch := TriangleBatch.new()
	for at_and_cloud in _clouds_in(_sky_tiles, cover):
		var at: Vector2 = at_and_cloud[0]
		var cloud: Cloud = at_and_cloud[1]
		var clear := lerpf(car_clear_alpha, 1.0,
				clampf((at.distance_to(_sky_view_center) - car_clear_radius) / car_clear_fade, 0.0, 1.0))
		_sky_shapes[cloud.template].append_to(batch, at, cloud.scale,
				Color(body, cloud_alpha * _strength(cloud, cover) * sky_fade * clear))
	batch.commit(_sky_layer)

## Every cloud out at `cover` across `tiles`, as [position, cloud] pairs in the
## layer's own (undrifted) space.
func _clouds_in(tiles: Rect2i, cover: float) -> Array:
	var found := []
	for tile_y in range(tiles.position.y, tiles.size.y + 1):
		for tile_x in range(tiles.position.x, tiles.size.x + 1):
			var tile_origin := Vector2(tile_x * tile_size.x, tile_y * tile_size.y)
			for cloud in _clouds:
				if _strength(cloud, cover) > 0.0:
					found.append([tile_origin + cloud.position, cloud])
	return found

func _strength(cloud: Cloud, cover: float) -> float:
	return clampf((cover - cloud.rank) / fade_band, 0.0, 1.0)

## 0 close up, 1 once the camera is zoomed far enough out to see the sky.
func _sky_fade() -> float:
	var camera := get_viewport().get_camera_2d() if get_viewport() != null else null
	if camera == null:
		return 0.0
	return clampf(inverse_lerp(sky_zoom_start, sky_zoom_full, camera.zoom.x), 0.0, 1.0)

## Same measurement RainLayer uses: the view in this node's space, any zoom.
func _visible_rect() -> Rect2:
	var viewport := get_viewport()
	if viewport == null:
		return FALLBACK_RECT
	var to_local := get_global_transform_with_canvas().affine_inverse()
	var viewport_rect := viewport.get_visible_rect()
	var rect := Rect2(to_local * viewport_rect.position, to_local * viewport_rect.end - to_local * viewport_rect.position).abs()
	if rect.size.x < 1.0 or rect.size.y < 1.0:
		return FALLBACK_RECT
	return rect
