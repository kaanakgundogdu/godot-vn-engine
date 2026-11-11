class_name VNEngineSaveFormat
extends RefCounted

enum Kind {SLOT, FLOW, GLOBAL}

const VERSION := 1
const KEY := "format"


static func version_of(data: Dictionary) -> int:
	return int(data.get(KEY, 1))


static func is_newer(data: Dictionary) -> bool:
	return version_of(data) > VERSION


static func stamp(data: Dictionary) -> Dictionary:
	data[KEY] = VERSION
	return data


static func upgrade(data: Dictionary, kind: Kind) -> Dictionary:
	return run_steps(data, version_of(data), steps(kind))


static func run_steps(data: Dictionary, from: int, chain: Array[Callable]) -> Dictionary:
	for i in range(from - 1, chain.size()):
		data = chain[i].call(data)
		data[KEY] = i + 2
	return data


static func steps(_kind: Kind) -> Array[Callable]:
	return []
