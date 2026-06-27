class_name TrackSurfaceArea3D
extends Area3D

enum SurfaceType {
    ROAD,
    WEAK_OFFROAD,
    OFFROAD,
    HEAVY_OFFROAD,
    SLIPPERY,
    BOOST_PAD,
    JUMP_PAD,
    OUT_OF_BOUNDS
}

const SURFACE_LAYER = 8
const KART_LAYER = 2

@export var surface_type: SurfaceType = SurfaceType.ROAD
@export var surface_priority: int = 0
@export var speed_multiplier: float = 1.0
@export var acceleration_multiplier: float = 1.0
@export var turn_multiplier: float = 1.0
@export var grip_multiplier: float = 1.0
@export var boost_duration: float = 0.85
@export var boost_speed_bonus: float = 18.0
@export var jump_impulse: float = 8.5
@export var respawn_height_offset: float = 1.6
@export var display_track_visuals: bool = true
@export var display_debug_mesh: bool = false
@export_group("Visual Tuning")
@export var visual_yaw_degrees: float = -90.0
@export var visual_height_offset: float = 0.0
@export var visual_scale_x: float = 1.0
@export var visual_scale_z: float = 1.0
@export var visual_flip_forward: bool = false
@export_group("")

var _debug_mesh: MeshInstance3D = null
var _visual_root: Node3D = null


func _ready() -> void:
    collision_layer = SURFACE_LAYER
    collision_mask = KART_LAYER
    monitoring = true
    monitorable = true
    _apply_type_defaults()
    if display_track_visuals:
        _create_track_visuals()
    if display_debug_mesh:
        _create_debug_mesh()


func _apply_type_defaults() -> void:
    match surface_type:
        SurfaceType.WEAK_OFFROAD:
            _apply_default_if_unchanged(0.82, 0.82, 0.92, 0.90)
        SurfaceType.OFFROAD:
            _apply_default_if_unchanged(0.62, 0.70, 0.78, 0.76)
        SurfaceType.HEAVY_OFFROAD:
            _apply_default_if_unchanged(0.42, 0.52, 0.62, 0.65)
        SurfaceType.SLIPPERY:
            _apply_default_if_unchanged(1.0, 0.92, 0.72, 0.45)
        SurfaceType.BOOST_PAD:
            _apply_default_if_unchanged(1.0, 1.0, 1.0, 1.0)
            boost_duration = maxf(boost_duration, 0.85)
            boost_speed_bonus = maxf(boost_speed_bonus, 18.0)
        SurfaceType.JUMP_PAD:
            _apply_default_if_unchanged(1.0, 1.0, 1.0, 1.0)
            jump_impulse = maxf(jump_impulse, 8.5)
        SurfaceType.OUT_OF_BOUNDS:
            _apply_default_if_unchanged(0.25, 0.25, 0.4, 0.4)
        _:
            _apply_default_if_unchanged(1.0, 1.0, 1.0, 1.0)


func _apply_default_if_unchanged(default_speed: float, default_accel: float, default_turn: float, default_grip: float) -> void:
    if is_equal_approx(speed_multiplier, 1.0):
        speed_multiplier = default_speed
    if is_equal_approx(acceleration_multiplier, 1.0):
        acceleration_multiplier = default_accel
    if is_equal_approx(turn_multiplier, 1.0):
        turn_multiplier = default_turn
    if is_equal_approx(grip_multiplier, 1.0):
        grip_multiplier = default_grip


func is_boost_pad() -> bool:
    return surface_type == SurfaceType.BOOST_PAD


func is_jump_pad() -> bool:
    return surface_type == SurfaceType.JUMP_PAD


func is_out_of_bounds() -> bool:
    return surface_type == SurfaceType.OUT_OF_BOUNDS


func get_surface_name() -> String:
    match surface_type:
        SurfaceType.WEAK_OFFROAD:
            return "weak_offroad"
        SurfaceType.OFFROAD:
            return "offroad"
        SurfaceType.HEAVY_OFFROAD:
            return "heavy_offroad"
        SurfaceType.SLIPPERY:
            return "slippery"
        SurfaceType.BOOST_PAD:
            return "boost_pad"
        SurfaceType.JUMP_PAD:
            return "jump_pad"
        SurfaceType.OUT_OF_BOUNDS:
            return "out_of_bounds"
        _:
            return "road"


func _create_track_visuals() -> void:
    var collision_shape: CollisionShape3D = _find_first_collision_shape()
    if collision_shape == null or collision_shape.shape == null:
        return
    var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
    if box_shape == null:
        return
    if not is_boost_pad() and not is_jump_pad():
        return
    _visual_root = Node3D.new()
    _visual_root.name = "TrackSurfaceVisuals"
    _visual_root.transform = collision_shape.transform
    _visual_root.position.y -= box_shape.size.y * 0.515
    _visual_root.position.y += visual_height_offset
    _visual_root.rotation.y += deg_to_rad(visual_yaw_degrees)
    if visual_flip_forward:
        _visual_root.rotation.y += PI
    add_child(_visual_root)
    var visual_size: Vector3 = Vector3(box_shape.size.x * visual_scale_x, box_shape.size.y, box_shape.size.z * visual_scale_z)
    if is_boost_pad():
        _create_boost_pad_visual(visual_size)
    elif is_jump_pad():
        _create_jump_pad_visual(visual_size)


func _create_boost_pad_visual(size: Vector3) -> void:
    var base_material: StandardMaterial3D = _make_track_visual_material(Color(0.02, 0.12, 0.24, 1.0), Color(0.0, 0.8, 1.0, 1.0), 0.35)
    var arrow_material: StandardMaterial3D = _make_track_visual_material(Color(0.0, 0.85, 1.0, 1.0), Color(0.0, 0.95, 1.0, 1.0), 1.9)
    _add_flat_box_visual("BoostPadBase", Vector3(size.x, 0.012, size.z), Vector3.ZERO, 0.0, base_material)
    _add_flat_box_visual("BoostPadLeftEdge", Vector3(0.16, 0.014, size.z * 0.92), Vector3(-size.x * 0.47, 0.008, 0.0), 0.0, arrow_material)
    _add_flat_box_visual("BoostPadRightEdge", Vector3(0.16, 0.014, size.z * 0.92), Vector3(size.x * 0.47, 0.008, 0.0), 0.0, arrow_material)
    for arrow_index: int in range(3):
        var z_offset: float = lerpf(-size.z * 0.28, size.z * 0.28, float(arrow_index) / 2.0)
        _add_flat_box_visual("BoostChevron%dA" % arrow_index, Vector3(size.x * 0.38, 0.014, 0.24), Vector3(-size.x * 0.14, 0.014, z_offset), deg_to_rad(32.0), arrow_material)
        _add_flat_box_visual("BoostChevron%dB" % arrow_index, Vector3(size.x * 0.38, 0.014, 0.24), Vector3(size.x * 0.14, 0.014, z_offset), deg_to_rad(-32.0), arrow_material)


func _create_jump_pad_visual(size: Vector3) -> void:
    var base_material: StandardMaterial3D = _make_track_visual_material(Color(0.24, 0.10, 0.02, 1.0), Color(1.0, 0.45, 0.02, 1.0), 0.35)
    var arrow_material: StandardMaterial3D = _make_track_visual_material(Color(1.0, 0.72, 0.06, 1.0), Color(1.0, 0.50, 0.0, 1.0), 1.65)
    _add_flat_box_visual("JumpPadBase", Vector3(size.x, 0.012, size.z), Vector3.ZERO, 0.0, base_material)
    _add_flat_box_visual("JumpPadLaunchLip", Vector3(size.x * 0.86, 0.035, 0.38), Vector3(0.0, 0.025, -size.z * 0.36), 0.0, arrow_material)
    for arrow_index: int in range(2):
        var z_offset: float = lerpf(-size.z * 0.05, size.z * 0.28, float(arrow_index))
        _add_flat_box_visual("JumpArrow%dA" % arrow_index, Vector3(size.x * 0.36, 0.014, 0.26), Vector3(-size.x * 0.12, 0.014, z_offset), deg_to_rad(35.0), arrow_material)
        _add_flat_box_visual("JumpArrow%dB" % arrow_index, Vector3(size.x * 0.36, 0.014, 0.26), Vector3(size.x * 0.12, 0.014, z_offset), deg_to_rad(-35.0), arrow_material)


func _add_flat_box_visual(visual_name: String, size: Vector3, local_position: Vector3, yaw: float, material: StandardMaterial3D) -> void:
    if _visual_root == null:
        return
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = visual_name
    var box_mesh: BoxMesh = BoxMesh.new()
    box_mesh.size = size
    mesh_instance.mesh = box_mesh
    mesh_instance.position = local_position
    mesh_instance.rotation.y = yaw
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh_instance.set_meta("skip_world_collision", true)
    _visual_root.add_child(mesh_instance)


func _make_track_visual_material(albedo: Color, emission_color: Color, emission_energy: float) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = albedo
    material.roughness = 0.28
    material.metallic = 0.05
    material.emission_enabled = true
    material.emission = emission_color
    material.emission_energy_multiplier = emission_energy
    return material


func _create_debug_mesh() -> void:
    var collision_shape: CollisionShape3D = _find_first_collision_shape()
    if collision_shape == null or collision_shape.shape == null:
        return
    var box_shape: BoxShape3D = collision_shape.shape as BoxShape3D
    if box_shape == null:
        return
    _debug_mesh = MeshInstance3D.new()
    _debug_mesh.name = "DebugSurfaceTint"
    var box_mesh: BoxMesh = BoxMesh.new()
    box_mesh.size = box_shape.size
    _debug_mesh.mesh = box_mesh
    _debug_mesh.transform = collision_shape.transform
    _debug_mesh.material_override = _make_debug_material()
    add_child(_debug_mesh)


func _find_first_collision_shape() -> CollisionShape3D:
    for child: Node in get_children():
        var collision_shape: CollisionShape3D = child as CollisionShape3D
        if collision_shape != null:
            return collision_shape
    return null


func _make_debug_material() -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = _get_debug_color()
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.no_depth_test = false
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material


func _get_debug_color() -> Color:
    match surface_type:
        SurfaceType.WEAK_OFFROAD:
            return Color(0.45, 0.78, 0.22, 0.22)
        SurfaceType.OFFROAD:
            return Color(0.25, 0.52, 0.13, 0.28)
        SurfaceType.HEAVY_OFFROAD:
            return Color(0.18, 0.30, 0.08, 0.34)
        SurfaceType.SLIPPERY:
            return Color(0.56, 0.82, 1.0, 0.24)
        SurfaceType.BOOST_PAD:
            return Color(0.0, 0.62, 1.0, 0.42)
        SurfaceType.JUMP_PAD:
            return Color(1.0, 0.56, 0.05, 0.40)
        SurfaceType.OUT_OF_BOUNDS:
            return Color(1.0, 0.0, 0.0, 0.20)
        _:
            return Color(1.0, 1.0, 1.0, 0.12)
