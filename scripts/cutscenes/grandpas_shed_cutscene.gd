class_name GrandpasShedCutscene
extends Cutscene
## "Grandpa's Shed", at the garage: the player goes in to dig through
## Eugen's tool shed, and the camera sits on the house while the clock spins
## on through the evening and the night (a snore or two in the dark) to the
## next morning and the rooster. Out they come, metal detector in hand; it
## warbles and dies. Plays when the player presses E at the garage while the
## quest is on (GrandpasGarage), which then puts the detector in the trunk.
##
## The words live in res://cutscenes/grandpas_shed.tres; edit them in the
## inspector.

const ID := &"grandpas_shed"
const DETECTOR := preload("res://scenes/items/icons/item_metal_detector.tscn")
## The grip's middle in the detector icon's own space.
const GRIP := Vector2(23.0, -27.0)

@export var battery_line: String = "Well this could work, I guess we just need a battery."

@export_group("Staging")
@export var zoom: float = 1.6
## How far out the camera sits on the house while the time goes by.
@export var house_zoom: float = 0.9
@export var close_zoom: float = 1.9
## How long the night takes to pass, in real seconds.
@export var lapse_seconds: float = 6.0
## The clock stops this many hours after morning (DayNightCycle.NIGHT_END),
## once the sun is well up.
@export var morning_hours_after: float = 1.5
## Where the detector's grip sits in the player's hand, in their character
## space, and how big it is there (mirrored so the coil points ahead).
@export var hand_spot := Vector2(40.0, -100.0)
@export var detector_scale: float = 2.2

## Set by GrandpasGarage before playing.
var garage: Node2D

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(garage) or PlayerProfile.character == null:
		return
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	var start := car.global_position if car != null else garage.global_position + Vector2(50.0, 150.0)
	var door := Vector2(start.x, garage.global_position.y + 20.0)
	var name := PlayerProfile.display_name()
	var me := PlayerProfile.character

	await Cutscenes.fade_out(0.0)
	var player := Cutscenes.spawn_actor(me, start + Vector2(-110.0, 10.0), false)
	Cutscenes.cut_to(start + Vector2(-60.0, -120.0), zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.walk(player, door, 130.0)
	Cutscenes.sound(&"door_close", -4.0)
	player.visible = false

	# The house, while the day goes and the night comes and goes.
	await Cutscenes.camera_to(garage.global_position + Vector2(0.0, -120.0), house_zoom, 1.0)
	await _pass_the_night()
	Cutscenes.sound(&"rooster_crow", -4.0)
	await Cutscenes.wait(1.4)

	# Out they come, detector in hand.
	Cutscenes.sound(&"door_close", -6.0)
	player.visible = true
	Cutscenes.face(player, true)
	var detector := DETECTOR.instantiate() as Node2D
	detector.scale = Vector2(-detector_scale, detector_scale)
	detector.position = hand_spot - GRIP * detector.scale
	detector.z_index = GrandpaNpc.WRENCH_Z
	player.attach(detector)
	await Cutscenes.camera_to(player.global_position + Vector2(50.0, -80.0), close_zoom, 0.8)
	Cutscenes.sound(&"detector_dud", -6.0)
	await Cutscenes.hop(player, 14.0)
	await Cutscenes.wait(0.9)
	await Cutscenes.subtitle(name, me, battery_line, player)
	await Cutscenes.wait(0.5)

## Spins the clock on to the morning after next night: past 9 PM and on to
## `morning_hours_after` past 8 AM, over `lapse_seconds`. Snores while it's
## dark. Skipped, it just jumps there.
func _pass_the_night() -> void:
	var length := DayNightCycle.DAY_LENGTH
	var now := DayNightCycle.time_of_day
	var morning := DayNightCycle.NIGHT_END + morning_hours_after * DayNightCycle.SECONDS_PER_HOUR
	var to_morning := fposmod(morning - now, length)
	# Always through a whole night, even starting in the small hours.
	if fposmod(DayNightCycle.NIGHT_START - now, length) > to_morning:
		to_morning += length
	var left := to_morning
	var snores := 0
	while left > 0.0 and not Cutscenes.is_skipping():
		await Cutscenes.get_tree().process_frame
		var step := minf(left, to_morning * Cutscenes.get_process_delta_time() / lapse_seconds)
		DayNightCycle.advance_seconds(step)
		left -= step
		var hour := DayNightCycle.get_hour()
		if snores < 2 and hour >= 1.0 + snores * 2.5 and hour < 7.0:
			Cutscenes.sound(&"sleep_snore", -8.0)
			snores += 1
	if left > 0.0:
		DayNightCycle.advance_seconds(left)
