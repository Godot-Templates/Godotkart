class_name RaceVisualUpgrader
extends Node3D

const GRASS_MATERIAL: Material = preload("res://assets/materials/gta_style_grass_pbr.tres")
const ROAD_MATERIAL: Material = preload("res://assets/materials/gta_style_sandy_road_pbr.tres")
const EDGE_MATERIAL: Material = preload("res://assets/materials/gta_style_sandstone_edge_pbr.tres")

func _ready() -> void:
    _apply_material("BumpyGrassTerrain/BumpyGrassTerrainAsset", GRASS_MATERIAL)
    _apply_material("SandBrickTrackLoop/SandBrickTrackLoopAsset", ROAD_MATERIAL)
    _apply_material("SandBrickTrackLoop/InnerSandstoneEdgeAsset", EDGE_MATERIAL)
    _apply_material("SandBrickTrackLoop/OuterSandstoneEdgeAsset", EDGE_MATERIAL)

func _apply_material(node_path: NodePath, material: Material) -> void:
    var mesh_instance: MeshInstance3D = get_node_or_null(node_path) as MeshInstance3D
    if mesh_instance == null:
        return
    mesh_instance.material_override = material
