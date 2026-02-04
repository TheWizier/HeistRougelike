class_name AreaNode extends Resource

var geometry: Array[Rect2i] = []
var neighbours: Array[AreaNode] = []
var area_type: AreaTypes.Type
var security_level: int = 0

func _init(p_area_type: AreaTypes.Type) -> void:
	area_type = p_area_type
