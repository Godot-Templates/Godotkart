class_name MotorcycleBicycleControllerV4
extends RigidBody3D

const WORLD_COLLIDER_NAME = "GeneratedTrackCollision"
const FALLBACK_GROUND_BODY_NAME = "GeneratedFallbackGroundBody"
const FALLBACK_GROUND_VISUAL_NAME = "GeneratedFallbackGroundVisual"
const GRAVITY = 9.8
const MIN_VECTOR_LENGTH = 0.001

@export var show_debug_sliders: bool = true
@export var engine_acceleration: float = 12.5
@export var brake_deceleration: float = 34.0
@export var reverse_acceleration: float = 8.0
@export var coast_deceleration: float = 2.0
@export var max_forward_speed: float = 42.0
@export var max_reverse_speed: float = 9.0
@export var wheelbase: float = 2.15
@export var max_low_speed_steer: float = 0.54
@export var max_high_speed_steer: float = 0.46
@export var steering_response: float = 22.0
@export var high_speed_curvature_scale: float = 1.75
@export var turn_lateral_grip: float = 36.0
@export var max_lean: float = 0.436332
@export var max_drift_lean: float = 0.523599
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
@export var hop_impulse: float = 3.2
@export var min_drift_speed: float = 8.0
@export var drift_charge_duration: float = 1.0
@export var drift_steer_multiplier: float = 1.55
@export var drift_grip_multiplier: float = 1.45
@export var drift_lateral_speed: float = 1.8
@export var drift_lateral_velocity_damping: float = 18.0
@export var boost_duration: float = 1.25
@export var boost_speed_bonus: float = 17.0
@export var boost_acceleration: float = 54.0
@export var boost_fov_bonus: float = 14.0
@export var boost_fx_fov_enabled: bool = true
@export var boost_fx_wind_enabled: bool = true
@export var obstacle_probe_distance: float = 2.1
@export var obstacle_probe_speed_lookahead: float = 0.08
@export var obstacle_wall_normal_max_up: float = 0.55
@export var wall_slide_speed_retention: float = 0.995
@export var wall_bounce_strength: float = 0.16
@export var wall_bounce_max_speed: float = 1.6
@export var wall_unstick_push_speed: float = 0.85

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
var _raw_forward_pressed: bool = false
var _raw_reverse_pressed: bool = false
var _raw_left_pressed: bool = false
var _raw_right_pressed: bool = false
var _camera_look_active: bool = false
var _camera_orbit_yaw: float = 0.0
var _camera_orbit_pitch: float = 0.0
var _camera_mouse_sensitivity: float = 0.006
var _physics_setup_complete: bool = false
var _raw_hop_drift_pressed: bool = false
var _was_hop_drift_pressed: bool = false
var _is_drifting: bool = false
var _drift_time: float = 0.0
var _drift_direction: float = 0.0
var _boost_time_remaining: float = 0.0
var _boost_hop_drift_lockout: bool = false
var _spark_phase: float = 0.0
var _drift_spark_nodes: Array[MeshInstance3D] = []
var _spark_white_material: StandardMaterial3D = null
var _spark_gold_material: StandardMaterial3D = null
var _debug_max_speed_value_label: Label = null
var _debug_acceleration_value_label: Label = null
var _debug_lean_value_label: Label = null
var _boost_effect_time: float = 0.0
var _boost_wind_material: StandardMaterial3D = null
var _boost_wind_streaks: Array[MeshInstance3D] = []
var _obstacle_rider_probe_shape: CapsuleShape3D = null
var _obstacle_blocked: bool = false
var _obstacle_block_normal: Vector3 = Vector3.ZERO

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
    _create_obstacle_probe_shapes()
    _create_drift_sparks()
    _create_boost_effects()
    _create_debug_sliders()
    call_deferred("_finish_physics_setup")


func _ensure_input_actions() -> void:
    for action_name: String in ["drive_forward", "drive_reverse", "steer_left", "steer_right", "hop_drift"]:
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


func _create_obstacle_probe_shapes() -> void:
    _obstacle_rider_probe_shape = CapsuleShape3D.new()
    _obstacle_rider_probe_shape.radius = 0.62
    _obstacle_rider_probe_shape.height = 1.95


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
            KEY_SPACE:
                _raw_hop_drift_pressed = key_event.pressed


func _physics_process(delta: float) -> void:
    if not _physics_setup_complete:
        return
    var throttle_pressed: bool = _is_forward_pressed()
    var brake_pressed: bool = _is_reverse_pressed()
    var steer_input: float = _get_steer_input()
    var hop_drift_pressed: bool = _is_hop_drift_pressed()
    _update_ground_reference(delta)
    _update_motorcycle_axes()
    _apply_suspension()
    _update_hop_drift(steer_input, hop_drift_pressed, delta)
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
    contact_monitor = true
    max_contacts_reported = 16
    linear_damp = 0.02
    angular_damp = 6.0
    collision_layer = 2
    collision_mask = 1
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
    if _boost_time_remaining > 0.0:
        _drive_speed = move_toward(_drive_speed, max_forward_speed + boost_speed_bonus, boost_acceleration * delta)
    _drive_speed = clampf(_drive_speed, -max_reverse_speed, _get_active_forward_speed_limit())


func _update_steering_and_heading(steer_input: float, delta: float) -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    var speed_abs: float = maxf(absf(_drive_speed), horizontal_speed)
    var speed_weight: float = clampf((speed_abs - 4.0) / 32.0, 0.0, 1.0)
    var max_steer: float = lerpf(max_low_speed_steer, max_high_speed_steer, speed_weight)
    var active_steer_input: float = steer_input
    if _is_drifting and absf(active_steer_input) < 0.1:
        active_steer_input = _drift_direction
    var steer_multiplier: float = drift_steer_multiplier if _is_drifting else 1.0
    var target_steer_angle: float = clampf(-active_steer_input * max_steer * steer_multiplier, -max_low_speed_steer * drift_steer_multiplier, max_low_speed_steer * drift_steer_multiplier)
    var steer_weight: float = 1.0 - exp(-steering_response * delta)
    _front_steer_angle = lerpf(_front_steer_angle, target_steer_angle, steer_weight)
    var curvature_scale: float = lerpf(1.0, high_speed_curvature_scale, speed_weight)
    var raw_yaw_rate: float = _drive_speed * tan(_front_steer_angle) / maxf(wheelbase, 0.1) * curvature_scale
    var active_turn_grip: float = turn_lateral_grip * (drift_grip_multiplier if _is_drifting else 1.0)
    var grip_yaw_limit: float = active_turn_grip / maxf(speed_abs, 4.0) * curvature_scale
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
    var active_max_lean: float = max_drift_lean if _is_drifting else max_lean
    _target_lean_angle = clampf(lean_from_turn * lean_sign, -active_max_lean, active_max_lean)


func _apply_controlled_velocity(delta: float) -> void:
    _obstacle_blocked = false
    _obstacle_block_normal = Vector3.ZERO
    if _grounded_wheel_count <= 0:
        return
    var vertical_velocity: Vector3 = _smoothed_ground_up * linear_velocity.dot(_smoothed_ground_up)
    var lateral_speed: float = linear_velocity.dot(_bike_right)
    var lateral_target: float = 0.0
    var active_lateral_damping: float = lateral_velocity_damping
    if _is_drifting:
        var drift_speed_ratio: float = clampf(absf(_drive_speed) / maxf(max_forward_speed, 0.001), 0.0, 1.0)
        lateral_target = _drift_direction * drift_lateral_speed * drift_speed_ratio
        active_lateral_damping = drift_lateral_velocity_damping
    var damped_lateral_speed: float = move_toward(lateral_speed, lateral_target, active_lateral_damping * delta)
    var target_velocity: Vector3 = _bike_forward * _drive_speed + _bike_right * damped_lateral_speed + vertical_velocity
    var travel_direction: Vector3 = _bike_forward if _drive_speed >= 0.0 else -_bike_forward
    var obstacle_normal: Vector3 = _get_obstacle_block_normal(travel_direction, absf(_drive_speed))
    _obstacle_block_normal = obstacle_normal
    _obstacle_blocked = obstacle_normal.length() >= MIN_VECTOR_LENGTH
    if _obstacle_blocked:
        target_velocity = _apply_wall_slide_response(target_velocity, obstacle_normal)
        var blocked_forward_speed: float = target_velocity.dot(_bike_forward)
        var slide_drive_retention: float = _get_wall_slide_drive_retention(obstacle_normal, travel_direction)
        if _drive_speed > 0.0:
            var retained_forward_speed: float = _drive_speed * slide_drive_retention
            _drive_speed = minf(_drive_speed, maxf(maxf(blocked_forward_speed, retained_forward_speed), 0.0))
        elif _drive_speed < 0.0:
            var retained_reverse_speed: float = _drive_speed * slide_drive_retention
            _drive_speed = maxf(_drive_speed, minf(minf(blocked_forward_speed, retained_reverse_speed), 0.0))
    linear_velocity = target_velocity
    var planar_velocity: Vector3 = linear_velocity - _smoothed_ground_up * linear_velocity.dot(_smoothed_ground_up)
    _front_slip_angle = atan2(planar_velocity.dot(_bike_right), maxf(absf(_drive_speed), 1.0))
    _rear_slip_angle = _front_slip_angle
    angular_velocity = _smoothed_ground_up * _yaw_rate


func _get_wall_slide_drive_retention(obstacle_normal: Vector3, travel_direction: Vector3) -> float:
    if obstacle_normal.length() < MIN_VECTOR_LENGTH or travel_direction.length() < MIN_VECTOR_LENGTH:
        return 0.0
    var wall_normal: Vector3 = obstacle_normal - _smoothed_ground_up * obstacle_normal.dot(_smoothed_ground_up)
    if wall_normal.length() < MIN_VECTOR_LENGTH:
        return 0.0
    wall_normal = wall_normal.normalized()
    var head_on_amount: float = clampf(-wall_normal.dot(travel_direction.normalized()), 0.0, 1.0)
    var tangent_amount: float = sqrt(maxf(0.0, 1.0 - head_on_amount * head_on_amount))
    var steep_hit_weight: float = clampf((head_on_amount - 0.78) / 0.22, 0.0, 1.0)
    return lerpf(1.0, tangent_amount * wall_slide_speed_retention, steep_hit_weight)


func _apply_wall_slide_response(target_velocity: Vector3, obstacle_normal: Vector3) -> Vector3:
    if obstacle_normal.length() < MIN_VECTOR_LENGTH:
        return target_velocity
    var wall_normal: Vector3 = obstacle_normal - _smoothed_ground_up * obstacle_normal.dot(_smoothed_ground_up)
    if wall_normal.length() < MIN_VECTOR_LENGTH:
        wall_normal = obstacle_normal.normalized()
    else:
        wall_normal = wall_normal.normalized()
    var vertical_velocity: Vector3 = _smoothed_ground_up * target_velocity.dot(_smoothed_ground_up)
    var planar_velocity: Vector3 = target_velocity - vertical_velocity
    var into_wall_speed: float = planar_velocity.dot(wall_normal)
    if into_wall_speed >= 0.0:
        return target_velocity
    var slide_velocity: Vector3 = planar_velocity - wall_normal * into_wall_speed
    slide_velocity *= wall_slide_speed_retention
    var bounce_speed: float = clampf(-into_wall_speed * wall_bounce_strength, 0.0, wall_bounce_max_speed)
    slide_velocity += wall_normal * bounce_speed
    if get_contact_count() > 0 and slide_velocity.length() < wall_unstick_push_speed:
        slide_velocity += wall_normal * wall_unstick_push_speed
    return slide_velocity + vertical_velocity


func _get_obstacle_block_normal(travel_direction: Vector3, speed_abs: float) -> Vector3:
    if travel_direction.length() < MIN_VECTOR_LENGTH or speed_abs < 0.25:
        return Vector3.ZERO
    var probe_direction: Vector3 = travel_direction.normalized()
    var probe_distance: float = obstacle_probe_distance + minf(speed_abs * obstacle_probe_speed_lookahead, 3.0)
    var ray_normal: Vector3 = _get_ray_obstacle_block_normal(probe_direction, probe_distance)
    if ray_normal.length() >= MIN_VECTOR_LENGTH:
        return ray_normal
    var shape_normal: Vector3 = _get_shape_obstacle_block_normal(probe_direction, speed_abs, probe_distance)
    if shape_normal.length() >= MIN_VECTOR_LENGTH:
        return shape_normal
    var contact_normal: Vector3 = _get_contact_obstacle_block_normal(probe_direction)
    if contact_normal.length() >= MIN_VECTOR_LENGTH:
        return contact_normal
    return Vector3.ZERO


func _get_ray_obstacle_block_normal(probe_direction: Vector3, probe_distance: float) -> Vector3:
    var best_normal: Vector3 = Vector3.ZERO
    var best_opposition: float = 0.0
    var probe_heights: Array[float] = [0.72, 1.45, 2.35]
    var probe_side_offsets: Array[float] = [-0.46, 0.0, 0.46]
    for probe_height: float in probe_heights:
        for side_offset: float in probe_side_offsets:
            var from_position: Vector3 = global_position + _smoothed_ground_up * probe_height + _bike_right * side_offset
            var to_position: Vector3 = from_position + probe_direction * probe_distance
            var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_position, to_position, 1)
            query.exclude = [get_rid()]
            query.hit_from_inside = true
            var ray_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
            if ray_result.is_empty():
                continue
            var hit_normal: Vector3 = ray_result["normal"] as Vector3
            if hit_normal.length() < MIN_VECTOR_LENGTH:
                hit_normal = -probe_direction
            else:
                hit_normal = hit_normal.normalized()
            if hit_normal.dot(_smoothed_ground_up) > obstacle_wall_normal_max_up:
                continue
            var opposition: float = -hit_normal.dot(probe_direction)
            if opposition > best_opposition and opposition > 0.18:
                best_opposition = opposition
                best_normal = hit_normal
    return best_normal


func _get_shape_obstacle_block_normal(probe_direction: Vector3, speed_abs: float, ray_probe_distance: float) -> Vector3:
    if _obstacle_rider_probe_shape == null:
        return Vector3.ZERO
    var shape_probe_distance: float = clampf(0.75 + speed_abs * 0.035, 0.85, minf(ray_probe_distance, 2.2))
    var local_probe_transform: Transform3D = Transform3D(Basis.IDENTITY, Vector3(0.0, 2.1, 0.12))
    var shape_transform: Transform3D = global_transform * local_probe_transform
    var query: PhysicsShapeQueryParameters3D = PhysicsShapeQueryParameters3D.new()
    query.shape = _obstacle_rider_probe_shape
    query.transform = shape_transform
    query.motion = probe_direction * shape_probe_distance
    query.collision_mask = 1
    query.exclude = [get_rid()]
    query.collide_with_bodies = true
    query.collide_with_areas = false

    var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var cast_result: PackedFloat32Array = space_state.cast_motion(query)
    var hit_detected: bool = false
    var sample_origin: Vector3 = shape_transform.origin + probe_direction * shape_probe_distance
    if cast_result.size() >= 2 and cast_result[1] < 1.0:
        hit_detected = true
        var unsafe_fraction: float = cast_result[1]
        sample_origin = shape_transform.origin + probe_direction * (shape_probe_distance * unsafe_fraction)
        query.motion = Vector3.ZERO
        query.transform = _translated_transform(shape_transform, probe_direction * (shape_probe_distance * unsafe_fraction))
        var rest_normal: Vector3 = _get_wall_normal_from_rest_info(space_state.get_rest_info(query), probe_direction)
        if rest_normal.length() >= MIN_VECTOR_LENGTH:
            return rest_normal
    else:
        query.motion = Vector3.ZERO
        query.transform = shape_transform
        var current_rest_normal: Vector3 = _get_wall_normal_from_rest_info(space_state.get_rest_info(query), probe_direction)
        if current_rest_normal.length() >= MIN_VECTOR_LENGTH:
            return current_rest_normal
        var current_hits: Array[Dictionary] = space_state.intersect_shape(query, 4)
        if not current_hits.is_empty():
            hit_detected = true
            sample_origin = shape_transform.origin

    if not hit_detected:
        return Vector3.ZERO

    var sampled_normal: Vector3 = _sample_obstacle_surface_normal(sample_origin, probe_direction)
    if sampled_normal.length() >= MIN_VECTOR_LENGTH:
        return sampled_normal
    var nearby_normal: Vector3 = _sample_nearby_obstacle_normal(probe_direction)
    if nearby_normal.length() >= MIN_VECTOR_LENGTH:
        return nearby_normal
    return Vector3.ZERO


func _translated_transform(source_transform: Transform3D, offset: Vector3) -> Transform3D:
    var shifted_transform: Transform3D = source_transform
    shifted_transform.origin += offset
    return shifted_transform


func _get_wall_normal_from_rest_info(rest_info: Dictionary, probe_direction: Vector3) -> Vector3:
    if rest_info.is_empty() or not rest_info.has("normal"):
        return Vector3.ZERO
    var rest_normal: Vector3 = rest_info["normal"] as Vector3
    if rest_normal.length() < MIN_VECTOR_LENGTH:
        return Vector3.ZERO
    rest_normal = rest_normal.normalized()
    if rest_normal.dot(_smoothed_ground_up) > obstacle_wall_normal_max_up:
        return Vector3.ZERO
    if -rest_normal.dot(probe_direction) < 0.08:
        return Vector3.ZERO
    return rest_normal


func _sample_obstacle_surface_normal(sample_origin: Vector3, probe_direction: Vector3) -> Vector3:
    var best_normal: Vector3 = Vector3.ZERO
    var best_opposition: float = 0.0
    var sample_offsets: Array[Vector3] = [
        Vector3.ZERO,
        _smoothed_ground_up * 0.45,
        -_smoothed_ground_up * 0.35,
        _bike_right * 0.48,
        -_bike_right * 0.48
    ]
    for sample_offset: Vector3 in sample_offsets:
        var from_position: Vector3 = sample_origin + sample_offset - probe_direction * 0.35
        var to_position: Vector3 = sample_origin + sample_offset + probe_direction * 1.15
        var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_position, to_position, 1)
        query.exclude = [get_rid()]
        query.hit_from_inside = true
        var ray_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
        if ray_result.is_empty():
            continue
        var hit_normal: Vector3 = ray_result["normal"] as Vector3
        if hit_normal.length() < MIN_VECTOR_LENGTH:
            continue
        hit_normal = hit_normal.normalized()
        if hit_normal.dot(_smoothed_ground_up) > obstacle_wall_normal_max_up:
            continue
        var opposition: float = -hit_normal.dot(probe_direction)
        if opposition > best_opposition and opposition > 0.12:
            best_opposition = opposition
            best_normal = hit_normal
    return best_normal


func _sample_nearby_obstacle_normal(probe_direction: Vector3) -> Vector3:
    var best_normal: Vector3 = Vector3.ZERO
    var best_opposition: float = 0.0
    var sample_heights: Array[float] = [0.82, 1.45, 2.22]
    var cast_directions: Array[Vector3] = [
        probe_direction,
        -probe_direction,
        _bike_right,
        -_bike_right,
        (probe_direction + _bike_right).normalized(),
        (probe_direction - _bike_right).normalized(),
        (-probe_direction + _bike_right).normalized(),
        (-probe_direction - _bike_right).normalized()
    ]
    for sample_height: float in sample_heights:
        var center_position: Vector3 = global_position + _smoothed_ground_up * sample_height
        for cast_direction: Vector3 in cast_directions:
            if cast_direction.length() < MIN_VECTOR_LENGTH:
                continue
            cast_direction = cast_direction.normalized()
            var from_position: Vector3 = center_position - cast_direction * 2.35
            var to_position: Vector3 = center_position + cast_direction * 2.35
            var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(from_position, to_position, 1)
            query.exclude = [get_rid()]
            query.hit_from_inside = true
            query.hit_back_faces = true
            var ray_result: Dictionary = get_world_3d().direct_space_state.intersect_ray(query)
            if ray_result.is_empty():
                continue
            var hit_normal: Vector3 = ray_result["normal"] as Vector3
            if hit_normal.length() < MIN_VECTOR_LENGTH:
                continue
            hit_normal = hit_normal.normalized()
            if hit_normal.dot(_smoothed_ground_up) > obstacle_wall_normal_max_up:
                continue
            var opposition: float = -hit_normal.dot(probe_direction)
            if opposition > best_opposition and opposition > 0.06:
                best_opposition = opposition
                best_normal = hit_normal
    return best_normal


func _get_contact_obstacle_block_normal(probe_direction: Vector3) -> Vector3:
    if not _has_blocking_body_contact(probe_direction):
        return Vector3.ZERO
    return _sample_nearby_obstacle_normal(probe_direction)


func _has_blocking_body_contact(probe_direction: Vector3) -> bool:
    if get_contact_count() <= 0:
        return false
    var planar_velocity: Vector3 = linear_velocity - _smoothed_ground_up * linear_velocity.dot(_smoothed_ground_up)
    if planar_velocity.dot(probe_direction) > 5.0:
        return false
    var colliding_bodies: Array = get_colliding_bodies()
    if colliding_bodies.is_empty():
        return true
    for body_value: Variant in colliding_bodies:
        var collision_object: CollisionObject3D = body_value as CollisionObject3D
        if collision_object == null:
            continue
        if (collision_object.collision_layer & 1) != 0:
            return true
    return false


func _apply_aero_downforce() -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    if horizontal_speed <= 2.0:
        return
    apply_central_force(-_smoothed_ground_up * horizontal_speed * horizontal_speed * aero_downforce)


func _limit_unstable_velocity() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var active_speed_limit: float = _get_active_forward_speed_limit()
    if horizontal_velocity.length() > active_speed_limit:
        var capped_horizontal: Vector3 = horizontal_velocity.normalized() * active_speed_limit
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
    if boost_fx_fov_enabled:
        target_fov += boost_fov_bonus * _get_boost_effect_strength()
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
    _update_drift_sparks(delta)
    _update_boost_effects(delta)


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
        "yaw_rate": _yaw_rate,
        "is_drifting": _is_drifting,
        "drift_time": _drift_time,
        "drift_ready": _drift_time >= drift_charge_duration,
        "boost_time_remaining": _boost_time_remaining,
        "obstacle_blocked": _obstacle_blocked,
        "obstacle_block_normal": _obstacle_block_normal
    }


func _update_hop_drift(steer_input: float, hop_drift_pressed: bool, delta: float) -> void:
    if _boost_time_remaining > 0.0:
        _boost_time_remaining = maxf(_boost_time_remaining - delta, 0.0)
    if _boost_time_remaining > 0.0:
        if _is_drifting:
            _finish_drift(false)
        _boost_hop_drift_lockout = _boost_hop_drift_lockout or hop_drift_pressed
        _was_hop_drift_pressed = hop_drift_pressed
        return
    if _boost_hop_drift_lockout:
        if not hop_drift_pressed:
            _boost_hop_drift_lockout = false
        _was_hop_drift_pressed = hop_drift_pressed
        return
    var just_pressed: bool = hop_drift_pressed and not _was_hop_drift_pressed
    var just_released: bool = not hop_drift_pressed and _was_hop_drift_pressed
    var speed_abs: float = absf(_drive_speed)
    if just_pressed and _grounded_wheel_count > 0 and speed_abs >= min_drift_speed * 0.35:
        linear_velocity += _smoothed_ground_up * hop_impulse
    if hop_drift_pressed and absf(steer_input) > 0.1 and speed_abs >= min_drift_speed:
        var steer_direction: float = signf(steer_input)
        if not _is_drifting:
            _start_drift(steer_direction)
        else:
            _drift_direction = steer_direction
        _drift_time += delta
    elif _is_drifting:
        _finish_drift(just_released and _drift_time >= drift_charge_duration)
    _was_hop_drift_pressed = hop_drift_pressed


func _start_drift(direction: float) -> void:
    _is_drifting = true
    _drift_time = 0.0
    _drift_direction = direction if absf(direction) > 0.1 else 1.0


func _finish_drift(apply_boost: bool) -> void:
    if apply_boost:
        _trigger_drift_boost()
    _is_drifting = false
    _drift_time = 0.0
    _drift_direction = 0.0


func _trigger_drift_boost() -> void:
    if _boost_time_remaining > 0.0:
        return
    _boost_time_remaining = boost_duration
    _boost_effect_time = 0.0
    _boost_hop_drift_lockout = false
    _drive_speed = minf(_get_active_forward_speed_limit(), maxf(_drive_speed, max_forward_speed + boost_speed_bonus * 0.45))


func _get_active_forward_speed_limit() -> float:
    if _boost_time_remaining > 0.0:
        return max_forward_speed + boost_speed_bonus
    return max_forward_speed


func _get_boost_effect_strength() -> float:
    if _boost_time_remaining <= 0.0:
        return 0.0
    return clampf(_boost_time_remaining / maxf(boost_duration, 0.001), 0.0, 1.0)


func _create_boost_effects() -> void:
    _create_boost_wind_streaks()


func _create_boost_wind_streaks() -> void:
    _boost_wind_material = _make_boost_material(Color(0.76, 0.94, 1.0, 0.52), true)
    for streak_index: int in range(10):
        var streak: MeshInstance3D = MeshInstance3D.new()
        streak.name = "BoostWindStreak%d" % streak_index
        streak.top_level = true
        streak.visible = false
        var streak_mesh: BoxMesh = BoxMesh.new()
        streak_mesh.size = Vector3(0.06, 0.06, 3.2)
        streak.mesh = streak_mesh
        streak.material_override = _boost_wind_material
        add_child(streak)
        _boost_wind_streaks.append(streak)


func _make_boost_material(color: Color, use_no_depth: bool) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.no_depth_test = use_no_depth
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _update_boost_effects(delta: float) -> void:
    var boost_active: bool = _boost_time_remaining > 0.0
    if boost_active:
        _boost_effect_time += delta
    else:
        _boost_effect_time = 0.0
    _update_boost_wind_streaks(boost_active)


func _update_boost_wind_streaks(boost_active: bool) -> void:
    var active: bool = boost_active and boost_fx_wind_enabled
    var effect_basis: Basis = _get_boost_effect_basis()
    for streak_index: int in range(_boost_wind_streaks.size()):
        var streak: MeshInstance3D = _boost_wind_streaks[streak_index]
        streak.visible = active
        if not active:
            continue
        var row: float = floorf(float(streak_index) * 0.5)
        var side: float = -1.0 if streak_index % 2 == 0 else 1.0
        var cycle: float = fmod(_boost_effect_time * 4.2 + row * 0.17, 1.0)
        var height: float = 0.28 + fmod(row, 3.0) * 0.24
        var side_offset: float = side * (0.72 + row * 0.11)
        var trail_offset: float = 0.5 + cycle * 3.2
        streak.global_transform = Transform3D(effect_basis, global_position + _bike_right * side_offset + _smoothed_ground_up * height - _bike_forward * trail_offset)
        streak.scale = Vector3(1.0, 1.0, 0.65 + absf(sin(_boost_effect_time * 9.0 + float(streak_index) * 0.71)) * 0.55)


func _get_boost_effect_basis() -> Basis:
    return Basis(_bike_right.normalized(), _smoothed_ground_up.normalized(), _bike_forward.normalized()).orthonormalized()


func _hide_mesh_nodes(nodes: Array[MeshInstance3D]) -> void:
    for mesh_node: MeshInstance3D in nodes:
        mesh_node.visible = false


func _create_debug_sliders() -> void:
    if not show_debug_sliders:
        return

    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "DebugTuningSliders"
    canvas.layer = 100
    add_child(canvas)

    var panel: PanelContainer = PanelContainer.new()
    panel.name = "Panel"
    panel.position = Vector2(16.0, 16.0)
    panel.custom_minimum_size = Vector2(360.0, 270.0)
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    canvas.add_child(panel)

    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 12)
    margin.add_theme_constant_override("margin_top", 10)
    margin.add_theme_constant_override("margin_right", 12)
    margin.add_theme_constant_override("margin_bottom", 10)
    panel.add_child(margin)

    var root: VBoxContainer = VBoxContainer.new()
    root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margin.add_child(root)

    var title_label: Label = Label.new()
    title_label.text = "Debug Tuning"
    root.add_child(title_label)

    _debug_max_speed_value_label = _create_debug_slider_row(root, "Max speed", 8.0, 90.0, 1.0, max_forward_speed, Callable(self, "_on_debug_max_speed_changed"))
    _debug_acceleration_value_label = _create_debug_slider_row(root, "Acceleration", 1.0, 80.0, 0.5, engine_acceleration, Callable(self, "_on_debug_acceleration_changed"))
    _debug_lean_value_label = _create_debug_slider_row(root, "Side lean", 0.0, 75.0, 1.0, rad_to_deg(max_lean), Callable(self, "_on_debug_lean_changed"))
    _update_debug_slider_labels()

    var boost_fx_label: Label = Label.new()
    boost_fx_label.text = "Boost FX"
    root.add_child(boost_fx_label)
    _create_debug_toggle(root, "FOV kick", boost_fx_fov_enabled, Callable(self, "_on_debug_boost_fov_toggled"))
    _create_debug_toggle(root, "Light wind streaks", boost_fx_wind_enabled, Callable(self, "_on_debug_boost_wind_toggled"))

    var test_boost_button: Button = Button.new()
    test_boost_button.text = "Test boost"
    test_boost_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    test_boost_button.pressed.connect(Callable(self, "_on_debug_test_boost_pressed"))
    root.add_child(test_boost_button)


func _create_debug_slider_row(parent: VBoxContainer, title: String, min_value: float, max_value: float, step: float, initial_value: float, value_changed_callback: Callable) -> Label:
    var row: VBoxContainer = VBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(row)

    var label_row: HBoxContainer = HBoxContainer.new()
    row.add_child(label_row)

    var name_label: Label = Label.new()
    name_label.text = title
    name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label_row.add_child(name_label)

    var value_label: Label = Label.new()
    value_label.custom_minimum_size = Vector2(70.0, 0.0)
    value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    label_row.add_child(value_label)

    var slider: HSlider = HSlider.new()
    slider.min_value = min_value
    slider.max_value = max_value
    slider.step = step
    slider.value = initial_value
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    slider.value_changed.connect(value_changed_callback)
    row.add_child(slider)

    return value_label


func _create_debug_toggle(parent: VBoxContainer, title: String, initial_value: bool, toggled_callback: Callable) -> void:
    var checkbox: CheckBox = CheckBox.new()
    checkbox.text = title
    checkbox.button_pressed = initial_value
    checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    checkbox.toggled.connect(toggled_callback)
    parent.add_child(checkbox)


func _on_debug_max_speed_changed(value: float) -> void:
    max_forward_speed = value
    _drive_speed = clampf(_drive_speed, -max_reverse_speed, _get_active_forward_speed_limit())
    _update_debug_slider_labels()


func _on_debug_acceleration_changed(value: float) -> void:
    engine_acceleration = value
    _update_debug_slider_labels()


func _on_debug_lean_changed(value: float) -> void:
    max_lean = deg_to_rad(value)
    _target_lean_angle = clampf(_target_lean_angle, -max_lean, max_lean)
    _visual_lean_angle = clampf(_visual_lean_angle, -max_lean, max_lean)
    _update_debug_slider_labels()


func _on_debug_boost_fov_toggled(toggled_on: bool) -> void:
    boost_fx_fov_enabled = toggled_on


func _on_debug_boost_wind_toggled(toggled_on: bool) -> void:
    boost_fx_wind_enabled = toggled_on
    if not toggled_on:
        _hide_mesh_nodes(_boost_wind_streaks)


func _on_debug_test_boost_pressed() -> void:
    _trigger_drift_boost()


func _update_debug_slider_labels() -> void:
    if _debug_max_speed_value_label != null:
        _debug_max_speed_value_label.text = "%.0f u/s" % max_forward_speed
    if _debug_acceleration_value_label != null:
        _debug_acceleration_value_label.text = "%.1f u/s2" % engine_acceleration
    if _debug_lean_value_label != null:
        _debug_lean_value_label.text = "%.0f deg" % rad_to_deg(max_lean)


func _create_drift_sparks() -> void:
    _spark_white_material = _make_spark_material(Color(0.92, 0.98, 1.0, 1.0))
    _spark_gold_material = _make_spark_material(Color(1.0, 0.68, 0.12, 1.0))
    for spark_index: int in range(12):
        var spark: MeshInstance3D = MeshInstance3D.new()
        spark.name = "DriftSpark%d" % spark_index
        spark.top_level = true
        spark.visible = false
        var spark_mesh: BoxMesh = BoxMesh.new()
        spark_mesh.size = Vector3(0.10, 0.10, 0.10)
        spark.mesh = spark_mesh
        spark.material_override = _spark_white_material
        add_child(spark)
        _drift_spark_nodes.append(spark)


func _make_spark_material(color: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = color
    material.roughness = 0.22
    return material


func _update_drift_sparks(delta: float) -> void:
    _spark_phase += delta * 18.0
    var sparks_active: bool = _is_drifting
    var charged: bool = _drift_time >= drift_charge_duration
    for spark_index: int in range(_drift_spark_nodes.size()):
        var spark: MeshInstance3D = _drift_spark_nodes[spark_index]
        spark.visible = sparks_active
        if not sparks_active:
            continue
        spark.material_override = _spark_gold_material if charged else _spark_white_material
        var side: float = -1.0 if spark_index % 2 == 0 else 1.0
        var lane: float = float(spark_index) * 0.5
        var phase: float = _spark_phase + float(spark_index) * 0.73
        var base_position: Vector3 = _rear_wheel_tire.global_position - _bike_forward * 0.42 + _bike_right * side * 0.34
        var spray_offset: Vector3 = -_bike_forward * (0.12 + lane * 0.045) + _bike_right * side * (0.04 + absf(sin(phase)) * 0.18) + _smoothed_ground_up * (0.04 + absf(cos(phase * 1.7)) * 0.12)
        spark.global_position = base_position + spray_offset
        var pulse_scale: float = 0.55 + absf(sin(phase * 1.9)) * 0.55
        spark.scale = Vector3.ONE * pulse_scale


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
    var static_body: StaticBody3D = scene_root.get_node_or_null(WORLD_COLLIDER_NAME) as StaticBody3D
    if static_body == null:
        static_body = StaticBody3D.new()
        static_body.name = WORLD_COLLIDER_NAME
        static_body.collision_layer = 1
        static_body.collision_mask = 0
        scene_root.add_child(static_body)
        _add_mesh_colliders(scene_root, static_body)
    _enable_concave_backface_collision(static_body)
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


func _enable_concave_backface_collision(static_body: StaticBody3D) -> void:
    for child: Node in static_body.get_children():
        var collision_shape: CollisionShape3D = child as CollisionShape3D
        if collision_shape == null:
            continue
        var concave_shape: ConcavePolygonShape3D = collision_shape.shape as ConcavePolygonShape3D
        if concave_shape != null:
            concave_shape.backface_collision = true


func _add_mesh_colliders(node: Node, static_body: StaticBody3D) -> void:
    if node == self or node == static_body:
        return
    if node is MeshInstance3D:
        var mesh_instance: MeshInstance3D = node as MeshInstance3D
        if not _is_descendant_of(mesh_instance, self) and mesh_instance.mesh != null:
            var shape: Shape3D = mesh_instance.mesh.create_trimesh_shape()
            var concave_shape: ConcavePolygonShape3D = shape as ConcavePolygonShape3D
            if concave_shape != null:
                concave_shape.backface_collision = true
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


func _is_hop_drift_pressed() -> bool:
    return _raw_hop_drift_pressed or Input.is_action_pressed("hop_drift") or Input.is_physical_key_pressed(KEY_SPACE) or Input.is_key_pressed(KEY_SPACE)


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
