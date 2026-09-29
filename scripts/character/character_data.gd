@tool
class_name CharacterData
extends Resource
## A saved character loadout: one optional part scene per slot. This is
## the thing the Character Creator dock writes to res://characters/*.tres,
## and it's what CharacterAssembler / CharacterRig read back at runtime.
##
## @tool is required, not cosmetic: the editor dock creates and loads these
## resources while the editor is running, and a non-tool script comes back
## as a *placeholder* instance in that context — one you can read exported
## properties from but can NOT call methods on. Without this, get_part()/
## set_part() fail with "Attempt to call a method on a placeholder
## instance" and loading a character silently produces nothing.
##
## Storing PackedScene references (rather than ids that need a lookup) is
## deliberate: the resource is self-contained, so loading a character is
## just ResourceLoader.load(), with no database to keep in sync.

@export var display_name: String = "New Character"

@export var legs_scene: PackedScene
@export var boots_scene: PackedScene
@export var torso_scene: PackedScene
@export var head_scene: PackedScene
@export var hair_scene: PackedScene
@export var eyes_scene: PackedScene
@export var accessory_scene: PackedScene

@export_group("Voice")
## How they sound in a CharacterDialog (see CharacterVoice). 0 leaves the
## voice untuned: one gets derived from `display_name` instead.
@export_range(0.0, 400.0) var voice_pitch_hz: float = 0.0
## Formant scale: below 1 is a big, deep chest, above 1 a tiny squeaky head.
@export_range(0.6, 1.6) var voice_throat: float = 1.0
@export_range(0.0, 1.0) var voice_rasp: float = 0.0
## Pitch wobble, from steady to a nervous quaver.
@export_range(0.0, 1.0) var voice_wobble: float = 0.0

func get_part(slot: CharacterPartData.Slot) -> PackedScene:
	match slot:
		CharacterPartData.Slot.LEGS:
			return legs_scene
		CharacterPartData.Slot.BOOTS:
			return boots_scene
		CharacterPartData.Slot.TORSO:
			return torso_scene
		CharacterPartData.Slot.HEAD:
			return head_scene
		CharacterPartData.Slot.HAIR:
			return hair_scene
		CharacterPartData.Slot.EYES:
			return eyes_scene
		CharacterPartData.Slot.ACCESSORY:
			return accessory_scene
	return null

func set_part(slot: CharacterPartData.Slot, scene: PackedScene) -> void:
	match slot:
		CharacterPartData.Slot.LEGS:
			legs_scene = scene
		CharacterPartData.Slot.BOOTS:
			boots_scene = scene
		CharacterPartData.Slot.TORSO:
			torso_scene = scene
		CharacterPartData.Slot.HEAD:
			head_scene = scene
		CharacterPartData.Slot.HAIR:
			hair_scene = scene
		CharacterPartData.Slot.EYES:
			eyes_scene = scene
		CharacterPartData.Slot.ACCESSORY:
			accessory_scene = scene
