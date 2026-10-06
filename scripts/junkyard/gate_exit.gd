class_name GateExit
extends Area2D
## The way out through a gap in a fence: drive the player's car into it and
## you're back on the open world, at the spot you came in from (PlayerCar and
## WorldState handle that, same as the Back button).

@export_file("*.tscn") var target_scene: String = "res://scenes/world/main.tscn"

var _leaving: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if _leaving or not body.is_in_group(PlayerCar.GROUP):
		return
	_leaving = true
	Sfx.play(&"gate_rattle", -4.0, 0.05)
	SaveSystem.save_game()
	SceneLoader.change_scene.call_deferred(target_scene)
