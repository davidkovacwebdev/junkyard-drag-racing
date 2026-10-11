class_name CemeterySkeleton
extends Node2D
## A skeleton the player's horn woke up in the cemetery at night (see
## CemeteryHaunt). It claws up out of the ground by a grave, shrieks, and runs
## the car down, arms out, glowing red eyes, bones clacking. Running into the
## car knocks it to bits with a clatter and gives the car a hard jolt. If it
## hasn't caught the car after `chase_seconds`, it sinks back into the dirt.
##
## Drawn in code, junk-toy style: a skull with two red eyes, one ribcage
## block with a shade strip, a pelvis, and four bone sticks for the arms and
## legs that swing as it runs. Origin at its feet, so it Y-sorts with the car
## and the graves. No collision: the dead go straight through tombstones.
##
## Every one that reaches the car robs it on the way down: `STEAL` scrap or
## money (whichever the player has, picked at random), with a red popup.

const BONE := Color(0.88, 0.86, 0.78, 1)
const BONE_SHADE := Color(0.72, 0.7, 0.62, 1)
const EYE := Color(0.95, 0.18, 0.12, 1)
const LIMB := 9.0
const RISE_SECONDS := 0.7
const SINK_SECONDS := 0.6
## How close counts as having caught the car, and how hard it jolts it.
const CATCH_RADIUS := 46.0
const JOLT := 0.35
const RATTLE_GAP := Vector2(0.45, 0.8)
## How much scrap or money each one that reaches the car takes.
const STEAL := Vector2i(10, 20)
const LOSS_COLOR := Color(0.95, 0.3, 0.25, 1)

enum State { RISING, CHASING, SINKING, BROKEN }

## Way faster than the car: there's no outrunning them.
@export var speed: float = 720.0
@export var chase_seconds: float = 16.0

var _state := State.RISING
var _time := 0.0
var _stride := 0.0
var _facing := 1.0
## 0 underground, 1 standing up out of it.
var _risen := 0.0
var _next_rattle := 0.0
var _car: PlayerCar

func _ready() -> void:
	_car = get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	_next_rattle = randf_range(RATTLE_GAP.x, RATTLE_GAP.y)
	Sfx.play_at(&"skeleton_rise", global_position, -6.0)

func _process(delta: float) -> void:
	_time += delta
	match _state:
		State.RISING:
			_risen = minf(_time / RISE_SECONDS, 1.0)
			if _risen >= 1.0:
				_state = State.CHASING
				_time = 0.0
				Sfx.play_at(&"skeleton_shriek", global_position, -4.0)
		State.CHASING:
			_chase(delta)
		State.SINKING:
			_risen = maxf(1.0 - _time / SINK_SECONDS, 0.0)
			if _risen <= 0.0:
				queue_free()
	queue_redraw()

func _chase(delta: float) -> void:
	if not is_instance_valid(_car) or _time > chase_seconds or Cutscenes.is_active():
		_state = State.SINKING
		_time = 0.0
		return
	var to_car := _car.global_position - global_position
	if to_car.length() < CATCH_RADIUS:
		_crash_into_car()
		return
	global_position += to_car.normalized() * minf(speed * delta, to_car.length())
	_facing = signf(to_car.x) if absf(to_car.x) > 4.0 else _facing
	_stride += delta * 14.0
	_next_rattle -= delta
	if _next_rattle <= 0.0:
		_next_rattle = randf_range(RATTLE_GAP.x, RATTLE_GAP.y)
		Sfx.play_at(&"skeleton_rattle", global_position, -10.0)

## Into the car: it falls to bits, and the car lurches.
func _crash_into_car() -> void:
	_state = State.BROKEN
	Sfx.play_at(&"bone_clatter", global_position, -2.0)
	_car.velocity *= JOLT
	_rob()
	var pile := _bone_pile()
	get_parent().add_child(pile)
	pile.global_position = global_position
	queue_free()

## Takes 10-20 scrap or money off the player, whichever they've got (a coin
## toss if both), and says so over the car.
func _rob() -> void:
	var pots: Array[String] = []
	if Inventory.scrap > 0:
		pots.append("scrap")
	if Inventory.money > 0:
		pots.append("money")
	if pots.is_empty():
		return
	var pot: String = pots[randi() % pots.size()]
	var amount := randi_range(STEAL.x, STEAL.y)
	if pot == "scrap":
		amount = mini(amount, Inventory.scrap)
		Inventory.scrap -= amount
	else:
		amount = mini(amount, Inventory.money)
		Inventory.money -= amount
	Sfx.play(&"loot_lost", -4.0, 0.03)
	_popup("-%d scrap" % amount if pot == "scrap" else "-$%d" % amount)

## Red text drifting up off the car.
func _popup(text: String) -> void:
	var label := Label.new()
	label.text = text
	label.add_theme_color_override("font_color", LOSS_COLOR)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.add_theme_font_size_override("font_size", 34)
	label.z_index = 20
	get_parent().add_child(label)
	# Scattered, so a pack hitting at once stays readable.
	label.global_position = _car.global_position + Vector2(randf_range(-110.0, 50.0), randf_range(-190.0, -100.0))
	var tween := label.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tween.tween_property(label, "position:y", label.position.y - 60.0, 1.1)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 1.1).set_delay(0.4)
	tween.tween_callback(label.queue_free)

## A few loose bones flung out where it hit, gone again after a moment.
func _bone_pile() -> Node2D:
	var pile := Node2D.new()
	for i in 4:
		var bone := Polygon2D.new()
		bone.polygon = FlatProps.sliver(Vector2(-14.0, 0.0), Vector2(14.0, 0.0), LIMB)
		bone.color = BONE
		bone.rotation = randf() * TAU
		pile.add_child(bone)
		var fly := Vector2(randf_range(-70.0, 70.0), randf_range(-60.0, -10.0))
		var tween := bone.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(bone, "position", fly, 0.35)
		tween.parallel().tween_property(bone, "rotation", bone.rotation + randf_range(-6.0, 6.0), 0.35)
		tween.tween_property(bone, "position:y", 6.0, 0.25).set_ease(Tween.EASE_IN)
		tween.tween_interval(1.5)
		tween.tween_property(bone, "modulate:a", 0.0, 0.5)
	var timer := pile.create_tween()
	timer.tween_interval(2.8)
	timer.tween_callback(pile.queue_free)
	return pile

func _draw() -> void:
	# Coming up out of (or going back into) the ground: drawn lower, and only
	# what's above the dirt.
	var sunk := (1.0 - _risen) * 130.0
	var flip := Vector2(_facing, 1.0)
	var swing := sin(_stride) * 0.6 if _state == State.CHASING else 0.0
	var at := func(p: Vector2) -> Vector2: return p * flip + Vector2(0.0, sunk)
	# Legs, swinging from the hip.
	for side: float in [-1.0, 1.0]:
		var hip: Vector2 = at.call(Vector2(side * 7.0, -52.0))
		var foot: Vector2 = at.call(Vector2(side * 7.0 + sin(_stride + (PI if side > 0.0 else 0.0)) * 18.0 * absf(swing) / 0.6, 0.0))
		if foot.y > 0.0:
			foot.y = 0.0
		if hip.y < 0.0:
			draw_colored_polygon(FlatProps.sliver(hip, foot, LIMB), BONE_SHADE if side > 0.0 else BONE)
	if sunk >= 120.0:
		return
	# Pelvis, ribcage and its shade strip.
	_rect_above_ground(at.call(Vector2(-14.0, -60.0)), Vector2(28.0, 12.0) * flip, BONE)
	_rect_above_ground(at.call(Vector2(-16.0, -104.0)), Vector2(32.0, 40.0) * flip, BONE)
	_rect_above_ground(at.call(Vector2(8.0, -104.0)), Vector2(8.0, 40.0) * flip, BONE_SHADE)
	# Arms reaching out in front, bobbing.
	for side: float in [-1.0, 1.0]:
		var shoulder: Vector2 = at.call(Vector2(6.0 * side, -98.0))
		var hand: Vector2 = at.call(Vector2(46.0, -92.0 + side * 8.0 + swing * 8.0))
		if shoulder.y < 0.0:
			draw_colored_polygon(FlatProps.sliver(shoulder, hand, LIMB), BONE)
	# Skull and the two red eyes.
	var skull: Vector2 = at.call(Vector2(4.0, -122.0))
	if skull.y + 18.0 < 0.0:
		draw_colored_polygon(FlatProps.octagon(skull, 20.0, 18.0), BONE)
		for x: float in [-2.0, 11.0]:
			draw_colored_polygon(FlatProps.octagon(at.call(Vector2(x, -124.0)), 5.0, 5.0), EYE)

## A rect in the skeleton's flipped space, clipped to above the ground line.
func _rect_above_ground(corner: Vector2, extent: Vector2, color: Color) -> void:
	var rect := Rect2(corner, extent).abs()
	if rect.position.y >= 0.0:
		return
	rect.end.y = minf(rect.end.y, 0.0)
	draw_rect(rect, color)
