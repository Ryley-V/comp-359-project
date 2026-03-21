class_name SpatialClient

var position: Vector3
var entity: Node3D
var index: int

func _init(_position: Vector3 = Vector3.ZERO, _entity: Node3D = null):
	position = _position
	entity = _entity
