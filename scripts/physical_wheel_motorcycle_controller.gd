class_name PhysicalWheelMotorcycleController
extends RigidBody3D

const TRACK_LIFT = 0.28
const TERRAIN_X_FREQUENCY = 0.075
const TERRAIN_Z_FREQUENCY = 0.061
const TERRAIN_DIAGONAL_FREQUENCY = 0.18
const TERRAIN_CROSS_FREQUENCY = 0.13
const WORLD_COLLIDER_NAME = "GeneratedTrackCollision"

@export var engine_force: float = 1200.0
@export var brake_force: float = 680.0
@export var reverse_force: float = 260.0
@export var max_forward_speed: float = 70.0
@export var max_reverse_speed: float = 10.0
@export var tire_lateral_grip: float = 1.85
@export var tire_longitudinal_grip: float = 1.25
@export var air_drag: float = 1.1
@export var upright_stability: float = 180.0
@export var angular_stability_damping: float = 55.0
@export var max_front_steer: float = 0.36
@export var max_lean: float = 0.523599
@export var visual_smoothing: float = 10.0
@export var max_angular_speed: float = 6.0
@export var max_vertical_speed: float = 18.0
@export var wheel_mass: float = 18.0
@export var rear_wheel_radius: float = 0.60
@export var front_wheel_radius: float = 0.52
@export var rear_wheel_width: float = 0.24
@export var front_wheel_width: float = 0.20
@export var wheel_motor_impulse: float = 32.0
@export var steering_torque: float = 260.0
@export var max_drive_torque: float = 950.0
@export var max_brake_torque: float = 1200.0
@export var lean_torque: float = 2100.0
@export var lean_turn_torque: float = 2300.0
@export var camera_base_fov: float = 74.0
@export var camera_speed_fov_boost: float = 60.0
@export var wheel_friction_multiplier: float = 2.4
@export var track_friction_multiplier: float = 2.8

var _visual_lean: float = 0.0
var _front_steer_angle: float = 0.0
var _raw_forward_pressed: bool = false
var _raw_reverse_pressed: bool = false
var _raw_left_pressed: bool = false
var _raw_right_pressed: bool = false
var _camera_look_active: bool = false
var _camera_orbit_yaw: float = 0.0
var _camera_orbit_pitch: float = 0.0
var _camera_mouse_sensitivity: float = 0.006
var _model_base_rotation: Vector3
var _front_fork_left_base_rotation: Vector3
var _front_fork_right_base_rotation: Vector3
var _handlebar_base_rotation: Vector3
var _left_grip_base_rotation: Vector3
var _right_grip_base_rotation: Vector3
var _headlight_base_rotation: Vector3
var _front_wheel_tire_visual_rest: Transform3D = Transform3D.IDENTITY
var _front_wheel_hub_visual_rest: Transform3D = Transform3D.IDENTITY
var _front_wheel_body: RigidBody3D
var _rear_wheel_body: RigidBody3D
var _front_hinge: HingeJoint3D
var _rear_hinge: HingeJoint3D
var _wheel_physics_material: PhysicsMaterial
var _track_physics_material: PhysicsMaterial

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
    _camera.current = true
    _cache_visual_rest_pose()
    _create_debug_sliders()
    _configure_frame_body()
    call_deferred("_finish_physics_setup")


func _finish_physics_setup() -> void:
    _create_physics_materials()
    _create_world_collision()
    _create_physical_wheels()
    _update_physics_material_friction()


func _create_physics_materials() -> void:
    _wheel_physics_material = PhysicsMaterial.new()
    _wheel_physics_material.rough = true
    _wheel_physics_material.bounce = 0.0
    _track_physics_material = PhysicsMaterial.new()
    _track_physics_material.rough = true
    _track_physics_material.bounce = 0.0


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
    _apply_rear_wheel_torque(throttle_pressed, brake_pressed)
    var reverse_only: bool = brake_pressed and not throttle_pressed and absf(steer_input) <= 0.01
    _update_front_steering(steer_input)
    _apply_tire_steering_forces(reverse_only)
    _apply_balance_assist(steer_input, reverse_only)
    _apply_body_drag()
    _limit_unstable_velocity()
    _update_camera_orbit()
    _update_camera_fov(delta)
    _update_visuals(delta)


func _configure_frame_body() -> void:
    mass = 210.0
    continuous_cd = true
    linear_damp = 0.12
    angular_damp = 3.0
    collision_layer = 2
    collision_mask = 0
    center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
    center_of_mass = Vector3(0.0, 0.25, 0.0)
    var ground_y: float = _get_ground_height(global_position)
    var rear_center_offset_y: float = _rear_wheel_tire.global_position.y - global_position.y
    global_position.y = ground_y + rear_wheel_radius - rear_center_offset_y + 0.02
    linear_velocity = Vector3.ZERO
    angular_velocity = Vector3.ZERO


func _create_physical_wheels() -> void:
    if _front_wheel_body != null or _rear_wheel_body != null:
        return
    var parent_node: Node = get_parent()
    if parent_node == null:
        parent_node = self
    _front_wheel_body = _create_wheel_body("FrontPhysicalWheel", _front_wheel_tire, _front_wheel_hub, front_wheel_radius, front_wheel_width, parent_node)
    _rear_wheel_body = _create_wheel_body("RearPhysicalWheel", _rear_wheel_tire, _rear_wheel_hub, rear_wheel_radius, rear_wheel_width, parent_node)
    _cache_front_wheel_visual_rest_pose()
    _front_hinge = _create_wheel_hinge("FrontWheelHinge", _front_wheel_body, parent_node, false)
    _rear_hinge = _create_wheel_hinge("RearWheelHinge", _rear_wheel_body, parent_node, true)


func _create_wheel_body(body_name: String, tire: Node3D, hub: Node3D, radius: float, width: float, parent_node: Node) -> RigidBody3D:
    var wheel_body: RigidBody3D = RigidBody3D.new()
    wheel_body.name = body_name
    wheel_body.mass = wheel_mass
    wheel_body.continuous_cd = true
    wheel_body.linear_damp = 0.05
    wheel_body.angular_damp = 0.08
    wheel_body.collision_layer = 4
    wheel_body.collision_mask = 1
    wheel_body.physics_material_override = _wheel_physics_material
    var wheel_global_transform: Transform3D = tire.global_transform
    parent_node.add_child(wheel_body)
    wheel_body.global_transform = wheel_global_transform
    var shape: CylinderShape3D = CylinderShape3D.new()
    shape.radius = radius
    shape.height = width
    var collision_shape: CollisionShape3D = CollisionShape3D.new()
    collision_shape.name = "WheelCollisionShape"
    collision_shape.shape = shape
    wheel_body.add_child(collision_shape)
    _reparent_visual_to_wheel(tire, wheel_body)
    _reparent_visual_to_wheel(hub, wheel_body)
    return wheel_body


func _reparent_visual_to_wheel(visual: Node3D, wheel_body: RigidBody3D) -> void:
    var old_global_transform: Transform3D = visual.global_transform
    var old_parent: Node = visual.get_parent()
    if old_parent != null:
        old_parent.remove_child(visual)
    wheel_body.add_child(visual)
    visual.global_transform = old_global_transform


func _cache_front_wheel_visual_rest_pose() -> void:
    _front_wheel_tire_visual_rest = _front_wheel_tire.transform
    _front_wheel_hub_visual_rest = _front_wheel_hub.transform


func _create_wheel_hinge(hinge_name: String, wheel_body: RigidBody3D, parent_node: Node, _motor_enabled: bool) -> HingeJoint3D:
    var hinge: HingeJoint3D = HingeJoint3D.new()
    hinge.name = hinge_name
    parent_node.add_child(hinge)
    hinge.global_transform = _make_hinge_transform(wheel_body, 0.0, false)
    hinge.node_a = hinge.get_path_to(self)
    hinge.node_b = hinge.get_path_to(wheel_body)
    hinge.exclude_nodes_from_collision = true
    hinge.set("angular_limit/enable", false)
    hinge.set("motor/enable", false)
    hinge.set("motor/target_velocity", 0.0)
    hinge.set("motor/max_impulse", wheel_motor_impulse)
    return hinge


func _make_hinge_transform(wheel_body: RigidBody3D, steer_angle: float, use_body_axes: bool) -> Transform3D:
    var axle: Vector3 = wheel_body.global_transform.basis.y.normalized()
    var up_hint: Vector3 = Vector3.UP
    if use_body_axes:
        up_hint = global_transform.basis.y.normalized()
        axle = _get_body_right_on_ground(up_hint).rotated(up_hint, steer_angle).normalized()
    if absf(axle.dot(up_hint)) > 0.95:
        up_hint = global_transform.basis.z.normalized()
    var x_axis: Vector3 = up_hint.cross(axle).normalized()
    var y_axis: Vector3 = axle.cross(x_axis).normalized()
    return Transform3D(Basis(x_axis, y_axis, axle), wheel_body.global_position)


func _update_front_steering(steer_input: float) -> void:
    _front_steer_angle = -steer_input * max_front_steer


func _apply_rear_wheel_torque(throttle_pressed: bool, brake_pressed: bool) -> void:
    if _rear_wheel_body == null:
        return
    var local_velocity: Vector3 = global_transform.basis.inverse() * linear_velocity
    var drive_torque: float = 0.0
    if throttle_pressed and absf(local_velocity.z) < max_forward_speed:
        drive_torque = minf(engine_force * 1.15, max_drive_torque) * tire_longitudinal_grip
    elif brake_pressed:
        if local_velocity.z > 0.5:
            drive_torque = -minf(brake_force, max_brake_torque) * tire_longitudinal_grip
        elif absf(local_velocity.z) < max_reverse_speed:
            drive_torque = -minf(reverse_force, max_drive_torque * 0.55) * tire_longitudinal_grip
    if absf(drive_torque) > 0.01:
        var axle: Vector3 = _rear_wheel_body.global_transform.basis.y.normalized()
        _rear_wheel_body.apply_torque(axle * drive_torque)


func _apply_tire_steering_forces(reverse_only: bool) -> void:
    if reverse_only or _front_wheel_body == null or _rear_wheel_body == null:
        return
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var speed: float = horizontal_velocity.length()
    if speed < 0.5:
        return
    var ground_up: Vector3 = _get_ground_normal(global_position)
    if ground_up.dot(Vector3.UP) < 0.82:
        ground_up = Vector3.UP
    _apply_single_tire_side_force(_front_wheel_body.global_position, front_wheel_radius, _get_steered_front_axle(ground_up), ground_up, 1.0)
    _apply_single_tire_side_force(_rear_wheel_body.global_position, rear_wheel_radius, _get_body_right_on_ground(ground_up), ground_up, 0.72)


func _apply_single_tire_side_force(wheel_position: Vector3, wheel_radius: float, wheel_axle: Vector3, ground_up: Vector3, grip_scale: float) -> void:
    var contact_point: Vector3 = wheel_position - ground_up * wheel_radius
    var relative_position: Vector3 = contact_point - global_position
    var point_velocity: Vector3 = linear_velocity + angular_velocity.cross(relative_position)
    var lateral_axis: Vector3 = (wheel_axle - ground_up * wheel_axle.dot(ground_up)).normalized()
    var lateral_speed: float = point_velocity.dot(lateral_axis)
    var normal_load: float = mass * 9.8 * 0.5 * grip_scale
    var max_side_force: float = normal_load * tire_lateral_grip
    var desired_force: Vector3 = -lateral_axis * lateral_speed * lean_turn_torque * grip_scale
    var side_force: Vector3 = _clamp_vector_length(desired_force, max_side_force)
    apply_force(side_force, relative_position)


func _get_steered_front_axle(ground_up: Vector3) -> Vector3:
    return _get_body_right_on_ground(ground_up).rotated(ground_up.normalized(), _front_steer_angle).normalized()


func _get_body_right_on_ground(ground_up: Vector3) -> Vector3:
    var body_right: Vector3 = global_transform.basis.x
    var projected_right: Vector3 = body_right - ground_up * body_right.dot(ground_up)
    if projected_right.length() < 0.001:
        projected_right = Vector3.RIGHT
    return projected_right.normalized()


func _clamp_vector_length(vector: Vector3, max_length: float) -> Vector3:
    var length: float = vector.length()
    if length > max_length and length > 0.001:
        return vector * (max_length / length)
    return vector


func _apply_body_drag() -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var speed: float = horizontal_velocity.length()
    if speed <= 0.01:
        return
    apply_central_force(-horizontal_velocity.normalized() * speed * speed * air_drag)


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
    var rig_anchor: Vector3 = global_position + Vector3.UP * 1.65
    var body_forward: Vector3 = -global_transform.basis.z
    var flat_forward: Vector3 = Vector3(body_forward.x, 0.0, body_forward.z)
    if flat_forward.length() < 0.001:
        flat_forward = Vector3.FORWARD
    flat_forward = flat_forward.normalized()
    flat_forward = flat_forward.rotated(Vector3.UP, _camera_orbit_yaw).normalized()
    var right_axis: Vector3 = flat_forward.cross(Vector3.UP).normalized()
    var yaw_basis: Basis = Basis(right_axis, Vector3.UP, -flat_forward)
    var pitch_basis: Basis = Basis(right_axis, _camera_orbit_pitch)
    _camera_rig.global_transform = Transform3D(pitch_basis * yaw_basis, rig_anchor)


func _update_camera_fov(delta: float) -> void:
    var horizontal_speed: float = Vector3(linear_velocity.x, 0.0, linear_velocity.z).length()
    var speed_ratio: float = clampf(horizontal_speed / maxf(max_forward_speed, 0.001), 0.0, 1.0)
    var target_fov: float = camera_base_fov + camera_speed_fov_boost * speed_ratio
    var fov_weight: float = clampf(visual_smoothing * delta, 0.0, 1.0)
    _camera.fov = lerpf(_camera.fov, target_fov, fov_weight)


func _create_world_collision() -> void:
    var scene_root: Node = get_tree().current_scene
    if scene_root == null or scene_root.has_node(WORLD_COLLIDER_NAME):
        return
    var static_body: StaticBody3D = StaticBody3D.new()
    static_body.name = WORLD_COLLIDER_NAME
    static_body.collision_layer = 1
    static_body.collision_mask = 4
    static_body.physics_material_override = _track_physics_material
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


func _create_debug_sliders() -> void:
    var canvas: CanvasLayer = CanvasLayer.new()
    canvas.name = "VehicleDebugCanvas"
    add_child(canvas)
    var panel: PanelContainer = PanelContainer.new()
    panel.name = "VehicleDebugPanel"
    panel.anchor_left = 1.0
    panel.anchor_right = 1.0
    panel.offset_left = -330.0
    panel.offset_top = 16.0
    panel.offset_right = -16.0
    panel.offset_bottom = 370.0
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
    _add_debug_slider(box, "Max Lean", "max_lean_degrees", rad_to_deg(max_lean), 0.0, 85.0, 1.0)
    _add_debug_slider(box, "Lean Speed", "lean_torque", lean_torque, 100.0, 20000.0, 100.0)
    _add_debug_slider(box, "Turn Power", "lean_turn_torque", lean_turn_torque, 0.0, 10000.0, 100.0)
    _add_debug_slider(box, "Camera FOV", "camera_base_fov", camera_base_fov, 40.0, 110.0, 1.0)
    _add_debug_slider(box, "Speed FOV", "camera_speed_fov_boost", camera_speed_fov_boost, 0.0, 60.0, 1.0)


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
            wheel_mass = maxf(value * 0.085, 8.0)
            if _front_wheel_body != null:
                _front_wheel_body.mass = wheel_mass
            if _rear_wheel_body != null:
                _rear_wheel_body.mass = wheel_mass
        "tire_lateral_grip":
            tire_lateral_grip = value
            tire_longitudinal_grip = maxf(value * 0.68, 0.1)
            _update_physics_material_friction()
        "max_lean_degrees":
            max_lean = deg_to_rad(clampf(value, 0.0, 85.0))
        "lean_torque":
            lean_torque = value
        "lean_turn_torque":
            lean_turn_torque = value
        "camera_base_fov":
            camera_base_fov = value
        "camera_speed_fov_boost":
            camera_speed_fov_boost = value


func _format_slider_value(value: float) -> String:
    return str(snappedf(value, 0.01))


func _update_physics_material_friction() -> void:
    var wheel_friction: float = maxf(tire_lateral_grip * wheel_friction_multiplier, 0.1)
    var track_friction: float = maxf(tire_lateral_grip * track_friction_multiplier, 0.1)
    if _wheel_physics_material != null:
        _wheel_physics_material.friction = wheel_friction
    if _track_physics_material != null:
        _track_physics_material.friction = track_friction


func _apply_balance_assist(steer_input: float, reverse_only: bool) -> void:
    var horizontal_velocity: Vector3 = Vector3(linear_velocity.x, 0.0, linear_velocity.z)
    var speed_factor: float = clampf(horizontal_velocity.length() / 14.0, 0.0, 1.0)
    var ground_up: Vector3 = _get_ground_normal(global_position)
    if ground_up.dot(Vector3.UP) < 0.82:
        ground_up = Vector3.UP
    var roll_axis: Vector3 = -global_transform.basis.z.normalized()
    var target_lean_angle: float = _get_target_lean_angle(steer_input, speed_factor)
    var current_lean_angle: float = _get_body_lean_angle(ground_up)
    var lean_error: float = target_lean_angle - current_lean_angle
    var roll_velocity: float = angular_velocity.dot(roll_axis)
    var roll_stiffness: float = upright_stability + lean_torque
    var roll_damping: float = angular_stability_damping * 2.0
    if reverse_only:
        roll_stiffness *= 2.0
        roll_damping *= 1.6
    apply_torque(roll_axis * (lean_error * roll_stiffness - roll_velocity * roll_damping))
    _apply_lean_limit(ground_up)
    var yaw_velocity: float = angular_velocity.dot(Vector3.UP)
    var non_yaw_angular_velocity: Vector3 = angular_velocity - Vector3.UP * yaw_velocity
    apply_torque(-non_yaw_angular_velocity * angular_stability_damping * 0.25)


func _get_target_lean_angle(steer_input: float, speed_factor: float) -> float:
    if absf(steer_input) <= 0.01:
        return 0.0
    var safe_max_lean: float = _get_safe_max_lean()
    var low_speed_lean_factor: float = lerpf(0.35, 1.0, speed_factor)
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
    var smoothing_weight: float = clampf(visual_smoothing * delta, 0.0, 1.0)
    _visual_lean = lerpf(_visual_lean, 0.0, smoothing_weight)
    _model.rotation = _model_base_rotation
    _front_fork_left.rotation = _front_fork_left_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _front_fork_right.rotation = _front_fork_right_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _handlebar.rotation = _handlebar_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _left_grip.rotation = _left_grip_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _right_grip.rotation = _right_grip_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _headlight.rotation = _headlight_base_rotation + Vector3(0.0, _front_steer_angle, 0.0)
    _update_front_wheel_visual_steering()


func _update_front_wheel_visual_steering() -> void:
    if _front_wheel_body == null:
        return
    var ground_up: Vector3 = _get_ground_normal(_front_wheel_body.global_position)
    if ground_up.dot(Vector3.UP) < 0.82:
        ground_up = Vector3.UP
    ground_up = ground_up.normalized()
    var steered_basis: Basis = Basis(ground_up, _front_steer_angle) * _front_wheel_body.global_transform.basis
    var steered_wheel_transform: Transform3D = Transform3D(steered_basis, _front_wheel_body.global_position)
    _front_wheel_tire.global_transform = steered_wheel_transform * _front_wheel_tire_visual_rest
    _front_wheel_hub.global_transform = steered_wheel_transform * _front_wheel_hub_visual_rest


func _cache_visual_rest_pose() -> void:
    _model_base_rotation = _model.rotation
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
        input_value -= 1.0
    if _raw_right_pressed or Input.is_action_pressed("steer_right") or Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT):
        input_value += 1.0
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
