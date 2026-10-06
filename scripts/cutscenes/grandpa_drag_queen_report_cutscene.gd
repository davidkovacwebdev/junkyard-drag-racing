class_name GrandpaDragQueenReportCutscene
extends Cutscene
## Handing in "Pay Your Respects": the player reports back from the Drag
## Queen's grave. Grandpa cuts them off, wide-eyed, to ask if there were any
## drag racers there, and the player decides to just say yes. Asked about
## the flag on his wheelchair, he remembers the big parade for her, and
## reckons "Drag Queen" was her racing name, like Steve McQueen. Pushed on
## it, he gets annoyed, and the player lets it go and promises him a bigger
## flag. The quest's `turn_in_cutscene`; GrandpaNpc finishes the quest once
## it's over.
##
## The words live in res://cutscenes/grandpa_drag_queen_report.tres; edit
## them in the inspector. The beats:
##   - the player walks up; he asks the `ask_line`
##   - the player starts the `report_line` and he interrupts, eyes wide,
##     with the `interrupt_line`
##   - a long pause, then the player's `fib_lines`; the camera glances at the
##     flag on his wheelchair
##   - back and forth through the `chat`, him getting annoyed at the end
##   - the player's `closing_line`

const ID := &"grandpa_drag_queen_report"
const GRANDPA := preload("res://characters/grandpa.tres")
## In `chat`, a line starting with this is the player's; any other is his.
const PLAYER_MARK := "> "

@export var speaker_name: String = "Grandpa"
## These defaults are the scene as written; edits in the inspector on the
## .tres override them.
@export var ask_line: String = "So how was it?"
## Trails off as he barges in.
@export var report_line: String = "I left the wheel... I met some people there... and—"
@export var interrupt_line: String = "WERE THERE ANY DRAG RACERS?"
## Said after a long pause; the last one asks about the flag.
@export_multiline var fib_lines: PackedStringArray = [
	"... Actually... Yeah, yeah, there were some racers there...",
	"By the way, where did you get the flag?",
]
## The back and forth that follows. Lines starting with "> " are the
## player's; the rest are his.
@export_multiline var chat: PackedStringArray = [
	"Oh, a while ago there was this massive parade celebrating our beloved Drag Queen.",
	"> Was that her real name?",
	"Well, it was probably a name she used for racing, you know, like Steve McQueen or Evel Knievel...",
	"> Gramps, are you sure?",
]
## Shouted, annoyed.
@export var annoyed_line: String = "What's up with these questions?!"
@export var closing_line: String = "Nevermind. I'll get you a larger flag, which you can put around your shoulders when it's cold."

@export_group("Staging")
## Where the player's own character stands, relative to Grandpa.
@export var player_offset := Vector2(110.0, -40.0)
@export var zoom: float = 1.9
@export var flag_zoom: float = 2.4
## Aims above the pair's feet so heads stay in frame.
@export var camera_lift: float = 70.0
## The player's long, awkward pause before the fib.
@export var pause_seconds: float = 1.8

## Set by GrandpaNpc before playing: the Grandpa parked in the world.
var grandpa: GrandpaNpc

func _init() -> void:
	id = ID

func play() -> void:
	if not is_instance_valid(grandpa):
		return
	var player_spot := grandpa.global_position + player_offset
	var middle := (player_spot + grandpa.global_position) * 0.5 + Vector2(0.0, -camera_lift)

	await Cutscenes.fade_out(0.0)
	var player: CutsceneActor = null
	if PlayerProfile.character != null:
		player = Cutscenes.spawn_actor(PlayerProfile.character, player_spot + Vector2(80.0, 0.0), false)
	Cutscenes.cut_to(middle, zoom)
	await Cutscenes.fade_in(0.8)
	if player != null:
		await Cutscenes.walk(player, player_spot, 120.0)
		Cutscenes.face(player, false)

	await _grandpa(ask_line)
	await _player(report_line, player)
	if not Cutscenes.is_skipping():
		grandpa.widen_eyes(2.4)
		Cutscenes.shake(6.0, 0.3)
	await _grandpa(interrupt_line)

	await Cutscenes.wait(pause_seconds)
	for i in fib_lines.size():
		await _player(fib_lines[i], player)
		# Asking about the flag, the camera glances over at it.
		if i == fib_lines.size() - 1:
			await Cutscenes.camera_to(grandpa.trans_flag_position(), flag_zoom, 0.6)
			await Cutscenes.wait(0.5)
			await Cutscenes.camera_to(middle, zoom, 0.6)

	for line in chat:
		if line.begins_with(PLAYER_MARK):
			await _player(line.trim_prefix(PLAYER_MARK), player)
		else:
			await _grandpa(line)

	if not Cutscenes.is_skipping():
		grandpa.twitch(0.6, -4.0)
		Cutscenes.shake(8.0, 0.5)
	await _grandpa(annoyed_line)
	await Cutscenes.wait(0.6)
	await _player(closing_line, player)
	await Cutscenes.wait(0.5)

func _grandpa(line: String) -> void:
	await Cutscenes.subtitle(speaker_name, GRANDPA, line, grandpa.actor)

func _player(line: String, player: CutsceneActor) -> void:
	await Cutscenes.subtitle(PlayerProfile.display_name(), PlayerProfile.character, line, player)
