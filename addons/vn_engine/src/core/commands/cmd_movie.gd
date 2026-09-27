class_name VNEngineCmdMovie
extends VNEngineCommand

func command_name() -> String:
	return "movie"

func is_blocking() -> bool:
	return true

func apply(args: String, ctx: VNEngineCommandContext) -> void:
	var movie_id := args.strip_edges()

	if ctx.video:
		var can_play := movie_id != "" and ctx.assets != null and ctx.assets.resolve("movie", movie_id) != ""
		if can_play and ctx.bus:
			ctx.bus.blocked_finished.connect(func(): VNEngineMain.save_data().unlock_movie(movie_id), CONNECT_ONE_SHOT)
		ctx.video.play_movie(movie_id)
	else:
		VNEngineLog.warn("CmdMovie", "No VideoSystem in scene, resolving block immediately: %s" % movie_id)
		if ctx.bus:
			ctx.bus.resolve_block()
