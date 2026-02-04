class_name Portal
extends Resource

enum PortalType {
	OPEN,          # hole in wall
	DOOR,          # normal door
	SECURITY_DOOR  # locked / gated
}

var a: AreaNode
var b: AreaNode
var portal_type: PortalType

# I want to make holes where we sety up portals and then create entities of portals
