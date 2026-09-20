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
@export var player_position: Vector2 = Vector2.ZERO
@export var has_player_position: bool = false
## Ids of looted trash props — see WorldState.get_looted_snapshot().
@export var looted: Dictionary = {}
