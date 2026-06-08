class_name MotorcycleBicycleControllerV4
extends RigidBody3D

const WORLD_COLLIDER_NAME = "GeneratedTrackCollision"
const FALLBACK_GROUND_BODY_NAME = "GeneratedFallbackGroundBody"
const FALLBACK_GROUND_VISUAL_NAME = "GeneratedFallbackGroundVisual"
const GRAVITY = 9.8
const MIN_VECTOR_LENGTH = 0.001

@export var engine_acceleration: float = 12.5
@export var brake_deceleration: float = 34.0
@export var reverse_acceleration: float = 8.0
@export var coast_deceleration: float = 2.0
@export var max_forward_speed: float = 48.0
@export var max_reverse_speed: float = 9.0
@export var wheelbase: float = 2.15
@export var max_low_speed_steer: float = 0.62
@export var max_high_speed_steer: float = 0.60
@export var steering_response: float = 22.0
@export var high_speed_curvature_scale: float = 2.25
@export var turn_lateral_grip: float = 44.0
@export var max_lean: float = 0.72
@export var lean_response: float = 14.0
@export var suspension_rest_length: float = 0.62
@export var suspension_stiffness: float = 15000.0
@export var suspension_compression_damping: float = 2600.0
@export var suspension_rebound_damping: float = 3600.0
@export var suspension_max_force: float = 13000.0
@export var lateral_velocity_damping: float = 56.0
@export var rolling_resistance: float = 0.045
@export var air_drag: float = 0.008
@export var aero_downforce: float = 1.10
@export var max_vertical_speed: float = 18.0
@export var rear_wheel_radius: float = 0.60
@export var front_wheel_radius: float = 0.52
@export var visual_smoothing: float = 13.0
@export var camera_base_fov: float = 68.0
@export var camera_speed_fov_boost: float = 24.0

var _front_wheel_local_rest: Vector3 = Vector3.ZERO
var _rear_wheel_local_rest: Vector3 = Vector3.ZERO
var _front_wheel_base_position: Vector3 = Vector3.ZERO
var _rear_wheel_base_position: Vector3 = Vector3.ZERO
var _front_hub_base_position: Vector3 = Vector3.ZERO
var _rear_hub_base_position: Vector3 = Vector3.ZERO
var _front_wheel_base_rotation: Vector3 = Vector3.ZERO
var _rear_wheel_base_rotation: Vector3 = Vector3.ZERO
var _front_hub_base_rotation: Vector3 = Vector3.ZERO
var _rear_hub_base_rotation: Vector3 = Vector3.ZERO
var _front_fork_left_base_rotation: Vector3 = Vector3.ZERO
var _front_fork_right_base_rotation: Vector3 = Vector3.ZERO
var _handlebar_base_rotation: Vector3 = Vector3.ZERO
var _left_grip_base_rotation: Vector3 = Vector3.ZERO
var _right_grip_base_rotation: Vector3 = Vector3.ZERO
var _headlight_base_rotation: Vector3 = Vector3.ZERO
var _model_base_rotation: Vector3 = Vector3.ZERO

var _front_suspension_compression: float = 0.0
var _rear_suspension_compression: float = 0.0
var _grounded_wheel_count: int = 0
var _front_wheel_spin: float = 0.0
var _rear_wheel_spin: float = 0.0
var _front_steer_angle: float = 0.0
var _target_lean_angle: float = 0.0
var _visual_lean_angle: float = 0.0
var _drive_speed: float = 0.0
var _heading_forward: Vector3 = Vector3.FORWARD
var _smoothed_ground_up: Vector3 = Vector3.UP
var _bike_forward: Vector3 = Vector3.FORWARD
var _bike_right: Vector3 = Vector3.RIGHT
var _front_slip_angle: float = 0.0
var _rear_slip_angle: float = 0.0
var _front_normal_load: float = 0.0
var _rear_normal_load: float = 0.0
var _yaw_rate: float = 0.0
var _last_safe_position: Vector3 = Vector3.ZERO
var _airborne_time: float = 0.0
var _raw_forward_pressed: bool = false
var _raw_reverse_pressed: bool = false
var _raw_left_pressed: bool = false
var _raw_right_pressed: bool = false
var _camera_look_active: bool = false
var _camera_orbit_yaw: float = 0.0
var _camera_orbit_pitch: float = 0.0
var _camera_mouse_sensitivity: float = 0.006
var _physics_setup_complete: bool = false

@onready var _camera_rig: Node3D = $CameraRig
@onready var _camera: Camera3D = $CameraRig/Camera3D
@onready var _model: Node3D = $Model
@onready var _front_wheel_tire: Node3D = $Model/FrontWheelTire
@onready var _front_wheel_hub: Node3D = $Model/FrontWheelHub
@onready var _rear_wheel_tire: Node3D = $Model/RearWheelTire
@onready var _rear_wheel_hub: Node3D = $Model/RearWheelHub
@onready var _front_fork_left: Node3D = $Model/FrontForkLeft
@onready var _front_fork_right: Node3D = $Model/FrontForkRight
@onready var _handlebar: Node3D = $Model/Handlebar
@onready var _left_grip: Node3D = $Model/LeftGrip
@onready var _right_grip: Node3D = $Model/RightGrip
@onready var _headlight: Node3D = $Model/TinyHeadlight


func _ready() -> void:
    _ensure_input_actions()
    _camera.top_level = true
    _camera.current = true
    _cache_visual_rest_pose()
    call_deferred("_finish_physics_setup")


func _ensure_input_actions() -> void:
    for action_name: String in ["drive_forward", "drive_reverse", "steer_left", "steer_right"]:
        if not InputMap.has_action(action_name):
            InputMap.add_action(action_name)


func _finish_physics_setup() -> void:
    _create_world_collision()
    _make_world_meshes_double_sided(get_tree().current_scene)
    _configure_frame_body()
    _update_ground_reference(1.0)
    _initialize_heading()
    _update_motorcycle_axes()
    _physics_setup_complete = true


func _input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        var mouse_button: InputEventMouseButton = event as InputEventMouseButton
        if mouse_button.button_index == MOUSE_BUTTON_MIDDLE:
            _camera_look_active = mouse_button.pressed
            Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if _camera_look_active else Input.MOUSE_MODE_VISIBLE
    elif event is InputEventMouseMotion and _camera_look_active:
        var mouse_motion: InputEventMouseMotion = event as InputEventMouseMotion
        _camera_orbit_yaw -= mouse_motion.relative.x * _camera_mouse_sensitivity
        _camera_orbit_pitch = clampf(_camera_orbit_pitch - mouse_motion.relative.y * _camera_mouse_sensitivity, -0.45, 0.45)
    elif event is InputEventKey:
        var key_event: InputEventKey = event as InputEventKey
        if key_event.echo:
            return
        var keycode: Key = key_event.physical_keycode
        if keycode == KEY_NONE:
            keycode = key_event.keycode
        match keycode:
            KEY_W, KEY_UP:
                _raw_forward_pressed = key_event.pressed
            KEY_S, KEY_DOWN:
                _raw_reverse_pressed = key_event.pressed
            KEY_A, KEY_LEFT:
                _raw_left_pressed = key_event.pressed
            KEY_D, KEY_RIGHT:
                _raw_right_pressed = key_event.pressed


func _physics_process(delta: float) -> void:
    if not _physics_setup_complete:
        return
    var throttle_pressed: bool = _is_forward_pressed()
    var brake_pressed: bool = _is_reverse_pressed()
    var steer_input: float = _get_steer_input()
    _update_ground_reference(delta)
    _update_motorcycle_axes()
    _apply_suspension()
    _update_ground_recovery(delta)
    _update_drive_speed(throttle_pressed, brake_pressed, delta)
    _update_steering_and_heading(steer_input, delta)
    _apply_controlled_velocity(delta)
    _apply_aero_downforce()
    _limit_unstable_velocity()
    _update_body_pose(delta)
    _update_camera_orbit()
    _update_camera_fov(delta)
    _update_visuals(delta)


func _configure_frame_body() -> void:
    mass = 210.0
    continuous_cd = true
    linear_damp = 0.02
    angular_damp = 6.0
    collision_layer = 2
    collision_mask = 0
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector3(0.0, -0.16, 0.05)
    var front_ground_height: float = _get_ground_height(global_transform * _front_wheel_local_rest)
    var rear_ground_height: float = _get_ground_height(global_transform * _rear_wheel_local_rest)
    var front_body_height: float = front_ground_height + front_wheel_radius - _front_wheel_local_rest.y + _get_static_compression(0.52) * 0.25
    var rear_body_height: float = rear_ground_height + rear_wheel_radius - _rear_wheel_local_rest.y + _get_static_compression(0.48) * 0.25
    global_position.y = minf(front_body_height, rear_body_height)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO
    _drive_speed = 0.0
    _last_safe_position = global_position
    _airborne_time = 0.0


func _initialize_heading() -> void:
    var front_position: Vector3 = global_transform * _front_wheel_local_rest
    var rear_position: Vector3 = global_transform * _rear_wheel_local_rest
    var forward: Vector3 = front_position - rear_position
    forward = forward - Vector3.UP * forward.dot(Vector3.UP)
    if forward.length() < MIN_VECTOR_LENGTH:
        forward = -global_transform.basis.z
        forward = forward - Vector3.UP * forward.dot(Vector3.UP)
    _heading_forward = forward.normalized() if forward.length() >= MIN_VECTOR_LENGTH else Vector3.FORWARD


func _update_ground_reference(delta: float) -> void:
    var front_position: Vector3 = global_transform * _front_wheel_local_rest
    var rear_position: Vector3 = global_transform * _rear_wheel_local_rest
    var front_normal: Vector3 = _get_ground_normal(front_position)
    var rear_normal: Vector3 = _get_ground_normal(rear_position)
    var sampled_up: Vector3 = (front_normal + rear_normal).normalized()
    if sampled_up.length() < MIN_VECTOR_LENGTH or sampled_up.dot(Vector3.UP) < 0.72:
        sampled_up = Vector3.UP
    var weight: float = 1.0 - exp(-8.0 * delta)
    _smoothed_ground_up = _smoothed_ground_up.lerp(sampled_up, weight).normalized()


func _update_motorcycle_axes() -> void:
    var forward: Vector3 = _heading_forward - _smoothed_ground_up * _heading_forward.dot(_smoothed_ground_up)
    if forward.length() < MIN_VECTOR_LENGTH:
        forward = -global_transform.basis.z
        forward = forward - _smoothed_ground_up * forward.dot(_smoothed_ground_up)
    if forward.length() < MIN_VECTOR_LENGTH:
        forward = Vector3.FORWARD
    _bike_forward = forward.normalized()
    _heading_forward = _bike_forward
    _bike_right = _bike_forward.cross(_smoothed_ground_up).normalized()


func _apply_suspension() -> void:
    _grounded_wheel_count = 0
    _front_suspension_compression = _apply_single_suspension(_front_wheel_local_rest, front_wheel_radius, 0.52, true)
    _rear_suspension_compression = _apply_single_suspension(_rear_wheel_local_rest, rear_wheel_radius, 0.48, false)


func _apply_single_suspension(wheel_local_rest: Vector3, wheel_radius: float, load_share: float, is_front: bool) -> float:
    var suspension_axis: Vector3 = _smoothed_ground_up
    var mount_position: Vector3 = global_transform * (wheel_local_rest + Vector3.UP * suspension_rest_length)
    var ray_result: Dictionary = _raycast_suspension(mount_position, suspension_axis, wheel_radius)
    if ray_result.is_empty():
        if is_front:
            _front_normal_load = 0.0
        else:
            _rear_normal_load = 0.0
        return 0.0
    var ground_position: Vector3 = ray_result["position"] as Vector3
    var ground_normal: Vector3 = (ray_result["normal"] as Vector3).normalized()
    if ground_normal.dot(Vector3.UP) < 0.72:
        ground_normal = Vector3.UP
    var distance_to_ground: float = (mount_position - ground_position).dot(suspension_axis) - wheel_radius
    var compression: float = clampf(suspension_rest_length - distance_to_ground, 0.0, suspension_rest_length)
    if compression <= 0.0:
        return 0.0
    _grounded_wheel_count += 1
    var relative_position: Vector3 = ground_position - global_position
    var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(relative_position)
    var normal_speed: float = point_velocity.dot(ground_normal)
    var damping: float = suspension_compression_damping if normal_speed < 0.0 else suspension_rebound_damping
    var suspension_force: float = compression * suspension_stiffness - normal_speed * damping
    suspension_force = clampf(suspension_force, 0.0, suspension_max_force)
    apply_force(ground_normal * suspension_force, relative_position)
    if is_front:
        _front_normal_load = maxf(suspension_force, mass * GRAVITY * load_share * 0.20)
    else:
        _rear_normal_load = maxf(suspension_force, mass * GRAVITY * load_share * 0.20)
    return compression


func _update_ground_recovery(delta: float) -> void:
    if _grounded_wheel_count > 0:
        _airborne_time = 0.0
        _last_safe_position = global_position
        return

    _airborne_time += delta
    if _airborne_time < 0.75 and global_position.y > -3.0:
        return

    global_position = _last_safe_position + Vector3.UP * 1.25
    linear_velocity = _bike_forward * maxf(_drive_speed * 0.35, 3.0)
    angular_velocity = Vector3.ZERO
    _drive_speed *= 0.35
    _airborne_time = 0.0


func _update_drive_speed(throttle_pressed: bool, brake_pressed: bool, delta: float) -> void:
    var planar_velocity: Vector3 = linear_velocity - _smoothed_ground_up * linear_velocity.dot(_smoothed_ground_up)
    var measured_forward_speed: float = planar_velocity.length()
    if planar_velocity.dot(_bike_forward) < -0.1:
        measured_forward_speed = -measured_forward_speed
    _drive_speed = lerpf(_drive_speed, measured_forward_speed, clampf(delta * 3.0, 0.0, 1.0))
    if throttle_pressed:
        var power_fade: float = clampf(1.0 - maxf(_drive_speed, 0.0) / max_forward_speed * 0.35, 0.35, 1.0)
        _drive_speed += engine_acceleration * power_fade * delta
    elif brake_pressed:
        if _drive_speed > 0.5:
            _drive_speed = move_toward(_drive_speed, 0.0, brake_deceleration * delta)
        else:
            _drive_speed -= reverse_acceleration * delta
    else:
        var drag_deceleration: float = coast_deceleration + _drive_speed * _drive_speed * air_drag + absf(_drive_speed) * rolling_resistance
        _drive_speed = move_toward(_drive_speed, 0.0, drag_deceleration * delta)
    _drive_speed = clampf(_drive_speed, -max_reverse_speed, max_forward_speed)


func _update_steering_and_heading(steer_input: float, delta: float) -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    var speed_abs: float = maxf(absf(_drive_speed), horizontal_speed)
    var speed_weight: float = clampf((speed_abs - 4.0) / 32.0, 0.0, 1.0)
    var max_steer: float = lerpf(max_low_speed_steer, max_high_speed_steer, speed_weight)
    var target_steer_angle: float = -steer_input * max_steer
    var steer_weight: float = 1.0 - exp(-steering_response * delta)
    _front_steer_angle = lerpf(_front_steer_angle, target_steer_angle, steer_weight)
    var curvature_scale: float = lerpf(1.0, high_speed_curvature_scale, speed_weight)
    var raw_yaw_rate: float = _drive_speed * tan(_front_steer_angle) / maxf(wheelbase, 0.1) * curvature_scale
    var grip_yaw_limit: float = turn_lateral_grip / maxf(speed_abs, 4.0) * curvature_scale
    _yaw_rate = clampf(raw_yaw_rate, -grip_yaw_limit, grip_yaw_limit)
    if speed_abs < 0.35:
        _yaw_rate = 0.0
    if absf(_yaw_rate) > 0.0001:
        _heading_forward = _heading_forward.rotated(_smoothed_ground_up, _yaw_rate * delta).normalized()
    var physical_yaw_rate: float = absf(_yaw_rate) / maxf(curvature_scale, 0.001)
    var lateral_acceleration: float = speed_abs * physical_yaw_rate
    var lean_from_turn: float = atan(lateral_acceleration / GRAVITY)
    var lean_sign: float = 0.0
    if absf(_front_steer_angle) > 0.001:
        lean_sign = -signf(_front_steer_angle)
    _target_lean_angle = clampf(lean_from_turn * lean_sign, -max_lean, max_lean)


func _apply_controlled_velocity(delta: float) -> void:
    if _grounded_wheel_count <= 0:
        return
    var vertical_velocity: Vector3 = _smoothed_ground_up * linear_velocity.dot(_smoothed_ground_up)
    var lateral_speed: float = linear_velocity.dot(_bike_right)
    var damped_lateral_speed: float = move_toward(lateral_speed, 0.0, lateral_velocity_damping * delta)
    linear_velocity = _bike_forward * _drive_speed + _bike_right * damped_lateral_speed + vertical_velocity
    var planar_velocity: Vector3 = linear_velocity - _smoothed_ground_up * linear_velocity.dot(_smoothed_ground_up)
    _front_slip_angle = atan2(planar_velocity.dot(_bike_right), maxf(absf(_drive_speed), 1.0))
    _rear_slip_angle = _front_slip_angle
    angular_velocity = _smoothed_ground_up * _yaw_rate


func _apply_aero_downforce() -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    if horizontal_speed <= 2.0:
        return
    apply_central_force(-_smoothed_ground_up * horizontal_speed * horizontal_speed * aero_downforce)


func _limit_unstable_velocity() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    if horizontal_velocity.length() > max_forward_speed:
        var capped_horizontal: Vector3 = horizontal_velocity.normalized() * max_forward_speed
        linear_velocity.x = capped_horizontal.x
        linear_velocity.z = capped_horizontal.z
    linear_velocity.y = clampf(linear_velocity.y, -max_vertical_speed, max_vertical_speed)


func _update_body_pose(delta: float) -> void:
    var lean_weight: float = 1.0 - exp(-lean_response * delta)
    _visual_lean_angle = lerpf(_visual_lean_angle, _target_lean_angle, lean_weight)
    var forward: Vector3 = _bike_forward
    var up: Vector3 = _smoothed_ground_up.rotated(forward, _visual_lean_angle).normalized()
    var right: Vector3 = forward.cross(up).normalized()
    var corrected_forward: Vector3 = up.cross(right).normalized()
    var body_transform: Transform3D = global_transform
    body_transform.basis = Basis(right, up, -corrected_forward).orthonormalized()
    global_transform = body_transform


func _update_camera_orbit() -> void:
    var flat_forward: Vector3 = Vector3(_bike_forward.x, 0.0, _bike_forward.z)
    if flat_forward.length() < MIN_VECTOR_LENGTH:
        flat_forward = Vector3.FORWARD
    flat_forward = flat_forward.normalized().rotated(Vector3.UP, _camera_orbit_yaw).normalized()
    var look_target: Vector3 = global_position + flat_forward * 4.5 + Vector3.UP * 0.75
    var camera_position: Vector3 = global_position - flat_forward * 7.0 + Vector3.UP * (4.6 + _camera_orbit_pitch * 2.2)
    _camera_rig.global_position = global_position + Vector3.UP * 1.2
    _camera.global_position = camera_position
    _camera.look_at(look_target, Vector3.UP)


func _update_camera_fov(delta: float) -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    var speed_ratio: float = clampf(horizontal_speed / maxf(max_forward_speed, 0.001), 0.0, 1.0)
    var target_fov: float = camera_base_fov + camera_speed_fov_boost * speed_ratio
    var fov_weight: float = clampf(visual_smoothing * delta, 0.0, 1.0)
    _camera.fov = lerpf(_camera.fov, target_fov, fov_weight)


func _update_visuals(delta: float) -> void:
    _front_wheel_spin += _drive_speed * delta / maxf(front_wheel_radius, 0.01)
    _rear_wheel_spin += _drive_speed * delta / maxf(rear_wheel_radius, 0.01)
    _model.rotation = _model_base_rotation
    _front_fork_left.rotation = _front_fork_left_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _front_fork_right.rotation = _front_fork_right_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _handlebar.rotation = _handlebar_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _left_grip.rotation = _left_grip_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _right_grip.rotation = _right_grip_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _headlight.rotation = _headlight_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    var smoothing_weight: float = clampf(visual_smoothing * delta, 0.0, 1.0)
    var front_static_compression: float = _get_static_compression(0.52)
    var rear_static_compression: float = _get_static_compression(0.48)
    var front_offset: float = clampf(_front_suspension_compression - front_static_compression, -suspension_rest_length * 0.45, suspension_rest_length * 0.55)
    var rear_offset: float = clampf(_rear_suspension_compression - rear_static_compression, -suspension_rest_length * 0.45, suspension_rest_length * 0.55)
    _front_wheel_tire.position = _front_wheel_tire.position.lerp(_front_wheel_base_position + Vector3.UP * front_offset, smoothing_weight)
    _front_wheel_hub.position = _front_wheel_hub.position.lerp(_front_hub_base_position + Vector3.UP * front_offset, smoothing_weight)
    _rear_wheel_tire.position = _rear_wheel_tire.position.lerp(_rear_wheel_base_position + Vector3.UP * rear_offset, smoothing_weight)
    _rear_wheel_hub.position = _rear_wheel_hub.position.lerp(_rear_hub_base_position + Vector3.UP * rear_offset, smoothing_weight)
    _front_wheel_tire.rotation = _front_wheel_base_rotation + Vector3(_front_wheel_spin, _front_steer_angle, 0.0)
    _front_wheel_hub.rotation = _front_hub_base_rotation + Vector3(_front_wheel_spin, _front_steer_angle, 0.0)
    _rear_wheel_tire.rotation = _rear_wheel_base_rotation + Vector3(_rear_wheel_spin, 0.0, 0.0)
    _rear_wheel_hub.rotation = _rear_hub_base_rotation + Vector3(_rear_wheel_spin, 0.0, 0.0)


func get_telemetry() -> Dictionary:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    return {
        "speed": horizontal_velocity.length(),
        "drive_speed": _drive_speed,
        "lean_angle": _visual_lean_angle,
        "target_lean_angle": _target_lean_angle,
        "steer_angle": _front_steer_angle,
        "front_slip_angle": _front_slip_angle,
        "rear_slip_angle": _rear_slip_angle,
        "front_normal_load": _front_normal_load,
        "rear_normal_load": _rear_normal_load,
        "grounded_wheels": _grounded_wheel_count,
        "bike_forward": _bike_forward,
        "bike_right": _bike_right,
        "ground_up": _smoothed_ground_up,
        "yaw_rate": _yaw_rate
    }


func _cache_visual_rest_pose() -> void:
    _model_base_rotation = _model.rotation
    _front_wheel_base_position = _front_wheel_tire.position
    _rear_wheel_base_position = _rear_wheel_tire.position
    _front_hub_base_position = _front_wheel_hub.position
    _rear_hub_base_position = _rear_wheel_hub.position
    _front_wheel_base_rotation = _front_wheel_tire.rotation
    _rear_wheel_base_rotation = _rear_wheel_tire.rotation
    _front_hub_base_rotation = _front_wheel_hub.rotation
    _rear_hub_base_rotation = _rear_wheel_hub.rotation
    _front_fork_left_base_rotation = _front_fork_left.rotation
    _front_fork_right_base_rotation = _front_fork_right.rotation
    _handlebar_base_rotation = _handlebar.rotation
    _left_grip_base_rotation = _left_grip.rotation
    _right_grip_base_rotation = _right_grip.rotation
    _headlight_base_rotation = _headlight.rotation
    _front_wheel_local_rest = global_transform.affine_inverse() * _front_wheel_tire.global_position
    _rear_wheel_local_rest = global_transform.affine_inverse() * _rear_wheel_tire.global_position


func _get_static_compression(load_share: float) -> float:
    var supported_weight: float = mass * GRAVITY * load_share
    return clampf(supported_weight / maxf(suspension_stiffness, 1.0), 0.02, suspension_rest_length * 0.62)


func _raycast_suspension(mount_position: Vector3, suspension_axis: Vector3, wheel_radius: float) -> Dictionary:
    var from_position: Vector3 = mount_position + suspension_axis * 0.35
    var to_position: Vector3 = mount_position - suspension_axis * (suspension_rest_length + wheel_radius + 1.6)
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_position, to_position, 1)
    query.exclude = [get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(query)


func _raycast_ground(world_position: Vector3) -> Dictionary:
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(world_position + Vector3.UP * 12.0, world_position + Vector3.DOWN * 16.0, 1)
    query.exclude = [get_rid()]
    return get_world_3d().direct_space_state.intersect_ray(query)


func _get_ground_height(world_position: Vector3) -> float:
    var ray_result: Dictionary = _raycast_ground(world_position)
    if not ray_result.is_empty():
        var ground_position: Vector3 = ray_result["position"] as Vector3
        return ground_position.y
    return world_position.y - front_wheel_radius


func _get_ground_normal(world_position: Vector3) -> Vector3:
    var ray_result: Dictionary = _raycast_ground(world_position)
    if not ray_result.is_empty():
        var normal: Vector3 = ray_result["normal"] as Vector3
        return normal.normalized()
    return Vector3.UP


func _create_world_collision() -> void:
    var scene_root: Node = get_tree().current_scene
    if scene_root == null:
        return
    if not scene_root.has_node(WORLD_COLLIDER_NAME):
        var static_body: StaticBody3D = StaticBody3D.new()
        static_body.name = WORLD_COLLIDER_NAME
        static_body.collision_layer = 1
        static_body.collision_mask = 0
        scene_root.add_child(static_body)
        _add_mesh_colliders(scene_root, static_body)
    _create_fallback_ground(scene_root)


func _create_fallback_ground(scene_root: Node) -> void:
    if scene_root.has_node(FALLBACK_GROUND_BODY_NAME):
        return

    var ground_body: StaticBody3D = StaticBody3D.new()
    ground_body.name = FALLBACK_GROUND_BODY_NAME
    ground_body.collision_layer = 1
    ground_body.collision_mask = 0
    ground_body.position = Vector3(0.0, -1.45, 0.0)
    scene_root.add_child(ground_body)

    var ground_shape: BoxShape3D = BoxShape3D.new()
    ground_shape.size = Vector3(4000.0, 0.5, 4000.0)
    var collision_shape: CollisionShape3D = CollisionShape3D.new()
    collision_shape.name = "FallbackGroundCollision"
    collision_shape.shape = ground_shape
    ground_body.add_child(collision_shape)

    var ground_visual: MeshInstance3D = MeshInstance3D.new()
    ground_visual.name = FALLBACK_GROUND_VISUAL_NAME
    var plane_mesh: PlaneMesh = PlaneMesh.new()
    plane_mesh.size = Vector2(4000.0, 4000.0)
    ground_visual.mesh = plane_mesh
    ground_visual.position = Vector3(0.0, -1.18, 0.0)
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.19, 0.42, 0.23, 1.0)
    material.roughness = 0.95
    ground_visual.material_override = material
    scene_root.add_child(ground_visual)


func _add_mesh_colliders(node: Node, static_body: StaticBody3D) -> void:
    if node == self or node == static_body:
        return
    if node is MeshInstance3D:
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if not _is_descendant_of(mesh_instance, self) and mesh_instance.mesh != null:
            var shape: Shape3D = mesh_instance.mesh.create_trimesh_shape()
            if shape != null:
                var collision_shape: CollisionShape3D = CollisionShape3D.new()
                collision_shape.name = "%sCollision" % mesh_instance.name
                collision_shape.shape = shape
                static_body.add_child(collision_shape)
                collision_shape.transform = static_body.global_transform.affine_inverse() * mesh_instance.global_transform
    for child: Node in node.get_children():
        _add_mesh_colliders(child, static_body)


func _make_world_meshes_double_sided(node: Node) -> void:
    if node == null or node == self:
        return
    if node is MeshInstance3D and not _is_descendant_of(node, self):
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        var mesh: Mesh = mesh_instance.mesh
        if mesh != null:
            for surface_index: int in range(mesh.get_surface_count()):
                var source_material: Material = mesh_instance.get_active_material(surface_index)
                var base_material: BaseMaterial3D = source_material as BaseMaterial3D
                if base_material != null:
                    var writable_material: BaseMaterial3D = base_material.duplicate() as BaseMaterial3D
                    writable_material.cull_mode = BaseMaterial3D.CULL_DISABLED
                    mesh_instance.set_surface_override_material(surface_index, writable_material)
    for child: Node in node.get_children():
        _make_world_meshes_double_sided(child)


func _is_descendant_of(node: Node, possible_parent: Node) -> bool:
    var current: Node = node
    while current != null:
        if current == possible_parent:
            return true
        current = current.get_parent()
    return false


func _is_forward_pressed() -> bool:
    return _raw_forward_pressed or Input.is_action_pressed("drive_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)


func _is_reverse_pressed() -> bool:
    return _raw_reverse_pressed or Input.is_action_pressed("drive_reverse") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)


func _get_steer_input() -> float:
    var input_value: float = 0.0
    if _raw_left_pressed or Input.is_action_pressed("steer_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_value -= 1.0
    if _raw_right_pressed or Input.is_action_pressed("steer_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_value += 1.0
    return input_value
