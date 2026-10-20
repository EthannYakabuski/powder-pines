extends SceneTree
const AppScene = preload("res://main.tscn")
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
	_run.call_deferred()

func check(condition: bool,message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)

func _run() -> void:
	root.size = Vector2i(540,960)
	root.content_scale_size = Vector2i(540,960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	var app: Control = AppScene.instantiate()
	app.test_mode = true
	root.add_child(app)
	app.set_process(false)
	await process_frame
	for page in ["resort","runs","lodge","season","daily","journal"]:
		app._show_tab(page)
		await process_frame
		await process_frame
		check(app.body.get_child_count()>0,"Page builds: "+page)
		check(app.nav.visible,"Navigation remains available: "+page)
		check(app.nav.get_global_rect().end.y<=root.size.y,"Navigation fits viewport: "+page)
	app._show_tab("resort")
	app._switch_side(true)
	await process_frame
	await process_frame
	check(app.hill.backside,"North face can be selected")
	app._move_hill(800)
	check(app.hill.scroll_y>0,"Hill can be panned to lower runs")
	app.model.data.coins = 10000.0
	app._buy_run(6)
	check(int(app.model.data.runs[6])==1,"Run UI opens the north face run")
	app._upgrade("staff")
	check(int(app.model.data.staff)==1,"Lodge UI hires an employee")
	app._daily_claim()
	check(int(app.model.data.streak)==1,"Daily UI grants the login gift")
	var after_gift: float = float(app.model.data.coins)
	app._daily_claim()
	check(float(app.model.data.coins)==after_gift,"Repeated daily UI action cannot duplicate a gift")
	app._start_slalom()
	check(app.busy and app.slalom!=null and not app.nav.visible,"Slalom enters a focused playable state")
	app._slalom_finished(1200,12,0)
	check(not app.busy and app.nav.visible and int(app.model.data.slaloms)==1,"Slalom finish grants progression and restores navigation")
	var after_finish: float = float(app.model.data.coins)
	app._slalom_finished(1200,12,0)
	check(float(app.model.data.coins)==after_finish,"Duplicate finish callback cannot grant a second prize")
	if app.services==null or not app.services.can_reward():
		app._double_prize()
		check(float(app.model.data.coins)==after_finish,"Unavailable rewarded ad grants no fake coins")
	root.remove_child(app)
	app.free()
	await process_frame
	await process_frame
	print(JSON.stringify({"suite":"powder-pines-ui-flows","checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
