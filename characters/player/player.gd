extends CharacterBody3D
class_name Player

var player_sm: LimboHSM
var paused: bool = false
var movement_input := Vector2.ZERO
var _mouse_input_dir := Vector2.ZERO
var mouse_sensitivity: float = 0.15
var _last_movement_dir := Vector3.BACK

@export var walk_speed: float = 4.0
@export var run_speed: float = 12.0
@export var jump_height: float = 1.0
@export var jump_time_to_peak: float = 0.4
@export var jump_time_to_descent: float = 0.3

@onready var jump_velocity: float = ((2.0 * jump_height) / jump_time_to_peak)
@onready var jump_gravity: float = ((-2.0 * jump_height) / (jump_time_to_peak ** 2))
@onready var fall_gravity: float = ((-2.0 * jump_height) / (jump_time_to_descent ** 2))

@onready var camera_control = $CameraControl
@onready var spring_arm_3d = $CameraControl/SpringArm3D
@onready var camera_3d = $CameraControl/SpringArm3D/Camera3D
@onready var body = $MeshInstance3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	initialize_state_machine()
	print("VECTOR3")
	print(Vector3.ZERO)
	print("VECTOR3")

func _input(event: InputEvent) -> void:
	# Essential Buttons
	if Input.is_action_just_pressed("exit"):
		get_tree().quit()
	if event.is_action_pressed("pause"):
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			# Enter Live Play
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
			paused = true
		elif Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
			# Enter Pause Menu
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
			paused = false

func _unhandled_input(event: InputEvent) -> void:
	# Rotate Camera
	var is_mouse_motion := (
		event is InputEventMouseMotion and
		Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED
	)
	if is_mouse_motion:
		_mouse_input_dir = event.screen_relative * mouse_sensitivity
	# Zoom Camera
	if event.is_action_pressed("zoomin"):
		spring_arm_3d.spring_length -= 1
		spring_arm_3d.spring_length = clamp(spring_arm_3d.spring_length, 2.0, 12.0)
	elif event.is_action_pressed("zoomout"):
		spring_arm_3d.spring_length += 1
		spring_arm_3d.spring_length = clamp(spring_arm_3d.spring_length, 2.0, 12.0)
	# Walking and Running
	if player_sm.get_active_state().name == "walk" and event.is_action_pressed("run"):
		player_sm.dispatch(&"to_run")
	if player_sm.get_active_state().name == "run" and event.is_action_released("run"):
		player_sm.dispatch(&"to_walk")
	# Handle Attacks
	if event.is_action_pressed("attack"):
		player_sm.dispatch(&"to_attack")

func _physics_process(delta: float) -> void:
	print(player_sm.get_active_state())
	print(velocity)
	if not is_on_floor() and velocity.y < 0.0:
		player_sm.dispatch(&"to_fall")
	# Camera by Mouse
	camera_control.rotation.x -= _mouse_input_dir.y * delta
	camera_control.rotation.x = clamp(camera_control.rotation.x, -PI/2.0, PI/8.0)
	camera_control.rotation.y -= _mouse_input_dir.x * delta
	_mouse_input_dir = Vector2.ZERO
	# Move the PC
	moving(delta)
	jumping(delta)
	move_and_slide()

func moving(delta: float) -> void:
	movement_input = Input.get_vector("leftward", "rightward", "forward", "backward") \
		.rotated(-camera_control.global_rotation.y)
	var vel_2d = Vector2(velocity.x, velocity.z)
	#var is_running: bool = Input.is_action_pressed("run") # ====== TODO: Replace with state machine logic! ======
	var speed = run_speed if player_sm.get_active_state().name == "run" else walk_speed
	if movement_input != Vector2.ZERO:
		vel_2d += movement_input * speed * delta
		vel_2d = vel_2d.limit_length(speed)
	else:
		vel_2d = vel_2d.move_toward(Vector2.ZERO, (speed ** 2) * delta)
	velocity.x = vel_2d.x
	velocity.z = vel_2d.y
	if movement_input.length() > 0.2:
		_last_movement_dir = velocity
	var target_angle := Vector3.BACK.signed_angle_to(_last_movement_dir, Vector3.UP)
	body.global_rotation.y = target_angle

func jumping(delta: float) -> void:
	var gravity = jump_gravity if velocity.y > 0.0 else fall_gravity
	velocity.y += gravity * delta
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y += jump_velocity

func initialize_state_machine() -> void:
	player_sm = LimboHSM.new()
	add_child(player_sm)
	var idle_state = LimboState.new().named("idle").call_on_enter(idle_start).call_on_update(idle_update)
	var walk_state = LimboState.new().named("walk").call_on_enter(walk_start).call_on_update(walk_update)
	var run_state = LimboState.new().named("run").call_on_enter(run_start).call_on_update(run_update)
	var jump_state = LimboState.new().named("jump").call_on_enter(walk_start).call_on_update(run_update)
	var leap_state = LimboState.new().named("leap").call_on_enter(leap_start).call_on_update(leap_update)
	var fall_state = LimboState.new().named("fall").call_on_enter(fall_start).call_on_update(fall_update)
	#var attack_state = LimboState.new().named("attack").call_on_enter(attack_start).call_on_update(attack_update)
	player_sm.add_child(idle_state)
	player_sm.add_child(walk_state)
	player_sm.add_child(run_state)
	player_sm.add_child(jump_state)
	player_sm.add_child(fall_state)
	player_sm.add_child(leap_state)
	#player_sm.add_child(attack_state)
	player_sm.initial_state = idle_state
	player_sm.add_transition(idle_state, walk_state, &"to_walk")
	player_sm.add_transition(idle_state, run_state, &"to_run")
	player_sm.add_transition(player_sm.ANYSTATE, idle_state, &"state_ended")
	player_sm.add_transition(walk_state, run_state, &"to_run")
	player_sm.add_transition(run_state, walk_state, &"to_walk")
	player_sm.add_transition(idle_state, jump_state, &"to_jump")
	player_sm.add_transition(walk_state, jump_state, &"to_jump")
	player_sm.add_transition(run_state, leap_state, &"to_leap")
	player_sm.add_transition(jump_state, fall_state, &"to_fall")
	player_sm.add_transition(leap_state, fall_state, &"to_fall")
	#player_sm.add_transition(player_sm.ANYSTATE, attack_state, &"to_attack")
	player_sm.initialize(self)
	player_sm.set_active(true)

func idle_start() -> void:
	# This is where to call the animation!
	pass

func idle_update(delta: float) -> void:
	if is_on_floor() and (velocity.x != 0.0 or velocity.z != 0.0):
		player_sm.dispatch(&"to_walk")
	elif not is_on_floor() and velocity.y > 0.0:
		player_sm.dispatch(&"to_jump")

func walk_start() -> void:
	# This is where to call the animation!
	pass

func walk_update(delta: float) -> void:
	if is_on_floor() and velocity.x == 0.0 and velocity.y == 0.0 and velocity.z == 0.0:
		player_sm.dispatch(&"state_ended")
	elif not is_on_floor() and velocity.y > 0.0:
		player_sm.dispatch(&"to_jump")

func run_start() -> void:
	# This is where to call the animation!
	pass

func run_update(delta: float) -> void:
	if is_on_floor() and velocity.x == 0.0 and velocity.y == 0.0 and velocity.z == 0.0:
		player_sm.dispatch(&"state_ended")
	elif not is_on_floor() and velocity.y > 0.0:
		player_sm.dispatch(&"to_leap")

func jump_start() -> void:
	# This is where to call the animation!
	pass

func jump_update(delta: float) -> void:
	if is_on_floor():
		player_sm.dispatch(&"state_ended")

func leap_start() -> void:
	# This is where to call the animation!
	pass

func leap_update(delta: float) -> void:
	if is_on_floor():
		player_sm.dispatch(&"state_ended")

func fall_start() -> void:
	# This is where to call the animation!
	pass

func fall_update(delta: float) -> void:
	if is_on_floor():
		player_sm.dispatch(&"state_ended")

func attack_start() -> void:
	# This is where to call the animation!
	pass

func attack_update(delta: float) -> void:
	pass
