class_name ItemBox3D
extends Area3D

signal item_box_collected(item_box: ItemBox3D, kart: Node3D)

const ITEM_BOX_LAYER = 32
const KART_LAYER = 2

@export var respawn_seconds: float = 4.0
@export var spin_speed: float = 1.8
@export var bob_height: float = 0.28
@export var bob_speed: float = 2.4
@export var box_size: float = 2.2

var _visual_root: Node3D = null
var _available: bool = true
var _respawn_timer: float = 0.0
var _base_visual_y: float = 0.0
var _life_time: float = 0.0


func _ready() -> void:
    add_to_group("item_boxes")
    collision_layer = ITEM_BOX_LAYER
    collision_mask = KART_LAYER
    monitoring = true
    monitorable = true
    body_entered.connect(Callable(self, "_on_body_entered"))
    if _find_collision_shape() == null:
        _create_collision_shape()
    _create_visual()


func _process(delta: float) -> void:
    _life_time += delta
    if not _available:
        _respawn_timer = maxf(_respawn_timer - delta, 0.0)
        if _respawn_timer <= 0.0:
            set_available(true)
    if _visual_root != null and _available:
        _visual_root.rotation.y += spin_speed * delta
        _visual_root.position.y = _base_visual_y + sin(_life_time * bob_speed) * bob_height


func collect(kart: Node3D) -> void:
    if not _available:
        return
    set_available(false)
    item_box_collected.emit(self, kart)


func set_available(available: bool) -> void:
    _available = available
    set_deferred("monitoring", available)
    visible = available
    if available:
        _respawn_timer = 0.0
    else:
        _respawn_timer = respawn_seconds


func is_available() -> bool:
    return _available


func _on_body_entered(body: Node3D) -> void:
    if body is MotorcycleBicycleControllerV4:
        collect(body)


func _find_collision_shape() -> CollisionShape3D:
    for child: Node in get_children():
        var collision_shape: CollisionShape3D = child as CollisionShape3D
        if collision_shape != null:
            return collision_shape
    return null


func _create_collision_shape() -> void:
    var collision_shape: CollisionShape3D = CollisionShape3D.new()
    collision_shape.name = "ItemBoxShape"
    var shape: BoxShape3D = BoxShape3D.new()
    shape.size = Vector3(box_size, box_size, box_size)
    collision_shape.shape = shape
    add_child(collision_shape)


func _create_visual() -> void:
    if _visual_root != null:
        return
    _visual_root = Node3D.new()
    _visual_root.name = "ItemBoxVisual"
    _base_visual_y = 0.0
    add_child(_visual_root)
    var mesh_instance: MeshInstance3D = MeshInstance3D.new()
    mesh_instance.name = "QuestionCube"
    var box_mesh: BoxMesh = BoxMesh.new()
    box_mesh.size = Vector3.ONE * box_size * 0.74
    mesh_instance.mesh = box_mesh
    mesh_instance.material_override = _make_box_material()
    mesh_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    mesh_instance.set_meta("skip_world_collision", true)
    _visual_root.add_child(mesh_instance)
    var marker_mesh: MeshInstance3D = MeshInstance3D.new()
    marker_mesh.name = "QuestionMarkPlate"
    var plate_mesh: BoxMesh = BoxMesh.new()
    plate_mesh.size = Vector3(box_size * 0.34, box_size * 0.08, box_size * 0.08)
    marker_mesh.mesh = plate_mesh
    marker_mesh.position = Vector3(0.0, box_size * 0.08, -box_size * 0.38)
    marker_mesh.material_override = _make_mark_material()
    marker_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    marker_mesh.set_meta("skip_world_collision", true)
    _visual_root.add_child(marker_mesh)


func _make_box_material() -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(0.25, 0.75, 1.0, 0.72)
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.emission_enabled = true
    material.emission = Color(0.15, 0.85, 1.0, 1.0)
    material.emission_energy_multiplier = 1.35
    return material


func _make_mark_material() -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = Color(1.0, 1.0, 1.0, 1.0)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = Color(1.0, 1.0, 1.0, 1.0)
    material.emission_energy_multiplier = 1.2
    return material
