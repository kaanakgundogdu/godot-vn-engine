class_name VNEngineCmdAnimate
extends VNEngineCommand

func command_name() -> String:
	return "animate"

func is_blocking_for(args: String) -> bool:
	return parse_quoted_args(args).has("wait")

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var tokens: Array[String] = parse_quoted_args(args)
	var wait: bool = tokens.has("wait")
	var rest: PackedStringArray = PackedStringArray()
	for token in tokens:
		if token != "wait":
			rest.append(token)

	if rest.size() < 2:
		VNEngineLog.warn("CmdAnimate", "Missing argument: '@animate' expects a character id and an animation name")
		if wait and ctx.bus:
			ctx.bus.resolve_block()
		return

	var char_id: String = rest[0].to_lower()
	var anim_name: String = rest[1]
	var params: Dictionary = VNEngineAnimation.parse_params(rest.slice(2))

	if wait:
		await ctx.animations.play_on_character(char_id, anim_name, params, ctx)
		if ctx.bus:
			ctx.bus.resolve_block()
	else:
		ctx.animations.play_on_character(char_id, anim_name, params, ctx)
