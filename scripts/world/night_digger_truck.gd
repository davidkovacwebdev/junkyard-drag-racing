class_name NightDiggerTruck
extends GarbageTruck
## "Graveyard Shift": the masked digger's little brown pickup (Gus the smith
## and his kid, planting fake treasure), out on the roads at night. Drives
## the road network like the garbage truck it's built on, only faster, and it
## doesn't collect bins or drop anything.
##
## He haunts the graveyard: he starts on a road near it and, at every
## junction, takes the turn that keeps him closest, so a player hunting him
## there will cross his path.
##
## Off screen but in earshot, sound-wave chevrons at the screen edge point
## at it (EngineNoiseIndicator), brighter and faster the closer it is, but
## only once the beggar has told the player to listen for it ("Graveyard
## Shift" is on).
##
## Every hard ram knocks a chunk off the health bar over it (one of the
## quest's `count_goal`, counted even before the beggar hands out the quest);
## at zero it breaks down where it is and NightDiggerCutscene plays. Spawned
## and cleared away by NightDiggerSpawner.

const SCENE := preload("res://scenes/world/night_digger/night_digger_truck.tscn")
const QUEST := preload("res://quests/night_digger.tres")
const CUTSCENE := preload("res://cutscenes/night_digger.tres")
## It never turns up on screen: a fresh spawn starts at least this far off.
const SPAWN_MIN_DISTANCE := 1600.0
## The health bar over the cab.
const BAR_SIZE := Vector2(130.0, 14.0)
const BAR_LIFT := 150.0
const BAR_BACK := Color(0.15, 0.14, 0.13, 0.85)
## How far from the graveyard gate his roads may run. Past it, heading
## further away, he turns round (checked every LEASH_CHECK seconds).
const HAUNT_RADIUS := 3000.0
const LEASH_CHECK := 0.5
const LEASH_LOOK := 250.0
## Sunrise: how long it takes to fade away home (go_home()).
const HOME_FADE := 1.2
## Broken down: how fast it rolls to a stop.
const BREAKDOWN_DECEL := 900.0

var broken := false
var _leash_timer := 0.0

## The bar draws on its own layer that follows the camera, over the night
## tint (NightOverlay) that would otherwise swallow it.
const BAR_LAYER := 2
var _bar: Node2D
var _noise: EngineNoiseIndicator

static func spawn(parent: Node) -> NightDiggerTruck:
	var truck := SCENE.instantiate() as NightDiggerTruck
	parent.add_child(truck)
	return truck

func _init() -> void:
	speed = 360.0
	steer_acceleration = 560.0
	mass = 90.0
	collect_start_hour = 99.0
	drop_chance = 0.0
	engine_volume_db = -16.0

func _ready() -> void:
	roads_path = ^"../../Roads"
	skid_marks_path = ^"../../SkidMarks"
	super()
	_move_out_of_sight()
	var layer := CanvasLayer.new()
	layer.layer = BAR_LAYER
	layer.follow_viewport_enabled = true
	add_child(layer)
	_bar = Node2D.new()
	_bar.draw.connect(_draw_bar)
	layer.add_child(_bar)
	# The engine-noise chevrons at the screen edge, on a plain screen layer.
	var hud := CanvasLayer.new()
	hud.layer = BAR_LAYER
	add_child(hud)
	_noise = EngineNoiseIndicator.new()
	hud.add_child(_noise)
	_update_noise()

## Starts somewhere on a road by the graveyard, well away from the player's
## car (anywhere out of sight if there's no such spot).
func _move_out_of_sight() -> void:
	var car := get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var spots: Array[Dictionary] = []
	var fallback: Array[Dictionary] = []
	for track in _tracks:
		for i in 8:
			var travelled := track.length * (i + 0.5) / 8.0
			var at := track.sample(travelled)
			if car != null and at.distance_to(car.global_position) < SPAWN_MIN_DISTANCE:
				continue
			var spot := {"road": track, "travelled": travelled}
			if at.distance_to(_graveyard()) <= HAUNT_RADIUS:
				spots.append(spot)
			else:
				fallback.append(spot)
	var pool := spots if not spots.is_empty() else fallback
	if pool.is_empty():
		return
	var chosen: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
	_current_road = chosen["road"]
	_forward = _rng.randf() < 0.5
	_travelled = chosen["travelled"]
	_next_road = null
	global_position = _current_road.sample(_travelled)

## Of the junction's exits, the one that keeps him nearest the graveyard
## (judged by where each road leads), with a little chance of a wander.
func _pick_exit(candidates: Array[Dictionary]) -> Dictionary:
	if _rng.randf() < 0.15:
		return super(candidates)
	var gate := _graveyard()
	var best: Dictionary = candidates[0]
	var best_distance := INF
	for candidate in candidates:
		var road: RoadTrack = candidate["road"]
		var far_end := road.last_point() if candidate["forward"] else road.first_point()
		var middle := road.sample(road.length * 0.5)
		var distance := minf(far_end.distance_to(gate), middle.distance_to(gate))
		if distance < best_distance:
			best_distance = distance
			best = candidate
	return best

## Too far out and still heading away: turn round on this road.
func _keep_near_graveyard() -> void:
	var gate := _graveyard()
	var here := global_position.distance_to(gate)
	if _current_road == null or here <= HAUNT_RADIUS:
		return
	var step := LEASH_LOOK if _forward else -LEASH_LOOK
	var ahead := _current_road.sample(clampf(_travelled + step, 0.0, _current_road.length))
	if ahead.distance_to(gate) > here:
		_forward = not _forward
		_next_road = null

func _graveyard() -> Vector2:
	var gate := get_tree().get_first_node_in_group(GraveyardGate.GROUP) as Node2D
	return gate.global_position if gate != null else global_position

func _build_visual() -> void:
	var body := PartDatabase.load_part_data(
			"res://scenes/world/night_digger/night_pickup_body.tscn") as BodyPartData
	var wheel := PartDatabase.load_part_data(
			"res://scenes/parts/wheels/wheel_standard.tscn") as WheelPartData
	var model := CarModelData.new()
	model.body = body
	model.wheels = [wheel, wheel]
	_visual.build_from(model)
	_visual.fit_collision($CollisionShape2D)

func _physics_process(delta: float) -> void:
	if broken:
		velocity = velocity.move_toward(Vector2.ZERO, BREAKDOWN_DECEL * delta)
		move_and_collide(velocity * delta)
		return
	super(delta)
	_leash_timer -= delta
	if _leash_timer <= 0.0:
		_leash_timer = LEASH_CHECK
		_keep_near_graveyard()
		_update_noise()
	_bar.position = global_position
	_bar.queue_redraw()

## The chevrons only point at it once the player knows to listen for it.
func _update_noise() -> void:
	_noise.source = self if Quests.has_quest(QUEST.id) and not broken else null

## Sunrise: Gus heads home. It fades out where it is (its engine with it)
## and is gone.
func go_home() -> void:
	broken = true
	_noise.source = null
	_bar.visible = false
	set_collision_layer(0)
	set_collision_mask(0)
	var tween := create_tween().set_parallel()
	tween.tween_property(self, "modulate:a", 0.0, HOME_FADE)
	for child in get_children():
		if child is EngineSound:
			tween.tween_property(child, "volume_db", -60.0, HOME_FADE)
	tween.chain().tween_callback(queue_free)

## How much of its health is left, 0-1.
func health() -> float:
	return 1.0 - clampf(float(Quests.count_of(QUEST.id)) / QUEST.count_goal, 0.0, 1.0)

func _wants_package() -> bool:
	return false

func _update_marker() -> void:
	pass

## A hard ram: a chunk off its health, and at zero it breaks down.
func _count_ram() -> void:
	if _ram_timer > 0.0 or broken:
		return
	_ram_timer = ram_cooldown
	Sfx.play_at(&"car_whack", global_position, -4.0, 0.08)
	var hits := Quests.add_count(QUEST.id)
	_bar.queue_redraw()
	if hits >= QUEST.count_goal:
		_break_down()
	else:
		_float_text("%d / %d" % [hits, QUEST.count_goal])

func _break_down() -> void:
	broken = true
	_noise.source = null
	_bar.queue_redraw()
	Sfx.play_at(&"collision", global_position, -2.0)
	Sfx.play_at(&"engine_stall", global_position, -4.0)
	for child in get_children():
		if child is EngineSound:
			child.queue_free()
	var cutscene := CUTSCENE.duplicate() as NightDiggerCutscene
	cutscene.truck = self
	Cutscenes.play_once(cutscene)

## The health bar over the cab: a dark back and a red fill, till it breaks.
func _draw_bar() -> void:
	if broken:
		return
	var left := Vector2(-BAR_SIZE.x * 0.5, -BAR_LIFT)
	_bar.draw_rect(Rect2(left, BAR_SIZE), BAR_BACK)
	_bar.draw_rect(Rect2(left + Vector2(3.0, 3.0), Vector2((BAR_SIZE.x - 6.0) * health(), BAR_SIZE.y - 6.0)), UiPalette.DANGER_RED)
