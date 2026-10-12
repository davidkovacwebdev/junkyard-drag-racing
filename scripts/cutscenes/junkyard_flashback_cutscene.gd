class_name JunkyardFlashbackCutscene
extends Cutscene
## "What Happened?", at the junkyard: the man at the counter (Vern, or
## whichever crane worker has his job now) comes over, sorry for the
## player's loss, and tells them how Eugen died. He thought he'd seen the One
## Piece, the junkyard's mythical treasure, glinting in the heap.
##
## Then the flashback, at night (a blue tint over the yard): Grandpa rolls
## along the outside of the front fence in his wheelchair, sighs that it's
## arm day, tips out of it onto his face (the empty chair rolls back), drags
## himself up to the fence by his arms, lunges for the top rail, hangs
## there kicking his dead legs, slips, heaves himself up rail by rail, teeters
## over the top and drops down behind it, crawls on his arms all the way to
## the crane, legs trailing, and
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
@export var legs_line: String = "Ahhh, damn legs... Guess it's arm day."
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
## Where along the front fence Grandpa climbs in (x from the yard's middle,
## between two posts and well clear of the gate). Where he rolls in from and
## parks, outside the fence (relative to the yard's middle), and where the
## shine shows on the heap (relative to it).
@export var fence_climb_x: float = -690.0
@export var roll_from := Vector2(-1450.0, 680.0)
@export var park_spot := Vector2(-880.0, 680.0)
@export var shine_spot := Vector2(-20.0, -150.0)
## How far in front of the fence he hangs off it, and how far behind it he
## lands.
@export var fence_front_gap: float = 30.0
@export var fence_back_gap: float = 18.0
## His body's lift off the ground after each heave up the fence; a lower
## one is a slip back down.
@export var fence_heaves: Array[float] = [34.0, 14.0, 52.0, 80.0]
## His lift lying across the top rail, before he tips over.
@export var fence_drape_lift: float = 134.0
## How far up the mast he gets before it goes, and in how many pulls.
@export var climb_height: float = 260.0
@export var climb_pulls: int = 5
## Where he hits the ground, from the crane's tracks.
@export var landing_offset := Vector2(250.0, 30.0)
## How far below where he lands the paramedics walk in, along the front of
## the fallen crane instead of across its tracks (inside the front fence).
@export var medic_lane: float = 150.0
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
	var fence_foot := yard.global_position + Vector2(fence_climb_x, (yard as JunkyardYard).yard_size.y * 0.5)
	var parked := yard.global_position + park_spot
	var in_chair := Cutscenes.spawn_actor(GRANDPA_CHAIR, yard.global_position + roll_from, true)
	var front_fence := _front_fence(yard as JunkyardYard, in_chair.get_parent())
	var shine := _make_shine()
	(pile if pile != null else yard).add_child(shine)
	shine.position = shine_spot
	shine.visible = false
	_pulse(shine)
	# Kept up off the bottom of the lot so the view never runs off the dirt.
	Cutscenes.cut_to(fence_foot + Vector2(-60.0, -40.0), flashback_zoom + 0.35)
	await Cutscenes.fade_in(0.8)

	# He rolls up to the fence in his chair...
	Cutscenes.sound(&"wheelchair_squeak", -6.0)
	var roll := Cutscenes.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	roll.tween_property(in_chair, "global_position", parked, 2.8)
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
	# ...tips out of it, flat on his face, and the empty chair rolls back.
	await _tip_out(in_chair, parked)
	var chair := EMPTY_CHAIR.instantiate() as Node2D
	chair.scale = Vector2.ONE * Cutscenes.ACTOR_SCALE
	in_chair.get_parent().add_child(chair)
	chair.global_position = parked
	in_chair.visible = false
	var grandpa := Cutscenes.spawn_actor(GRANDPA, parked + Vector2(24.0, 14.0), true)
	grandpa.set_pose(0.55, 40.0)
	var flop := grandpa.pose(PI * 0.5, CutsceneActor.CRAWL_LIFT, 0.3, Tween.TRANS_QUAD, Tween.EASE_IN)
	var roll_back := Cutscenes.create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	roll_back.tween_property(chair, "global_position", parked + Vector2(-26.0, 0.0), 0.6)
	await Cutscenes.play_tween(flop)
	Cutscenes.sound(&"flesh_splat", -6.0, grandpa)
	Cutscenes.sound(&"wheelchair_squeak", -12.0)
	Cutscenes.shake(4.0, 0.2)
	await Cutscenes.wait(0.7)

	# Over the fence...
	await _climb_fence(grandpa, fence_foot)
	# ...and off to the crane, dragging himself along by his arms.
	var crane_foot := crane.global_position + Vector2(-40.0, 30.0)
	var crawl := grandpa.crawl_to(crane_foot)
	Cutscenes.camera_to((crane_foot + grandpa.global_position) * 0.5 + Vector2(0.0, -120.0), flashback_zoom, 3.0)
	shine.visible = true
	Cutscenes.sound(&"wink_ting", -6.0)
	await Cutscenes.subtitle(dealer_name, operator, shine_line)
	Cutscenes.sound(&"wink_ting", -8.0)
	await Cutscenes.subtitle(dealer_name, operator, shiiine_line)
	await Cutscenes.play_tween(crawl)

	# Up the mast, hand over hand, legs dangling.
	var mast_foot := crane.global_position + Vector2(0.0, -70.0)
	grandpa.raise_arms(true)
	await Cutscenes.stand_up(grandpa)
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
	Cutscenes.camera_to(landing + Vector2(-260.0, -60.0), flashback_zoom + 0.2, 1.4)
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
	var lane_y := landing.y + medic_lane
	_walk_round(lou, lane_y + 10.0, landing + Vector2(110.0, 80.0))
	await _walk_round(gord, lane_y, landing + Vector2(-60.0, 105.0))
	Cutscenes.face(lou, false)
	await Cutscenes.camera_to(landing + Vector2(0.0, -40.0), flashback_zoom + 0.6, 0.8)
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
	for section in front_fence:
		section.queue_free()
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

## The front fence again, Y-sorted in with everyone (either side of the
## gate), so whoever is inside the yard goes behind it: Grandpa once he's
## over, the ambulance and the paramedics walking in along it.
func _front_fence(lot: JunkyardYard, parent: Node) -> Array[Node2D]:
	var half := lot.yard_size.x * 0.5
	var sections: Array[Node2D] = []
	for span: Vector2 in [Vector2(-half, -lot.gate_half_width), Vector2(lot.gate_half_width, half)]:
		var section := lot.front_fence_section(span.x, span.y)
		parent.add_child(section)
		section.global_position = lot.to_global(section.position)
		sections.append(section)
	return sections

## He slumps forward in the chair and over the front of it.
func _tip_out(in_chair: CutsceneActor, parked: Vector2) -> void:
	var lean := Cutscenes.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	lean.tween_property(in_chair, "rotation", 0.3, 0.35)
	lean.parallel().tween_property(in_chair, "global_position", parked + Vector2(8.0, 0.0), 0.35)
	await Cutscenes.play_tween(lean)
	in_chair.rotation = 0.0

## Crawls up to the front fence and lunges for the top rail. Hangs there,
## legs swinging, then heaves himself up rail by rail (slipping back once),
## flops across the top, teeters, and drops down behind it, where the
## Y-sorted front fence hides him behind its rails. Then he
## crawls out from behind it into the yard.
func _climb_fence(grandpa: CutsceneActor, fence_foot: Vector2) -> void:
	var front := fence_foot + Vector2(0.0, fence_front_gap)
	await Cutscenes.play_tween(grandpa.crawl_to(front))
	Cutscenes.camera_to(fence_foot + Vector2(-10.0, -80.0), flashback_zoom + 0.6, 2.5)
	await Cutscenes.wait(0.5)

	# Up on his arms, a lunge, and a hand on the top rail.
	grandpa.raise_arms(true, 0.25)
	Cutscenes.sound(&"grandpa_heave", -4.0)
	await Cutscenes.play_tween(grandpa.pose(0.0, 22.0, 0.3, Tween.TRANS_BACK, Tween.EASE_OUT))
	Cutscenes.sound(&"wood_clonk", -8.0)
	await Cutscenes.play_tween(grandpa.pose(0.0, 6.0, 0.25, Tween.TRANS_QUAD, Tween.EASE_IN))
	# Dangling there, the dead legs swinging under him.
	for swing: float in [0.14, -0.1, 0.06, 0.0]:
		await Cutscenes.play_tween(grandpa.pose(swing, 6.0, 0.22))
	await Cutscenes.wait(0.3)

	# Heave by heave up the rails.
	var lift := 6.0
	for heave in fence_heaves:
		if heave < lift:
			Cutscenes.sound(&"grandpa_gasp", -8.0)
			await Cutscenes.play_tween(grandpa.pose(-0.08, heave, 0.25, Tween.TRANS_QUAD, Tween.EASE_IN))
			await Cutscenes.play_tween(grandpa.pose(0.0, heave, 0.2))
			await Cutscenes.wait(0.35)
		else:
			Cutscenes.sound(&"grandpa_heave", -4.0)
			await Cutscenes.play_tween(grandpa.pose(0.1, heave, 0.32, Tween.TRANS_BACK, Tween.EASE_OUT))
			Cutscenes.sound(&"wood_clonk", -10.0)
			Cutscenes.shake(3.0, 0.15)
			await Cutscenes.play_tween(grandpa.pose(0.0, heave, 0.2))
			await Cutscenes.wait(0.4)
		lift = heave

	# Belly across the top rail...
	Cutscenes.sound(&"grandpa_heave", -3.0)
	await Cutscenes.play_tween(grandpa.pose(PI * 0.5, fence_drape_lift, 0.4, Tween.TRANS_BACK, Tween.EASE_OUT))
	Cutscenes.sound(&"wood_clonk", -6.0)
	# ...teetering on it...
	for teeter: float in [0.25, -0.15, 0.35]:
		await Cutscenes.play_tween(grandpa.pose(PI * 0.5 + teeter, fence_drape_lift, 0.3))
	await Cutscenes.wait(0.2)
	# ...and over, down behind it.
	grandpa.set_footing_y(fence_foot.y - fence_back_gap)
	await Cutscenes.play_tween(grandpa.pose(PI * 0.5, CutsceneActor.CRAWL_LIFT, 0.3, Tween.TRANS_QUAD, Tween.EASE_IN))
	Cutscenes.sound(&"flesh_splat", -4.0, grandpa)
	Cutscenes.shake(6.0, 0.25)
	await Cutscenes.wait(0.6)
	await Cutscenes.play_tween(grandpa.crawl_to(fence_foot + Vector2(90.0, -80.0)))

## Hand over hand up the mast: a jerky pull, a clank, a swing of the legs.
func _climb_mast(grandpa: CutsceneActor, foot: Vector2) -> void:
	await _haul_up(grandpa, foot, climb_height, climb_pulls)

## Up `height` above `foot` by the arms in `pulls` jerky pulls, swinging
## side to side, a clank on each.
func _haul_up(grandpa: CutsceneActor, foot: Vector2, height: float, pulls: int) -> void:
	var step := height / maxi(pulls, 1)
	for i in pulls:
		var pull := Cutscenes.create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		pull.tween_property(grandpa, "global_position", foot + Vector2(0.0, -step * (i + 1)), 0.3)
		pull.parallel().tween_property(grandpa, "rotation", 0.12 if i % 2 == 0 else -0.12, 0.3)
		Cutscenes.sound(&"crane_shove", -10.0)
		await Cutscenes.play_tween(pull)
		await Cutscenes.wait(0.35)
	grandpa.rotation = 0.0

## Down from the truck to `lane_y`, along it until level with `spot`, then
## up to it, so the walk never cuts across the fallen crane.
func _walk_round(medic: CutsceneActor, lane_y: float, spot: Vector2) -> void:
	await Cutscenes.walk(medic, Vector2(medic.global_position.x + 40.0, lane_y), 150.0)
	await Cutscenes.walk(medic, Vector2(spot.x, lane_y), 170.0)
	await Cutscenes.walk(medic, spot, 150.0)

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
