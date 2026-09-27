class_name VNEngineEndingPlayer
extends RefCounted


func present(root: VNEngineMain, ending: VNEngineEndingDef, stage: VNEngineStageScreen, shared_resolver: VNEngineAssetResolver) -> void:
	var overlay: VNEngineCardOverlay = root.get_card_overlay()
	var opened: bool = false
	var opened_movie: bool = false

	if ending.ed_movie != "":
		var movie_resolver: VNEngineAssetResolver = _resolver_for(stage, shared_resolver)
		var movie_path: String = movie_resolver.resolve("movie", ending.ed_movie) if movie_resolver != null else ""
		if movie_path != "":
			root.persistent_audio.stop_bgm()
			overlay.open(VNEngineCardOverlay.MODE_MOVIE, {"movie_path": movie_path, "movie_id": ending.ed_movie, "hold_on_close": true})
			opened = true
			opened_movie = true

	if not opened and ending.cg != "":
		var image_resolver: VNEngineAssetResolver = _resolver_for(stage, shared_resolver)
		var image_path: String = image_resolver.resolve("cg", ending.cg) if image_resolver != null else ""
		if image_path != "":
			overlay.open(VNEngineCardOverlay.MODE_IMAGE, {"image_path": image_path, "hold_on_close": true}, ending.card_duration)
			opened = true

	if not opened:
		overlay.open(VNEngineCardOverlay.MODE_TITLE, {"title": ending.title, "hold_on_close": true}, ending.card_duration)

	if not opened_movie and ending.bgm != "":
		var bgm_path: String = shared_resolver.resolve("music", ending.bgm)
		if bgm_path != "":
			root.persistent_audio.play_bgm(bgm_path, true)

	await overlay.finished


func release(root: VNEngineMain) -> void:
	root.get_card_overlay().release()


func _resolver_for(stage: VNEngineStageScreen, shared_resolver: VNEngineAssetResolver) -> VNEngineAssetResolver:
	if stage != null and stage.story_runner != null and stage.story_runner.ctx != null:
		return stage.story_runner.ctx.assets
	return shared_resolver
