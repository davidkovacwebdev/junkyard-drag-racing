class_name JunkyardFlashbackCutscene
extends Cutscene
## "What Happened?", at the junkyard: the man at the counter (Vern, or
## whichever crane worker has his job now) comes over, sorry for the
## player's loss, and tells them how Eugen died. He thought he'd seen the One
## Piece, the junkyard's mythical treasure, glinting in the heap.
##
## Then the flashback, at night (a blue tint over the yard): Grandpa rolls
## up to the side fence in his wheelchair, sighs that he'll have to use his
## legs, climbs out and over the fence (the chair stays parked outside),
## waddles to the crane on his useless legs, and
## hauls himself up the mast by his hands. The crane tips over and comes down
## on him, squashing him flat as a pancake. The garbage truck (also the
## town's ambulance) backs in, two paramedics climb out, look him over, and
## one says he flat-lined. A beat of silence, and they both crack up.
##
## Back in the present the player can't believe they laughed, the man
## admits it was a pretty good joke, and hands over a note Grandpa left.
## Played by JunkyardStory as the junkyard loads while the quest is on; the note itself is
## handed over there, after the scene.
##
## The words live in res://cutscenes/junkyard_flashback.tres; edit them in
## the inspector. `{dealer}` in a line becomes the man's name.

const ID := &"junkyard_flashback"
## Grandpa in his wheelchair (as he arrives), and out of it (dangling legs).
const GRANDPA_CHAIR := preload("res://characters/grandpa.tres")
const GRANDPA := preload("res://characters/grandpa_flashback.tres")
const EMPTY_CHAIR := preload("res://scenes/characters/props/empty_wheelchair.tscn")
const GORD := preload("res://characters/paramedic_gord.tres")
const LOU := preload("res://characters/paramedic_lou.tres")
const NOTE := preload("res://scenes/items/icons/item_note.tscn")
const DEALER_TOKEN := "{dealer}"
const NIGHT_TINT := Color(0.58, 0.63, 0.88, 1)
const GOLD := Color(0.98, 0.84, 0.3, 1)

## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var sorry_line: String = "{player}! I'm so sorry, kid."
@export var thanks_line: String = "Thanks... but what happened?"
@export var fool_line: String = "That old fool... he thought he saw the One Piece."
@export var myth_line: String = "One piece of the junkyard treasure. The old myth, passed down from generation to generation."
@export var broke_in_line: String = "He broke into the junkyard in the middle of the night."
## Grandpa's, as he parks his wheelchair by the fence.
@export var legs_line: String = "Ahhh, I guess I'll have to use my legs."
@export var shine_line: String = "I remember him telling me, even last week, he thought he saw a golden shine in the junkyard."
@export var shiiine_line: String = "A gooooolden shiiiiine..."
@export var climb_line: String = "He tried climbing the crane to get it, but..."
@export var ambulance_line: String = "Ambulance came..."
@export var flatline_line: String = "It seems he flat-lined."
@export var laughed_line: String = "They laughed????"
@export var joke_line: String = "It was a pretty good joke. Good timing. Although I see your point."
@export var sucks_line: String = "This sucks...."
@export var miss_line: String = "I'll miss old Eugen... He left you this."
@export var bye_line: String = "Thanks, {dealer}."

@export_group("Staging")
@export var zoom: float = 1.4
@export var flashback_zoom: float = 0.75
## Where Grandpa climbs in over the left side fence (relative to the yard's
## middle): low in the yard, so he stays below the crane's boom. Where he
## rolls in from, and where the shine shows on the heap (relative to it).
@export var fence_spot := Vector2(-950.0, 470.0)
@export var roll_from := Vector2(-1300.0, 470.0)
@export var shine_spot := Vector2(-20.0, -150.0)
## How far up the mast he gets before it goes, and in how many pulls.
@export var climb_height: float = 260.0
@export var climb_pulls: int = 5
## Where he hits the ground, from the crane's tracks.
@export var landing_offset := Vector2(250.0, 30.0)
## The beat of silence after the joke, before they crack up.
@export var joke_beat: float = 0.5

## Set by JunkyardStory before playing.
var yard: Node2D

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(yard):
		return
	var crane := yard.get_node_or_null(^"Yard/Crane") as JunkyardCrane
	var pile := yard.get_node_or_null(^"Yard/Pile") as Node2D
	var dealer := yard.get_node_or_null(^"Yard/Dealer") as Node2D
	var car := yard.get_node_or_null(^"Yard/PlayerCar") as Node2D
	if crane == null or dealer == null or car == null:
		return
	var me := PlayerProfile.character
	var name := PlayerProfile.display_name()
	var operator := CraneWorkerGenerator.current_operator()
	var dealer_name := operator.display_name

	# --- The present: he comes over. ---
	await Cutscenes.fade_out(0.0)
	dealer.visible = false
	var man := Cutscenes.spawn_actor(operator, dealer.global_position, false)
	var player: CutsceneActor = null
	if me != null:
		player = Cutscenes.spawn_actor(me, car.global_position + Vector2(90.0, 20.0), true)
	var meet := car.global_position + Vector2(300.0, 10.0)
	Cutscenes.cut_to(meet + Vector2(-60.0, -130.0), zoom)
	await Cutscenes.fade_in(0.8)
	await Cutscenes.walk(man, meet, 170.0)
	Cutscenes.face(man, false)
	await Cutscenes.subtitle(dealer_name, operator, _fill(sorry_line, dealer_name), man)
	if player != null:
		player.cry(2.0)
		_sob()
	await Cutscenes.subtitle(name, me, thanks_line, player)
	await Cutscenes.subtitle(dealer_name, operator, fool_line, man)
	await Cutscenes.subtitle(dealer_name, operator, myth_line, man)

	# --- The flashback: that night. ---
	await Cutscenes.fade_out(0.7)
	var hidden: Array[CanvasItem] = [car, man]
	if player != null:
		hidden.append(player)
	for item in hidden:
		item.visible = false
	# That night the crane still stood (it's lying in the yard now).
	var wreck_angle := crane.rotation
	crane.rotation = 0.0
	var night := CanvasModulate.new()
	night.color = NIGHT_TINT
	yard.add_child(night)
	var fence := yard.global_position + fence_spot
	var parked := fence + Vector2(-110.0, 0.0)
	var in_chair := Cutscenes.spawn_actor(GRANDPA_CHAIR, yard.global_position + roll_from, true)
	var shine := _make_shine()
	(pile if pile != null else yard).add_child(shine)
	shine.position = shine_spot
	shine.visible = false
	_pulse(shine)
	# Kept right of the fence enough that the view never runs off the dirt.
	Cutscenes.cut_to(fence + Vector2(110.0, -120.0), flashback_zoom + 0.35)
	await Cutscenes.fade_in(0.8)

	# He rolls up to the fence in his chair...
	Cutscenes.sound(&"wheelchair_squeak", -6.0)
	var roll := Cutscenes.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	roll.tween_property(in_chair, "global_position", parked, 2.4)
	await Cutscenes.subtitle(dealer_name, operator, broke_in_line)
	await Cutscenes.play_tween(roll)
	Cutscenes.sound(&"wheelchair_squeak", -8.0)
	await Cutscenes.wait(0.4)
	Cutscenes.sound(&"grandpa_sigh", -4.0)
	var sag := Cutscenes.create_tween().set_trans(Tween.TRANS_SINE)
	sag.tween_property(in_chair, "rotation", 0.08, 0.6)
	sag.tween_interval(0.5)
	sag.tween_property(in_chair, "rotation", 0.0, 0.6)
	await Cutscenes.play_tween(sag)
	await Cutscenes.subtitle(GRANDPA_CHAIR.display_name, GRANDPA_CHAIR, legs_line, in_chair)
	# ...gets out, and leaves it parked there.
	var chair := EMPTY_CHAIR.instantiate() as Node2D
	chair.scale = Vector2.ONE * Cutscenes.ACTOR_SCALE
	in_chair.get_parent().add_child(chair)
	chair.global_position = parked
	in_chair.visible = false
	var grandpa := Cutscenes.spawn_actor(GRANDPA, parked + Vector2(30.0, 12.0), true)
	await Cutscenes.hop(grandpa, 24.0)

	# Over the fence...
	await _climb_fence(grandpa, fence)
	# ...and off to the crane.
	var crane_foot := crane.global_position + Vector2(-40.0, 30.0)
	Cutscenes.walk(grandpa, crane_foot, 120.0)
	Cutscenes.camera_to((crane_foot + grandpa.global_position) * 0.5 + Vector2(0.0, -120.0), flashback_zoom, 3.0)
	shine.visible = true
	Cutscenes.sound(&"wink_ting", -6.0)
	await Cutscenes.subtitle(dealer_name, operator, shine_line)
	Cutscenes.sound(&"wink_ting", -8.0)
	await Cutscenes.subtitle(dealer_name, operator, shiiine_line)
	await Cutscenes.walk(grandpa, crane_foot, 120.0)

	# Up the mast, hand over hand, legs dangling.
	var mast_foot := crane.global_position + Vector2(0.0, -70.0)
	grandpa.global_position = mast_foot
	Cutscenes.face(grandpa, true)
	Cutscenes.camera_to(crane.global_position + Vector2(120.0, -240.0), flashback_zoom, 1.2)
	_climb_mast(grandpa, mast_foot)
	await Cutscenes.subtitle(dealer_name, operator, climb_line)
	await Cutscenes.wait(0.4)

	# It goes. He drops off first, then it comes down on top of him.
	Cutscenes.sound(&"crane_collapse", 0.0)
	var landing := crane.global_position + landing_offset
	var fall := Cutscenes.create_tween()
	fall.tween_property(crane, "rotation", CraneWreck.FALL_ANGLE, 0.95).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	var drop := Cutscenes.create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	drop.tween_interval(0.2)
	drop.tween_property(grandpa, "global_position", landing, 0.45)
	await Cutscenes.play_tween(fall)
	Cutscenes.shake(18.0, 0.6)
	await Cutscenes.play_tween(grandpa.flatten())
	Cutscenes.sound(&"pancake_splat", -2.0)
	await Cutscenes.wait(1.4)

	# The ambulance (the garbage truck) backs in.
	Cutscenes.camera_to(landing + Vector2(-260.0, -140.0), flashback_zoom + 0.2, 1.4)
	var truck := PenGarbageTruck.spawn(crane.get_parent(), landing + Vector2(-1400.0, 60.0), false)
	truck.scale = Vector2.ONE * 0.8
	Cutscenes.sound(&"siren_whoop", -6.0)
	var park := landing + Vector2(-520.0, 60.0)
	# Beeping all the way in.
	truck.reverse_to(park, 2.6)
	await Cutscenes.subtitle(dealer_name, operator, ambulance_line)
	await Cutscenes.wait(0.9)
	truck.global_position = park
	Cutscenes.sound(&"siren_whoop", -8.0)
	Cutscenes.sound(&"door_close", -6.0)
	var gord := Cutscenes.spawn_actor(GORD, park + Vector2(40.0, 20.0), true)
	var lou := Cutscenes.spawn_actor(LOU, park + Vector2(10.0, -10.0), true)
	Cutscenes.walk(lou, landing + Vector2(120.0, -30.0), 150.0)
	await Cutscenes.walk(gord, landing + Vector2(-110.0, 20.0), 150.0)
	Cutscenes.face(lou, false)
	await Cutscenes.camera_to(landing + Vector2(0.0, -120.0), flashback_zoom + 0.6, 0.8)
	await Cutscenes.wait(0.8)
	await Cutscenes.subtitle(GORD.display_name, GORD, flatline_line, gord)
	await Cutscenes.wait(joke_beat)
	_crack_up(gord, 1.0)
	_crack_up(lou, 1.25)
	await Cutscenes.wait(2.4)

	# --- Back to the present. ---
	await Cutscenes.fade_out(0.8)
	crane.rotation = wreck_angle
	night.queue_free()
	shine.queue_free()
	truck.queue_free()
	chair.queue_free()
	for actor in [grandpa, gord, lou]:
		actor.visible = false
	for item in hidden:
		item.visible = true
	if player != null:
		Cutscenes.cut_to(player.global_position + Vector2(100.0, -140.0), zoom + 0.4)
	await Cutscenes.fade_in(0.8)

	await Cutscenes.subtitle(name, me, laughed_line, player)
	await Cutscenes.subtitle(dealer_name, operator, joke_line, man)
	await Cutscenes.subtitle(name, me, sucks_line, player)
	await Cutscenes.subtitle(dealer_name, operator, miss_line, man)
	# He hands it over: a folded note.
	if player != null:
		var note := NOTE.instantiate() as Node2D
		note.scale = Vector2.ONE * 0.6
		note.position = Vector2(46.0, -110.0)
		note.z_index = GrandpaNpc.WRENCH_Z
		player.attach(note)
	Cutscenes.sound(&"paper_unfold", -4.0)
	await Cutscenes.wait(0.6)
	await Cutscenes.subtitle(name, me, _fill(bye_line, dealer_name), player)
	await Cutscenes.wait(0.5)
	dealer.visible = true

func _fill(line: String, dealer_name: String) -> String:
	return line.replace(DEALER_TOKEN, dealer_name)

## The player's own sob: Grandpa's, pitched up out of his range.
func _sob() -> void:
	if not Cutscenes.is_skipping():
		Sfx.play(&"grandpa_sob", -5.0, 0.0).pitch_scale = 1.35

## Up to the side fence, a rattle as he scrambles over it, and down into
## the yard.
func _climb_fence(grandpa: CutsceneActor, fence: Vector2) -> void:
	await Cutscenes.walk(grandpa, fence + Vector2(-20.0, 0.0), 90.0)
	Cutscenes.sound(&"gate_rattle", -4.0)
	await Cutscenes.hop(grandpa, 80.0)
	grandpa.global_position = fence + Vector2(30.0, 0.0)
	await Cutscenes.walk(grandpa, fence + Vector2(90.0, 10.0), 140.0)

## Hand over hand up the mast: a jerky pull, a clank, a swing of the legs.
func _climb_mast(grandpa: CutsceneActor, foot: Vector2) -> void:
	var step := climb_height / maxi(climb_pulls, 1)
	for i in climb_pulls:
		var pull := Cutscenes.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pull.tween_property(grandpa, "global_position", foot + Vector2(0.0, -step * (i + 1)), 0.3)
		pull.parallel().tween_property(grandpa, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.3)
		Cutscenes.sound(&"crane_shove", -10.0)
		await Cutscenes.play_tween(pull)
		await Cutscenes.wait(0.35)
	grandpa.rotation = 0.0

## Doubled over laughing: a big guffaw (Grandpa's laugh, pitched to suit)
## and a few bounces.
func _crack_up(medic: CutsceneActor, pitch: float) -> void:
	if not Cutscenes.is_skipping():
		var laugh := Sfx.play(&"grandpa_laugh", -3.0, 0.0)
		laugh.pitch_scale = pitch
	for i in 4:
		await Cutscenes.hop(medic, 18.0)

## The glint on the heap: a fat four-pointed star.
func _make_shine() -> Node2D:
	var star := Polygon2D.new()
	star.color = GOLD
	star.polygon = PackedVector2Array([
		Vector2(0.0, -34.0), Vector2(8.0, -8.0), Vector2(34.0, 0.0), Vector2(8.0, 8.0),
		Vector2(0.0, 34.0), Vector2(-8.0, 8.0), Vector2(-34.0, 0.0), Vector2(-8.0, -8.0),
	])
	star.z_index = 20
	return star

## Swells and shrinks the glint until it's freed.
func _pulse(star: Node2D) -> void:
	var pulse := star.create_tween().set_loops()
	pulse.tween_property(star, "scale", Vector2.ONE * 1.3, 0.5).set_trans(Tween.TRANS_SINE)
	pulse.tween_property(star, "scale", Vector2.ONE * 0.6, 0.5).set_trans(Tween.TRANS_SINE)
