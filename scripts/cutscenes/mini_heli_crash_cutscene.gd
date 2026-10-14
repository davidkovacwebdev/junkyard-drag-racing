class_name MiniHeliCrashCutscene
extends Cutscene
## "Test Pilot": Grandpa's helicopter gives out. A side view up in the sky:
## the player in the tub, eyes popping, arms up, screaming, the helicopter
## tipping and wobbling down trailing black smoke while the clouds rush past,
## until the ground comes up to meet it. CRASH, black. Then the player comes
## to beside the wreck, somewhere out on the map, the car parked next to it.
## Played by HeliTestStory when the flight (MiniHeliFlight) has wound down,
## which then sends the player back to Grandpa.
##
## The words live in res://cutscenes/mini_heli_crash.tres; edit them in the
## inspector.

const ID := &"mini_heli_crash"
## Just under the cutscene letterbox and subtitles (Cutscenes.LAYER).
const LAYER := 49
const SKY := Color(0.6, 0.76, 0.84)
const CLOUD := Color(0.93, 0.95, 0.96)
const GROUND := Color(0.45, 0.52, 0.31)
const GROUND_SHADE := Color(0.38, 0.44, 0.26)
const MOUTH := Color(0.15, 0.14, 0.13)
## Eyes pop around this point, the mouth goes here (character space, the
## same spots GrandpaNpc and CutsceneActor use).
const EYES_CENTER := Vector2(0.0, -214.0)
const MOUTH_AT := Vector2(0.0, -191.0)
const SCARED_EYES := 1.45

@export var scream_line: String = "AAAAAAAAAAAH!"
@export var grandpa_line: String = "GRAAAAANDPAAAA!"
@export var ow_line: String = "...ow."
@export var back_line: String = "I need to get back to Grandpa."

@export_group("Staging")
@export var heli_scale: float = 1.0
@export var fall_seconds: float = 4.5

## Set by HeliTestStory before playing: the flight that's ending, where it
## comes down, and what puts the wreck there.
var flight: MiniHeliFlight
var crash_at: Vector2
var place_wreck: Callable

func _init() -> void:
	id = ID

func play() -> void:
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	await Cutscenes.fade_out(0.4)
	if is_instance_valid(flight):
		flight.finish()
	var size := Cutscenes.get_viewport().get_visible_rect().size

	# Up in the sky, side on.
	var layer := CanvasLayer.new()
	layer.layer = LAYER
	Cutscenes.get_tree().root.add_child(layer)
	var sky := ColorRect.new()
	sky.color = SKY
	sky.size = size
	layer.add_child(sky)
	var scene := Node2D.new()
	layer.add_child(scene)
	var clouds: Array[Polygon2D] = []
	for i in 4:
		var cloud := Polygon2D.new()
		cloud.polygon = FlatProps.octagon(Vector2.ZERO, randf_range(110.0, 180.0), randf_range(40.0, 60.0))
		cloud.color = CLOUD
		cloud.position = Vector2(size.x * (0.12 + 0.26 * i), size.y * randf_range(0.3, 1.2) + i * 120.0)
		scene.add_child(cloud)
		clouds.append(cloud)
	var ground := Polygon2D.new()
	ground.polygon = PackedVector2Array([Vector2(-40.0, 30.0), Vector2(size.x * 0.4, 0.0), Vector2(size.x + 40.0, 40.0),
			Vector2(size.x + 40.0, size.y), Vector2(-40.0, size.y)])
	ground.color = GROUND
	ground.position = Vector2(0.0, size.y + 60.0)
	scene.add_child(ground)
	var heli := MiniHeli.new()
	heli.scale = Vector2.ONE * heli_scale
	heli.position = Vector2(size.x * 0.46, size.y * 0.62)
	heli.rotation = 0.35
	heli.spin = 0.35
	heli.smoke_parent = scene
	scene.add_child(heli)
	heli.smoking = true
	var pilot := heli.seat_pilot(me)
	_scare(pilot)
	await Cutscenes.fade_in(0.25)

	# Falling: the clouds rush up past, it tips and wobbles.
	if not Cutscenes.is_skipping():
		var fall := scene.create_tween().set_parallel()
		for cloud in clouds:
			fall.tween_property(cloud, "position:y", cloud.position.y - size.y * 1.8, fall_seconds)
		var wobble := heli.create_tween().set_loops(8).set_trans(Tween.TRANS_SINE)
		wobble.tween_property(heli, "rotation", 0.55, 0.28)
		wobble.tween_property(heli, "rotation", 0.25, 0.28)
	await Cutscenes.wait(0.8)
	Cutscenes.sound(&"heli_sputter", -4.0)
	await Cutscenes.subtitle(my_name, me, scream_line, pilot)
	await Cutscenes.wait(0.5)
	Cutscenes.sound(&"heli_sputter", -4.0)
	await Cutscenes.subtitle(my_name, me, grandpa_line, pilot)
	await Cutscenes.wait(0.4)

	# The ground comes up.
	if not Cutscenes.is_skipping():
		var impact := scene.create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		impact.tween_property(ground, "position:y", size.y * 0.72, 0.9)
		impact.tween_property(heli, "position:y", size.y * 0.72, 0.9)
		await Cutscenes.play_tween(impact)
	Cutscenes.sound(&"heli_crash", 0.0)
	Cutscenes.clear_subtitle()
	await Cutscenes.fade_out(0.06)
	layer.queue_free()

	# Coming to beside the wreck.
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	if car != null:
		car.park(crash_at + Vector2(280.0, 40.0), false)
	if place_wreck.is_valid():
		place_wreck.call(crash_at)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, crash_at + Vector2(130.0, 50.0), true)
		CharacterInjuries.apply(player, CharacterInjuries.current_level())
		await Cutscenes.fall_over(player)
	Cutscenes.cut_to(crash_at + Vector2(80.0, -80.0), 1.4)
	await Cutscenes.wait(1.0)
	await Cutscenes.fade_in(1.4)
	await Cutscenes.wait(0.6)
	if player != null:
		await Cutscenes.stand_up(player)
	await Cutscenes.wait(0.3)
	await Cutscenes.subtitle(my_name, me, ow_line, player)
	await Cutscenes.subtitle(my_name, me, back_line, player)
	await Cutscenes.wait(0.3)

## Terrified: eyes popped wide, mouth an O, both arms up.
static func _scare(actor: CutsceneActor) -> void:
	if actor == null:
		return
	actor.raise_arms(true, 0.15)
	var eyes := actor.find_child("EyesPart", true, false) as Node2D
	if eyes != null:
		eyes.position += EYES_CENTER * (1.0 - SCARED_EYES) * eyes.scale.y
		eyes.scale *= SCARED_EYES
	var mouth := Polygon2D.new()
	mouth.polygon = FlatProps.octagon(MOUTH_AT, 8.0, 11.0)
	mouth.color = MOUTH
	mouth.z_index = 40
	actor.attach(mouth)
