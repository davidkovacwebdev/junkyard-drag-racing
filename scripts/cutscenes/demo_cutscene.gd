class_name DemoCutscene
extends Cutscene
## A dumb little movie that uses every Cutscenes step. Dev menu: F2.

const PUNKER := preload("res://characters/punker.tres")
const SMITH := preload("res://characters/smith.tres")

func play() -> void:
	var car := Cutscenes.get_tree().get_first_node_in_group(PlayerCar.GROUP) as Node2D
	if car == null:
		return
	var spot := car.global_position + Vector2(0.0, 160.0)

	await Cutscenes.fade_out(0.3)
	await Cutscenes.title_card("MEANWHILE, NEAR YOUR CAR...", 1.6)
	var smith := Cutscenes.spawn_actor(SMITH, spot + Vector2(-140.0, 0.0), true)
	var punker := Cutscenes.spawn_actor(PUNKER, spot + Vector2(700.0, 0.0), false)
	Cutscenes.cut_to(spot + Vector2(80.0, -90.0), 1.5)
	await Cutscenes.fade_in(0.8)

	await Cutscenes.walk(punker, spot + Vector2(120.0, 0.0), 220.0)
	await Cutscenes.subtitle("Scrap Dealer", PUNKER, "Oi, Smithy! You seen my lucky hubcap?", punker)
	await Cutscenes.subtitle("Smith", SMITH, "The shiny one? Nope. Never seen it. Not wearing it.", smith)

	await Cutscenes.camera_to(smith.global_position + Vector2(0.0, -110.0), 2.4, 0.9)
	await Cutscenes.wait(0.4)
	Cutscenes.sound(&"pogo_boing", -6.0)
	await Cutscenes.hop(smith, 30.0)
	await Cutscenes.subtitle("Smith", SMITH, "...It's a hat now.", smith)

	await Cutscenes.camera_to(spot + Vector2(80.0, -90.0), 1.5, 0.5)
	Cutscenes.shake(10.0, 0.3)
	Cutscenes.sound(&"pogo_boing", -4.0)
	await Cutscenes.hop(punker, 60.0)
	await Cutscenes.subtitle("Scrap Dealer", PUNKER, "THAT'S IT!", punker)

	Cutscenes.camera_follow(punker)
	Cutscenes.walk(smith, spot + Vector2(-900.0, 0.0), 300.0)
	await Cutscenes.walk(punker, spot + Vector2(-300.0, 0.0), 320.0)
	Cutscenes.sound(&"crane_shove", 0.0)
	Cutscenes.shake(16.0, 0.35)
	await Cutscenes.fall_over(punker)
	await Cutscenes.wait(0.8)
	await Cutscenes.subtitle("Scrap Dealer", PUNKER, "...I'm fine.", punker)

	await Cutscenes.camera_to(car, 1.1, 1.2)
	Cutscenes.sound(&"truck_honk", -4.0)
	await Cutscenes.wait(0.8)
	await Cutscenes.fade_out(0.6)
