class_name SpatialHashGridFast

var cell_size: float
var _cells: Array = []

var world_min: Vector3
var world_max: Vector3
var grid_size: Vector3i

var _client_nodes: Dictionary = {}

func _init(_cell_size: float, _world_min: Vector3 = Vector3.ZERO, _world_max: Vector3 = Vector3.ZERO):
	cell_size = _cell_size
	world_min = _world_min
	world_max = _world_max

	grid_size = Vector3i(
		maxi(1, ceil((world_max.x - world_min.x) / cell_size)),
		maxi(1, ceil((world_max.y - world_min.y) / cell_size)),
		maxi(1, ceil((world_max.z - world_min.z) / cell_size))
	)

	for z in range(grid_size.z):
		var layer = []
		layer.resize(grid_size.y)

		for y in range(grid_size.y):
			var row = []
			row.resize(grid_size.x)
			row.fill(null)
			layer[y] = row

		_cells.append(layer)

func _get_cell_coords(pos: Vector3) -> Vector3i:
	return Vector3i(
		clampi(floori((pos.x - world_min.x) / cell_size), 0, grid_size.x - 1),
		clampi(floori((pos.y - world_min.y) / cell_size), 0, grid_size.y - 1),
		clampi(floori((pos.z - world_min.z) / cell_size), 0, grid_size.z - 1)
	)

func insert(client: SpatialClient) -> void:
	# Fetch the coordinates of the cell then insert the node there.
	# Note: The node list at the cell level is maintained as a Doubly linked list.
	if _client_nodes.has(client):
		remove(client)
	var cell_coords = _get_cell_coords(client.position)

	var headNode = {
		"next": null,
		"prev": null,
		"client": client
	}

	headNode["next"] = _cells[cell_coords.z][cell_coords.y][cell_coords.x]

	if _cells[cell_coords.z][cell_coords.y][cell_coords.x] != null:
		_cells[cell_coords.z][cell_coords.y][cell_coords.x].prev = headNode

	_cells[cell_coords.z][cell_coords.y][cell_coords.x] = headNode
	_client_nodes[client] = headNode

func remove(client: SpatialClient, pos: Vector3 = Vector3.INF) -> void:
	if pos == Vector3.INF:
		pos = client.position

	var node = _client_nodes.get(client)
	if node == null:
		return

	if node.next != null:
		node.next.prev = node.prev

	if node.prev != null:
		node.prev.next = node.next

	if node.prev == null:
		var cell_coords := _get_cell_coords(pos)
		_cells[cell_coords.z][cell_coords.y][cell_coords.x] = node.next

	_client_nodes.erase(client)

func find_nearby(pos: Vector3, radius: float) -> Array:
	# Fetch the coordinates of the cells that are within the radius and then traverse the linked list at each cell to fetch the clients.
	var results: Array[SpatialClient] = []

	var i1 = _get_cell_coords(pos - Vector3(radius, radius, radius))
	var i2 = _get_cell_coords(pos + Vector3(radius, radius, radius))

	for z in range(i1.z, i2.z + 1):
		for y in range(i1.y, i2.y + 1):
			for x in range(i1.x, i2.x + 1):
				var node = _cells[z][y][x]
				while node != null:
					results.append(node.client)
					node = node.next

	return results

func update(client: SpatialClient, old_position: Vector3) -> void:
	# Check if the client has moved to a different cell, if yes then remove it from the old cell and insert it into the new cell.
	var old_cell_coords = _get_cell_coords(old_position)
	var new_cell_coords = _get_cell_coords(client.position)

	if old_cell_coords != new_cell_coords:
		remove(client, old_position)
		insert(client)

func clear() -> void:
	_client_nodes.clear()

	for z in range(grid_size.z):
		for y in range(grid_size.y):
			for x in range(grid_size.x):
				_cells[z][y][x] = null
