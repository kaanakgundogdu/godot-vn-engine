class_name VNEngineCmdWeather
extends VNEngineCommand

const TYPES: PackedStringArray = ["rain", "snow", "fog"]

func command_name() -> String:
	return "weather"

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens := args.strip_edges().split(" ", false)
	if tokens.is_empty():
		VNEngineLog.warn("CmdWeather", "Missing argument: '@weather' expects rain, snow, fog or stop")
		return

	var type := tokens[0].to_lower()
	if type != "stop" and not TYPES.has(type):
		VNEngineLog.warn("CmdWeather", "Unknown weather: '%s'" % tokens[0])
		return

	var strength := 0.6
	var fade := 1.0
	for i in range(1, tokens.size()):
		var token := tokens[i]
		if token.begins_with("strength="):
			var number := token.substr(9)
			if number.is_valid_float():
				strength = clampf(number.to_float(), 0.05, 1.0)
		elif token.begins_with("fade="):
			var number := token.substr(5)
			if number.is_valid_float():
				fade = maxf(number.to_float(), 0.0)

	if type == "stop":
		ctx.state.weather = {}
		if ctx.weather:
			ctx.weather.stop(fade)
		return

	ctx.state.weather = {"type": type, "strength": strength}
	if ctx.weather:
		ctx.weather.set_weather(type, strength, fade)
