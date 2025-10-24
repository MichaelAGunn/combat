extends CharacterBody3D
class_name Player

enum States {IDLE, WALK, RUN, JUMP, FALL}
var state: States = States.IDLE
var paused: bool = false
var movement_input := Vector2.ZERO
var _mouse_input_dir := Vector2.ZERO
var mouse_sensitivity: float = 0.15

@onready var camera_control = $CameraControl
@onready var spring_arm_3d = $CameraControl/SpringArm3D
@onready var camera_3d = $CameraControl/SpringArm3D/Camera3D
@onready var body = $MeshInstance3D

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

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

func _physics_process(delta: float) -> void:
	# Camera by Mouse
	camera_control.rotation.x -= _mouse_input_dir.y * delta
	camera_control.rotation.x = clamp(camera_control.rotation.x, -PI/2.0, PI/8.0)
	camera_control.rotation.y -= _mouse_input_dir.x * delta
	_mouse_input_dir = Vector2.ZERO
