extends SceneTree
const AppScene = preload("res://main.tscn")

func _initialize() -> void:
	_run.call_deferred()

func _run() -> void:
	var output: String = "user://captures"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			output = arg.trim_prefix("--out=")
	DirAccess.make_dir_recursive_absolute(output)
	var app: Control = AppScene.instantiate()
	app.test_mode = true
	root.add_child(app)
	await process_frame
	await process_frame
	for page in ["resort","runs","lodge","season","daily","journal","slalom"]:
		if page=="slalom":
			app._start_slalom()
			app.slalom.distance = 850.0
		else:
			app._show_tab(page)
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var path: String = output.path_join(page+".png")
		var result: Error = root.get_texture().get_image().save_png(path)
		print("POWDER_PINES_CAPTURE ",path," result=",result)
		if result!=OK:
			quit(1)
			return
	root.remove_child(app)
	app.free()
	await process_frame
	await process_frame
	quit()
