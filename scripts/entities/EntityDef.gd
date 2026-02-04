class_name EntityDef extends Resource

@export var id: String
@export var scene: PackedScene

# Generation metadata
@export_category("level generation")
@export var weight: float = 1.0
@export var min_security_level: int = 0
@export var max_security_level: int = 999
