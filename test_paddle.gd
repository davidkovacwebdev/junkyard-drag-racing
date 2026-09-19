extends SceneTree
## TEMP smoke test: assemble a car with paddle "wheels" on a floor and log
## how far it travels, to verify the swing really drives it forward.

var body: CarBody
var frames := 0
var max_frames := 360

func _initialize() -> void:
	var ground := StaticBody2D.new()
	var gshape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(30000, 80)
	gshape.shape = rect
	ground.add_child(gshape)
	ground.position = Vector2(0, 120)
	root.add_child(ground)

	var parent := Node2D.new()
	root.add_child(parent)

	var body_scene := load("res://scenes/parts/bodies/body_classic.tscn") as PackedScene
	var wheel_path := "res://scenes/parts/wheels/wheel_paddle.tscn"
	var user_args := OS.get_cmdline_user_args()
	max_frames = 360
	if user_args.size() > 2:
		max_frames = int(user_args[2])
	if user_args.size() > 0:
		wheel_path = user_args[0]
	var wheel_scene := load(wheel_path) as PackedScene
	var engine_scene := load("res://scenes/parts/engines/engine_v6.tscn") as PackedScene
	if user_args.size() > 1:
		engine_scene = load(user_args[1]) as PackedScene
	var assembled := CarAssembler.assemble(body_scene, [wheel_scene, wheel_scene], engine_scene, parent, Vector2(0, 20))
	body = assembled.body

	physics_frame.connect(_on_physics_frame)

func _on_physics_frame() -> void:
	frames += 1
	if frames % 30 == 0:
		print("t=%4d  x=%8.1f  y=%7.1f  vx=%7.1f  rot=%6.1f" % [
			frames, body.global_position.x, body.global_position.y,
			body.linear_velocity.x, rad_to_deg(body.rotation)])
	if frames >= max_frames:
		print("FINAL x=%.1f vx=%.1f" % [body.global_position.x, body.linear_velocity.x])
		quit()
