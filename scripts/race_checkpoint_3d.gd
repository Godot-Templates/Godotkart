class_name RaceCheckpoint3D
extends Area3D

signal kart_entered(checkpoint: RaceCheckpoint3D, kart: Node3D)

const CHECKPOINT_LAYER = 16
const KART_LAYER = 2

enum VisualMode {
    FULL_GATE,
    GROUND_LINE_ONLY
}

@export var checkpoint_index: int = 0
@export var checkpoint_width: float = 72.0
@export var checkpoint_height: float = 10.0
@export var checkpoint_depth: float = 18.0
@export var is_start_finish: bool = false
@export var show_gate_visual: bool = true
@export var visual_mode: VisualMode = VisualMode.GROUND_LINE_ONLY
@export_group("Visual Tuning")
@export var visual_line_width_scale: float = 0.92
@export var visual_line_height_offset: float = 0.04
@export var visual_gate_alpha_scale: float = 1.0
@export_group("")

var respawn_transform: Transform3D = Transform3D.IDENTITY
var _gate_material: StandardMaterial3D = null
var _line_material: StandardMaterial3D = null


func _ready() -> void:
    collision_layer = CHECKPOINT_LAYER
    collision_mask = KART_LAYER
    monitoring = true
    monitorable = true
    body_entered.connect(Callable(self, "_on_body_entered"))
    if get_child_count() == 0 or _find_collision_shape() == null:
        _create_collision_shape()
    if show_gate_visual:
        _create_checkpoint_visual()


func setup(index: int, checkpoint_position: Vector3, forward: Vector3, width: float, start_finish: bool) -> void:
    checkpoint_index = index
    checkpoint_width = width
    is_start_finish = start_finish
    global_transform = Transform3D(_basis_from_forward(forward), checkpoint_position)
    respawn_transform = Transform3D(_basis_from_forward(forward), checkpoint_position + Vector3.UP * 1.35)


func _basis_from_forward(forward: Vector3) -> Basis:
    var flat_forward: Vector3 = Vector3(forward.x, 0.0, forward.z)
    if flat_forward.length() < 0.001:
        flat_forward = Vector3.FORWARD
    flat_forward = flat_forward.normalized()
    var right: Vector3 = flat_forward.cross(Vector3.UP).normalized()
    return Basis(right, Vector3.UP, -flat_forward).orthonormalized()


func _create_collision_shape() -> void:
    var collision_shape: CollisionShape3D = CollisionShape3D.new()
    collision_shape.name = "CheckpointShape"
    var box_shape: BoxShape3D = BoxShape3D.new()
    box_shape.size = Vector3(checkpoint_width, checkpoint_height, checkpoint_depth)
    collision_shape.shape = box_shape
    collision_shape.position.y = checkpoint_height * 0.35
    add_child(collision_shape)


func _find_collision_shape() -> CollisionShape3D:
    for child: Node in get_children():
        var collision_shape: CollisionShape3D = child as CollisionShape3D
        if collision_shape != null:
            return collision_shape
    return null


func _on_body_entered(body: Node3D) -> void:
    if body is MotorcycleBicycleControllerV4:
        kart_entered.emit(self, body)


func _create_checkpoint_visual() -> void:
    _gate_material = _make_gate_material(_scaled_alpha(Color(0.15, 0.55, 1.0, 0.38)), Color(0.1, 0.65, 1.0, 1.0), 0.75)
    _line_material = _make_gate_material(Color(1.0, 1.0, 1.0, 0.82), Color(1.0, 0.95, 0.55, 1.0), 0.35)
    if is_start_finish:
        _gate_material = _make_gate_material(_scaled_alpha(Color(1.0, 0.78, 0.08, 0.62)), Color(1.0, 0.65, 0.05, 1.0), 1.15)
    var visual_root: Node3D = Node3D.new()
    visual_root.name = "CheckpointVisual"
    add_child(visual_root)
    var line_width: float = checkpoint_width * clampf(visual_line_width_scale, 0.1, 1.25)
    var line_depth: float = 1.45 if is_start_finish else 0.82
    _add_visual_box(visual_root, "Line", Vector3(line_width, 0.035, line_depth), Vector3(0.0, visual_line_height_offset, 0.0), _line_material)
    if visual_mode == VisualMode.GROUND_LINE_ONLY and not is_start_finish:
        return
    _add_visual_box(visual_root, "LeftPost", Vector3(0.24, checkpoint_height * 0.55, 0.24), Vector3(-checkpoint_width * 0.5, checkpoint_height * 0.28, 0.0), _gate_material)
    _add_visual_box(visual_root, "RightPost", Vector3(0.24, checkpoint_height * 0.55, 0.24), Vector3(checkpoint_width * 0.5, checkpoint_height * 0.28, 0.0), _gate_material)
    _add_visual_box(visual_root, "TopBar", Vector3(checkpoint_width + 0.5, 0.18, 0.18), Vector3(0.0, checkpoint_height * 0.56, 0.0), _gate_material)
    if not is_start_finish:
        _add_visual_box(visual_root, "GhostPanel", Vector3(checkpoint_width * 0.82, checkpoint_height * 0.50, 0.08), Vector3(0.0, checkpoint_height * 0.45, 0.0), _make_gate_material(_scaled_alpha(Color(0.08, 0.45, 1.0, 0.12)), Color(0.0, 0.55, 1.0, 1.0), 0.25))


func _add_visual_box(parent: Node3D, visual_name: String, size: Vector3, local_position: Vector3, material: StandardMaterial3D) -> void:
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = visual_name
    var box_mesh: BoxMesh = BoxMesh.new()
    box_mesh.size = size
    mesh_instance.mesh = box_mesh
    mesh_instance.position = local_position
    mesh_instance.material_override = material
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh_instance.set_meta("skip_world_collision", true)
    parent.add_child(mesh_instance)


func _scaled_alpha(color: Color) -> Color:
    return Color(color.r, color.g, color.b, clampf(color.a * visual_gate_alpha_scale, 0.0, 1.0))


func _make_gate_material(albedo: Color, emission_color: Color, emission_energy: float) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = albedo
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.emission_enabled = true
    material.emission = emission_color
    material.emission_energy_multiplier = emission_energy
    return material
