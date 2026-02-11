class_name EntityPlacing extends RefCounted


static func create_entity(
	pos: Vector2i,
	entity_def: EntityDef,
	level_data: LevelData,
	entities_root: Node2D,
	level: Level
) -> Entity:
	var instance: Entity = entity_def.scene.instantiate()
	instance.level = level
	instance.pos = pos
	level_data.entity_list.append(instance)
	return instance  # caller sets any additional properties, then adds to tree
