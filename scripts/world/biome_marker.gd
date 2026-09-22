@tool
class_name BiomeMarker
extends Node2D
## A dot dropped on the map that claims the land around it for a biome.
##
## Markers cut the map up the way a Voronoi diagram does: every spot on land
## belongs to whichever marker is nearest, so the regions are straight-edged
## cells that meet along the bisectors between markers. Drag one and its borders
## follow — the terrain redraws live in the editor, and the coast bands, roads
## and everything else on top are untouched. Only the land's colour changes.
##
## Cells are clipped to the islands, so a marker doesn't need to sit on land:
## drop one out at sea and it just claims nothing, which is a safe way to keep a
## biome out of the corner of an island.
##
## **The dot is authoring-only.** It draws in the editor so you can see and grab
## it, and draws nothing at all while the game is running.

## Which biome this marker claims. The colour lives in `TerrainBiome`.
@export var biome: TerrainBiome.Kind = TerrainBiome.Kind.PLAINS:
	set(value):
		biome = value
		queue_redraw()

const DOT_RADIUS := 10.0
const LABEL_GAP := 15.0

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	var color := TerrainBiome.base_color(biome)
	# A dark ring first, so the dot reads against sand or water alike.
	draw_circle(Vector2.ZERO, DOT_RADIUS + 3.0, Color(0.1, 0.1, 0.12, 0.85))
	draw_circle(Vector2.ZERO, DOT_RADIUS, color)
	# Small cream crosshair, so the dot's exact centre is obvious.
	var arm := DOT_RADIUS * 0.52
	draw_line(Vector2(-arm, 0.0), Vector2(arm, 0.0), Color(0.97, 0.95, 0.9), 2.0)
	draw_line(Vector2(0.0, -arm), Vector2(0.0, arm), Color(0.97, 0.95, 0.9), 2.0)
	_draw_label(TerrainBiome.display_name(biome), color)

## The biome's name beside the dot. Drawn with the editor's fallback font —
## this is authoring furniture, not part of the game's art.
func _draw_label(text: String, color: Color) -> void:
	var font := ThemeDB.fallback_font
	if font == null:
		return
	var size := 12
	var baseline := Vector2(LABEL_GAP, 4.0)
	# Faint dark backing, so pale labels stay legible over pale sand.
	var shadow := Color(0.1, 0.1, 0.12, 0.6)
	for offset in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
		draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, shadow)
	draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color.lightened(0.5))
