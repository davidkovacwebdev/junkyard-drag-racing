class_name DynamiteFishingCutscene
extends Cutscene
## "Fish Supper", at the fishing pier: Grandpa just sits there, saying
## nothing (crickets). Then he lobs a stick of dynamite into the water. BOOM.
## Fish float up belly first, and he screams at the player to go get them,
## shoving a net at them. The player flings the net out and hauls the fish
## in. Sirens, off in the distance and getting closer: "QUICK WE NEED TO
## RUN". Played by DinnerStory when the two of them reach the pier, which
## then finishes the quest; "Catch and Run" follows.
##
## The words live in res://cutscenes/dynamite_fishing.tres; edit them in
## the inspector.

const ID := &"dynamite_fishing"
const GRANDPA := preload("res://characters/grandpa.tres")
const STICK := Color(0.78, 0.18, 0.14, 1)
const FUSE := Color(0.15, 0.14, 0.13, 1)
const SPARK := Color(0.95, 0.75, 0.1, 1)
const SPRAY := Color(0.86, 0.92, 0.95, 1)
const SPRAY_SHADE := Color(0.64, 0.78, 0.85, 1)
const FISH := Color(0.62, 0.66, 0.7, 1)
const FISH_BELLY := Color(0.86, 0.86, 0.82, 1)
const POLE := Color(0.55, 0.4, 0.28, 1)
const MESH := Color(0.3, 0.3, 0.32, 1)
## Where the fish come up around the blast.
const FISH_SPOTS: Array[Vector2] = [Vector2(-70.0, -10.0), Vector2(-20.0, 20.0), Vector2(40.0, -16.0),
		Vector2(80.0, 14.0), Vector2(10.0, -30.0)]

@export var speaker_name: String = "Grandpa"
@export var catch_line: String = "What are you waiting for lad! Go catch them!"
@export var run_line: String = "QUICK WE NEED TO RUN"

@export_group("Staging")
@export var zoom: float = 1.3
## How long he sits there saying nothing first.
@export var silence_seconds: float = 3.0
## Where the net sits in the player's hand, in their character space.
@export var hand_spot := Vector2(40.0, -100.0)

## Set by DinnerStory before playing: Grandpa at the pier, and where his
## dynamite comes down in the water.
var grandpa: GrandpaNpc
var water_at: Vector2

var _props: Array[Node2D] = []

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var from := car.global_position if car != null else grandpa.global_position + Vector2(-200.0, 20.0)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, from + Vector2(0.0, 16.0), true)
		Cutscenes.sound(&"door_close", -6.0)
	await Cutscenes.camera_to((grandpa.global_position + water_at) * 0.5 + Vector2(-60.0, -80.0), zoom, 0.8)
	if player != null:
		await Cutscenes.walk(player, grandpa.global_position + Vector2(-100.0, 12.0), 150.0)
		Cutscenes.face(player, true)
	grandpa.actor.face(true)

	# He just sits there.
	await Cutscenes.wait(silence_seconds * 0.4)
	Cutscenes.sound(&"cricket_chirp", -8.0)
	await Cutscenes.wait(silence_seconds * 0.6)

	# Then: dynamite.
	await _throw_dynamite()
	await _blast()
	await _float_fish()

	if not Cutscenes.is_skipping():
		grandpa.twitch(1.0)
	Cutscenes.shake(5.0, 0.4)
	await Cutscenes.subtitle(speaker_name, GRANDPA, catch_line, grandpa.actor)
	# The net, shoved into the player's hands.
	var net: Node2D = null
	if player != null:
		net = _net()
		net.position = hand_spot
		player.attach(net)
		Cutscenes.sound(&"wood_clonk", -8.0)
		await Cutscenes.hop(player, 10.0)
	await _cast_net(player, net)

	# Sirens, somewhere, getting closer.
	Cutscenes.sound(&"siren_whoop", -18.0)
	await Cutscenes.wait(0.9)
	Cutscenes.sound(&"siren_whoop", -14.0)
	if not Cutscenes.is_skipping():
		grandpa.widen_eyes(1.4, -4.0)
	Cutscenes.shake(8.0, 0.4)
	await Cutscenes.subtitle(speaker_name, GRANDPA, run_line, grandpa.actor)
	Cutscenes.sound(&"siren_whoop", -12.0)
	await Cutscenes.wait(0.4)
	await Cutscenes.fade_out(0.4)
	for prop in _props:
		if is_instance_valid(prop):
			prop.queue_free()

func _throw_dynamite() -> void:
	var stick := _add_prop(_dynamite(), grandpa.global_position + Vector2(20.0, -90.0))
	Cutscenes.sound(&"axe_whoosh", -6.0)
	await _arc(stick, water_at, 160.0, 0.8, 7.0)
	Cutscenes.sound(&"bobber_plop", -6.0)
	stick.visible = false
	await Cutscenes.wait(0.9)

func _blast() -> void:
	Cutscenes.sound(&"dynamite_boom", 0.0)
	Cutscenes.shake(18.0, 0.7)
	var spout := _add_prop(_spout(), water_at)
	spout.scale = Vector2(0.2, 0.2)
	if Cutscenes.is_skipping():
		spout.visible = false
		return
	var tween := spout.create_tween().set_trans(Tween.TRANS_QUAD)
	tween.tween_property(spout, "scale", Vector2.ONE, 0.25).set_ease(Tween.EASE_OUT)
	tween.tween_interval(0.3)
	tween.tween_property(spout, "scale", Vector2(1.2, 0.0), 0.5).set_ease(Tween.EASE_IN)
	await Cutscenes.play_tween(tween)
	spout.visible = false

func _float_fish() -> void:
	for spot in FISH_SPOTS:
		var fish := _add_prop(_fish(), water_at + spot)
		fish.scale = Vector2(-1.0 if randf() < 0.5 else 1.0, 1.0)
		Cutscenes.sound(&"bobber_plop", -10.0)
		if not Cutscenes.is_skipping():
			var bob := fish.create_tween().set_loops()
			bob.tween_property(fish, "position:y", fish.position.y - 4.0, 0.6).set_trans(Tween.TRANS_SINE)
			bob.tween_property(fish, "position:y", fish.position.y + 2.0, 0.6).set_trans(Tween.TRANS_SINE)
		await Cutscenes.wait(0.2)
	await Cutscenes.wait(0.6)

## Out goes the net, in come the fish.
func _cast_net(player: CutsceneActor, net: Node2D) -> void:
	if player == null or net == null:
		return
	var hand := net.global_position
	net.get_parent().remove_child(net)
	_add_prop(net, hand)
	Cutscenes.sound(&"rod_cast", -6.0)
	await _arc(net, water_at, 120.0, 0.6, 0.0)
	Cutscenes.sound(&"paddle_splash", -6.0)
	await Cutscenes.wait(0.3)
	for prop in _props:
		if is_instance_valid(prop) and prop.has_meta(&"fish"):
			prop.visible = false
	Cutscenes.sound(&"reel_whirr", -8.0)
	await _arc(net, hand, 60.0, 0.6, 0.0)
	Cutscenes.sound(&"scrap_pickup", -6.0)
	await Cutscenes.hop(player, 14.0)

## Lobs `prop` to `to` along a hump `height` high, over `seconds`, spinning
## `spin` turns' worth of radians on the way.
func _arc(prop: Node2D, to: Vector2, height: float, seconds: float, spin: float) -> void:
	var from := prop.global_position
	if Cutscenes.is_skipping():
		prop.global_position = to
		return
	var tween := prop.create_tween()
	tween.tween_method(func(t: float) -> void:
		prop.global_position = from.lerp(to, t) + Vector2(0.0, -4.0 * height * t * (1.0 - t))
		prop.rotation = spin * t, 0.0, 1.0, seconds)
	await Cutscenes.play_tween(tween)

func _add_prop(prop: Node2D, at: Vector2) -> Node2D:
	Cutscenes.get_tree().current_scene.add_child(prop)
	prop.global_position = at
	prop.z_index = 5
	_props.append(prop)
	return prop

# --- Props: flat polygons ------------------------------------------------------------

func _polygon(parent: Node2D, points: PackedVector2Array, color: Color) -> void:
	var shape := Polygon2D.new()
	shape.polygon = points
	shape.color = color
	parent.add_child(shape)

## A red stick with a fuse and its spark.
func _dynamite() -> Node2D:
	var stick := Node2D.new()
	_polygon(stick, PackedVector2Array([Vector2(-16.0, -6.0), Vector2(16.0, -6.0), Vector2(16.0, 6.0), Vector2(-16.0, 6.0)]), STICK)
	_polygon(stick, FlatProps.sliver(Vector2(16.0, 0.0), Vector2(26.0, -8.0), 4.0), FUSE)
	_polygon(stick, FlatProps.octagon(Vector2(28.0, -10.0), 6.0, 6.0), SPARK)
	return stick

## The water heaving up: a fat spout with a jagged crown.
func _spout() -> Node2D:
	var spout := Node2D.new()
	_polygon(spout, PackedVector2Array([Vector2(-60.0, 10.0), Vector2(-46.0, -90.0), Vector2(-30.0, -60.0),
			Vector2(-12.0, -150.0), Vector2(6.0, -80.0), Vector2(26.0, -130.0), Vector2(40.0, -70.0),
			Vector2(56.0, -100.0), Vector2(62.0, 10.0)]), SPRAY)
	_polygon(spout, PackedVector2Array([Vector2(-60.0, 10.0), Vector2(62.0, 10.0), Vector2(56.0, -20.0),
			Vector2(-54.0, -20.0)]), SPRAY_SHADE)
	return spout

## A fish floating belly up: body, tail, and the pale belly on top.
func _fish() -> Node2D:
	var fish := Node2D.new()
	fish.set_meta(&"fish", true)
	_polygon(fish, FlatProps.octagon(Vector2.ZERO, 18.0, 8.0), FISH)
	_polygon(fish, PackedVector2Array([Vector2(14.0, 0.0), Vector2(28.0, -9.0), Vector2(28.0, 9.0)]), FISH)
	_polygon(fish, PackedVector2Array([Vector2(-14.0, -4.0), Vector2(12.0, -4.0), Vector2(8.0, -8.0),
			Vector2(-10.0, -8.0)]), FISH_BELLY)
	return fish

## A landing net: a pole and a dark mesh scoop.
func _net() -> Node2D:
	var net := Node2D.new()
	_polygon(net, FlatProps.sliver(Vector2(-10.0, 30.0), Vector2(26.0, -40.0), 6.0), POLE)
	_polygon(net, PackedVector2Array([Vector2(16.0, -48.0), Vector2(40.0, -58.0), Vector2(52.0, -40.0),
			Vector2(42.0, -22.0), Vector2(26.0, -30.0)]), MESH)
	return net
