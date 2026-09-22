extends Node2D
## Throwaway: renders the Water + Terrain nodes (markers included) with the real
## renderer and saves PNGs so the coast bands, biome cells and water ripples can
## be eyeballed.

@onready var _camera: Camera2D = $Camera2D

var _shots := [
	{"pos": Vector2(5350, -250), "zoom": Vector2.ONE, "path": "/tmp/terrain_coast_east.png"},
	{"pos": Vector2(0, -3000), "zoom": Vector2.ONE, "path": "/tmp/terrain_coast_north.png"},
	{"pos": Vector2(-5100, 0), "zoom": Vector2.ONE, "path": "/tmp/terrain_coast_west.png"},
	{"pos": Vector2(0, 0), "zoom": Vector2(0.5, 0.5), "path": "/tmp/terrain_biomes.png"},
	{"pos": Vector2(0, 0), "zoom": Vector2(0.12, 0.12), "path": "/tmp/terrain_whole.png"},
]

func _ready() -> void:
	_run.call_deferred()

func _run() -> void:
	var land := $Terrain as TerrainNetwork
	var water := $Water as Water
	for shot in _shots:
		_camera.position = shot["pos"]
		_camera.zoom = shot["zoom"]
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		image.save_png(shot["path"])
		print("saved ", shot["path"])
	print("islands=", land.get_island_polygons().size(), " cells=", land._cells.size())
	print("on_land(0,0)=", land.is_on_land(Vector2.ZERO))
	# The whole city box must be on land however the coast wobbles — that's the
	# point of wobbling outward only. Four corners is the harshest case.
	var bounds := land._normalized_bounds()
	var corners := [bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)]
	for corner in corners:
		print("bounds corner ", corner, " on_land=", land.is_on_land(corner))
	print("on_land(20000,0)=", land.is_on_land(Vector2(20000, 0)))
	# Coastline must actually wander: sample the shoreline's distance from the
	# island centre round the loop and report the spread.
	var coast: PackedVector2Array = land.get_island_polygons()[0]
	var centre := bounds.get_center()
	var lowest := INF
	var highest := 0.0
	for point in coast:
		var d := point.distance_to(centre)
		lowest = minf(lowest, d)
		highest = maxf(highest, d)
	print("coast reach min=", lowest, " max=", highest, " spread=", highest - lowest)
	# Biome cells must tile the land: the nearest-marker rule and the drawn cells
	# are the same rule, so a point inside a cell must agree with biome_at().
	print("biome_at(300,-200)=", land.biome_at(Vector2(300, -200)), " (expect 0 PLAINS)")
	print("biome_at(-700,1500)=", land.biome_at(Vector2(-700, 1500)), " (expect 2 DESERT)")
	print("biome_at(-3500,-1800)=", land.biome_at(Vector2(-3500, -1800)), " (expect 3 FOREST)")
	print("patches=", land._islands[0].patches.size())
	print("water_rect=", water._visible_rect(), " t=", water._time)
	get_tree().quit()
