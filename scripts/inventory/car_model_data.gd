class_name CarModelData
extends Resource
## One garage-inventory entry, built from real parts — the same
## BodyPartData/EnginePartData/WheelPartData classes the drag-race rig
## uses — instead of a one-off car struct. A body (which may bring its
## own default engine along), plus one WheelPartData per wheel mount.
## A Resource on purpose: this slots straight into ResourceSaver/JSON
## later for save games without restructuring.

@export var body: BodyPartData
@export var engine: EnginePartData
@export var wheels: Array[WheelPartData] = []
## Bolt-ons, at most one per AccessoryPartData.Spot.
@export var accessories: Array[AccessoryPartData] = []

## The body IS the car's identity/paint job for now — no separate
## "car name" or "car color" to keep in sync with whatever body is
## equipped.
var display_name: String:
	get: return body.display_name if body != null else "Unnamed Car"

var body_color: Color:
	get: return body.color if body != null else Color.WHITE

func accessory_in(spot: AccessoryPartData.Spot) -> AccessoryPartData:
	for accessory in accessories:
		if accessory != null and accessory.spot == spot:
			return accessory
	return null

## Puts `accessory` in its spot, replacing whatever was there.
func set_accessory(accessory: AccessoryPartData) -> void:
	remove_accessory(accessory.spot)
	accessories.append(accessory)

func remove_accessory(spot: AccessoryPartData.Spot) -> void:
	for i in range(accessories.size() - 1, -1, -1):
		if accessories[i] == null or accessories[i].spot == spot:
			accessories.remove_at(i)

func durability_multiplier() -> float:
	var multiplier := 1.0
	for accessory in accessories:
		if accessory != null:
			multiplier *= accessory.durability_multiplier
	return multiplier

func speed_multiplier() -> float:
	var multiplier := 1.0
	for accessory in accessories:
		if accessory != null:
			multiplier *= accessory.speed_multiplier
	return multiplier

func accessory_mass() -> float:
	var total := 0.0
	for accessory in accessories:
		if accessory != null:
			total += accessory.mass
	return total

## The first non-empty override any fitted accessory sets for `property`
## (horn_sound, body_impact_sound), or `fallback`.
func accessory_sound(property: StringName, fallback: StringName) -> StringName:
	for accessory in accessories:
		if accessory != null and accessory.get(property) != &"":
			return accessory.get(property)
	return fallback
