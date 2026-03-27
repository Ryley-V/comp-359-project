class_name SpatialHashGrid

var cell_size: float
var _cells: Dictionary = {}

func _init(
	_cell_size: float,
	_world_min: Vector3 = Vector3.ZERO,
	_world_max: Vector3 = Vector3.ZERO
):
	cell_size = _cell_size
	
func _cell_key(x: int, y: int, z: int) -> Vector3i:
	return Vector3i(x, y, z)

func _get_cell_coords(pos: Vector3) -> Vector3i:
	return (
		Vector3i(
			floor(pos.x / cell_size),
			floor(pos.y / cell_size),
			floor(pos.z / cell_size),
		)
	)

func insert(client: SpatialClient):
	var cell_coords = _get_cell_coords(client.position)
	
	if not _cells.has(cell_coords):
		_cells[cell_coords] = []
	_cells[cell_coords].append(client)

func remove(client: SpatialClient):
	var cell_coords = _get_cell_coords(client.position)

	if _cells.has(cell_coords):
		_cells[cell_coords].erase(client)
		if _cells[cell_coords].is_empty():
			_cells.erase(cell_coords)

func update(client: SpatialClient, old_position: Vector3):
	var old_cell_coords = _get_cell_coords(old_position)
	var new_cell_coords = _get_cell_coords(client.position)

	if old_cell_coords != new_cell_coords:
		if _cells.has(old_cell_coords):
			_cells[old_cell_coords].erase(client)
			if _cells[old_cell_coords].is_empty():
				_cells.erase(old_cell_coords)
			
		if not _cells.has(new_cell_coords):
			_cells[new_cell_coords] = []
		_cells[new_cell_coords].append(client)

func clear() -> void:
	_cells.clear()


func find_nearby(pos: Vector3, radius: float) -> Array:
	var results: Array[SpatialClient] = []

	var min_coords = _get_cell_coords(pos - Vector3(radius, radius, radius))
	var max_coords = _get_cell_coords(pos + Vector3(radius, radius, radius))

	for x in range(min_coords.x, max_coords.x + 1):
		for y in range(min_coords.y, max_coords.y + 1):
			for z in range(min_coords.z, max_coords.z + 1):
				var cell_key = _cell_key(x, y, z)
				if _cells.has(cell_key):
					results.append_array(_cells[cell_key])

	return results
