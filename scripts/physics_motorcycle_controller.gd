class_name PhysicsMotorcycleController
extends RigidBody3D

const TRACK_LIFT = 0.28
const TERRAIN_X_FREQUENCY = 0.075
const TERRAIN_Z_FREQUENCY = 0.061
const TERRAIN_DIAGONAL_FREQUENCY = 0.18
const TERRAIN_CROSS_FREQUENCY = 0.13

@export var engine_force: float = 420.0
@export var brake_force: float = 680.0
@export var reverse_force: float = 260.0
@export var max_forward_speed: float = 34.0
@export var max_reverse_speed: float = 10.0
@export var suspension_rest_length: float = 0.38
@export var suspension_stiffness: float = 6200.0
@export var suspension_damping: float = 820.0
@export var tire_lateral_grip: float = 1.85
@export var tire_longitudinal_grip: float = 1.25
@export var tire_response: float = 4.0
@export var rolling_resistance: float = 52.0
@export var air_drag: float = 1.1
@export var upright_stability: float = 260.0
@export var angular_stability_damping: float = 72.0
@export var max_front_steer: float = 0.36
@export var max_lean: float = 0.18
@export var wheel_radius: float = 0.34
@export var visual_smoothing: float = 10.0
@export var max_angular_speed: float = 3.2
@export var max_vertical_speed: float = 16.0

var _wheel_spin: float = 0.0
var _visual_steer: float = 0.0
var _visual_lean: float = 0.0
var _raw_forward_pressed: bool = false
var _raw_reverse_pressed: bool = false
var _raw_left_pressed: bool = false
var _raw_right_pressed: bool = false
var _camera_look_active: bool = false
var _camera_orbit_yaw: float = 0.0
var _camera_orbit_pitch: float = 0.0
var _camera_mouse_sensitivity: float = 0.006

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

var _model_base_rotation: Vector3
var _front_wheel_base_rotation: Vector3
var _front_hub_base_rotation: Vector3
var _rear_wheel_base_rotation: Vector3
var _rear_hub_base_rotation: Vector3
var _front_fork_left_base_rotation: Vector3
var _front_fork_right_base_rotation: Vector3
var _handlebar_base_rotation: Vector3
var _left_grip_base_rotation: Vector3
var _right_grip_base_rotation: Vector3
var _headlight_base_rotation: Vector3


func _ready() -> void:
    _camera.current = true
    _cache_visual_rest_pose()
    _create_debug_sliders()
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector3(0.0, 0.35, 0.1)
    var ground_y: float = _get_ground_height(global_position)
    global_position.y = ground_y + suspension_rest_length + wheel_radius * 0.55
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO


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
    var throttle_pressed: bool = _is_forward_pressed()
    var brake_pressed: bool = _is_reverse_pressed()
    var steer_input: float = _get_steer_input()
    _limit_unstable_velocity()
    _apply_wheel_forces(throttle_pressed, brake_pressed, steer_input)
    _apply_upright_stability()
    _apply_body_drag()
    _limit_unstable_velocity()
    _update_camera_orbit()
    _update_visuals(steer_input, delta)


func _apply_wheel_forces(throttle_pressed: bool, brake_pressed: bool, steer_input: float) -> void:
    var contacts: Array[Dictionary] = [
        {"offset": Vector3(-0.34, 0.2, -1.45), "front": true, "drive": 0.15},
        {"offset": Vector3(0.34, 0.2, -1.45), "front": true, "drive": 0.15},
        {"offset": Vector3(-0.36, 0.2, 1.18), "front": false, "drive": 0.85},
        {"offset": Vector3(0.36, 0.2, 1.18), "front": false, "drive": 0.85},
    ]
    for contact: Dictionary in contacts:
        var local_offset: Vector3 = contact["offset"] as Vector3
        var is_front: bool = contact["front"] as bool
        var drive_split: float = contact["drive"] as float
        _apply_single_wheel_force(local_offset, is_front, drive_split, throttle_pressed, brake_pressed, steer_input)


func _apply_single_wheel_force(
        local_offset: Vector3,
        is_front: bool,
        drive_split: float,
        throttle_pressed: bool,
        brake_pressed: bool,
        steer_input: float) -> void:
    var world_attachment: Vector3 = global_transform * local_offset
    var ground_y: float = _get_ground_height(world_attachment)
    var normal: Vector3 = _get_ground_normal(world_attachment)
    var distance_to_ground: float = world_attachment.y - ground_y - wheel_radius
    var compression: float = clampf(suspension_rest_length - distance_to_ground, 0.0, suspension_rest_length)
    if compression <= 0.0:
        return

    var relative_position: Vector3 = world_attachment - global_position
    var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(relative_position)
    var normal_speed: float = point_velocity.dot(normal)
    var suspension_force: float = compression * suspension_stiffness - normal_speed * suspension_damping
    if suspension_force > 0.0:
        apply_force(normal * suspension_force, relative_position)

    var steer_angle: float = steer_input * max_front_steer if is_front else 0.0
    var wheel_forward: Vector3 = -global_transform.basis.z.rotated(normal, steer_angle).normalized()
    var wheel_right: Vector3 = wheel_forward.cross(normal).normalized()
    wheel_forward = normal.cross(wheel_right).normalized()

    var normal_load: float = maxf(suspension_force, mass * 9.8 * 0.1)
    var lateral_speed: float = point_velocity.dot(wheel_right)
    var lateral_force: Vector3 = _clamp_force(-wheel_right * lateral_speed * tire_response * mass, normal_load * tire_lateral_grip)
    apply_force(lateral_force, relative_position)

    var forward_speed: float = point_velocity.dot(wheel_forward)
    var drive_force: float = 0.0
    if throttle_pressed and forward_speed < max_forward_speed:
        drive_force += engine_force * drive_split
    if brake_pressed:
        if forward_speed > 0.5:
            drive_force -= brake_force * drive_split
        elif forward_speed > -max_reverse_speed:
            drive_force -= reverse_force * drive_split

    var rolling_force: float = -forward_speed * rolling_resistance * drive_split
    var longitudinal_force: Vector3 = _clamp_force(wheel_forward * (drive_force + rolling_force), normal_load * tire_longitudinal_grip)
    apply_force(longitudinal_force, relative_position)


func _apply_body_drag() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var speed: float = horizontal_velocity.length()
    if speed <= 0.01:
        return
    var drag_force: Vector3 = -horizontal_velocity.normalized() * speed * speed * air_drag
    apply_central_force(drag_force)


func _limit_unstable_velocity() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var horizontal_speed: float = horizontal_velocity.length()
    if horizontal_speed > max_forward_speed:
        var capped_horizontal: Vector3 = horizontal_velocity.normalized() * max_forward_speed
        linear_velocity.x = capped_horizontal.x
        linear_velocity.z = capped_horizontal.z
    linear_velocity.y = clampf(linear_velocity.y, -max_vertical_speed, max_vertical_speed)
    var angular_speed: float = angular_velocity.length()
    if angular_speed > max_angular_speed:
        angular_velocity = angular_velocity.normalized() * max_angular_speed


func _update_camera_orbit() -> void:
    _camera_rig.rotation = Vector3(_camera_orbit_pitch, _camera_orbit_yaw, 0.0)


func _create_debug_sliders() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "VehicleDebugCanvas"
    add_child(canvas)

    var panel: PanelContainer = PanelContainer.new()
    panel.name = "VehicleDebugPanel"
    panel.anchor_left = 1.0
    panel.anchor_top = 0.0
    panel.anchor_right = 1.0
    panel.anchor_bottom = 0.0
    panel.offset_left = -330.0
    panel.offset_top = 16.0
    panel.offset_right = -16.0
    panel.offset_bottom = 178.0
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
    _add_debug_slider(box, "Acceleration", "engine_force", engine_force, 80.0, 1200.0, 10.0)
    _add_debug_slider(box, "Weight", "mass", mass, 60.0, 500.0, 5.0)
    _add_debug_slider(box, "Traction", "tire_lateral_grip", tire_lateral_grip, 0.25, 5.0, 0.05)


func _add_debug_slider(parent: VBoxContainer, title: String, property_name: String, current_value: float, minimum: float, maximum: float, step: float) -> void:
    var row: HBoxContainer = HBoxContainer.new()
    row.add_theme_constant_override("separation", 6)
    parent.add_child(row)

    var name_label: Label = Label.new()
    name_label.text = title
    name_label.custom_minimum_size = Vector2(92.0, 0.0)
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
    value_label.custom_minimum_size = Vector2(54.0, 0.0)
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
        "tire_lateral_grip":
            tire_lateral_grip = value
            tire_longitudinal_grip = maxf(value * 0.68, 0.1)


func _format_slider_value(value: float) -> String:
    return str(snappedf(value, 0.01))


func _apply_upright_stability() -> void:
    var target_up: Vector3 = _get_ground_normal(global_position)
    if target_up.dot(Vector3.UP) < 0.82:
        target_up = Vector3.UP
    var body_up: Vector3 = global_transform.basis.y.normalized()
    var correction_axis: Vector3 = body_up.cross(target_up)
    var correction_strength: float = correction_axis.length()
    if correction_strength > 0.001:
        var correction_torque: Vector3 = correction_axis.normalized() * correction_strength * upright_stability
        apply_torque(correction_torque)
    apply_torque(-angular_velocity * angular_stability_damping)


func _clamp_force(force: Vector3, max_length: float) -> Vector3:
    var length: float = force.length()
    if length > max_length and length > 0.001:
        return force * (max_length / length)
    return force


func _update_visuals(steer_input: float, delta: float) -> void:
    var smoothing_weight: float = clampf(visual_smoothing * delta, 0.0, 1.0)
    var target_steer: float = steer_input * max_front_steer
    var speed_ratio: float = clampf(Vector3(linear_velocity.x, 0.0, linear_velocity.z).length() / max_forward_speed, 0.0, 1.0)
    var target_lean: float = -steer_input * max_lean * speed_ratio
    _visual_steer = lerpf(_visual_steer, target_steer, smoothing_weight)
    _visual_lean = lerpf(_visual_lean, target_lean, smoothing_weight)
    var local_velocity: Vector3 = global_transform.basis.inverse() * linear_velocity
    _wheel_spin += -local_velocity.z * delta / maxf(wheel_radius, 0.01)
    _model.rotation = _model_base_rotation + Vector3(0.0, 0.0, _visual_lean)
    _front_wheel_tire.rotation = _front_wheel_base_rotation + Vector3(_wheel_spin, _visual_steer, 0.0)
    _front_wheel_hub.rotation = _front_hub_base_rotation + Vector3(_wheel_spin, _visual_steer, 0.0)
    _rear_wheel_tire.rotation = _rear_wheel_base_rotation + Vector3(_wheel_spin, 0.0, 0.0)
    _rear_wheel_hub.rotation = _rear_hub_base_rotation + Vector3(_wheel_spin, 0.0, 0.0)
    _front_fork_left.rotation = _front_fork_left_base_rotation + Vector3(0.0, _visual_steer, 0.0)
    _front_fork_right.rotation = _front_fork_right_base_rotation + Vector3(0.0, _visual_steer, 0.0)
    _handlebar.rotation = _handlebar_base_rotation + Vector3(0.0, _visual_steer, 0.0)
    _left_grip.rotation = _left_grip_base_rotation + Vector3(0.0, _visual_steer, 0.0)
    _right_grip.rotation = _right_grip_base_rotation + Vector3(0.0, _visual_steer, 0.0)
    _headlight.rotation = _headlight_base_rotation + Vector3(0.0, _visual_steer, 0.0)


func _cache_visual_rest_pose() -> void:
    _model_base_rotation = _model.rotation
    _front_wheel_base_rotation = _front_wheel_tire.rotation
    _front_hub_base_rotation = _front_wheel_hub.rotation
    _rear_wheel_base_rotation = _rear_wheel_tire.rotation
    _rear_hub_base_rotation = _rear_wheel_hub.rotation
    _front_fork_left_base_rotation = _front_fork_left.rotation
    _front_fork_right_base_rotation = _front_fork_right.rotation
    _handlebar_base_rotation = _handlebar.rotation
    _left_grip_base_rotation = _left_grip.rotation
    _right_grip_base_rotation = _right_grip.rotation
    _headlight_base_rotation = _headlight.rotation


func _is_forward_pressed() -> bool:
    return _raw_forward_pressed or Input.is_action_pressed("drive_forward") or Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP)


func _is_reverse_pressed() -> bool:
    return _raw_reverse_pressed or Input.is_action_pressed("drive_reverse") or Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN)


func _get_steer_input() -> float:
    var input_value: float = 0.0
    if _raw_left_pressed or Input.is_action_pressed("steer_left") or Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT):
        input_value += 1.0
    if _raw_right_pressed or Input.is_action_pressed("steer_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_value -= 1.0
    return input_value


func _get_ground_height(world_position: Vector3) -> float:
    var terrain_z: float = -world_position.z
    return _terrain_height(world_position.x, terrain_z) + TRACK_LIFT


func _get_ground_normal(world_position: Vector3) -> Vector3:
    var sample_distance: float = 1.6
    var height_left: float = _get_ground_height(world_position + Vector3(-sample_distance, 0.0, 0.0))
    var height_right: float = _get_ground_height(world_position + Vector3(sample_distance, 0.0, 0.0))
    var height_back: float = _get_ground_height(world_position + Vector3(0.0, 0.0, -sample_distance))
    var height_forward: float = _get_ground_height(world_position + Vector3(0.0, 0.0, sample_distance))
    var tangent_x: Vector3 = Vector3(sample_distance * 2.0, height_right - height_left, 0.0)
    var tangent_z: Vector3 = Vector3(0.0, height_forward - height_back, sample_distance * 2.0)
    var sampled_normal: Vector3 = tangent_z.cross(tangent_x).normalized()
    return sampled_normal.slerp(Vector3.UP, 0.45).normalized()


func _terrain_height(x: float, z: float) -> float:
    var rolling: float = sin(x * TERRAIN_X_FREQUENCY) * 0.65 + cos(z * TERRAIN_Z_FREQUENCY) * 0.55
    var ripples: float = sin((x + z) * TERRAIN_DIAGONAL_FREQUENCY) * 0.22 + cos((x - z) * TERRAIN_CROSS_FREQUENCY) * 0.18
    return rolling + ripples
