class_name HybridSuspensionMotorcycleController
extends RigidBody3D

const TRACK_LIFT = 0.28
const TERRAIN_X_FREQUENCY = 0.075
const TERRAIN_Z_FREQUENCY = 0.061
const TERRAIN_DIAGONAL_FREQUENCY = 0.18
const TERRAIN_CROSS_FREQUENCY = 0.13
const WORLD_COLLIDER_NAME = "GeneratedTrackCollision"

@export var engine_force: float = 3400.0
@export var brake_force: float = 680.0
@export var reverse_force: float = 260.0
@export var max_forward_speed: float = 70.0
@export var max_reverse_speed: float = 10.0
@export var suspension_rest_length: float = 0.44
@export var suspension_stiffness: float = 9000.0
@export var suspension_compression_damping: float = 1550.0
@export var suspension_rebound_damping: float = 2450.0
@export var suspension_max_force: float = 6500.0
@export var tire_lateral_grip: float = 3.0
@export var tire_longitudinal_grip: float = 1.65
@export var tire_response: float = 0.42
@export var rolling_resistance: float = 10.0
@export var air_drag: float = 0.24
@export var aero_downforce: float = 0.28
@export var upright_stability: float = 180.0
@export var angular_stability_damping: float = 130.0
@export var max_front_steer: float = 0.32
@export var max_lean: float = 0.785398
@export var visual_smoothing: float = 10.0
@export var max_angular_speed: float = 7.0
@export var max_vertical_speed: float = 12.0
@export var rear_wheel_radius: float = 0.60
@export var front_wheel_radius: float = 0.52
@export var lean_torque: float = 9000.0
@export var lean_turn_response: float = 1.25
@export var max_lateral_accel: float = 16.0
@export var countersteer_roll_torque: float = 900.0
@export var camera_base_fov: float = 70.0
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
var _smoothed_steer_input: float = 0.0
var _smoothed_lean_target: float = 0.0
var _smoothed_ground_up: Vector3 = Vector3.UP
var _raw_forward_pressed: bool = false
var _raw_reverse_pressed: bool = false
var _raw_left_pressed: bool = false
var _raw_right_pressed: bool = false
var _camera_look_active: bool = false
var _camera_orbit_yaw: float = 0.0
var _camera_orbit_pitch: float = 0.0
var _camera_mouse_sensitivity: float = 0.006
var _physics_setup_complete: bool = false
var _mesh_ground_ready: bool = false
var _front_contact_shadow: MeshInstance3D = null
var _rear_contact_shadow: MeshInstance3D = null

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
    _camera.top_level = true
    _camera.current = true
    _cache_visual_rest_pose()
    _create_debug_sliders()
    call_deferred("_finish_physics_setup")


func _finish_physics_setup() -> void:
    _create_world_collision()
    _make_world_meshes_double_sided(get_tree().current_scene)
    _create_contact_shadows()
    _mesh_ground_ready = true
    _configure_frame_body()
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
    var reverse_only: bool = brake_pressed and not throttle_pressed and absf(steer_input) <= 0.01
    _update_front_steering(steer_input, delta)
    _apply_suspension_and_tire_forces(throttle_pressed, brake_pressed)
    _apply_balance_assist(_smoothed_steer_input, reverse_only, delta)
    _apply_lean_turning(delta)
    _apply_body_drag()
    _apply_aero_stabilization()
    _apply_airborne_fall_force()
    _limit_unstable_velocity()
    _update_camera_orbit()
    _update_camera_fov(delta)
    _update_visuals(delta)


func _configure_frame_body() -> void:
    mass = 210.0
    continuous_cd = true
    linear_damp = 0.08
    angular_damp = 2.2
    collision_layer = 2
    collision_mask = 0
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector3(0.0, 0.12, 0.05)
    var front_world_position: Vector3 = global_transform * _front_wheel_local_rest
    var rear_world_position: Vector3 = global_transform * _rear_wheel_local_rest
    var front_ground_y: float = _get_ground_height(front_world_position)
    var rear_ground_y: float = _get_ground_height(rear_world_position)
    var static_compression: float = _get_nominal_static_compression(0.52)
    var front_body_y: float = front_ground_y + front_wheel_radius - _front_wheel_local_rest.y + static_compression * 0.35
    var rear_body_y: float = rear_ground_y + rear_wheel_radius - _rear_wheel_local_rest.y + static_compression * 0.35
    global_position.y = minf(front_body_y, rear_body_y)
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO


func _apply_suspension_and_tire_forces(throttle_pressed: bool, brake_pressed: bool) -> void:
    _grounded_wheel_count = 0
    _front_suspension_compression = _apply_single_wheel_force(
            _front_wheel_local_rest,
            front_wheel_radius,
            true,
            0.0,
            0.58,
            throttle_pressed,
            brake_pressed,
            0.52)
    _rear_suspension_compression = _apply_single_wheel_force(
            _rear_wheel_local_rest,
            rear_wheel_radius,
            false,
            1.0,
            0.42,
            throttle_pressed,
            brake_pressed,
            0.48)


func _apply_single_wheel_force(
        wheel_local_rest: Vector3,
        wheel_radius: float,
        is_front: bool,
        drive_split: float,
        brake_split: float,
        throttle_pressed: bool,
        brake_pressed: bool,
        load_share: float) -> float:
    var static_compression: float = _get_nominal_static_compression(load_share)
    var mount_local: Vector3 = wheel_local_rest + Vector3.UP * (suspension_rest_length - static_compression)
    var mount_position: Vector3 = global_transform * mount_local
    var ray_result: Dictionary = _raycast_ground(mount_position)
    if _mesh_ground_ready and ray_result.is_empty():
        return 0.0
    var normal: Vector3 = Vector3.UP
    var ground_y: float = 0.0
    if ray_result.is_empty():
        normal = _get_ground_normal(mount_position)
        ground_y = _get_ground_height(mount_position)
    else:
        normal = ray_result["normal"] as Vector3
        var ground_position: Vector3 = ray_result["position"] as Vector3
        ground_y = ground_position.y
    if normal.dot(Vector3.UP) < 0.72:
        normal = Vector3.UP
    normal = normal.slerp(Vector3.UP, 0.18).normalized()
    var distance_to_ground: float = mount_position.y - ground_y - wheel_radius
    var compression: float = clampf(suspension_rest_length - distance_to_ground, 0.0, suspension_rest_length)
    if compression <= 0.0:
        return 0.0
    _grounded_wheel_count += 1

    var contact_point: Vector3 = Vector3(mount_position.x, ground_y, mount_position.z)
    var relative_position: Vector3 = contact_point - global_position
    var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(relative_position)
    var normal_speed: float = point_velocity.dot(normal)
    var damping: float = suspension_compression_damping if normal_speed < 0.0 else suspension_rebound_damping
    var suspension_force: float = compression * suspension_stiffness - normal_speed * damping
    suspension_force = clampf(suspension_force, 0.0, suspension_max_force)
    if suspension_force <= 0.0:
        return compression

    apply_force(normal * suspension_force, relative_position)

    var steer_angle: float = _front_steer_angle if is_front else 0.0
    var wheel_forward: Vector3 = -global_transform.basis.z.rotated(normal, steer_angle).normalized()
    var wheel_right: Vector3 = wheel_forward.cross(normal).normalized()
    wheel_forward = normal.cross(wheel_right).normalized()
    var normal_load: float = maxf(suspension_force, mass * 9.8 * load_share * 0.2)

    var lateral_speed: float = point_velocity.dot(wheel_right)
    var lateral_force: Vector3 = _clamp_vector_length(
            -wheel_right * lateral_speed * tire_response * mass * load_share,
            normal_load * tire_lateral_grip)
    apply_force(lateral_force, relative_position)

    var forward_speed: float = point_velocity.dot(wheel_forward)
    var drive_force: float = 0.0
    if throttle_pressed and forward_speed < max_forward_speed:
        drive_force += engine_force * drive_split
    if brake_pressed:
        if forward_speed > 0.5:
            drive_force -= brake_force * brake_split
        elif forward_speed > -max_reverse_speed:
            drive_force -= reverse_force * drive_split
    var rolling_force: float = -forward_speed * rolling_resistance
    var longitudinal_force: Vector3 = _clamp_vector_length(
            wheel_forward * (drive_force + rolling_force),
            normal_load * tire_longitudinal_grip)
    apply_force(longitudinal_force, relative_position)
    return compression


func _get_nominal_static_compression(load_share: float) -> float:
    var supported_weight: float = mass * 9.8 * load_share
    return clampf(supported_weight / maxf(suspension_stiffness, 1.0), 0.02, suspension_rest_length * 0.65)


func _update_front_steering(steer_input: float, delta: float) -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    var input_weight: float = 1.0 - exp(-8.5 * delta)
    _smoothed_steer_input = lerpf(_smoothed_steer_input, steer_input, input_weight)
    var speed_factor: float = clampf((horizontal_speed - 3.0) / 15.0, 0.0, 1.0)
    var direct_steer: float = -_smoothed_steer_input * max_front_steer * (1.0 - speed_factor)
    var lean_angle: float = _get_body_lean_angle(_smoothed_ground_up)
    var lean_ratio: float = clampf(absf(lean_angle) / maxf(_get_safe_max_lean(), 0.01), 0.0, 1.0)
    var self_aligned_steer: float = -signf(lean_angle) * max_front_steer * 0.035 * lean_ratio * speed_factor
    _front_steer_angle = direct_steer + self_aligned_steer


func _apply_lean_turning(delta: float) -> void:
    if _grounded_wheel_count <= 0:
        return
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var speed: float = horizontal_velocity.length()
    if speed <= 2.0:
        return
    var lean_angle: float = _get_body_lean_angle(_smoothed_ground_up)
    if absf(lean_angle) <= 0.01:
        return
    var lateral_accel: float = minf(absf(tan(lean_angle)) * 9.8 * lean_turn_response, max_lateral_accel)
    var turn_sign: float = -signf(lean_angle)
    var target_yaw_velocity: float = turn_sign * lateral_accel / maxf(speed, 0.1)
    var yaw_velocity: float = angular_velocity.dot(Vector3.UP)
    var speed_factor: float = clampf(speed / 24.0, 0.0, 1.0)
    var frame_response: float = clampf(delta * 60.0, 0.5, 1.5)
    var yaw_tracking: float = angular_stability_damping * lerpf(1.1, 3.2, speed_factor) * frame_response
    apply_torque(Vector3.UP * (target_yaw_velocity - yaw_velocity) * yaw_tracking)

    var lateral_direction: Vector3 = Vector3.UP.cross(horizontal_velocity).normalized() * turn_sign
    apply_central_force(lateral_direction * lateral_accel * mass)


func _apply_body_drag() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var speed: float = horizontal_velocity.length()
    if speed <= 0.01:
        return
    apply_central_force(-horizontal_velocity.normalized() * speed * speed * air_drag)


func _apply_aero_stabilization() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var speed: float = horizontal_velocity.length()
    if speed <= 2.0:
        return
    var ground_up: Vector3 = _get_ground_normal(global_position)
    if ground_up.dot(Vector3.UP) < 0.72:
        ground_up = Vector3.UP
    apply_central_force(-ground_up.normalized() * speed * speed * aero_downforce)


func _apply_airborne_fall_force() -> void:
    if _grounded_wheel_count > 0:
        return
    apply_central_force(Vector3.DOWN * mass * 22.0)


func _limit_unstable_velocity() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    if horizontal_velocity.length() > max_forward_speed:
        var capped_horizontal: Vector3 = horizontal_velocity.normalized() * max_forward_speed
        linear_velocity.x = capped_horizontal.x
        linear_velocity.z = capped_horizontal.z
    linear_velocity.y = clampf(linear_velocity.y, -max_vertical_speed, max_vertical_speed)
    if angular_velocity.length() > max_angular_speed:
        angular_velocity = angular_velocity.normalized() * max_angular_speed


func _update_camera_orbit() -> void:
    var body_forward: Vector3 = -global_transform.basis.z
    var flat_forward: Vector3 = Vector3(body_forward.x, 0.0, body_forward.z)
    if flat_forward.length() < 0.001:
        flat_forward = Vector3.FORWARD
    flat_forward = flat_forward.normalized().rotated(Vector3.UP, _camera_orbit_yaw).normalized()
    var look_target: Vector3 = global_position + flat_forward * 3.75 + Vector3.UP * 0.25
    var camera_position: Vector3 = global_position - flat_forward * 6.5 + Vector3.UP * (8.0 + _camera_orbit_pitch * 2.5)
    _camera_rig.global_position = global_position + Vector3.UP * 1.2
    _camera.global_position = camera_position
    _camera.look_at(look_target, Vector3.UP)


func _update_camera_fov(delta: float) -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    var speed_ratio: float = clampf(horizontal_speed / maxf(max_forward_speed, 0.001), 0.0, 1.0)
    var target_fov: float = camera_base_fov + camera_speed_fov_boost * speed_ratio
    var fov_weight: float = clampf(visual_smoothing * delta, 0.0, 1.0)
    _camera.fov = lerpf(_camera.fov, target_fov, fov_weight)


func _create_debug_sliders() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "VehicleDebugCanvas"
    add_child(canvas)
    var panel: PanelContainer = PanelContainer.new()
    panel.name = "VehicleDebugPanel"
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.offset_left = -350.0
    panel.offset_top = 16.0
    panel.offset_right = -16.0
    panel.offset_bottom = 455.0
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    canvas.add_child(panel)
    var margin: MarginContainer = MarginContainer.new()
    margin.add_theme_constant_override("margin_left", 10)
    margin.add_theme_constant_override("margin_top", 8)
    margin.add_theme_constant_override("margin_right", 10)
    margin.add_theme_constant_override("margin_bottom", 8)
    panel.add_child(margin)
    var box: VBoxContainer = VBoxContainer.new()
    box.add_theme_constant_override("separation", 6)
    margin.add_child(box)
    _add_debug_slider(box, "Top Speed", "max_forward_speed", max_forward_speed, 8.0, 70.0, 1.0)
    _add_debug_slider(box, "Acceleration", "engine_force", engine_force, 80.0, 3600.0, 10.0)
    _add_debug_slider(box, "Weight", "mass", mass, 60.0, 500.0, 5.0)
    _add_debug_slider(box, "Suspension", "suspension_stiffness", suspension_stiffness, 3000.0, 16000.0, 100.0)
    _add_debug_slider(box, "Compression", "suspension_compression_damping", suspension_compression_damping, 200.0, 4000.0, 50.0)
    _add_debug_slider(box, "Rebound", "suspension_rebound_damping", suspension_rebound_damping, 200.0, 6000.0, 50.0)
    _add_debug_slider(box, "Traction", "tire_lateral_grip", tire_lateral_grip, 0.25, 5.0, 0.05)
    _add_debug_slider(box, "Downforce", "aero_downforce", aero_downforce, 0.0, 1.6, 0.02)
    _add_debug_slider(box, "Max Lean", "max_lean_degrees", rad_to_deg(max_lean), 0.0, 85.0, 1.0)
    _add_debug_slider(box, "Lean Speed", "lean_torque", lean_torque, 100.0, 20000.0, 100.0)
    _add_debug_slider(box, "Lean Turn", "lean_turn_response", lean_turn_response, 0.5, 3.0, 0.05)
    _add_debug_slider(box, "Camera FOV", "camera_base_fov", camera_base_fov, 40.0, 110.0, 1.0)
    _add_debug_slider(box, "Speed FOV", "camera_speed_fov_boost", camera_speed_fov_boost, 0.0, 60.0, 1.0)


func _add_debug_slider(parent: VBoxContainer, title: String, property_name: String, current_value: float, minimum: float, maximum: float, step: float) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)
    var name_label: Label = Label.new()
    name_label.text = title
    name_label.custom_minimum_size = Vector2(98.0, 0.0)
    row.add_child(name_label)
    var slider: HSlider = HSlider.new()
    slider.min_value = minimum
    slider.max_value = maximum
    slider.step = step
    slider.value = current_value
    slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(slider)
    var value_label: Label = Label.new()
    value_label.text = _format_slider_value(current_value)
    value_label.custom_minimum_size = Vector2(62.0, 0.0)
    row.add_child(value_label)
    slider.value_changed.connect(_on_debug_slider_changed.bind(property_name, value_label))


func _on_debug_slider_changed(value: float, property_name: String, value_label: Label) -> void:
    value_label.text = _format_slider_value(value)
    match property_name:
        "max_forward_speed":
            max_forward_speed = value
        "engine_force":
            engine_force = value
        "mass":
            mass = value
        "suspension_stiffness":
            suspension_stiffness = value
        "suspension_compression_damping":
            suspension_compression_damping = value
        "suspension_rebound_damping":
            suspension_rebound_damping = value
        "tire_lateral_grip":
            tire_lateral_grip = value
            tire_longitudinal_grip = maxf(value * 0.68, 0.1)
        "aero_downforce":
            aero_downforce = value
        "max_lean_degrees":
            max_lean = deg_to_rad(clampf(value, 0.0, 85.0))
        "lean_torque":
            lean_torque = value
        "lean_turn_response":
            lean_turn_response = value
        "camera_base_fov":
            camera_base_fov = value
        "camera_speed_fov_boost":
            camera_speed_fov_boost = value


func _format_slider_value(value: float) -> String:
    return str(snappedf(value, 0.01))


func _apply_balance_assist(steer_input: float, reverse_only: bool, delta: float) -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var horizontal_speed: float = horizontal_velocity.length()
    var speed_factor: float = clampf(horizontal_speed / 22.0, 0.0, 1.0)
    var sampled_ground_up: Vector3 = _get_ground_normal(global_position)
    if sampled_ground_up.dot(Vector3.UP) < 0.82:
        sampled_ground_up = Vector3.UP
    var ground_weight: float = 1.0 - exp(-4.0 * delta)
    _smoothed_ground_up = _smoothed_ground_up.slerp(sampled_ground_up.slerp(Vector3.UP, 0.35).normalized(), ground_weight).normalized()
    var roll_axis: Vector3 = -global_transform.basis.z.normalized()
    var desired_lean_angle: float = _get_target_lean_angle(steer_input, speed_factor)
    var lean_response: float = 8.5 if absf(steer_input) <= 0.05 else 5.8
    var lean_weight: float = 1.0 - exp(-lean_response * delta)
    _smoothed_lean_target = lerpf(_smoothed_lean_target, desired_lean_angle, lean_weight)
    var current_lean_angle: float = _get_body_lean_angle(_smoothed_ground_up)
    var lean_error: float = _smoothed_lean_target - current_lean_angle
    var roll_velocity: float = angular_velocity.dot(roll_axis)
    var roll_stiffness: float = upright_stability + lean_torque
    var roll_damping: float = angular_stability_damping * lerpf(6.5, 9.5, speed_factor)
    if reverse_only:
        roll_stiffness *= 2.0
        roll_damping *= 1.6
    var lean_error_ratio: float = clampf(lean_error / maxf(_get_safe_max_lean(), 0.01), -1.0, 1.0)
    var countersteer_kick: float = lean_error_ratio * countersteer_roll_torque * clampf(absf(steer_input), 0.0, 1.0) * speed_factor
    apply_torque(roll_axis * (lean_error * roll_stiffness - roll_velocity * roll_damping + countersteer_kick))
    _apply_lean_limit(_smoothed_ground_up)
    var yaw_velocity: float = angular_velocity.dot(Vector3.UP)
    var non_yaw_angular_velocity: Vector3 = angular_velocity - Vector3.UP * yaw_velocity
    apply_torque(-non_yaw_angular_velocity * angular_stability_damping * 0.18)


func _get_target_lean_angle(steer_input: float, speed_factor: float) -> float:
    if absf(steer_input) <= 0.01:
        return 0.0
    var safe_max_lean: float = _get_safe_max_lean()
    var low_speed_lean_factor: float = lerpf(0.25, 1.0, speed_factor)
    return clampf(steer_input * safe_max_lean * low_speed_lean_factor, -safe_max_lean, safe_max_lean)


func _get_body_lean_angle(up_axis: Vector3) -> float:
    var forward_axis: Vector3 = -global_transform.basis.z.normalized()
    var ground_up: Vector3 = up_axis.normalized()
    var body_up: Vector3 = global_transform.basis.y.normalized()
    var signed_sine: float = forward_axis.dot(ground_up.cross(body_up))
    var cosine: float = clampf(ground_up.dot(body_up), -1.0, 1.0)
    return atan2(signed_sine, cosine)


func _apply_lean_limit(up_axis: Vector3) -> void:
    var lean_angle: float = _get_body_lean_angle(up_axis)
    var safe_max_lean: float = _get_safe_max_lean()
    var overshoot: float = absf(lean_angle) - safe_max_lean
    if overshoot <= 0.0:
        return
    var roll_axis: Vector3 = -global_transform.basis.z.normalized()
    apply_torque(roll_axis * -signf(lean_angle) * overshoot * lean_torque * 3.0)


func _get_safe_max_lean() -> float:
    return minf(absf(max_lean), deg_to_rad(85.0))


func _update_visuals(delta: float) -> void:
    var local_velocity: Vector3 = global_transform.basis.inverse() * linear_velocity
    _front_wheel_spin += -local_velocity.z * delta / maxf(front_wheel_radius, 0.01)
    _rear_wheel_spin += -local_velocity.z * delta / maxf(rear_wheel_radius, 0.01)
    _model.rotation = _model_base_rotation
    _front_fork_left.rotation = _front_fork_left_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _front_fork_right.rotation = _front_fork_right_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _handlebar.rotation = _handlebar_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _left_grip.rotation = _left_grip_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _right_grip.rotation = _right_grip_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _headlight.rotation = _headlight_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)

    var smoothing_weight: float = clampf(visual_smoothing * delta, 0.0, 1.0)
    var front_static_compression: float = _get_nominal_static_compression(0.52)
    var rear_static_compression: float = _get_nominal_static_compression(0.48)
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
    _update_contact_shadow(_front_contact_shadow, _front_wheel_local_rest, _front_suspension_compression, 0.46)
    _update_contact_shadow(_rear_contact_shadow, _rear_wheel_local_rest, _rear_suspension_compression, 0.50)


func _create_contact_shadows() -> void:
    _front_contact_shadow = _create_single_contact_shadow("FrontContactShadow", 0.46)
    _rear_contact_shadow = _create_single_contact_shadow("RearContactShadow", 0.50)


func _create_single_contact_shadow(shadow_name: String, radius: float) -> MeshInstance3D:
    var shadow: MeshInstance3D = MeshInstance3D.new()
    shadow.name = shadow_name
    var mesh: CylinderMesh = CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = 0.012
    mesh.radial_segments = 32
    shadow.mesh = mesh
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.0, 0.0, 0.0, 0.28)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    shadow.material_override = material
    shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    shadow.visible = false
    var scene_root: Node = get_tree().current_scene
    if scene_root != null:
        scene_root.add_child(shadow)
    return shadow


func _update_contact_shadow(shadow: MeshInstance3D, wheel_local_rest: Vector3, compression: float, radius: float) -> void:
    if shadow == null:
        return
    if compression <= 0.0:
        shadow.visible = false
        return
    var wheel_world_position: Vector3 = global_transform * wheel_local_rest
    var ray_result: Dictionary = _raycast_ground(wheel_world_position)
    if ray_result.is_empty():
        shadow.visible = false
        return
    var ground_position: Vector3 = ray_result["position"] as Vector3
    var normal: Vector3 = (ray_result["normal"] as Vector3).normalized()
    var forward: Vector3 = -global_transform.basis.z.slide(normal)
    if forward.length() < 0.001:
        forward = normal.cross(Vector3.RIGHT)
    forward = forward.normalized()
    var right: Vector3 = forward.cross(normal).normalized()
    var aligned_forward: Vector3 = normal.cross(right).normalized()
    shadow.global_transform = Transform3D(Basis(right, normal, -aligned_forward).orthonormalized(), ground_position + normal * 0.025)
    shadow.scale = Vector3.ONE * clampf(radius / 0.5, 0.8, 1.2)
    shadow.visible = true


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


func _clamp_vector_length(vector: Vector3, max_length: float) -> Vector3:
    var length: float = vector.length()
    if length > max_length and length > 0.001:
        return vector * (max_length / length)
    return vector


func _create_world_collision() -> void:
    var scene_root: Node = get_tree().current_scene
    if scene_root == null or scene_root.has_node(WORLD_COLLIDER_NAME):
        return
    var static_body: StaticBody3D = StaticBody3D.new()
    static_body.name = WORLD_COLLIDER_NAME
    static_body.collision_layer = 1
    static_body.collision_mask = 0
    scene_root.add_child(static_body)
    _add_mesh_colliders(scene_root, static_body)


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


func _is_descendant_of(node: Node, possible_parent: Node) -> bool:
    var current: Node = node
    while current != null:
        if current == possible_parent:
            return true
        current = current.get_parent()
    return false


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


func _get_ground_height(world_position: Vector3) -> float:
    var ray_result: Dictionary = _raycast_ground(world_position)
    if not ray_result.is_empty():
        var ground_position: Vector3 = ray_result["position"] as Vector3
        return ground_position.y
    var terrain_z: float = -world_position.z
    return _terrain_height(world_position.x, terrain_z) + TRACK_LIFT


func _get_ground_normal(world_position: Vector3) -> Vector3:
    var ray_result: Dictionary = _raycast_ground(world_position)
    if not ray_result.is_empty():
        var normal: Vector3 = ray_result["normal"] as Vector3
        return normal.slerp(Vector3.UP, 0.18).normalized()
    var sample_distance: float = 1.6
    var height_left: float = _get_ground_height(world_position + Vector3(-sample_distance, 0.0, 0.0))
    var height_right: float = _get_ground_height(world_position + Vector3(sample_distance, 0.0, 0.0))
    var height_back: float = _get_ground_height(world_position + Vector3(0.0, 0.0, -sample_distance))
    var height_forward: float = _get_ground_height(world_position + Vector3(0.0, 0.0, sample_distance))
    var tangent_x: Vector3 = Vector3(sample_distance * 2.0, height_right - height_left, 0.0)
    var tangent_z: Vector3 = Vector3(0.0, height_forward - height_back, sample_distance * 2.0)
    var sampled_normal: Vector3 = tangent_z.cross(tangent_x).normalized()
    return sampled_normal.slerp(Vector3.UP, 0.45).normalized()


func _raycast_ground(world_position: Vector3) -> Dictionary:
    var space_state: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
    var query: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(
            world_position + Vector3.UP * 12.0,
            world_position + Vector3.DOWN * 16.0,
            1)
    query.exclude = [get_rid()]
    return space_state.intersect_ray(query)


func _terrain_height(x: float, z: float) -> float:
    var rolling: float = sin(x * TERRAIN_X_FREQUENCY) * 0.65 + cos(z * TERRAIN_Z_FREQUENCY) * 0.55
    var ripples: float = sin((x + z) * TERRAIN_DIAGONAL_FREQUENCY) * 0.22 + cos((x - z) * TERRAIN_CROSS_FREQUENCY) * 0.18
    return rolling + ripples
