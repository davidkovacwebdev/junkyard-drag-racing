class_name MotorBatteryCutscene
extends Cutscene
## "Fish It Out", in the crane pen: the claw has the toy car motor. The player
## climbs down from the crane, and the man from the counter (Vern, or
## whoever has his job now) walks over from his spot by the crane. He takes
## the motor and Grandpa's metal detector: he'll pull the battery and wire
## it in, come back tomorrow. Played by CranePen, which finishes the quest;
## "Charged Up" lands a day later.
##
## The words live in res://cutscenes/motor_battery.tres; edit them in the
## inspector.

const ID := &"motor_battery"

@export var got_it_line: String = "Got it! One toy car motor."
@export var extract_line: String = "I'll extract the battery and connect it to the detector, come back tomorrow."

@export_group("Staging")
@export var zoom: float = 1.1
@export var walk_speed: float = 240.0
## Where the two of them meet, right of the pit's middle, and how far apart.
@export var meet_gap: float = 150.0

## Set by CranePen before playing: the crane's cab (where the player climbs
## down), where the man stands watching, and who he is.
var cab_at: Vector2
var operator_at: Vector2
var operator: CharacterData

func _init() -> void:
	id = ID

func play() -> void:
	if operator == null:
		return
	var me := PlayerProfile.character
	var my_name := PlayerProfile.display_name()
	var meet := Vector2((cab_at.x + operator_at.x) * 0.5, operator_at.y)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, Vector2(cab_at.x, operator_at.y), true)
		Cutscenes.sound(&"door_close", -6.0)
	var man := Cutscenes.spawn_actor(operator, operator_at, false)
	await Cutscenes.camera_to(meet + Vector2(0.0, -150.0), zoom, 0.8)
	if player != null:
		Cutscenes.walk(player, meet - Vector2(meet_gap * 0.5, 0.0), walk_speed)
	await Cutscenes.walk(man, meet + Vector2(meet_gap * 0.5, 0.0), walk_speed)
	Cutscenes.face(man, false)
	if player != null:
		Cutscenes.face(player, true)
		await Cutscenes.hop(player, 12.0)
	await Cutscenes.subtitle(my_name, me, got_it_line, player)
	await Cutscenes.subtitle(operator.display_name, operator, extract_line, man)
	# The motor and the detector change hands.
	Cutscenes.sound(&"part_unbolt", -6.0)
	await Cutscenes.hop(man, 10.0)
	await Cutscenes.wait(0.6)
	await Cutscenes.fade_out(0.5)
