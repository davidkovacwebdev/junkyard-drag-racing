class_name DiggerRevealCutscene
extends DetectorAskCutscene
## "Heavy Machinery", at the junkyard counter: the player asks for something
## to dig with, and the man behind it has just the thing. Cut to the yard's
## little digger (DiggerRig) for a five-second montage to generic rock
## ("digger_montage", SongLibrary): quick cuts from all sorts of angles (in
## 2D: close-ups, the digger mirrored and tilted, a punch-in), the engine
## catching and a scoop or two. Back at the counter he says it's theirs to
## borrow any time after, for $100 (ScrapDealer). Played by ScrapDealer from
## his dialog; finishing it finishes the quest, and "Dig It" follows, with
## the player at the digger's controls.
##
## The words live in res://cutscenes/digger_reveal.tres; edit them in the
## inspector.

const DIGGER_ID := &"digger_reveal"

@export var dig_ask_line: String = "So, we marked the spot. Got anything I could dig with?"
@export var right_thing_line: String = "I've got just the right thing for you."
@export var borrow_line: String = "Take her. And after, you can borrow her any time you like. $100 a go."

@export_group("Staging")
## Where the digger's parked, from the man at the counter.
@export var digger_offset := Vector2(-420.0, 90.0)
@export var digger_zoom: float = 1.7
## How long the montage runs, and the song that plays over it.
@export var montage_seconds: float = 5.0
@export var montage_song: StringName = &"digger_montage"

func _init() -> void:
	id = DIGGER_ID

func play() -> void:
	if not await stage():
		return
	await i_say(greeting())
	await i_say(dig_ask_line)
	await npc_says(right_thing_line)
	if npc != null:
		npc.wink(-8.0)
	await Cutscenes.wait(0.6)

	# Cut to the digger: the montage, just the machine.
	await Cutscenes.fade_out(0.3)
	Cutscenes.clear_subtitle()
	for actor: CutsceneActor in [npc, player]:
		if actor != null:
			actor.visible = false
	var digger := DiggerRig.new()
	digger.global_position = npc_rig.global_position + digger_offset
	Cutscenes.get_tree().current_scene.add_child(digger)
	if not Cutscenes.is_skipping():
		await _montage(digger)
	digger.queue_free()

	# Back at the counter.
	for actor: CutsceneActor in [npc, player]:
		if actor != null:
			actor.visible = true
	Cutscenes.cut_to(two_shot, zoom)
	await Cutscenes.fade_in(0.3)
	await npc_says(borrow_line)
	await Cutscenes.wait(0.3)
	await Cutscenes.fade_out(0.5)
	unstage()

## Six quick shots of the digger over `montage_seconds` of rock. A 2D camera
## can't go round the back, so the "angles" are cuts: wide, the bucket up
## close, the digger turned the other way, the tracks, a dutch tilt, and a
## punch-in to finish.
func _montage(digger: DiggerRig) -> void:
	var music := _start_song()
	var at := digger.global_position
	var shot := montage_seconds / 6.0
	# Wide, engine catching.
	Cutscenes.cut_to(at + Vector2(10.0, -40.0), digger_zoom * 0.8)
	await Cutscenes.fade_in(0.15)
	Cutscenes.sound(&"ignition_click", -6.0)
	Cutscenes.sound(&"backfire", -6.0)
	Cutscenes.shake(3.0, 0.25)
	await Cutscenes.wait(shot - 0.15)
	# The bucket, close, coming down.
	Cutscenes.cut_to(at + DiggerRig.WRIST_DUG, digger_zoom * 2.2)
	digger.dig()
	await Cutscenes.wait(shot)
	# Turned round: the cab from the other side.
	digger.scale.x = -1.0
	Cutscenes.cut_to(at + Vector2(20.0, -20.0), digger_zoom * 1.6)
	await Cutscenes.wait(shot)
	# The tracks, rumbling.
	Cutscenes.cut_to(at + Vector2(-10.0, 22.0), digger_zoom * 2.6)
	Cutscenes.shake(4.0, shot)
	await Cutscenes.wait(shot)
	# Dutch angle, mid-scoop.
	digger.scale.x = 1.0
	digger.rotation = -0.14
	Cutscenes.cut_to(at + Vector2(30.0, -30.0), digger_zoom * 1.4)
	digger.dig()
	await Cutscenes.wait(shot)
	# Hero shot: level, punching in.
	digger.rotation = 0.0
	Cutscenes.cut_to(at + Vector2(10.0, -40.0), digger_zoom * 0.9)
	Cutscenes.sound(&"backfire", -6.0)
	Cutscenes.camera_to(at + Vector2(10.0, -40.0), digger_zoom * 1.3, shot)
	await Cutscenes.wait(shot - 0.3)
	await Cutscenes.fade_out(0.3)
	_stop_song(music)

## The montage song from the top on the Music bus, the game's own music
## hushed under it. Null when it isn't baked.
func _start_song() -> AudioStreamPlayer:
	var stream := load(SongLibrary.baked_path(montage_song)) as AudioStream
	if stream == null:
		return null
	Music.hush(true, 0.2)
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = &"Music"
	player.volume_db = Music.VOLUME_DB
	Cutscenes.get_tree().current_scene.add_child(player)
	player.play()
	return player

func _stop_song(player: AudioStreamPlayer) -> void:
	Music.hush(false)
	if not is_instance_valid(player):
		return
	var tween := player.create_tween()
	tween.tween_property(player, "volume_db", -60.0, 0.3)
	tween.tween_callback(player.queue_free)
