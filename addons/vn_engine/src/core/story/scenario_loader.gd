class_name VNEngineScenarioLoader
extends RefCounted


static func load_script(path: String, flag_list: VNEngineFlagList) -> VNEngineStoryScript:
	var baked_path: String = path + ".res"
	if ResourceLoader.exists(baked_path):
		var baked: VNEngineStoryScript = load(baked_path) as VNEngineStoryScript
		if baked != null:
			return baked
	return VNEngineScenarioParser.parse_file(path, flag_list)
