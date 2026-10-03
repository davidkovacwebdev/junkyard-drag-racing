class_name AlienEscapeCutscene
extends Cutscene
## Taking the flying saucer from the desert hangar: its pilot, Zib, pops the
## dome, jumps down, squeaks at the player and legs it out the hangar door and
## off into the desert. The saucer you get is the empty one.
##
## The words live in res://cutscenes/alien_escape.tres. Played by HangarUfo,
## which sets `saucer` first.

const ID := &"alien_escape"
const ALIEN := preload("res://characters/alien.tres")

@export var speaker_name: String = "Zib"
@export_multiline var panic_lines: PackedStringArray = [
	"BLIP?! An Earthling!",
	"Not the saucer! It's a rental!",
]

@export_group("Staging")
@export var zoom: float = 1.6
## The alien is smaller than a person: this scales the actor on top of the
## usual cutscene size.
@export var alien_scale: float = 0.6
@export var hop_height: float = 80.0
@export var run_speed: float = 560.0
## Where Zib lands, relative to the saucer, and where he runs to, relative to
## the hangar door.
@export var landing_offset := Vector2(-130.0, 40.0)
@export var escape_offset := Vector2(900.0, 700.0)

## Set by HangarUfo before playing.
var saucer: HangarUfo

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(saucer):
		return
	var seat := saucer.pilot_seat_global()
	var door := saucer.door_global()
	Cutscenes.cut_to(saucer.global_position + Vector2(0.0, -60.0), zoom)
	await Cutscenes.wait(0.4)

	Cutscenes.sound(&"ufo_hatch", -4.0)
	saucer.eject_pilot()
	var alien := Cutscenes.spawn_actor(ALIEN, seat, false)
	alien.scale = Vector2.ONE * alien_scale
	# Drawn over the hull while he climbs out, then back into the Y-sort.
	alien.z_index = 1
	await Cutscenes.hop(alien, hop_height)
	await Cutscenes.walk(alien, saucer.global_position + landing_offset, 300.0)
	alien.z_index = 0

	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car != null:
		Cutscenes.face(alien, car.global_position.x > alien.global_position.x)
	Cutscenes.sound(&"alien_yelp", -4.0)
	await Cutscenes.hop(alien, 30.0)
	for line in panic_lines:
		await Cutscenes.subtitle(speaker_name, ALIEN, line, alien)

	Cutscenes.sound(&"alien_yelp", -6.0)
	Cutscenes.camera_follow(alien)
	await Cutscenes.walk(alien, door, run_speed)
	await Cutscenes.walk(alien, door + escape_offset, run_speed)
	await Cutscenes.wait(0.3)
