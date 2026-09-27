@tool
class_name VNEngineBootDef
extends Resource

## Boot steps, played in order. Add one BootScreenDef per step. Empty
## array means go straight to the title screen.
@export var boot_screens: Array[VNEngineBootScreenDef] = []

func has_sequence() -> bool:
	for screen: VNEngineBootScreenDef in boot_screens:
		if screen != null and screen.enabled and (screen.image_path != "" or screen.movie_path != ""):
			return true
	return false
