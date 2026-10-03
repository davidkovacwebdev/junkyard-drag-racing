class_name HangarUfo
extends StaticBody2D
## The flying saucer stashed in the desert `Hangar`: the real `body_ufo` part,
## hovering over the floor behind the hangar's front wall where nobody driving
## past can see it, with its alien pilot sat in the dome. E takes it, once per
## save (see `WorldState.is_claimed()`): the pilot bails out and runs off
## (`AlienEscapeCutscene`) and the player gets the empty saucer.

const CLAIM_ID := "hangar_ufo"
const PART_ID := &"body_ufo"
const DISPLAY_WIDTH := 200.0
const HOVER := 34.0
const BOB_HEIGHT := 8.0
const BOB_SPEED := 1.6
const HUM_HEARING_RANGE := 900.0
const FOOTPRINT := Vector2(140.0, 24.0)
const ESCAPE := preload("res://cutscenes/alien_escape.tres")
const ALIEN := preload("res://characters/alien.tres")
## Where the pilot's head sits, in the saucer part's own space: the bottom of
## the dome, and how big the head is drawn in there.
const PILOT_SEAT := Vector2(0.0, -30.0)
const PILOT_SCALE := 0.4

## Interactable while non-empty (PlayerCar looks for it). Cleared on taking.
var display_name := "Flying Saucer"

var _part: PartData = null
var _art: Node2D = null
var _art_rest := Vector2.ZERO
var _pilot: Node2D = null
var _hum: SustainedSound = null
var _bob_phase := 0.0

func _ready() -> void:
	_part = _find_part()
	if _part == null or WorldState.is_claimed(CLAIM_ID):
		display_name = ""
		queue_free()
		return
	_build_collision()
	_build_art()
	_hum = SustainedSound.new()
	_hum.sound_name = &"ufo_hum_loop"
	_hum.base_volume_db = -10.0
	_hum.fade_in_time = 1.0
	_hum.fade_out_time = 0.6
	_hum.max_distance = HUM_HEARING_RANGE
	_hum.position = Vector2(0.0, -HOVER)
	add_child(_hum)
	_hum.set_active(true)

func get_interact_verb() -> String:
	return "take"

## Where the pilot sits, in world space.
func pilot_seat_global() -> Vector2:
	return _art.to_global(PILOT_SEAT) if _art != null else global_position

## The middle of the hangar's doorway, just outside it.
func door_global() -> Vector2:
	var hangar := get_parent() as Node2D
	return hangar.to_global(Vector2(0.0, 60.0)) if hangar != null else global_position

func eject_pilot() -> void:
	if _pilot != null:
		_pilot.visible = false

func interact(_actor: Node = null) -> void:
	if display_name.is_empty() or Cutscenes.is_active():
		return
	display_name = ""
	WorldState.mark_claimed(CLAIM_ID)
	Inventory.add_part(_part)
	var escape := ESCAPE as AlienEscapeCutscene
	escape.saucer = self
	await Cutscenes.play(escape)
	eject_pilot()
	Sfx.play(&"part_pickup", -6.0)
	Sfx.play(&"ufo_warble", -4.0)
	Pickup.spawn_float_text(get_parent(), global_position + Vector2(0.0, -HOVER - 110.0),
			"Found %s!" % _part.display_name)
	_hum.set_active(false)
	collision_layer = 0
	set_process(false)
	var tween := create_tween()
	tween.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tween.tween_property(_art, "position:y", _art.position.y - 160.0, 0.5)
	tween.parallel().tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_interval(0.6)
	tween.tween_callback(queue_free)

func _find_part() -> PartData:
	for body in PartDatabase.bodies:
		if body.id == PART_ID:
			return body
	return null

func _build_collision() -> void:
	var shape := RectangleShape2D.new()
	shape.size = FOOTPRINT
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = Vector2(0.0, -FOOTPRINT.y / 2.0)
	add_child(collision)

func _build_art() -> void:
	var instance := PartFactory.instantiate(_part)
	if instance == null:
		return
	PartPickup.neutralize(instance)
	_art = Node2D.new()
	_art.name = "Art"
	_art.add_child(instance)
	add_child(_art)
	var bounds := PartScale.measure_bounds(instance)
	var factor := DISPLAY_WIDTH / maxf(bounds.size.x, 0.001)
	_art.scale = Vector2(factor, factor)
	_art_rest = Vector2(-bounds.get_center().x, -bounds.end.y) * factor + Vector2(0.0, -HOVER)
	_art.position = _art_rest
	_build_pilot()

## Just the alien's head and eyes, from his own character parts, shrunk to fit
## under the dome.
func _build_pilot() -> void:
	_pilot = Node2D.new()
	_pilot.name = "Pilot"
	_pilot.scale = Vector2.ONE * PILOT_SCALE
	_pilot.position = PILOT_SEAT - Vector2(0.0, -180.0) * PILOT_SCALE
	for scene in [ALIEN.head_scene, ALIEN.eyes_scene]:
		_pilot.add_child((scene as PackedScene).instantiate())
	_art.add_child(_pilot)

func _process(delta: float) -> void:
	if _art == null:
		return
	_bob_phase += delta * BOB_SPEED
	_art.position = _art_rest + Vector2(0.0, -sin(_bob_phase) * BOB_HEIGHT)
	queue_redraw()

func _draw() -> void:
	var lift := 1.0 - 0.12 * (0.5 + 0.5 * sin(_bob_phase))
	draw_colored_polygon(FlatProps.octagon(Vector2.ZERO, DISPLAY_WIDTH * 0.42 * lift, 14.0 * lift),
			UiPalette.SHADOW)
