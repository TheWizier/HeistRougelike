class_name AreaTypes
extends Resource # or Object, or RefCounted

enum Type {
	ROOM,
	ROAD,
	CORRIDOR,
	VAULT,
}

const AREA_TYPE_TO_TAG := {
	Type.ROOM: &"room",
	Type.ROAD: &"road",
	Type.CORRIDOR: &"corridor",
	Type.VAULT: &"vault",
}
