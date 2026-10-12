class_name CutsceneActor
extends Node2D
## A character standing in the world for a cutscene: the same CharacterRig
## NPCs use, plus the few chunky moves a cutscene needs — walk (a bouncy
## waddle), a belly crawl on the arms, hop, fall flat, and a talking squash
## while their subtitle types.
##
## The root moves around the world; `_body` does the bobbing and tipping, so
## the two never fight. Made and cleaned up by Cutscenes.spawn_actor().

const WALK_BOB_PIXELS := 14.0
const WALK_STEPS_PER_SECOND := 4.0
const TALK_SQUASH := 0.05
## Squashed flat (see `flatten()`): this tall and this wide at full flatness.
const FLAT_HEIGHT := 0.07
const FLAT_WIDTH := 2.4
## Crying (see `cry()`): a tear from under each eye in turn, in character
## space, the same teardrops Grandpa sheds.
const TEAR_FROM := [Vector2(-12.0, -200.0), Vector2(12.0, -200.0)]
const TEAR_FALL := 46.0
const TEAR_Z := 11
## Blushing (see `blush()`): a red cheek under each eye, in character space.
const CHEEKS := [Vector2(-17.0, -186.0), Vector2(17.0, -186.0)]
const CHEEK_SIZE := Vector2(11.0, 7.0)
const BLUSH_COLOR := Color(0.86, 0.3, 0.3, 0.85)
## A part's (or attached prop's) slot z, kept once its z_index is zeroed.
const LAYER_META := &"layer"
## Crawling (see `crawl_to()`): flat on the belly, lifted this far so the
## body lies on the ground instead of half in it, and dragged on this far
## by each pull of an arm.
const CRAWL_LIFT := 26.0
const CRAWL_PULL := 60.0
const CRAWL_REACH_SECONDS := 0.15
const CRAWL_PULL_SECONDS := 0.4
## A reaching arm swings this far round from hanging at the side, out past
## the head.
const ARM_REACH := PI - 0.3
## Torso polygons lying wholly outside x ±this (character space) are an arm,
## or something held in that hand; they swing together from the shoulder.
const ARM_INNER_X := 26.0

var walking: bool = false
var talking: bool = false
## 0 standing, 1 pancaked flat on the ground (see `flatten()`).
var flatness: float = 0.0

var _body: Node2D
## The assembled character's parts, stacked by child order (see `_layer_parts()`).
var _parts: Node2D
var _base_scale: float = 1.0
## Shoulder pivots [left, right], rigged on the first crawl or reach.
var _arms: Array[Node2D] = []
var _facing: float = 1.0
var _time: float = 0.0

func setup(character: CharacterData, scale_factor: float) -> void:
	_base_scale = scale_factor
	_body = Node2D.new()
	add_child(_body)
	var rig := CharacterRig.new()
	rig.character_data = character
	rig.ready.connect(func() -> void: _layer_parts(rig.assembled))
	_body.add_child(rig)

## Puts `prop` on the character (a held tool, say). Its position is in
## character space, so it bobs, flips and tips along with the body. Its
## z_index says which parts it goes over (CharacterAssembler.base_z); it's
## turned into child order so the prop never leaves the world's Y-sort.
func attach(prop: Node2D) -> void:
	if _parts == null:
		_body.add_child(prop)
		return
	var layer := prop.z_index
	prop.z_index = 0
	prop.set_meta(LAYER_META, layer)
	var index := 0
	for child in _parts.get_children():
		if int(child.get_meta(LAYER_META, 0)) <= layer:
			index = child.get_index() + 1
	_parts.add_child(prop)
	_parts.move_child(prop, index)

## Slot z_indexes would lift the head and torso out of the world's Y-sort,
## so they'd draw over a car the character stands behind while the legs
## didn't. Child order keeps the same stacking and sorts as one piece.
func _layer_parts(parts: Node2D) -> void:
	_parts = parts
	for child in parts.get_children():
		if child is Node2D:
			child.set_meta(LAYER_META, (child as Node2D).z_index)
	CharacterAssembler.layer_by_child_order(parts)

func face(right: bool) -> void:
	_facing = 1.0 if right else -1.0

## Tween the walk; the waddle runs while it's moving.
func walk_to(to: Vector2, speed: float) -> Tween:
	face(to.x >= global_position.x)
	walking = true
	var tween := create_tween()
	tween.tween_property(self, "global_position", to, global_position.distance_to(to) / maxf(speed, 1.0))
	tween.finished.connect(func() -> void:
		walking = false
		_body.position.y = 0.0)
	return tween

func hop(height: float) -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(_body, "position:y", -height, 0.16).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "position:y", 0.0, 0.16).set_ease(Tween.EASE_IN)
	return tween

## Squashes the character flat into the ground, cartoon style: a quick
## overshoot, then a pancake. Lying down (`fall_over()`) first is fine; the
## squash is along the ground either way.
func flatten(seconds: float = 0.12) -> Tween:
	walking = false
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "flatness", 1.0, seconds)
	return tween

## Teary-eyed for `seconds`: tears roll from each eye in turn. Fire and
## forget; pair it with a sob sound.
func cry(seconds: float = 2.0) -> void:
	var tears := maxi(1, int(seconds / 0.4))
	for i in tears:
		if not is_instance_valid(self):
			return
		_drop_tear(TEAR_FROM[i % TEAR_FROM.size()])
		await get_tree().create_timer(0.4).timeout

func _drop_tear(from: Vector2) -> void:
	var tear := Polygon2D.new()
	tear.polygon = PackedVector2Array([Vector2(0.0, -10.0), Vector2(6.0, 1.0),
			Vector2(4.0, 7.0), Vector2(-4.0, 7.0), Vector2(-6.0, 1.0)])
	tear.color = GrandpaNpc.TEAR_COLOR
	tear.position = from
	tear.z_index = TEAR_Z
	attach(tear)
	var fall := create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	fall.tween_property(tear, "position:y", from.y + TEAR_FALL, 0.5)
	fall.parallel().tween_property(tear, "modulate:a", 0.0, 0.2).set_delay(0.3)
	fall.tween_callback(tear.queue_free)

## Red in the face for `seconds`: the cheeks glow up, hold, and fade. Fire
## and forget.
func blush(seconds: float = 3.0) -> void:
	var tween := create_tween()
	for at: Vector2 in CHEEKS:
		var cheek := Polygon2D.new()
		cheek.polygon = FlatProps.octagon(at, CHEEK_SIZE.x, CHEEK_SIZE.y)
		cheek.color = BLUSH_COLOR
		cheek.z_index = TEAR_Z
		cheek.modulate.a = 0.0
		attach(cheek)
		tween.parallel().tween_property(cheek, "modulate:a", 1.0, 0.3)
		tween.parallel().tween_property(cheek, "modulate:a", 0.0, 0.6).set_delay(seconds)
		tween.parallel().tween_callback(cheek.queue_free).set_delay(seconds + 0.6)

## Tips over backwards and lands with a little bounce.
func fall_over() -> Tween:
	walking = false
	var direction := -_facing
	var tween := create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "rotation", direction * PI * 0.5, 0.45)
	return tween

func stand_up() -> Tween:
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(_body, "rotation", 0.0, 0.35)
	tween.parallel().tween_property(_body, "position:y", 0.0, 0.35)
	return tween

## Belly down, head first towards `to`, dragging the body along by the arms:
## one reaches out past the head, then hauls back while the body lurches
## forward, the other arm next. The legs just trail.
func crawl_to(to: Vector2) -> Tween:
	var direction := signf(to.x - global_position.x)
	if direction == 0.0:
		direction = _facing
	face(direction > 0.0)
	var arms := _arm_pivots()
	var from := global_position
	var pulls := maxi(1, ceili(from.distance_to(to) / CRAWL_PULL))
	var tween := create_tween()
	tween.tween_property(_body, "rotation", direction * PI * 0.5, 0.2)
	tween.parallel().tween_property(_body, "position:y", -CRAWL_LIFT, 0.2)
	for i in pulls:
		var arm := arms[i % arms.size()] if not arms.is_empty() else null
		if arm != null:
			tween.tween_property(arm, "rotation", ARM_REACH * _outward(i % arms.size()), CRAWL_REACH_SECONDS)
		tween.tween_callback(_crawl_sound)
		tween.tween_property(self, "global_position", from.lerp(to, float(i + 1) / pulls), CRAWL_PULL_SECONDS) \
				.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if arm != null:
			tween.parallel().tween_property(arm, "rotation", 0.0, CRAWL_PULL_SECONDS)
	return tween

## Both arms straight up overhead (hanging off something, climbing), or back
## down at the sides.
func raise_arms(up: bool, seconds: float = 0.2) -> Tween:
	var tween := create_tween().set_parallel()
	var arms := _arm_pivots()
	for i in arms.size():
		tween.tween_property(arms[i], "rotation", PI * _outward(i) if up else 0.0, seconds)
	if arms.is_empty():
		tween.tween_interval(seconds)
	return tween

## Which way arm `index` swings to go outward: the left one clockwise.
static func _outward(index: int) -> float:
	return 1.0 if index == 0 else -1.0

func _crawl_sound() -> void:
	if not Cutscenes.is_skipping():
		Sfx.play_at(&"crawl_drag", global_position, -6.0)

## Wraps each side's arm polygons in a pivot at its shoulder (the top middle
## of them) so the arm swings from there, keeping their draw order.
func _arm_pivots() -> Array[Node2D]:
	if not _arms.is_empty() or _parts == null:
		return _arms
	var torso := _parts.find_child("TorsoPart", false, false) as Node2D
	if torso == null:
		return _arms
	for side: float in [-1.0, 1.0]:
		var polygons: Array[Polygon2D] = []
		for child in torso.get_children():
			if child is Polygon2D and _is_arm(child as Polygon2D, side):
				polygons.append(child)
		if polygons.is_empty():
			continue
		var left := INF
		var right := -INF
		var top := INF
		for polygon in polygons:
			for point in polygon.polygon:
				left = minf(left, point.x)
				right = maxf(right, point.x)
				top = minf(top, point.y)
		var pivot := Node2D.new()
		pivot.name = "Shoulder%s" % ("Left" if side < 0.0 else "Right")
		pivot.position = Vector2((left + right) * 0.5, top)
		torso.add_child(pivot)
		torso.move_child(pivot, polygons[0].get_index())
		for polygon in polygons:
			polygon.reparent(pivot)
		_arms.append(pivot)
	return _arms

static func _is_arm(polygon: Polygon2D, side: float) -> bool:
	for point in polygon.polygon:
		if point.x * side < ARM_INNER_X:
			return false
	return true

func _process(delta: float) -> void:
	_time += delta
	if walking:
		_body.position.y = -absf(sin(_time * PI * WALK_STEPS_PER_SECOND)) * WALK_BOB_PIXELS
		_body.skew = sin(_time * PI * WALK_STEPS_PER_SECOND) * 0.08
	else:
		_body.skew = 0.0
	var squash := sin(_time * TAU * 7.0) * TALK_SQUASH if talking else 0.0
	var flat_x := lerpf(1.0, FLAT_WIDTH, flatness)
	var flat_y := lerpf(1.0, FLAT_HEIGHT, flatness)
	_body.scale = Vector2(_facing * _base_scale * (1.0 - squash) * flat_x, _base_scale * (1.0 + squash) * flat_y)
