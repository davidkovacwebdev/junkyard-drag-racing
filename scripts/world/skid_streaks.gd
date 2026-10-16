class_name SkidStreaks
extends RefCounted
## Grows one continuous Line2D per wheel while skidding. A single line has
## no overlapping caps, so the translucent mark reads as one smooth streak
## instead of dark-jointed segments. A long skid is handed off to a fresh
## line every max_points so its tail starts fading instead of lingering whole.

var color: Color = Color(0.05, 0.05, 0.05, 0.55)
var width: float = 6.0
var min_gap: float = 8.0
var max_points: int = 40
var hold_time: float = 2.0
var fade_time: float = 3.0

## Live streak per wheel index; null means that wheel isn't mid-skid, so the
## next skid starts fresh instead of drawing a connector back to the last one.
var _streaks: Array = []

func configure(mark_color: Color, mark_width: float, mark_min_gap: float, mark_max_points: int, mark_hold_time: float, mark_fade_time: float) -> void:
	color = mark_color
	width = mark_width
	min_gap = mark_min_gap
	max_points = mark_max_points
	hold_time = mark_hold_time
	fade_time = mark_fade_time

func update(layer: Node2D, wheel_world_positions: Array[Vector2], skidding: bool, z_index: int = 0) -> void:
	if _streaks.size() != wheel_world_positions.size():
		finish_all()
		_streaks.resize(wheel_world_positions.size())
	for i in wheel_world_positions.size():
		var streak: Line2D = _streaks[i]
		if not skidding:
			if streak != null:
				_finish(streak)
				_streaks[i] = null
			continue
		var local_pos := layer.to_local(wheel_world_positions[i])
		if streak == null:
			_streaks[i] = _start(layer, local_pos, Line2D.LINE_CAP_ROUND, z_index)
			continue
		var last_point := streak.get_point_position(streak.get_point_count() - 1)
		if last_point.distance_to(local_pos) < min_gap:
			continue
		streak.add_point(local_pos)
		if streak.get_point_count() >= max_points:
			streak.end_cap_mode = Line2D.LINE_CAP_NONE
			_finish(streak)
			_streaks[i] = _start(layer, local_pos, Line2D.LINE_CAP_NONE, z_index)

func finish_all() -> void:
	for streak in _streaks:
		if streak != null and is_instance_valid(streak):
			_finish(streak)
	_streaks.clear()

func _start(layer: Node2D, first_point: Vector2, begin_cap: Line2D.LineCapMode, z_index: int) -> Line2D:
	var line := Line2D.new()
	line.width = width
	line.default_color = color
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = begin_cap
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	line.antialiased = true
	line.z_index = z_index
	line.add_point(first_point)
	layer.add_child(line)
	return line

func _finish(line: Line2D) -> void:
	if line.get_point_count() < 2:
		line.queue_free()
		return
	var tween := line.create_tween()
	tween.tween_interval(hold_time)
	tween.tween_property(line, "modulate:a", 0.0, fade_time)
	tween.tween_callback(line.queue_free)
