class_name ExPoliceBeatingCutscene
extends HospitalCopsCutscene
## "Visiting Hours (Again)": the Super Horn, outside the hospital, again. The
## police skid up furious: "THAT'S IT!" They lay into the car, and the harder
## they hit it the darker the screen gets, until it's black. The player comes
## to in front of the house, beaten up, Grandpa back in his chair: "Well,
## that just happened." Played by HospitalQuietZone in place of the usual
## fine while the quest's on (ExStory), which then finishes it.
##
## The words live in res://cutscenes/ex_police_beating.tres; edit them in
## the inspector.

const ID := &"ex_police_beating"

@export var thats_it_line: String = "THAT'S IT!"
@export var rita_line: String = "THAT'S IT!"
@export var happened_line: String = "Well, that just happened."
## How many whacks it takes to put the lights out.
@export var hits: int = 8

## Set by ExStory before playing: Grandpa (back in his chair when the player
## comes to) and where the car wakes up, by the house.
var grandpa: GrandpaNpc
var wake_at: Vector2

func _init() -> void:
	id = ID

func play() -> void:
	if not await arrive(5, true):
		return
	yell(dale)
	await Cutscenes.subtitle(DALE.display_name, DALE, thats_it_line, dale)
	yell(rita)
	await Cutscenes.subtitle(RITA.display_name, RITA, rita_line, rita)
	# Into the car with them, and lights out a whack at a time.
	Cutscenes.walk(rita, at + Vector2(-110.0, -10.0), 240.0)
	await Cutscenes.walk(dale, at + Vector2(-60.0, 20.0), 240.0)
	for i in hits:
		var officer := dale if i % 2 == 0 else rita
		Cutscenes.hop(officer, 18.0 + i * 2.0)
		Cutscenes.sound(&"car_whack", -4.0 + i * 0.5)
		Cutscenes.shake(8.0 + i * 1.5, 0.25)
		if player != null and i == 2:
			Cutscenes.fall_over(player)
		await Cutscenes.darken_to(float(i + 1) / hits, 0.35)
		await Cutscenes.wait(0.12)
	truck.queue_free()
	dale.visible = false
	rita.visible = false
	Cutscenes.clear_subtitle()

	# Coming to, out front of the house.
	await Cutscenes.wait(1.0)
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as PlayerCar
	if car != null:
		car.park(wake_at, false)
	if is_instance_valid(grandpa):
		grandpa.visible = true
	if player != null:
		player.global_position = wake_at + Vector2(-90.0, 20.0)
		# Black eyes, a split brow, blood down the shirt.
		CharacterInjuries.apply(player, 2)
	Cutscenes.cut_to(wake_at + Vector2(-90.0, -90.0), zoom + 0.4)
	await Cutscenes.fade_in(1.6)
	await Cutscenes.wait(0.6)
	if player != null:
		await Cutscenes.stand_up(player)
	await Cutscenes.wait(0.4)
	await Cutscenes.subtitle(my_name, me, happened_line, player)
	await Cutscenes.wait(0.4)
