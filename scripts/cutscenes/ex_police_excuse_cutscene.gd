class_name ExPoliceExcuseCutscene
extends HospitalCopsCutscene
## "Visiting Hours": Grandpa had the player lean on the horn outside the
## hospital, and the police come wailing up. "What the hell are you two
## doin'?" Grandpa, from the car, blames the car: it started honking all by
## itself, they're leaving right away. The officers look at each other, and
## let them go: no fine. Played by HospitalQuietZone in place of the usual
## fine while the quest's on (ExStory), which then finishes it.
##
## The words live in res://cutscenes/ex_police_excuse.tres; edit them in the
## inspector.

const ID := &"ex_police_excuse"

@export var what_line: String = "What the hell are you two doin'?"
@export var excuse_line: String = "Sorry, officer. This vehicle's no good, it started honking for no reason. We're moving right away."
@export var look_line: String = "..."
@export var okay_line: String = "...Okay? Move it along, then."

func _init() -> void:
	id = ID

func play() -> void:
	if not await arrive(3, false):
		return
	await Cutscenes.subtitle(DALE.display_name, DALE, what_line, dale)
	await grandpa_says(excuse_line)
	# The officers look at each other.
	Cutscenes.face(dale, false)
	Cutscenes.face(rita, true)
	await Cutscenes.wait(0.5)
	await Cutscenes.subtitle(RITA.display_name, RITA, look_line, rita)
	Cutscenes.face(dale, true)
	await Cutscenes.subtitle(DALE.display_name, DALE, okay_line, dale)
	await leave()
