class_name HiddenPartPickup
extends PartPickup
## A one-of-a-kind part orb placed somewhere on the map for the player to
## find. It never fades, and once taken it is gone for good on this save (see
## `WorldState.is_claimed()`). The part itself should have `found_in_junk` off
## so this is the only place it ever turns up.

## How far below its ground point a submerged orb sits, so it reads as lying
## on the sea bed rather than floating over the waves.
const SUBMERGED_DEPTH := 6.0
const SUBMERGED_TINT := Color(0.5, 0.75, 0.85, 0.4)
const BUBBLE_COUNT := 2
const BUBBLE_RISE := 46.0
const BUBBLE_RADIUS := 5.0

@export var part_id: StringName = &""
@export var claim_id: String = ""
## Played on top of the usual pickup sound when it's found.
@export var found_sound: StringName = &""
## Out at sea: drawn faint and sea-tinted under everything on the surface, with
## no shadow, and only a couple of rising bubbles giving it away.
@export var submerged := false

func _ready() -> void:
	var hidden_part := _find_part()
	if hidden_part == null or WorldState.is_claimed(claim_id):
		queue_free()
		return
	part = hidden_part
	persistent = true
	if submerged:
		_rest_offset = Vector2(0.0, -SUBMERGED_DEPTH)
		_orb_offset = _rest_offset
		modulate = SUBMERGED_TINT
		z_index = -1
	super()

func grant() -> void:
	WorldState.mark_claimed(claim_id)
	super()
	if found_sound != &"":
		Sfx.play(found_sound, -4.0)

func _draw() -> void:
	if not submerged:
		super()
		return
	draw_circle(_orb_offset, ORB_RADIUS, orb_color)
	_draw_icon(_orb_offset, ORB_RADIUS)
	for i in BUBBLE_COUNT:
		var rise := fposmod(_bob_phase * 0.3 + float(i) / BUBBLE_COUNT, 1.0)
		var bubble := _orb_offset + Vector2(10.0 - 18.0 * i, -ORB_RADIUS - rise * BUBBLE_RISE)
		draw_colored_polygon(FlatProps.octagon(bubble, BUBBLE_RADIUS, BUBBLE_RADIUS),
				Color(1.0, 1.0, 1.0, 1.0 - rise))

func _find_part() -> PartData:
	for list: Array in [PartDatabase.bodies, PartDatabase.wheels, PartDatabase.engines, PartDatabase.accessories]:
		for candidate: PartData in list:
			if candidate.id == part_id:
				return candidate
	return null
