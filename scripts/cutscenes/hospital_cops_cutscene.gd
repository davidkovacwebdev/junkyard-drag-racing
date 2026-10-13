class_name HospitalCopsCutscene
extends Cutscene
## The staging Grandpa's hospital pranks share (ExPoliceExcuseCutscene,
## ExPoliceBeatingCutscene), the same as PoliceFineCutscene's: the player
## climbs out of the car, the police garbage truck comes wailing up, and
## Officers Dale and Rita walk over. Grandpa stays in the car and talks from
## there. `leave()` sends them off again.

const DALE := preload("res://characters/officer_dale.tres")
const RITA := preload("res://characters/officer_rita.tres")
const GRANDPA := preload("res://characters/grandpa.tres")

@export_group("Staging")
@export var zoom: float = 1.3
@export var truck_scale: float = 0.8
@export var drive_in_seconds: float = 2.6

var me: CharacterData
var my_name: String
var at: Vector2
var player: CutsceneActor
var truck: PenGarbageTruck
var dale: CutsceneActor
var rita: CutsceneActor
var _park: Vector2
var _cab: Vector2

## Out of the car, the truck in, the officers over. False with no car.
func arrive(sirens: int, furious: bool) -> bool:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null:
		return false
	me = PlayerProfile.character
	my_name = PlayerProfile.display_name()
	at = car.global_position
	_park = at + Vector2(-860.0, 0.0)
	if me != null:
		player = Cutscenes.spawn_actor(me, at + Vector2(-70.0, 16.0), false)
		CharacterInjuries.apply(player, CharacterInjuries.current_level())
		Cutscenes.sound(&"door_close", -6.0)
	Cutscenes.camera_to(at + Vector2(-380.0, -90.0), zoom - 0.4, 1.0)
	truck = PenGarbageTruck.spawn(car.get_parent(), at + Vector2(-1700.0, 0.0), true)
	truck.scale = Vector2.ONE * truck_scale
	var drive_in := drive_in_seconds * (0.6 if furious else 1.0)
	_sirens(sirens, drive_in / sirens)
	await Cutscenes.play_tween(truck.drive_to(_park, drive_in))
	truck.global_position = _park
	if furious:
		Cutscenes.sound(&"pickup_skid", -2.0)
		Cutscenes.shake(10.0, 0.3)
	Cutscenes.sound(&"door_close", -6.0)
	_cab = _park + Vector2(330.0, 0.0)
	dale = Cutscenes.spawn_actor(DALE, _cab + Vector2(10.0, 18.0), true)
	rita = Cutscenes.spawn_actor(RITA, _cab + Vector2(-20.0, -8.0), true)
	Cutscenes.walk(rita, at + Vector2(-240.0, -6.0), 150.0)
	await Cutscenes.walk(dale, at + Vector2(-170.0, 18.0), 150.0)
	await Cutscenes.camera_to(at + Vector2(-150.0, -110.0), zoom, 0.8)
	return true

## Back in the truck and away.
func leave() -> void:
	Cutscenes.walk(rita, _cab + Vector2(-20.0, -8.0), 170.0)
	await Cutscenes.walk(dale, _cab + Vector2(10.0, 18.0), 170.0)
	dale.visible = false
	rita.visible = false
	Cutscenes.sound(&"door_close", -6.0)
	truck.face(false)
	_sirens(2, 0.9)
	await Cutscenes.play_tween(truck.drive_to(_park + Vector2(-1500.0, 0.0), 2.2))
	truck.queue_free()

func grandpa_says(line: String) -> void:
	await Cutscenes.subtitle("Grandpa (in the car)", GRANDPA, line, null)

## An officer losing it: a hop and a camera jolt as they start yelling.
func yell(officer: CutsceneActor) -> void:
	Cutscenes.hop(officer, 26.0)
	Cutscenes.shake(8.0, 0.25)

func _sirens(count: int, gap: float) -> void:
	for i in count:
		Cutscenes.sound(&"siren_whoop", -4.0)
		await Cutscenes.wait(gap)
