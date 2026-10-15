extends Node2D
## Single-car ramp jump: the player's garage car spawns on the flat start,
## rolls down the hill, launches off the kicker and either clears the spike
## pit or drops into it. The car is the same CarAssembler rig with the same
## physics as the drag strip: nothing here pushes, weighs or steers it.
##
## The sibling RaceController is only used for Escape-to-exit: its
## finish_x/max_duration are set far past anything this track reaches. The run
## ends here instead, once the car has sat still for a moment (or wrecked):
## its distance past the kicker's lip is read out, and a new personal best
## leaves a RampBestMarker where the car stopped.

@export var race_controller_path: NodePath
@export var camera_path: NodePath
@export var spike_sensor_path: NodePath

## On the flat start; CarAssembler stands the car on this y by its lowest point.
const SPAWN_POSITION := Vector2(-200.0, 0.0)
## How long the wreck sits in the spikes before heading back to the map.
const SPIKED_EXIT_DELAY := 3.0
## The kicker's lip, where the jump's distance is measured from.
const LIP_X := 3830.0
const PIXELS_PER_METER := 100.0
## Slower than this (px/s) for STOPPED_TIME seconds and the run is over.
const STOPPED_SPEED := 25.0
const STOPPED_TIME := 2.0
## How long the result sits on screen before heading back to the map.
const RESULT_EXIT_DELAY := 4.0
const RESULT_PANEL_SIZE := Vector2(420.0, 110.0)
const CLEAR_BUTTON_SIZE := Vector2(170.0, 40.0)

var _player_car: CarAssembler.AssembledCar
var _race_controller: RaceController
var _spiked := false
var _run_over := false
var _stopped_time := 0.0
var _last_body_x := SPAWN_POSITION.x
var _best_marker: RampBestMarker
var _ui: CanvasLayer
var _clear_button: ScrapButton

func _ready() -> void:
	_race_controller = get_node(race_controller_path) as RaceController
	var camera := get_node(camera_path) as CameraFollow
	(get_node(spike_sensor_path) as Area2D).body_entered.connect(_on_spike_sensor_body_entered)

	var cars_container := Node2D.new()
	cars_container.name = "Cars"
	add_child(cars_container)

	var car_data := DebugRace.field(1, RaceProgression.Course.DRAG)[0] if DebugRace.consume() else Inventory.get_selected_car()
	_player_car = CarAssembler.assemble_from_car_data(car_data, cars_container, SPAWN_POSITION)
	_build_ui()
	_refresh_best_marker()
	if _player_car == null:
		return
	_player_car.root.name = "Player_%s" % car_data.display_name
	# Grandpa's "Downhill Billie" (and its rerun) only ask the player to give
	# it a go.
	for quest_id in RampEvent.RUN_QUESTS:
		Quests.goal_met(quest_id)
	_race_controller.register_car(_player_car.root.name, _player_car)
	if camera != null:
		camera.targets = [_player_car.body]
	CarAutosteer.switch_off(_player_car.body)

## CarAssembler bolts a CarAutosteer onto every body so drag racers drift
## between lanes. This track has one lane, so it's switched off, the same way
## single_lane_race_setup.gd does it.
func _on_spike_sensor_body_entered(body: Node2D) -> void:
	if _spiked or _player_car == null:
		return
	if body != _player_car.body and not (body is CarWheel and _player_car.wheels.has(body)):
		return
	_spiked = true
	_run_over = true
	_hit_spikes.call_deferred()

## Pops every wheel on the spikes and sends the player back to the map.
func _hit_spikes() -> void:
	if is_instance_valid(_player_car.body):
		RaceCarAudio.play(_player_car.root, &"spike_pop", _player_car.body.global_position, -2.0)
	for wheel in _player_car.wheels.duplicate():
		if not is_instance_valid(wheel):
			continue
		var damage := CarPartDamage.of(wheel)
		if damage != null:
			damage.apply_damage(INF)
	get_tree().create_timer(SPIKED_EXIT_DELAY).timeout.connect(_race_controller.exit_race)

func _physics_process(delta: float) -> void:
	if _run_over or _player_car == null:
		return
	if not is_instance_valid(_player_car.body):
		_finish_run(_last_body_x)
		return
	_last_body_x = _player_car.body.global_position.x
	if _player_car.body.linear_velocity.length() < STOPPED_SPEED:
		_stopped_time += delta
	else:
		_stopped_time = 0.0
	if _stopped_time >= STOPPED_TIME:
		_finish_run(_last_body_x)

func _finish_run(body_x: float) -> void:
	_run_over = true
	var distance := maxf((body_x - LIP_X) / PIXELS_PER_METER, 0.0)
	var previous_best := RaceProgression.ramp_best_distance
	var is_new_best := distance > previous_best and is_instance_valid(_player_car.body)
	print(">>> RAMP RUN OVER: %.1f m%s" % [distance, " (new best)" if is_new_best else ""])
	if is_new_best:
		RaceProgression.set_ramp_best(distance, _capture_silhouette())
		SaveSystem.save_game()
		_refresh_best_marker()
		Sfx.play(&"results_fanfare", -2.0, 0.0)
		_show_result("NEW BEST!", RampBestMarker.format_distance(distance))
	else:
		Sfx.play(&"race_stalled", -6.0, 0.0)
		var best_line := "Best %s" % RampBestMarker.format_distance(previous_best) if previous_best > 0.0 else ""
		_show_result(RampBestMarker.format_distance(distance), best_line)
	get_tree().create_timer(RESULT_EXIT_DELAY).timeout.connect(_race_controller.exit_race)

## Every drawn polygon of the car as it sits now, relative to its body.
func _capture_silhouette() -> Array[PackedVector2Array]:
	var origin := _player_car.body.global_position
	var outlines: Array[PackedVector2Array] = []
	for part in [_player_car.body] + _player_car.wheels:
		if not is_instance_valid(part):
			continue
		for polygon_node in PartDent._drawn_polygons(part):
			var points := PackedVector2Array()
			for point in polygon_node.polygon:
				points.append(polygon_node.global_transform * (point + polygon_node.offset) - origin)
			if polygon_node.polygons.is_empty():
				outlines.append(points)
				continue
			for indices in polygon_node.polygons:
				var piece := PackedVector2Array()
				for index in indices:
					piece.append(points[index])
				outlines.append(piece)
	return outlines

func _refresh_best_marker() -> void:
	if is_instance_valid(_best_marker):
		_best_marker.queue_free()
	var has_best := RaceProgression.ramp_best_distance > 0.0
	_clear_button.visible = has_best
	if not has_best:
		return
	_best_marker = RampBestMarker.create(RaceProgression.ramp_best_distance, RaceProgression.ramp_best_silhouette)
	_best_marker.position = Vector2(LIP_X + RaceProgression.ramp_best_distance * PIXELS_PER_METER, 0.0)
	_best_marker.z_index = -1
	add_child(_best_marker)

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	add_child(_ui)
	_clear_button = ScrapButton.new()
	_clear_button.text = "Clear Best"
	_clear_button.font_size = 20
	_clear_button.tilt_degrees = 2.0
	_clear_button.jitter_seed = 31
	_clear_button.focus_mode = Control.FOCUS_NONE
	_clear_button.anchor_top = 1.0
	_clear_button.anchor_bottom = 1.0
	_clear_button.offset_left = 24.0
	_clear_button.offset_right = 24.0 + CLEAR_BUTTON_SIZE.x
	_clear_button.offset_top = -24.0 - CLEAR_BUTTON_SIZE.y
	_clear_button.offset_bottom = -24.0
	_clear_button.pressed.connect(_on_clear_pressed)
	_ui.add_child(_clear_button)

func _on_clear_pressed() -> void:
	var confirmed := await ConfirmPrompt.ask(get_tree(), "Clear Best?",
			"Your best jump of %s is gone for good." % RampBestMarker.format_distance(RaceProgression.ramp_best_distance),
			"Clear")
	if not confirmed:
		return
	RaceProgression.clear_ramp_best()
	SaveSystem.save_game()
	Sfx.play(&"profile_scrapped", -4.0)
	_refresh_best_marker()

func _show_result(headline: String, detail: String) -> void:
	var panel := ScrapPanel.new()
	panel.nails = false
	panel.tilt_degrees = -2.0
	panel.jitter_seed = 17
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.offset_left = -RESULT_PANEL_SIZE.x / 2.0
	panel.offset_right = RESULT_PANEL_SIZE.x / 2.0
	panel.offset_top = 40.0
	panel.offset_bottom = 40.0 + RESULT_PANEL_SIZE.y
	var label := Label.new()
	label.text = headline if detail.is_empty() else "%s\n%s" % [headline, detail]
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 34)
	label.add_theme_color_override("font_color", UiPalette.TEXT_LIGHT)
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.add_child(label)
	_ui.add_child(panel)
