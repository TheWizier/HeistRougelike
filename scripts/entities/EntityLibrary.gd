class_name EntityLibrary extends Node

@export var entity_groups: Array[EntityGroup]

var _group_map: Dictionary = {}

func _ready() -> void:
	build_index()

func build_index():
	_group_map.clear()
	for g in entity_groups:
		_group_map[g.name] = g

func get_group(name: String) -> EntityGroup:
	return _group_map.get(name)
