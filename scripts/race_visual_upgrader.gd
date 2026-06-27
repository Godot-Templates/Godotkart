class_name RaceVisualUpgrader
extends Node3D

const GRASS_MATERIAL: Material = preload("res://assets/materials/gta_style_grass_pbr.tres")
const ROAD_MATERIAL: Material = preload("res://assets/materials/gta_style_sandy_road_pbr.tres")
const EDGE_MATERIAL: Material = preload("res://assets/materials/gta_style_sandstone_edge_pbr.tres")
const SURFACE_ZONES_SCENE: PackedScene = preload("res://scenes/surface_zones.tscn")

func _ready() -> void:
    _ensure_surface_zones()
    _apply_material("BumpyGrassTerrain/BumpyGrassTerrainAsset", GRASS_MATERIAL)
    _apply_material("SandBrickTrackLoop/SandBrickTrackLoopAsset", ROAD_MATERIAL)
    _apply_material("SandBrickTrackLoop/InnerSandstoneEdgeAsset", EDGE_MATERIAL)
    _apply_material("SandBrickTrackLoop/OuterSandstoneEdgeAsset", EDGE_MATERIAL)

func _ensure_surface_zones() -> void:
    if get_node_or_null("SurfaceZones") != null:
        return
    var surface_zones: Node = SURFACE_ZONES_SCENE.instantiate()
    surface_zones.name = "SurfaceZones"
    add_child(surface_zones)


func _apply_material(node_path: NodePath, material: Material) -> void:
    var mesh_instance: MeshInstance3D = get_node_or_null(node_path) as MeshInstance3D
    if mesh_instance == null:
        return
    mesh_instance.material_override = material
