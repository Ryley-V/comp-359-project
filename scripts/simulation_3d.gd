extends Node3D

@export var entity_count: int = 3000
@export var world_size: float = 35.0
@export var cell_size: float = 4.0
@export var collision_radius: float = 1.0
@export var entity_speed: float = 8.0
@export var sphere_radius: float = 0.45

const BASE_COLOR := Color(0.2, 0.5, 1.0)
const COLLISION_COLOR := Color(1.0, 0.35, 0.1)

var grid: SpatialHashGridFast
var clients: Array[SpatialClient] = []
var velocities: Array[Vector3] = []
var collision_flags: Array[bool] = []

var shared_mesh: SphereMesh
var multi_mesh: MultiMesh
var multi_mesh_instance: MultiMeshInstance3D
var fps_label: Label
var info_label: Label

var collision_pair_count: int = 0
var broadphase_candidate_count: int = 0
var query_time_ms: float = 0.0

var use_spatial := true
var naive := Naive.new()

func _ready() -> void:
	randomize()
	_setup_environment()
	_setup_camera()
	_setup_ui()
	_setup_shared_mesh()
	_setup_simulation()
	add_child(naive)

func _process(delta: float) -> void:
	if Input.is_action_just_pressed("ui_accept"):
		use_spatial = !use_spatial
		print("Mode switched — Using Spatial:", use_spatial)

	_move_entities(delta)
	_detect_collisions()
	_update_visuals()
	_update_ui()

func _setup_simulation() -> void:
	var world_min := Vector3(-world_size, -world_size, -world_size)
	var world_max := Vector3(world_size, world_size, world_size)

	grid = SpatialHashGridFast.new(cell_size, world_min, world_max)

	clients.resize(entity_count)
	velocities.resize(entity_count)
	collision_flags.resize(entity_count)

	for i in range(entity_count):
		var position := Vector3(
			randf_range(-world_size, world_size),
			randf_range(-world_size, world_size),
			randf_range(-world_size, world_size)
		)

		multi_mesh.set_instance_transform(i, Transform3D(Basis(), position))
		multi_mesh.set_instance_color(i, BASE_COLOR)

		var client := SpatialClient.new(position, null)
		client.index = i

		var velocity := Vector3(
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0),
			randf_range(-1.0, 1.0)
		)

		if velocity.length_squared() < 0.0001:
			velocity = Vector3.RIGHT

		velocity = velocity.normalized() * entity_speed

		clients[i] = client
		velocities[i] = velocity
		collision_flags[i] = false

		grid.insert(client)

func _setup_shared_mesh() -> void:
	shared_mesh = SphereMesh.new()
	shared_mesh.radius = sphere_radius
	shared_mesh.height = sphere_radius * 2.0
	shared_mesh.radial_segments = 12
	shared_mesh.rings = 6

	var material := StandardMaterial3D.new()
	material.vertex_color_use_as_albedo = true
	material.emission_enabled = true
	material.emission_energy_multiplier = 0.35
	shared_mesh.material = material

	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_colors = true
	multi_mesh.mesh = shared_mesh
	multi_mesh.instance_count = entity_count

	multi_mesh_instance = MultiMeshInstance3D.new()
	multi_mesh_instance.multimesh = multi_mesh
	add_child(multi_mesh_instance)

func _setup_camera() -> void:
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, world_size * 0.9, world_size * 2.2)
	add_child(camera)
	camera.look_at(Vector3.ZERO, Vector3.UP)
	camera.fov = 60.0

func _setup_environment() -> void:
	var world_environment := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.05, 0.06, 0.1)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.35, 0.35, 0.4)
	environment.ambient_light_energy = 0.8
	world_environment.environment = environment
	add_child(world_environment)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-45.0, 25.0, 0.0)
	light.light_energy = 1.5
	add_child(light)

func _setup_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)

	var panel := VBoxContainer.new()
	panel.position = Vector2(12, 12)
	canvas.add_child(panel)

	fps_label = Label.new()
	fps_label.add_theme_font_size_override("font_size", 20)
	panel.add_child(fps_label)

	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 16)
	panel.add_child(info_label)

# move each entity through the world
# bounces off the world boundaries
# updates the hash grid with new positions
func _move_entities(delta: float) -> void:
	for i in range(entity_count):
		var client := clients[i]
		var old_position := client.position
		var velocity := velocities[i]
		var new_position := old_position + velocity * delta

# inverts the velocity if we hit the world boundary
		if new_position.x > world_size:
			new_position.x = world_size
			velocity.x *= -1.0
		elif new_position.x < -world_size:
			new_position.x = - world_size
			velocity.x *= -1.0

		if new_position.y > world_size:
			new_position.y = world_size
			velocity.y *= -1.0
		elif new_position.y < -world_size:
			new_position.y = - world_size
			velocity.y *= -1.0

		if new_position.z > world_size:
			new_position.z = world_size
			velocity.z *= -1.0
		elif new_position.z < -world_size:
			new_position.z = - world_size
			velocity.z *= -1.0

# handles updating position and velocity and updates the hash grid
		client.position = new_position
		velocities[i] = velocity
		grid.update(client, old_position)

func _detect_collisions() -> void:
	var start_time = Time.get_ticks_usec()
	var radius_sq = collision_radius * collision_radius

	collision_pair_count = 0
	broadphase_candidate_count = 0

	for i in range(entity_count):
		collision_flags[i] = false

	for i in range(entity_count):
		var client = clients[i]
		var candidates: Array
		if use_spatial:
			candidates = grid.find_nearby(client.position, collision_radius)
		else:
			candidates = naive.get_nearby(client, collision_radius, clients)

		var seen = {}
		broadphase_candidate_count += candidates.size()
		for other in candidates:
			if other == client:
				continue

			var other_client = other as SpatialClient
			var j = other_client.index

			if j <= i:
				continue
			
			if seen.has(j):
				continue
			seen[j] = true

			if client.position.distance_squared_to(other_client.position) <= radius_sq:
				collision_flags[i] = true
				collision_flags[j] = true
				collision_pair_count += 1
		
	query_time_ms = (Time.get_ticks_usec() - start_time) / 1000.0

func _update_ui() -> void:
	fps_label.text = "FPS: %.1f" % Engine.get_frames_per_second()
	info_label.text = "Entities: %d\nCollisions: %d\nCandidates: %d\nQuery Time: %.2f ms\nMode: %s" % [
		entity_count,
		collision_pair_count,
		broadphase_candidate_count,
		query_time_ms
		"Spatial" if use_spatial else "Naive"
	]

func _update_visuals() -> void:
	for i in range(entity_count):
		var client := clients[i]
		multi_mesh.set_instance_transform(i, Transform3D(Basis(), client.position))

		if collision_flags[i]:
			multi_mesh.set_instance_color(i, COLLISION_COLOR)
		else:
			multi_mesh.set_instance_color(i, BASE_COLOR)
