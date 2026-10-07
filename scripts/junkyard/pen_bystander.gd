class_name PenBystander
extends RigidBody2D
## Somebody standing out back next to the crane to watch the player dig.
##
## Vern, Grandpa's old crane buddy who runs the thing, is fair game: what the
## claw hauls up is him, as an engine part that pulls the car along on a rope
## (PunkerEngine, engine_crane_operator.tscn). From the next visit on a crane
## worker is on shift in his spot, made up by CraneWorkerGenerator, and each
## one the claw takes is replaced by a new one. Old Mo turns up too, off past
## the drum, and never lets the claw near him: he scoots out from under it
## every time and has something to say about it.
##
## A catchable bystander joins the heap as one of its items
## (`TrashHeap.add_item()`), so the crane's whole grab path (pinch, haul,
## bank) works on them unchanged; the pen only has to notice it was one
## (`is PenBystander`) and call `claim()`. Once claimed they never come back to
## the pen on that save (WorldState's claimed set, the same one the hangar's
## flying saucer uses). The man at the yard's counter stays where he is, so
## there's still someone to sell scrap to. A generated worker's claim is his
## place in line, so the next visit's worker is the next one along.
##
## A real body standing upright (rotation locked), heavy and flat-footed so a
## glancing shell barely shifts them, and they yelp when it does. An oil drum
## stands behind them (see the pen scene), so they can't be shoved off past the
## end of the claw's rail.
##
## A person isn't a lump of junk, and the shells are made to scoop junk: a
## narrow head slips out from between them more often than not. So they have a
## handle (`grab_point()`, the top of the head): jaws shutting anywhere near it
## count as having hold of them (see `CraneRig._pinched()`).

## Same size the yard draws people at.
const CHARACTER_SCALE := 0.55
const YELP_GAP := 1.2
## The top of the head, in character pixels above the feet: the first thing
## the jaws come down on.
const HEAD_HEIGHT := 235.0
## The speech line over their head: size (the pen's camera is zoomed out, so
## it's drawn big), width, and how long it stays up once typed out.
const SPEECH_FONT_SIZE := 46
const SPEECH_WIDTH := 720.0
const SPEECH_HOLD := 1.8

@export var character_data: CharacterData
## Their WorldState claim: set when they're caught, and from then on they're
## gone. Also what `after_claim` on someone else waits for.
@export var claim_id: String = ""
## Only standing here once this claim has been made on an earlier visit (Old
## Mo and the crane workers wait for Vern to have been fished out). Empty: here from
## the start.
@export var after_claim: String = ""
## Whether the claw can take them at all. Off (Old Mo), they're never part of
## the heap: the claw can bump them, but nothing it does counts as a catch.
@export var catchable: bool = true
## The engine part the claw hauls up, if catchable.
@export_file("*.tscn") var engine_scene: String = ""
## Made up on the spot (CraneWorkerGenerator) rather than set here: the next
## crane worker in line, with his own claim, look, engine and caught line.
@export var generated_worker: bool = false
## One of these, said over their head, when a shell shoves them.
@export var bump_lines: PackedStringArray = []
## How far forward they're bent standing still, radians.
@export var stoop: float = 0.0
## What they say when a shell shoves them, and when the claw hauls them off.
@export var yelp_sound: StringName = &"punker_yelp"
## The pen's line once they've been caught.
@export_multiline var caught_line: String = ""
## The heap they join, so the claw counts them.
@export var heap_path: NodePath = ^"../Heap"

@export_group("Dodging")
@export var dodges: bool = false
@export var crane_path: NodePath = ^"../Crane"
## How far one dodge scoots them, and how fast.
@export var dodge_distance: float = 80.0
@export var dodge_speed: float = 420.0
## They move once the jaws are this close above their head, and within this
## much of it sideways.
@export var alert_height: float = 260.0
@export var alert_width: float = 60.0
## The strip they can dodge about in (parent's x): clear of the crane's tracks
## on one side and the drum on the other.
@export var min_x: float = 575.0
@export var max_x: float = 660.0
@export var dodge_sound: StringName = &"oldmo_cackle"
## One of these, said out loud, every time they dodge (unless they're still
## halfway through the last one).
@export var dodge_lines: PackedStringArray = []

## What the claw hauls up: the TrashHeap reads `part_data` off its items.
var part_data: EnginePartData
var _rig: CharacterRig
var _crane: CraneRig
var _yelp_cooldown: float = 0.0
var _dodge_target: float = NAN
var _time: float = 0.0
var _speech_label: Label
var _speech: SpeechPlayer
var _speech_tween: Tween
var _last_line: int = -1

func _ready() -> void:
	var worker_index := -1
	if generated_worker:
		worker_index = CraneWorkerGenerator.next_index()
		claim_id = CraneWorkerGenerator.claim_id(worker_index)
		character_data = CraneWorkerGenerator.worker(worker_index)
		caught_line = CraneWorkerGenerator.caught_line(character_data)
		bump_lines = PackedStringArray(CraneWorkerGenerator.BUMP_LINES)
	# Already caught, or not their turn yet: someone else has the spot this
	# visit. The pen is rebuilt on every visit, so a claim made today shows up
	# the next time round.
	if claim_id.is_empty() or WorldState.is_claimed(claim_id) \
			or (not after_claim.is_empty() and not WorldState.is_claimed(after_claim)):
		queue_free()
		return
	_rig = CharacterRig.new()
	_rig.character_data = character_data
	_rig.scale = Vector2.ONE * CHARACTER_SCALE
	_rig.rotation = stoop
	add_child(_rig)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(60.0, 250.0) * CHARACTER_SCALE
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -125.0 * CHARACTER_SCALE)
	add_child(collision)
	mass = 120.0
	lock_rotation = true
	linear_damp = 3.0
	var footing := PhysicsMaterial.new()
	footing.friction = 1.0
	footing.bounce = 0.0
	physics_material_override = footing
	can_sleep = true
	contact_monitor = true
	max_contacts_reported = 4
	body_entered.connect(_on_bumped)
	_crane = get_node_or_null(crane_path) as CraneRig
	if catchable:
		part_data = CraneWorkerGenerator.engine_part(worker_index, character_data) \
				if generated_worker else _engine_data()
		var heap := get_node_or_null(heap_path) as TrashHeap
		if heap != null:
			heap.add_item(self)
	if not dodge_lines.is_empty() or not bump_lines.is_empty():
		_build_speech()

func _physics_process(delta: float) -> void:
	_time += delta
	_yelp_cooldown = maxf(_yelp_cooldown - delta, 0.0)
	if _rig != null:
		# A quick shuffle while they're scooting.
		_rig.position.y = -absf(sin(_time * 14.0)) * 4.0 if absf(linear_velocity.x) > 20.0 else 0.0
	if dodges and not freeze:
		_dodge()

## Watch the claw, and scoot out from under it whenever it comes down on them.
func _dodge() -> void:
	if not is_nan(_dodge_target):
		var dx := _dodge_target - position.x
		if absf(dx) < 3.0:
			linear_velocity.x = 0.0
			_dodge_target = NAN
		else:
			linear_velocity.x = signf(dx) * dodge_speed
		return
	if _crane == null or not _crane.is_awaiting_close():
		return
	var mouth: Vector2 = (get_parent() as Node2D).to_local(_crane.jaw_mouth_global())
	var head := position + Vector2(0.0, -HEAD_HEIGHT * CHARACTER_SCALE)
	if head.y - mouth.y > alert_height or absf(mouth.x - head.x) > alert_width:
		return
	var away := signf(position.x - mouth.x)
	if away == 0.0:
		away = 1.0
	var target := position.x + away * dodge_distance
	if target < min_x or target > max_x:
		target = position.x - away * dodge_distance
	_dodge_target = clampf(target, min_x, max_x)
	Sfx.play_at(dodge_sound, global_position, -4.0)
	_say_something(dodge_lines)

## A line over their head, typed out in their own voice, then gone.
func _say_something(lines: PackedStringArray) -> void:
	if _speech == null or _speech.is_typing() or lines.is_empty():
		return
	var pick := randi() % lines.size()
	if lines.size() > 1 and pick == _last_line:
		pick = (pick + 1) % lines.size()
	_last_line = pick
	if _speech_tween != null:
		_speech_tween.kill()
	_speech_label.modulate.a = 1.0
	_speech.speak(_speech_label, PlayerProfile.fill(lines[pick]), character_data)

func _build_speech() -> void:
	_speech_label = Label.new()
	_speech_label.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	_speech_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_speech_label.add_theme_constant_override("outline_size", 7)
	_speech_label.add_theme_font_size_override("font_size", SPEECH_FONT_SIZE)
	_speech_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_speech_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_speech_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_speech_label.size = Vector2(SPEECH_WIDTH, 130.0)
	_speech_label.position = Vector2(-SPEECH_WIDTH * 0.5, -HEAD_HEIGHT * CHARACTER_SCALE - 150.0)
	_speech_label.z_index = 20
	_speech_label.modulate.a = 0.0
	add_child(_speech_label)
	_speech = SpeechPlayer.new()
	add_child(_speech)
	_speech.typing_finished.connect(_on_line_said)

func _on_line_said() -> void:
	_speech_tween = create_tween()
	_speech_tween.tween_interval(SPEECH_HOLD)
	_speech_tween.tween_property(_speech_label, "modulate:a", 0.0, 0.4)

## The handle the claw grabs them by: the top of the head.
func grab_point() -> Vector2:
	return to_global(Vector2(0.0, -HEAD_HEIGHT * CHARACTER_SCALE))

## The claw got them: off the pen for good.
func claim() -> void:
	WorldState.mark_claimed(claim_id)

## Anything other than the floor or a piece of junk shoving them (the claw's
## shells) gets a yelp.
func _on_bumped(body: Node) -> void:
	if _yelp_cooldown > 0.0 or freeze or not (body is RigidBody2D) or body.is_in_group(TrashHeap.ITEM_GROUP):
		return
	_yelp_cooldown = YELP_GAP
	Sfx.play_at(yelp_sound, global_position + Vector2(0.0, -120.0), -4.0)
	_say_something(bump_lines)

## The catalog's copy, so the part they turn into is the same one the garage
## browses; loaded fresh if the catalog doesn't have it.
func _engine_data() -> EnginePartData:
	for engine in PartDatabase.engines:
		if engine.scene_path == engine_scene:
			return engine
	return PartDatabase.load_part_data(engine_scene) as EnginePartData
