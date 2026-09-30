class_name SaveData
extends Resource
## Everything SaveSystem persists for "Continue" — owned cars, currency,
## where the player was standing, and which roadside props were already
## looted. Plain Resource on purpose: ResourceSaver walks the whole
## nested graph (CarModelData -> BodyPartData -> its default_engine,
## etc.) on its own, so there's no manual (de)serialization to write or
## maintain as the car/part model grows.

@export var owned_cars: Array[CarModelData] = []
@export var selected_index: int = 0
@export var garage_capacity: int = 2
@export var scrap: int = 0
@export var money: int = 0
## Parts the junkyard crane has fished out of the heap for the player.
@export var spare_parts: Array[PartData] = []
@export var player_position: Vector2 = Vector2.ZERO
@export var has_player_position: bool = false
## Restock state of the city's trash — which props are empty and which have come
## back. See WorldState.get_looted_snapshot(); older saves store a plain set of
## looted ids here and are upgraded on load.
@export var looted: Dictionary = {}
@export var races_won: int = 0
@export var day: int = 1
@export var time_of_day: float = 0.0
## One-time cutscenes already played (see Cutscenes.play_once()).
@export var seen_cutscenes: Array[StringName] = []
## The name the player typed on the character creation screen.
@export var player_name: String = ""
## The player's own look from character creation. Null on older saves.
@export var player_character: CharacterData = null
## The quest log (see Quests): quests in progress, finished ones, and the one
## on the tracker.
@export var quests_active: Array[QuestData] = []
@export var quests_completed: Array[QuestData] = []
@export var tracked_quest: QuestData = null
## Ids of quests whose goal is met, waiting to be handed back to the giver.
@export var quests_ready: Array[StringName] = []
## Quests unlocked but not taken yet (their giver's head is on the map).
@export var quests_available: Array[QuestData] = []
## Tools and gadgets bought at the shop (see ItemData).
@export var owned_items: Array[ItemData] = []
