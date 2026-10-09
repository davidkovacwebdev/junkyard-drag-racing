class_name GrandpaHorse
extends StaticBody2D
## Tiger: the horse the player bought Grandpa ("Giddy Up"), standing beside
## his wheelchair from then on. It's the real horse engine part, unhitched,
## like the farm's paddock horse, and neighs now and then.
##
## Once the player has the fence piece for "Fenced In" it's painted, so it's
## already there to see when they drive back: Grandpa used the black and
## orange paint on Tiger instead of the fence. Orange all over, a few crooked
## black stripes, an empty beer bottle lying under its belly, carrots on the
## ground it's munching on, and the mess of the job around its hooves: paint
## splashed on the grass and the two cans dropped where they were emptied.
##
## GrandpaNpc makes it and keeps it in step with the quests (`refresh()`);
## Grandpa's funeral makes a `stand_in` (always there, painted, no mess);
## cutscenes can bring it on early with `walk_in()` and paint it with
## `set_painted()`.

const HORSE := preload("res://scenes/parts/engines/engine_horse.tscn")
const HORSE_QUEST := &"horse_for_gramps"
const PAINT_QUEST := &"fence_for_tiger"
## Same size as the farm's paddock horse.
const HORSE_SCALE := 0.5
## The footprint the car bumps into, around the hooves.
const BODY_SIZE := Vector2(110.0, 24.0)
const NEIGH_INTERVAL := Vector2(12.0, 28.0)

## The paint job, by the horse's own colours (engine_horse.tscn): its coat,
## its far-side legs and its belly shade each get their own orange.
const COAT := Color(0.56, 0.36, 0.21)
const COAT_FAR := Color(0.42, 0.27, 0.16)
const COAT_SHADE := Color(0.47, 0.3, 0.17)
const ORANGE := Color(0.88, 0.5, 0.16)
const ORANGE_FAR := Color(0.72, 0.38, 0.12)
const ORANGE_SHADE := Color(0.78, 0.42, 0.14)
const STRIPE := Color(0.13, 0.12, 0.11)
## Crooked, uneven stripes across the barrel (torso space), painted by a
## drunk man in a wheelchair.
const BARREL_STRIPES := [
	[Vector2(-48.0, -95.0), Vector2(-37.0, -95.0), Vector2(-41.0, -62.0), Vector2(-52.0, -64.0)],
	[Vector2(-14.0, -96.0), Vector2(-1.0, -96.0), Vector2(-9.0, -61.0), Vector2(-17.0, -61.0)],
	[Vector2(22.0, -95.0), Vector2(29.0, -94.0), Vector2(34.0, -63.0), Vector2(19.0, -61.0)],
]
## One more down the neck (neck space).
const NECK_STRIPE := [Vector2(4.0, -20.0), Vector2(13.0, -24.0), Vector2(27.0, -42.0), Vector2(19.0, -44.0)]
## Under its belly and in front of its nose (horse space, ground at y = 0).
const BOTTLE := [Vector2(-26.0, -16.0), Vector2(4.0, -16.0), Vector2(12.0, -12.0), Vector2(22.0, -12.0),
		Vector2(22.0, -4.0), Vector2(12.0, -4.0), Vector2(4.0, 0.0), Vector2(-26.0, 0.0)]
const BOTTLE_CAP := [Vector2(22.0, -13.0), Vector2(29.0, -13.0), Vector2(29.0, -3.0), Vector2(22.0, -3.0)]
const BOTTLE_COLOR := Color(0.42, 0.25, 0.12)
const BOTTLE_CAP_COLOR := Color(0.8, 0.66, 0.3)
const CARROT_A := [Vector2(72.0, -14.0), Vector2(76.0, -2.0), Vector2(116.0, -4.0)]
const CARROT_B := [Vector2(80.0, -2.0), Vector2(84.0, 8.0), Vector2(122.0, 2.0)]
const CARROT_TOPS := [Vector2(56.0, -16.0), Vector2(70.0, -20.0), Vector2(76.0, -10.0),
		Vector2(80.0, 8.0), Vector2(66.0, 6.0)]
## The mess on the ground, in this node's space (unscaled, ground at y = 0):
## paint splashed on the grass under Tiger, and the emptied cans, one tipped
## over spilling orange and one standing in its own black puddle.
const SPLASH_ORANGE := [Vector2(-34.0, -4.0), Vector2(-6.0, -8.0), Vector2(22.0, -5.0), Vector2(30.0, 2.0),
		Vector2(8.0, 8.0), Vector2(-24.0, 7.0), Vector2(-40.0, 2.0)]
const SPLASH_BLACK := [Vector2(10.0, -2.0), Vector2(30.0, -4.0), Vector2(42.0, 1.0), Vector2(30.0, 7.0), Vector2(12.0, 5.0)]
## The orange can lies on its side, its open mouth (full of orange) toward
## the puddle it spilled; the black one stands with paint run down its front.
const CAN_SPILL := [Vector2(-104.0, 0.0), Vector2(-88.0, -3.0), Vector2(-72.0, 1.0), Vector2(-78.0, 8.0), Vector2(-100.0, 8.0)]
const CAN_TIPPED := [Vector2(-130.0, -20.0), Vector2(-106.0, -20.0), Vector2(-106.0, 2.0), Vector2(-130.0, 2.0)]
const CAN_TIPPED_SHADE := [Vector2(-130.0, -5.0), Vector2(-106.0, -5.0), Vector2(-106.0, 2.0), Vector2(-130.0, 2.0)]
const CAN_TIPPED_MOUTH := [Vector2(-108.0, -21.0), Vector2(-102.0, -16.0), Vector2(-102.0, -2.0), Vector2(-108.0, 3.0),
		Vector2(-112.0, -2.0), Vector2(-112.0, -16.0)]
const CAN_UPRIGHT := [Vector2(-70.0, -28.0), Vector2(-50.0, -28.0), Vector2(-50.0, 0.0), Vector2(-70.0, 0.0)]
const CAN_UPRIGHT_SHADE := [Vector2(-56.0, -28.0), Vector2(-50.0, -28.0), Vector2(-50.0, 0.0), Vector2(-56.0, 0.0)]
const CAN_UPRIGHT_LID := [Vector2(-71.0, -28.0), Vector2(-66.0, -33.0), Vector2(-54.0, -33.0), Vector2(-49.0, -28.0),
		Vector2(-54.0, -24.0), Vector2(-66.0, -24.0)]
## Black run down from the rim in two uneven drips, a long one and a short.
const CAN_UPRIGHT_DRIP := [Vector2(-70.0, -27.0), Vector2(-50.0, -27.0), Vector2(-50.0, -22.0), Vector2(-56.0, -22.0),
		Vector2(-56.0, -15.0), Vector2(-61.0, -15.0), Vector2(-61.0, -22.0), Vector2(-64.0, -22.0),
		Vector2(-64.0, -7.0), Vector2(-69.0, -7.0), Vector2(-69.0, -22.0), Vector2(-70.0, -22.0)]
const CAN_STEEL := Color(0.64, 0.68, 0.74)
const CAN_STEEL_SHADE := Color(0.52, 0.56, 0.63)
const CAN_LID := Color(0.8, 0.83, 0.88)

const CARROT := Color(0.9, 0.52, 0.18)
const CARROT_SHADE := Color(0.8, 0.42, 0.14)
const CARROT_TOP := Color(0.36, 0.55, 0.26)

var _horse: HorseEngine
var _painted := false
## At Grandpa's funeral: there and painted whatever the quests say, and
## without the paint job's mess on the ground.
var stand_in := false
var _paint_job: Array[Node] = []
var _neigh: AmbientCall

func _ready() -> void:
	_horse = HORSE.instantiate()
	_horse.scale = Vector2.ONE * HORSE_SCALE
	add_child(_horse)
	_horse.set_hitched(false)
	var shape := RectangleShape2D.new()
	shape.size = BODY_SIZE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -BODY_SIZE.y * 0.5)
	add_child(collision)
	_neigh = AmbientCall.new()
	_neigh.sound_name = &"horse_neigh"
	_neigh.interval_range = NEIGH_INTERVAL
	_neigh.volume_db = -10.0
	_neigh.max_distance = 1200.0
	add_child(_neigh)
	refresh()
	Quests.quest_completed.connect(func(_quest: QuestData) -> void: refresh())
	Quests.quest_ready.connect(func(_quest: QuestData) -> void: refresh())

## In step with the quests: there once "Giddy Up" is done, painted once
## "Fenced In"'s fence piece is in the trunk (or the quest is done).
func refresh() -> void:
	if stand_in:
		_set_present(true)
		set_painted(true)
		return
	_set_present(Quests.is_complete(HORSE_QUEST))
	set_painted(Quests.is_ready(PAINT_QUEST) or Quests.is_complete(PAINT_QUEST))

## Brought on early by a cutscene: walks in from `from` (world space) to its
## spot, legs going by themselves off the movement.
func walk_in(from: Vector2, seconds: float) -> Tween:
	var spot := global_position
	_set_present(true)
	_horse.global_position = from
	_horse.scale.x = HORSE_SCALE * signf(spot.x - from.x) if spot.x != from.x else HORSE_SCALE
	var tween := _horse.create_tween()
	tween.tween_property(_horse, "global_position", spot, seconds)
	tween.tween_callback(func() -> void: _horse.scale.x = HORSE_SCALE)
	return tween

## Walks the whole of Tiger (mess and all) to `to` (world space) in
## `seconds`, turned the way it's going. Cutscenes only.
func walk_to(to: Vector2, seconds: float) -> Tween:
	if to.x != global_position.x:
		face(to.x > global_position.x)
	var tween := create_tween()
	tween.tween_property(self, "global_position", to, seconds)
	return tween

## Head up from the carrots (to say something), or back down to them.
func lift_head(up: bool) -> void:
	_horse.grazing = not up

func face(right: bool) -> void:
	_horse.scale.x = HORSE_SCALE * (1.0 if right else -1.0)

func set_painted(painted: bool) -> void:
	if painted == _painted:
		return
	_painted = painted
	_horse.grazing = painted
	_recolor(_horse.get_node("Harness/Horse/Torso"), painted)
	for node in _paint_job:
		node.queue_free()
	_paint_job.clear()
	if not painted:
		return
	var torso := _horse.get_node("Harness/Horse/Torso")
	var belly := torso.get_node("BellyShade")
	for stripe in BARREL_STRIPES:
		var polygon := _polygon(stripe, STRIPE)
		torso.add_child(polygon)
		torso.move_child(polygon, belly.get_index() + 1)
	var neck := torso.get_node("Neck")
	var neck_stripe := _polygon(NECK_STRIPE, STRIPE)
	neck.add_child(neck_stripe)
	neck.move_child(neck_stripe, neck.get_node("NeckShape").get_index() + 1)
	_paint_job.append_array(torso.get_children().filter(func(n: Node) -> bool: return n.has_meta(&"paint")))
	_paint_job.append(neck_stripe)
	# The bottle lies behind its legs, the carrots out in front of its nose.
	var horse := _horse.get_node("Harness/Horse")
	for prop: Polygon2D in [_polygon(BOTTLE, BOTTLE_COLOR), _polygon(BOTTLE_CAP, BOTTLE_CAP_COLOR)]:
		horse.add_child(prop)
		horse.move_child(prop, horse.get_node("Torso").get_index())
		_paint_job.append(prop)
	for prop: Polygon2D in [_polygon(CARROT_TOPS, CARROT_TOP), _polygon(CARROT_A, CARROT), _polygon(CARROT_B, CARROT_SHADE)]:
		horse.add_child(prop)
		_paint_job.append(prop)
	if stand_in:
		return
	# The mess sits on the ground under (behind) Tiger, unflipped and unscaled.
	var mess := [_polygon(SPLASH_ORANGE, ORANGE), _polygon(SPLASH_BLACK, STRIPE), _polygon(CAN_SPILL, ORANGE),
			_polygon(CAN_TIPPED, CAN_STEEL), _polygon(CAN_TIPPED_SHADE, CAN_STEEL_SHADE),
			_polygon(CAN_TIPPED_MOUTH, ORANGE_SHADE),
			_polygon(CAN_UPRIGHT, CAN_STEEL), _polygon(CAN_UPRIGHT_SHADE, CAN_STEEL_SHADE),
			_polygon(CAN_UPRIGHT_LID, CAN_LID), _polygon(CAN_UPRIGHT_DRIP, STRIPE)]
	for i in mess.size():
		add_child(mess[i])
		move_child(mess[i], i)
		_paint_job.append(mess[i])

func _set_present(present: bool) -> void:
	visible = present
	set_collision_layer_value(1, present)
	_neigh.set_process(present)
	if not present:
		_neigh.stop()

## Every coat-coloured polygon on the horse goes orange (or back to brown).
static func _recolor(node: Node, painted: bool) -> void:
	for child in node.get_children():
		if child is Polygon2D:
			var polygon := child as Polygon2D
			for pair: Array in [[COAT, ORANGE], [COAT_FAR, ORANGE_FAR], [COAT_SHADE, ORANGE_SHADE]]:
				var from: Color = pair[0] if painted else pair[1]
				if polygon.color.is_equal_approx(Color(from, 1.0)):
					polygon.color = pair[1] if painted else pair[0]
					break
		_recolor(child, painted)

static func _polygon(points: Array, color: Color) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.polygon = PackedVector2Array(points)
	polygon.color = color
	polygon.set_meta(&"paint", true)
	return polygon
