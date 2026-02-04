class_name EntityGroup extends Resource

@export var name: String
@export var entities: Array[EntityDef]

func pick_random(
	security_level: int
) -> EntityDef:
	var candidates: Array[EntityDef] = []

	for e in entities:
		if security_level < e.min_security_level:
			continue
		if security_level > e.max_security_level:
			continue
		candidates.append(e)

	if candidates.is_empty():
		return null
		
	var weigths: Array[int] = []
	for canditdate in candidates:
		weigths.append(canditdate.weight)
		
	return Utils.weighted_choice(candidates, weigths)
