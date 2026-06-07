class_name ForestTrackBuilder
extends Node3D

const TERRAIN_SIZE = 240.0
const TERRAIN_STEPS = 96
const TRACK_WIDTH = 13.0
const TRACK_SAMPLES_PER_SEGMENT = 14
const TRACK_BRICKS_ACROSS = 7
const TRACK_Y_OFFSET = 0.18
const EDGE_WIDTH = 0.75

var _sand_a: Color = Color(0.78, 0.58, 0.34)
var _sand_b: Color = Color(0.86, 0.68, 0.43)
var _sand_c: Color = Color(0.68, 0.46, 0.25)
var _grass_low: Color = Color(0.16, 0.42, 0.16)
var _grass_high: Color = Color(0.35, 0.62, 0.24)
var _edge_color: Color = Color(0.58, 0.38, 0.22)


func _ready() -> void:
    _build_level()


func _build_level() -> void:
    _build_terrain()
    var track_points: Array[Vector3] = _sample_track(_control_points(), TRACK_SAMPLES_PER_SEGMENT)
    _build_track(track_points)
    _build_track_edges(track_points)
    _build_start_marker(track_points)
    _setup_scene_nodes()


func _control_points() -> Array[Vector3]:
    return [
        Vector3(-54.0, 0.0, -42.0),
        Vector3(-25.0, 0.0, -62.0),
        Vector3(10.0, 0.0, -48.0),
        Vector3(44.0, 0.0, -66.0),
        Vector3(70.0, 0.0, -32.0),
        Vector3(50.0, 0.0, 0.0),
        Vector3(74.0, 0.0, 34.0),
        Vector3(34.0, 0.0, 63.0),
        Vector3(2.0, 0.0, 38.0),
        Vector3(-31.0, 0.0, 66.0),
        Vector3(-72.0, 0.0, 38.0),
        Vector3(-48.0, 0.0, 4.0),
        Vector3(-78.0, 0.0, -22.0)
    ]


func _sample_track(points: Array[Vector3], samples_per_segment: int) -> Array[Vector3]:
    var samples: Array[Vector3] = []
    var point_count: int = points.size()
    for i in range(point_count):
        var p0: Vector3 = points[(i - 1 + point_count) % point_count]
        var p1: Vector3 = points[i]
        var p2: Vector3 = points[(i + 1) % point_count]
        var p3: Vector3 = points[(i + 2) % point_count]
        for step in range(samples_per_segment):
            var t: float = float(step) / float(samples_per_segment)
            var t2: float = t * t
            var t3: float = t2 * t
            var sample: Vector3 = 0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3)
            samples.append(sample)
    return samples


func _build_terrain() -> void:
    var vertices: PackedVector3Array = PackedVector3Array()
    var colors: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()
    var half_size: float = TERRAIN_SIZE * 0.5
    var step_size: float = TERRAIN_SIZE / float(TERRAIN_STEPS)

    for z_index in range(TERRAIN_STEPS + 1):
        for x_index in range(TERRAIN_STEPS + 1):
            var x: float = -half_size + float(x_index) * step_size
            var z: float = -half_size + float(z_index) * step_size
            var y: float = _terrain_height(x, z)
            vertices.append(Vector3(x, y, z))
            var height_mix: float = clamp((y + 1.2) / 3.0, 0.0, 1.0)
            colors.append(_grass_low.lerp(_grass_high, height_mix))

    var row_size: int = TERRAIN_STEPS + 1
    for z_index in range(TERRAIN_STEPS):
        for x_index in range(TERRAIN_STEPS):
            var a: int = z_index * row_size + x_index
            var b: int = a + 1
            var c: int = a + row_size
            var d: int = c + 1
            indices.append_array(PackedInt32Array([a, b, c, b, d, c]))

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = _calculate_normals(vertices, indices)
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 1.0
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    material.specular_mode = BaseMaterial3D.SPECULAR_DISABLED

    var terrain: MeshInstance3D = MeshInstance3D.new()
    terrain.name = "BumpyGrassTerrain"
    terrain.mesh = mesh
    terrain.material_override = material
    add_child(terrain)


func _build_track(track_points: Array[Vector3]) -> void:
    var vertices: PackedVector3Array = PackedVector3Array()
    var colors: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()
    var point_count: int = track_points.size()
    var brick_depth: int = 2

    for i in range(point_count):
        var next_i: int = (i + 1) % point_count
        for brick_x in range(TRACK_BRICKS_ACROSS):
            var left_t: float = (float(brick_x) / float(TRACK_BRICKS_ACROSS)) - 0.5
            var right_t: float = (float(brick_x + 1) / float(TRACK_BRICKS_ACROSS)) - 0.5
            var a: Vector3 = _track_edge_point(track_points, i, left_t)
            var b: Vector3 = _track_edge_point(track_points, next_i, left_t)
            var c: Vector3 = _track_edge_point(track_points, next_i, right_t)
            var d: Vector3 = _track_edge_point(track_points, i, right_t)
            var base_index: int = vertices.size()
            vertices.append_array(PackedVector3Array([a, b, c, d]))
            var brick_band: int = int(floor(float(i) / float(brick_depth)))
            var brick_color: Color = _brick_color(brick_band, brick_x)
            colors.append_array(PackedColorArray([brick_color, brick_color, brick_color, brick_color]))
            indices.append_array(PackedInt32Array([base_index, base_index + 1, base_index + 2, base_index, base_index + 2, base_index + 3]))

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = _calculate_normals(vertices, indices)
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)

    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.vertex_color_use_as_albedo = true
    material.roughness = 0.92
    material.cull_mode = BaseMaterial3D.CULL_DISABLED

    var track: MeshInstance3D = MeshInstance3D.new()
    track.name = "SandBrickTrackLoop"
    track.mesh = mesh
    track.material_override = material
    add_child(track)


func _build_track_edges(track_points: Array[Vector3]) -> void:
    var edge_mesh: ArrayMesh = _ribbon_mesh(track_points, -0.5, -0.5 - EDGE_WIDTH / TRACK_WIDTH, _edge_color, TRACK_Y_OFFSET + 0.08)
    var inner_edge: MeshInstance3D = MeshInstance3D.new()
    inner_edge.name = "InnerSandstoneEdge"
    inner_edge.mesh = edge_mesh
    inner_edge.material_override = _flat_material(_edge_color)
    add_child(inner_edge)

    var outer_edge_mesh: ArrayMesh = _ribbon_mesh(track_points, 0.5, 0.5 + EDGE_WIDTH / TRACK_WIDTH, _edge_color.lightened(0.12), TRACK_Y_OFFSET + 0.08)
    var outer_edge: MeshInstance3D = MeshInstance3D.new()
    outer_edge.name = "OuterSandstoneEdge"
    outer_edge.mesh = outer_edge_mesh
    outer_edge.material_override = _flat_material(_edge_color.lightened(0.12))
    add_child(outer_edge)


func _build_start_marker(track_points: Array[Vector3]) -> void:
    var start_index: int = 4
    var tangent: Vector3 = _track_tangent(track_points, start_index)
    var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x).normalized()
    var center: Vector3 = track_points[start_index]
    center.y = _terrain_height(center.x, center.z) + TRACK_Y_OFFSET + 0.05
    var marker: MeshInstance3D = MeshInstance3D.new()
    marker.name = "StartLine"
    var box: BoxMesh = BoxMesh.new()
    box.size = Vector3(TRACK_WIDTH, 0.08, 1.0)
    marker.mesh = box
    marker.material_override = _flat_material(Color(0.94, 0.9, 0.76))
    marker.position = center
    marker.basis = Basis().looking_at(tangent, Vector3.UP).rotated(Vector3.UP, PI * 0.5)
    add_child(marker)

    var post_mesh: BoxMesh = BoxMesh.new()
    post_mesh.size = Vector3(0.45, 3.2, 0.45)
    for side in [-1.0, 1.0]:
        var post: MeshInstance3D = MeshInstance3D.new()
        post.name = "StartPost" if side < 0.0 else "StartPost2"
        post.mesh = post_mesh
        post.material_override = _flat_material(Color(0.49, 0.31, 0.16))
        post.position = center + right * side * (TRACK_WIDTH * 0.55)
        post.position.y += 1.6
        add_child(post)


func _setup_scene_nodes() -> void:
    var camera: Camera3D = get_node_or_null("Camera3D") as Camera3D
    if camera == null:
        camera = Camera3D.new()
        camera.name = "Camera3D"
        add_child(camera)
    camera.position = Vector3(0.0, 105.0, 128.0)
    camera.look_at(Vector3(0.0, 0.0, 0.0), Vector3.UP)
    camera.fov = 48.0
    camera.current = true

    var light: DirectionalLight3D = get_node_or_null("SunLight") as DirectionalLight3D
    if light == null:
        light = DirectionalLight3D.new()
        light.name = "SunLight"
        add_child(light)
    light.rotation_degrees = Vector3(-52.0, -34.0, 0.0)
    light.light_energy = 2.4
    light.shadow_enabled = true

    var world: WorldEnvironment = get_node_or_null("WorldEnvironment") as WorldEnvironment
    if world == null:
        world = WorldEnvironment.new()
        world.name = "WorldEnvironment"
        add_child(world)
    var environment: Environment = Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.54, 0.76, 0.95)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.64, 0.72, 0.64)
    environment.ambient_light_energy = 0.55
    world.environment = environment


func _track_edge_point(track_points: Array[Vector3], index: int, offset_ratio: float) -> Vector3:
    var point: Vector3 = track_points[index]
    var tangent: Vector3 = _track_tangent(track_points, index)
    var right: Vector3 = Vector3(-tangent.z, 0.0, tangent.x).normalized()
    var world_point: Vector3 = point + right * offset_ratio * TRACK_WIDTH
    world_point.y = _terrain_height(world_point.x, world_point.z) + TRACK_Y_OFFSET
    return world_point


func _track_tangent(track_points: Array[Vector3], index: int) -> Vector3:
    var point_count: int = track_points.size()
    var previous_point: Vector3 = track_points[(index - 1 + point_count) % point_count]
    var next_point: Vector3 = track_points[(index + 1) % point_count]
    return (next_point - previous_point).normalized()


func _ribbon_mesh(track_points: Array[Vector3], inner_ratio: float, outer_ratio: float, color: Color, y_offset: float) -> ArrayMesh:
    var vertices: PackedVector3Array = PackedVector3Array()
    var colors: PackedColorArray = PackedColorArray()
    var indices: PackedInt32Array = PackedInt32Array()
    var point_count: int = track_points.size()

    for i in range(point_count):
        var inner: Vector3 = _track_edge_point(track_points, i, inner_ratio)
        var outer: Vector3 = _track_edge_point(track_points, i, outer_ratio)
        inner.y += y_offset
        outer.y += y_offset
        vertices.append(inner)
        vertices.append(outer)
        colors.append(color)
        colors.append(color)

    for i in range(point_count):
        var next_i: int = (i + 1) % point_count
        var a: int = i * 2
        var b: int = next_i * 2
        var c: int = next_i * 2 + 1
        var d: int = i * 2 + 1
        indices.append_array(PackedInt32Array([a, b, c, a, c, d]))

    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = _calculate_normals(vertices, indices)
    arrays[Mesh.ARRAY_COLOR] = colors
    arrays[Mesh.ARRAY_INDEX] = indices

    var mesh: ArrayMesh = ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh


func _brick_color(brick_band: int, brick_x: int) -> Color:
    var pattern: int = (brick_band + brick_x) % 3
    if pattern == 0:
        return _sand_a
    if pattern == 1:
        return _sand_b
    return _sand_c


func _terrain_height(x: float, z: float) -> float:
    var rolling: float = sin(x * 0.075) * 0.65 + cos(z * 0.061) * 0.55
    var ripples: float = sin((x + z) * 0.18) * 0.22 + cos((x - z) * 0.13) * 0.18
    return rolling + ripples


func _calculate_normals(vertices: PackedVector3Array, indices: PackedInt32Array) -> PackedVector3Array:
    var normals: PackedVector3Array = PackedVector3Array()
    normals.resize(vertices.size())
    for i in range(vertices.size()):
        normals[i] = Vector3.ZERO
    for i in range(0, indices.size(), 3):
        var a: int = indices[i]
        var b: int = indices[i + 1]
        var c: int = indices[i + 2]
        var normal: Vector3 = (vertices[b] - vertices[a]).cross(vertices[c] - vertices[a]).normalized()
        normals[a] = normals[a] + normal
        normals[b] = normals[b] + normal
        normals[c] = normals[c] + normal
    for i in range(normals.size()):
        normals[i] = normals[i].normalized()
    return normals


func _flat_material(albedo: Color) -> StandardMaterial3D:
    var material: StandardMaterial3D = StandardMaterial3D.new()
    material.albedo_color = albedo
    material.roughness = 0.95
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material
