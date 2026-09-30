class_name Cutscene
extends Resource
## One cinematic: a little movie the player watches, GTA style — no input
## except Esc to skip. Subclass it, override `play()` and write the scene as a
## plain top-to-bottom script of awaited Cutscenes steps:
##
##   extends Cutscene
##   func play() -> void:
##       var smith := Cutscenes.spawn_actor(SMITH, spot)
##       Cutscenes.cut_to(spot, 1.5)
##       await Cutscenes.fade_in()
##       await Cutscenes.walk(smith, spot + Vector2(200, 0))
##       await Cutscenes.subtitle("Smith", SMITH, "Nice car.", smith)
##
## Start one with `Cutscenes.play(MyCutscene.new())`, or `play_once()` for a
## scene that should only ever happen once per save (keyed by `id`).
##
## It's a Resource so a cutscene's words can live in a .tres under
## res://cutscenes and be edited in the inspector: give the subclass
## `@export` vars for its lines and preload the .tres instead of calling new().
##
## Esc skips: every step returns straight away from then on, so `play()` just
## runs to its end and any state it sets still gets set. Code that must not
## happen on a skip can check `Cutscenes.is_skipping()`.

## Save key for `Cutscenes.play_once()`. Only needed for one-time scenes.
var id: StringName = &""

## A quest this scene hands the player. It lands in the journal (J) as the
## scene ends, skipped or not.
@export var gives_quest: QuestData

func play() -> void:
	pass
