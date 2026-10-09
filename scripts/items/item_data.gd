@tool
class_name ItemData
extends Resource
## A tool or gadget the player can own (the shop's stock). Not a car part:
## items live in `Inventory.owned_items` and are just "have it or not".
##
## Each lives in its own .tres under res://items, so name, price and blurb
## are edited in the inspector. @tool so the editor treats it as a real
## resource rather than a placeholder (see CharacterData).

## What saves and code refer to it by. Never change it once an item shipped.
@export var id: StringName = &""
@export var display_name: String = ""
@export var price: int = 0
## What the shopkeeper says about it when the player asks.
@export_multiline var description: String = ""
## A few flat polygons, authored around (0, 0) in a roughly 64 px box.
@export var icon_scene: PackedScene
## Played as it's bought, on top of the till (the Super Horn going off in
## the shop). Empty: just the till.
@export var buy_sound: StringName = &""
@export var buy_sound_volume_db: float = -4.0

@export_group("Using it")
## How many times it can be used from the trunk (1-6 or a double-click)
## before it's gone; the trunk shows what's left. 0: not usable, it just sits
## there being owned.
@export var uses: int = 0
## What using it does, for whoever listens to `Inventory.item_used`
## (&"beer": Drunk). Empty: nothing beyond the sound.
@export var use_effect: StringName = &""
@export var use_sound: StringName = &""
## Shown in the trunk when it's used. `{left}` becomes the uses left.
@export var use_line: String = ""
## Never runs out: usable any number of times, `uses` is ignored (a tool, like
## the fishing rod, rather than something you consume).
@export var reusable: bool = false
## Using it is something done out in the world (casting the rod), so the trunk
## shuts to get out of the way.
@export var closes_trunk: bool = false

@export_group("Reading it")
## Something to read (a letter): using it from the trunk opens it up on a
## sheet of paper with this text. Empty: not readable.
@export_multiline var read_text: String = ""
## Handed to the player the first time it's read (the clue in Grandpa's
## note). Nothing if they already have it or finished it.
@export var read_gives_quest: QuestData
