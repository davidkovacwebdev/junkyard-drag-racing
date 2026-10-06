class_name CemeteryGrounds
extends Node2D
## The cemetery behind the graveyard gate: a big lot of dead grass with
## gravel paths, rows of tombstones and crosses, a few crypts and dead
## trees, all fenced in with spiked iron. The scene's root, so the ground it
## paints sits behind the Y-sorted `Grounds` child (see JunkyardYard).
##
## The Drag Queen's grave is in the far back corner, out of sight from the
## gate, so the player has to drive around a bit to find it. The rows of
## graves are laid out here in code from `seed`; the grave itself, the car
## and the way out are placed in cemetery.tscn.

## The fenced lot, centred on the origin. The gate is in the bottom fence.
@export var lot_size: Vector2 = Vector2(2800, 2000)
## Extra dirt past the fence, so the camera never sees past the edge.
@export var margin: float = 700.0
@export var gate_half_width: float = 150.0
@export var seed: int = 31

@export_group("Colors")
@export var dirt_color: Color = Color(0.36, 0.33, 0.25, 1)
@export var grass_color: Color = GraveyardProp.DEAD_GRASS
@export var gravel_color: Color = Color(0.56, 0.54, 0.48, 1)
@export var patch_color: Color = GraveyardProp.MOUND

const PATH_WIDTH := 150.0
const WALL_THICKNESS := 60.0
## The gravel paths, as polylines in lot space: up from the gate, across
## the middle, and the long way round to the back corner.
const PATHS := [
	[Vector2(0, 1000), Vector2(0, 150), Vector2(0, -260)],
	[Vector2(-1150, 150), Vector2(1100, 150)],
	[Vector2(1100, 150), Vector2(1100, -560), Vector2(780, -760)],
	[Vector2(-1150, 150), Vector2(-1150, -620), Vector2(-300, -620)],
]
const ROW_YS := [-820.0, -420.0, -120.0, 420.0, 700.0]
const ROW_SPACING := 150.0
## Graves stay off the paths by this much, and out of these clearings
## (the Drag Queen's corner, the crypt at the head of the main path).
const PATH_CLEARANCE := 105.0
const CLEARINGS := [
	Rect2(520, -1000, 880, 480),
	Rect2(-220, -520, 440, 320),
]
const CRYPTS := [Vector2(0, -330), Vector2(-700, -880), Vector2(260, -880)]
const DEAD_TREES := [
	Vector2(-1250, -880), Vector2(1260, 330), Vector2(-420, 860), Vector2(560, -300),
	Vector2(1270, -420), Vector2(-850, 300), Vector2(470, -700),
]

@onready var _grounds: Node2D = $Grounds

func _ready() -> void:
	_build_walls()
	_build_fence()
	_build_graves()

## The hint at the bottom says what to do here, and how to leave once it's
## done.
func _process(_delta: float) -> void:
	var hint := get_node_or_null(^"UI/Hint") as Label
	if hint == null:
		return
	var searching := Quests.has_quest(DragQueenGrave.QUEST_ID) and not Quests.is_ready(DragQueenGrave.QUEST_ID)
	hint.text = "Find the Drag Queen's grave and leave Grandpa's wheel" if searching else "Drive out the gate to leave"

func _draw() -> void:
	var half := lot_size / 2.0
	var margin_vec := Vector2.ONE * margin
	draw_rect(Rect2(-half - margin_vec, lot_size + margin_vec * 2.0), dirt_color)
	draw_rect(Rect2(-half, lot_size), grass_color)
	var rng := _rng()
	for i in 6:
		var at := Vector2(rng.randf_range(-half.x + 120.0, half.x - 120.0), rng.randf_range(-half.y + 120.0, half.y - 120.0))
		var radius := rng.randf_range(60.0, 110.0)
		draw_colored_polygon(FlatProps.octagon(at, radius, radius * 0.4), patch_color)
	for path: Array in PATHS:
		for i in path.size() - 1:
			draw_colored_polygon(FlatProps.sliver(path[i], path[i + 1], PATH_WIDTH), gravel_color)
			draw_colored_polygon(FlatProps.octagon(path[i + 1], PATH_WIDTH * 0.5, PATH_WIDTH * 0.5), gravel_color)
	# Two stone gate posts framing the way out.
	for x: float in [-gate_half_width, gate_half_width]:
		draw_rect(Rect2(x - 14.0, half.y - 96.0, 28.0, 96.0), GraveyardProp.STONE)
		draw_rect(Rect2(x + 4.0, half.y - 96.0, 10.0, 96.0), GraveyardProp.STONE_SHADE)

func _build_walls() -> void:
	var half := lot_size / 2.0
	var t := WALL_THICKNESS
	var walls := StaticBody2D.new()
	walls.name = "Walls"
	add_child(walls)
	var side := half.x - gate_half_width
	for rect: Rect2 in [
		Rect2(-half.x - t, -half.y - t, lot_size.x + t * 2.0, t),
		Rect2(-half.x - t, -half.y, t, lot_size.y),
		Rect2(half.x, -half.y, t, lot_size.y),
		Rect2(-half.x - t, half.y, side + t, t),
		Rect2(gate_half_width, half.y, side + t, t),
	]:
		var shape := RectangleShape2D.new()
		shape.size = rect.size
		var collision := CollisionShape2D.new()
		collision.shape = shape
		collision.position = rect.get_center()
		walls.add_child(collision)

func _build_fence() -> void:
	var half := lot_size / 2.0
	_add_prop(GraveyardProp.Kind.IRON_FENCE, Vector2(-half.x, -half.y), 0.0, lot_size.x)
	_add_prop(GraveyardProp.Kind.IRON_FENCE, Vector2(-half.x, -half.y), 0.0, lot_size.y, true)
	_add_prop(GraveyardProp.Kind.IRON_FENCE, Vector2(half.x, -half.y), 0.0, lot_size.y, true)
	_add_prop(GraveyardProp.Kind.IRON_FENCE, Vector2(-half.x, half.y), 0.0, half.x - gate_half_width - 14.0)
	_add_prop(GraveyardProp.Kind.IRON_FENCE, Vector2(gate_half_width + 14.0, half.y), 0.0, half.x - gate_half_width - 14.0)

## Rows of tombstones and crosses, each a little crooked, with gaps where the
## paths run through.
func _build_graves() -> void:
	var rng := _rng()
	var half := lot_size / 2.0
	for row_y: float in ROW_YS:
		var x := -half.x + 110.0
		while x < half.x - 80.0:
			var at := Vector2(x + rng.randf_range(-12.0, 12.0), row_y + rng.randf_range(-10.0, 10.0))
			x += ROW_SPACING
			if not _is_free(at):
				continue
			var kind := GraveyardProp.Kind.CROSS if rng.randf() < 0.3 else GraveyardProp.Kind.TOMBSTONE
			_add_prop(kind, at, rng.randf_range(-9.0, 9.0))
	for at: Vector2 in CRYPTS:
		_add_prop(GraveyardProp.Kind.CRYPT, at, 0.0)
	for at: Vector2 in DEAD_TREES:
		_add_prop(GraveyardProp.Kind.DEAD_TREE, at, 0.0)

func _is_free(at: Vector2) -> bool:
	for clearing: Rect2 in CLEARINGS:
		if clearing.has_point(at):
			return false
	for path: Array in PATHS:
		for i in path.size() - 1:
			var nearest := Geometry2D.get_closest_point_to_segment(at, path[i], path[i + 1])
			if nearest.distance_to(at) < PATH_CLEARANCE:
				return false
	return true

func _add_prop(kind: GraveyardProp.Kind, at: Vector2, lean: float, length: float = 0.0,
		vertical: bool = false) -> void:
	var prop := GraveyardProp.new()
	prop.kind = kind
	prop.lean_degrees = lean
	if length > 0.0:
		prop.length = length
	prop.vertical = vertical
	prop.position = at
	_grounds.add_child(prop)

func _rng() -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	return rng
