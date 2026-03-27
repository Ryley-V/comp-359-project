class_name OptimizedSpatialHashGrid

var cell_size: float
var table_size: int

var _clients: Array[SpatialClient] = []
var _cell_hashes: PackedInt32Array
var _start: PackedInt32Array
var _count: PackedInt32Array
var _sorted: Array[SpatialClient] = []
var _sorted_cells: Array[Vector3i] = []

func _init(_cell_size: float, _table_size: int = 2048):
    cell_size = _cell_size
    table_size = _table_size

    _start = PackedInt32Array()
    _start.resize(table_size + 1)

    _count = PackedInt32Array()
    _count.resize(table_size)

    _cell_hashes = PackedInt32Array()

func _hash_cell(cx: int, cy: int, cz: int) -> int:
    var h: int = (cx * 92837111) ^ (cy * 689287499) ^ (cz * 283923481)
    return absi(h) % table_size

func _get_cell_coords(pos: Vector3) -> Vector3i:
    return Vector3i(
        floori(pos.x / cell_size),
        floori(pos.y / cell_size),
        floori(pos.z / cell_size)
    )

func insert(client: SpatialClient) -> void:
    _clients.append(client)

func remove(client: SpatialClient) -> void:
    _clients.erase(client)

func update(client: SpatialClient, old_position: Vector3) -> void:
    # Intentionally no-op. This structure is rebuilt once per frame.
    pass

func clear() -> void:
    _clients.clear()
    _sorted.clear()
    _sorted_cells.clear()
    _start.fill(0)
    _count.fill(0)

func prepare_frame() -> void:
    rebuild()

func rebuild() -> void:
    var n := _clients.size()

    _count.fill(0)
    _start.fill(0)

    if n == 0:
        _sorted.clear()
        _sorted_cells.clear()
        return

    _cell_hashes.resize(n)

    var client_cells: Array[Vector3i] = []
    client_cells.resize(n)

    for i in range(n):
        var cell := _get_cell_coords(_clients[i].position)
        client_cells[i] = cell
        var h := _hash_cell(cell.x, cell.y, cell.z)
        _cell_hashes[i] = h
        _count[h] += 1

    _start[0] = 0
    for i in range(1, table_size + 1):
        _start[i] = _start[i - 1] + _count[i - 1]

    _sorted.resize(n)
    _sorted_cells.resize(n)

    var cursors := _start.duplicate()
    for i in range(n):
        var h := _cell_hashes[i]
        var idx := cursors[h]
        _sorted[idx] = _clients[i]
        _sorted_cells[idx] = client_cells[i]
        cursors[h] += 1

func find_nearby(pos: Vector3, radius: float) -> Array[SpatialClient]:
    var results: Array[SpatialClient] = []

    if _clients.is_empty():
        return results

    var min_cell := _get_cell_coords(pos - Vector3(radius, radius, radius))
    var max_cell := _get_cell_coords(pos + Vector3(radius, radius, radius))

    for cx in range(min_cell.x, max_cell.x + 1):
        for cy in range(min_cell.y, max_cell.y + 1):
            for cz in range(min_cell.z, max_cell.z + 1):
                var query_cell := Vector3i(cx, cy, cz)
                var h := _hash_cell(cx, cy, cz)
                var bucket_start := _start[h]
                var bucket_end := _start[h + 1]

                for i in range(bucket_start, bucket_end):
                    if _sorted_cells[i] == query_cell:
                        results.append(_sorted[i])

    return results