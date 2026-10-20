extends Control
const Model = preload("res://game/resort_model.gd")
const Hill = preload("res://game/hill_view.gd")
const Slalom = preload("res://game/slalom_view.gd")
const SAVE_PATH: String = "user://resort-v1.json"
const NAVY: Color = Color("183b54")
const TEAL: Color = Color("40a99c")
const CORAL: Color = Color("f58467")
const WHITE: Color = Color("f6fcff")
var model: RefCounted = Model.new()
var body: VBoxContainer
var shell_margin: MarginContainer
var body_scroll: ScrollContainer
var coin_label: Label
var meta_label: Label
var xp_bar: ProgressBar
var toast_label: Label
var income_label: Label
var active_tab: String = "resort"
var active_side: bool = false
var hill: Control
var slalom: Control
var nav: HBoxContainer
var click_audio: AudioStreamPlayer
var music: AudioStreamPlayer
var timer: float = 0
var busy: bool = false
var services: Node
var last_slalom_prize: int = 0
var reward_claimed: bool = false
var captured: bool = false
var capture_mode: String = ""
var capture_path: String = ""
var test_mode: bool = false

func _ready() -> void:
	services = get_node_or_null("/root/Services")
	if is_instance_valid(services) and services.has_signal("menu_bottom_reserve_changed"):
		services.connect("menu_bottom_reserve_changed", _apply_banner_layout)
	get_viewport().size_changed.connect(_apply_banner_layout)
	if not test_mode:
		_load_save()
	var now: float = Time.get_unix_time_from_system()
	var offline: float = model.apply_offline(now)
	model.ensure_quests(now)
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_mode = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-path="):
			capture_path = arg.trim_prefix("--capture-path=")
		elif arg == "--test-profile":
			model.data.coins = 1500.0
			model.data.runs = [2,1,1,1,0,0,1,0,0,0,0,0]
			model.data.level = 5
			model.data.staff = 3
			model.data.revenue = 2400.0
	_build_shell()
	_show_tab(capture_mode if capture_mode in ["resort","runs","lodge","season","daily","journal"] else "resort")
	if capture_mode == "slalom":
		_start_slalom()
		if slalom != null:
			slalom.distance = 850.0
	if offline > 2.0:
		_toast("Welcome back! Your team earned %s coins." % _money(offline))
	_sync_achievements()
	_save()
	if not capture_path.is_empty():
		_capture.call_deferred()

func _build_shell() -> void:
	var bg: ColorRect = ColorRect.new()
	bg.color = Color("d9f0f4")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	var margin: MarginContainer = MarginContainer.new()
	shell_margin = margin
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left",18)
	margin.add_theme_constant_override("margin_right",18)
	margin.add_theme_constant_override("margin_top",22)
	margin.add_theme_constant_override("margin_bottom",64)
	add_child(margin)
	var layout: VBoxContainer = VBoxContainer.new()
	layout.add_theme_constant_override("separation",10)
	margin.add_child(layout)
	var brand: HBoxContainer = HBoxContainer.new()
	layout.add_child(brand)
	var logo: TextureRect = TextureRect.new()
	logo.texture = preload("res://assets/icon.svg")
	logo.custom_minimum_size = Vector2(54,54)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	brand.add_child(logo)
	var titles: VBoxContainer = VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	brand.add_child(titles)
	titles.add_child(_label("POWDER PINES",30,NAVY))
	titles.add_child(_label("Little village. Endless winter.",14,Color("4f7383")))
	var sound: Button = _button("♪",_toggle_sound,Color("d0e6e9"))
	sound.custom_minimum_size = Vector2(48,48)
	sound.mouse_filter = Control.MOUSE_FILTER_STOP
	brand.add_child(sound)
	var stats: HBoxContainer = HBoxContainer.new()
	layout.add_child(stats)
	coin_label = _label("",23,NAVY)
	coin_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stats.add_child(coin_label)
	meta_label = _label("",16,NAVY)
	stats.add_child(meta_label)
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size.y = 7
	xp_bar.show_percentage = false
	xp_bar.add_theme_stylebox_override("background",_style(Color("b8d9e4"),4))
	xp_bar.add_theme_stylebox_override("fill",_style(TEAL,4))
	layout.add_child(xp_bar)
	body_scroll = ScrollContainer.new()
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.follow_focus = true
	layout.add_child(body_scroll)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",9)
	body_scroll.add_child(body)
	toast_label = _label("Drag the mountain to explore. Your team earns while you play.",14,Color("406576"))
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.custom_minimum_size.y = 38
	layout.add_child(toast_label)
	nav = HBoxContainer.new()
	nav.add_theme_constant_override("separation",8)
	layout.add_child(nav)
	for tab in ["resort","lodge","season"]:
		var button: Button = _button(String(tab).capitalize(),_show_tab.bind(String(tab)),NAVY)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		nav.add_child(button)
	click_audio = AudioStreamPlayer.new()
	click_audio.stream = preload("res://assets/click.ogg")
	click_audio.volume_db = -14
	add_child(click_audio)
	music = AudioStreamPlayer.new()
	music.stream = preload("res://assets/alpine-loop.wav")
	music.volume_db = -23
	add_child(music)
	music.finished.connect(func():
		if _sound_enabled():
			music.play())
	if _sound_enabled():
		music.play()
	_update_stats()
	_apply_banner_layout()

func _apply_banner_layout(reserve_override: float = -1.0) -> void:
	if not is_instance_valid(shell_margin): return
	var reserve := reserve_override
	if reserve < 0.0:
		reserve = float(services.call("menu_bottom_reserve", self)) if is_instance_valid(services) and services.has_method("menu_bottom_reserve") else 0.0
	if busy: reserve = 0.0
	shell_margin.add_theme_constant_override("margin_bottom", int(ceil(maxf(64.0, 18.0 + maxf(0.0, reserve)))))
	if is_instance_valid(body_scroll):
		body_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED if busy else ScrollContainer.SCROLL_MODE_AUTO
		body_scroll.mouse_filter = Control.MOUSE_FILTER_IGNORE if busy else Control.MOUSE_FILTER_PASS


func _process(delta: float) -> void:
	model.tick(delta)
	timer += delta
	_update_stats()
	if timer >= 5.0:
		timer = 0
		model.ensure_quests(Time.get_unix_time_from_system())
		_sync_achievements()
		_save()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save()
	elif what == NOTIFICATION_APPLICATION_RESUMED and body != null:
		var amount: float = model.apply_offline(Time.get_unix_time_from_system())
		model.ensure_quests(Time.get_unix_time_from_system())
		if amount > 2:
			_toast("Your team earned %s coins while you were away." % _money(amount))

func _exit_tree() -> void:
	if music != null:
		music.stop()
		music.stream = null
	if click_audio != null:
		click_audio.stop()
		click_audio.stream = null

func _update_stats() -> void:
	if coin_label == null:
		return
	coin_label.text = "●  %s coins" % _money(float(model.data.coins))
	meta_label.text = "LV %d  ·  SEASON %d" % [int(model.data.level),int(model.data.season)]
	xp_bar.max_value = model.xp_to_next()
	xp_bar.value = int(model.data.xp)
	if income_label != null and is_instance_valid(income_label):
		income_label.text = "%0.1f coins / sec  ·  %d runs open" % [model.income_rate(),model.unlocked_runs()]

func _clear_body() -> void:
	hill = null
	slalom = null
	income_label = null
	for child in body.get_children():
		# Keep retired controls in-tree until current input dispatch completes.
		if child is CanvasItem: child.hide()
		child.queue_free()

func _show_tab(tab: String) -> void:
	_play_click()
	active_tab = tab
	busy = false
	_clear_body()
	nav.visible = true
	if services != null:
		services.set_menu_visible(true)
	_apply_banner_layout()
	match tab:
		"resort": _resort_page()
		"runs": _runs_page()
		"lodge": _lodge_page()
		"season": _season_page()
		"daily": _daily_page()
		"journal": _journal_page()
	_update_stats()

func _resort_page() -> void:
	var sides: HBoxContainer = HBoxContainer.new()
	body.add_child(sides)
	for side in [false,true]:
		var button: Button = _button("North face" if side else "Sunny front",_switch_side.bind(side),TEAL if side==active_side else Color("afced7"))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		sides.add_child(button)
	hill = Hill.new()
	hill.model = model
	hill.backside = active_side
	hill.custom_minimum_size.y = 385
	hill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(hill)
	var map_tools: HBoxContainer = HBoxContainer.new()
	body.add_child(map_tools)
	map_tools.add_child(_button("↑ Summit",_move_hill.bind(-390.0),Color("afced7")))
	income_label = _label("",15,NAVY)
	income_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	income_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	map_tools.add_child(income_label)
	map_tools.add_child(_button("↓ Village",_move_hill.bind(390.0),Color("afced7")))
	var actions: HBoxContainer = HBoxContainer.new()
	body.add_child(actions)
	var runs_button: Button = _button("Build runs",_show_tab.bind("runs"),NAVY)
	runs_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(runs_button)
	var ski_button: Button = _button("SKI NOW  →",_start_slalom,CORAL)
	ski_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	actions.add_child(ski_button)

func _switch_side(side: bool) -> void:
	active_side = side
	_show_tab("resort")

func _move_hill(amount: float) -> void:
	if hill != null:
		hill.move_view(amount)

func _runs_page() -> void:
	_title("A mountain of possibilities", "Open new pistes or groom your favorites to earn more.")
	var list: VBoxContainer = _scroll_list()
	for i in range(12):
		var level: int = int(model.data.runs[i])
		var panel: VBoxContainer = _card(list)
		var row: HBoxContainer = HBoxContainer.new()
		panel.add_child(row)
		var text_box: VBoxContainer = VBoxContainer.new()
		text_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(text_box)
		text_box.add_child(_label(model.RUN_NAMES[i],19,NAVY))
		text_box.add_child(_label(("NORTH" if i>=6 else "FRONT") + ("  ·  LEVEL %d/5" % level if level>0 else "  ·  UNOPENED"),12,Color("5c7c8b")))
		var cost_text: String = "MAX" if level>=5 else ("Open  %s" if level==0 else "Groom  %s") % _money(model.run_cost(i))
		var button: Button = _button(cost_text,_buy_run.bind(i),TEAL if level>0 else CORAL)
		button.disabled = level>=5
		row.add_child(button)
	body.add_child(_button("← Back to mountain",_show_tab.bind("resort"),Color("afced7")))

func _buy_run(index: int) -> void:
	if model.buy_run(index):
		_after_action("%s is ready for fresh tracks!" % model.RUN_NAMES[index])
		_show_tab("runs")
	else:
		_toast("Not quite enough coins. Ski a round or let your village earn.")

func _lodge_page() -> void:
	_title("The heart of the village", "A warm chalet, happy guests, and a team that keeps winter moving.")
	var list: VBoxContainer = _scroll_list()
	var specs: Array = [["chalet","Chalet comforts","Warm drinks, better rooms and a longer offline earnings cap."],["staff","Mountain team","Hire lifties, groomers and baristas. Each team member boosts income."],["tickets","Ticket & rental sales","Upgrade your sales desk and rentals to earn more from every run."]]
	for item in specs:
		var card: VBoxContainer = _card(list)
		card.add_child(_label("%s   ·   %d" % [item[1],int(model.data[item[0]])],22,NAVY))
		card.add_child(_paragraph(item[2]))
		var capped: bool = (int(model.data[item[0]]) >= (20 if item[0]=="staff" else 8))
		var button: Button = _button("Fully upgraded" if capped else "Upgrade  ·  %s coins" % _money(model.upgrade_cost(item[0])),_upgrade.bind(String(item[0])),TEAL)
		button.disabled = capped
		card.add_child(button)
	var info: VBoxContainer = _card(list)
	info.add_child(_paragraph("Offline guests earn at 50%% of your live rate for up to %d hours. Seasons preserve your whole village." % int(model.offline_cap()/3600)))
	info.add_child(_button("Daily rewards & quests",_show_tab.bind("daily"),CORAL))
	info.add_child(_button("Journal & Play Games",_show_tab.bind("journal"),NAVY))

func _upgrade(kind: String) -> void:
	if model.upgrade(kind):
		_after_action("A little more mountain magic. Upgrade complete!")
		_show_tab("lodge")
	else:
		_toast("Save a few more coins for this upgrade.")

func _season_page() -> void:
	_title("Season %d · A new chapter" % int(model.data.season), "Meet three mountain milestones to welcome the next winter.")
	var goals: Dictionary = model.season_goals()
	var list: VBoxContainer = _scroll_list()
	var card: VBoxContainer = _card(list)
	card.add_child(_label("THE WINTER NOTEBOOK",18,TEAL))
	_progress_row(card,"Open runs",model.unlocked_runs(),int(goals.runs))
	_progress_row(card,"Season earnings",int(model.data.season_revenue),int(goals.revenue))
	_progress_row(card,"Slalom outings",int(model.data.season_slaloms),int(goals.slaloms))
	card.add_child(_paragraph("Next season: +20% base income, a coin grant, and 100 XP. Your runs, chalet and team stay with you."))
	var next: Button = _button("WELCOME SEASON %d" % (int(model.data.season)+1),_advance_season,CORAL)
	next.disabled = not model.can_advance_season()
	card.add_child(next)
	var daily: VBoxContainer = _card(list)
	daily.add_child(_label("A reason to return",23,NAVY))
	daily.add_child(_paragraph("Seven-day gifts and fresh UTC-day quests reward a few relaxed runs at your own pace."))
	daily.add_child(_button("Open daily notebook",_show_tab.bind("daily"),TEAL))
	var ads: VBoxContainer = _card(list)
	ads.add_child(_label("A little lift",22,NAVY))
	ads.add_child(_paragraph("An optional rewarded ad can bring a 5-minute income grant. Unavailable ads never block the village."))
	var ad_button: Button = _button("Rewarded lift · %s coins" % _money(model.income_rate()*300),_income_reward,NAVY)
	ad_button.disabled = services == null or not services.can_reward()
	ads.add_child(ad_button)

func _advance_season() -> void:
	if model.advance_season():
		_after_action("Welcome to season %d! Your village keeps growing." % int(model.data.season))
		_show_tab("season")

func _daily_page() -> void:
	_title("Your daily notebook", "One claim per UTC day. Missed a day? Your village will still be here.")
	var list: VBoxContainer = _scroll_list()
	var card: VBoxContainer = _card(list)
	card.add_child(_label("7 DAYS OF WINTER",20,NAVY))
	var days: HBoxContainer = HBoxContainer.new()
	days.add_theme_constant_override("separation",4)
	card.add_child(days)
	for i in range(7):
		var badge: VBoxContainer = VBoxContainer.new()
		badge.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		days.add_child(badge)
		var day: Label = _label("D%d" % (i+1),15,TEAL if i<int(model.data.streak) else NAVY)
		day.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(day)
		var prize: Label = _label(str(model.LOGIN_REWARDS[i]),13,NAVY)
		prize.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.add_child(prize)
	var today: int = int(floor(Time.get_unix_time_from_system()/86400.0))
	var claim: Button = _button("Gift claimed today" if int(model.data.login_day)>=today else "Claim today's gift",_daily_claim,CORAL)
	claim.disabled = int(model.data.login_day)>=today
	card.add_child(claim)
	var names: Array[String] = ["Earn 400 coins", "Pass 12 slalom gates", "Finish 2 slalom outings"]
	for i in range(3):
		var quest: VBoxContainer = _card(list)
		quest.add_child(_label(names[i],20,NAVY))
		var progress: ProgressBar = ProgressBar.new()
		progress.value = model.quest_progress(i)*100
		progress.custom_minimum_size.y = 15
		quest.add_child(progress)
		var button: Button = _button("Claimed" if i in model.data.quests_claimed else "Claim %d coins + 25 XP" % (80+i*40),_claim_quest.bind(i),TEAL)
		button.disabled = i in model.data.quests_claimed or model.quest_progress(i)<1
		quest.add_child(button)
	body.add_child(_button("← Back to season",_show_tab.bind("season"),Color("afced7")))

func _daily_claim() -> void:
	var prize: int = model.daily_claim(Time.get_unix_time_from_system())
	_after_action("A winter gift: +%d coins. Day %d of 7." % [prize,int(model.data.streak)])
	_show_tab("daily")

func _claim_quest(index: int) -> void:
	var prize: int = model.claim_quest(index)
	_after_action("Notebook complete! +%d coins and 25 XP." % prize)
	_show_tab("daily")

func _journal_page() -> void:
	_title("Mountain memories", "Every fresh track adds to your mountain story.")
	var list: VBoxContainer = _scroll_list()
	var card: VBoxContainer = _card(list)
	card.add_child(_label("%d OF 20 ACHIEVEMENTS" % model.data.achievements.size(),21,NAVY))
	card.add_child(_paragraph("Best slalom: %d · Outings: %d\nLifetime earnings: %s · Gates: %d" % [int(model.data.best_slalom),int(model.data.slaloms),_money(float(model.data.revenue)),int(model.data.gates)]))
	if services != null:
		var android: bool = OS.get_name()=="Android"
		card.add_child(_paragraph("Play Games sign-in is optional. Your mountain stays playable offline." if android else "Online rankings are available in the Android edition. Your mountain is saved on this device."))
		var sign_in_button: Button = _button("Sign in to Play Games",_service_action.bind("sign_in"),TEAL)
		sign_in_button.disabled = not android
		card.add_child(sign_in_button)
		var achievements_button: Button = _button("Play Games achievements",_service_action.bind("open_achievements"),NAVY)
		achievements_button.disabled = not android
		card.add_child(achievements_button)
		var leaderboard_button: Button = _button("Slalom leaderboard",_leaderboard,NAVY)
		leaderboard_button.disabled = not android
		card.add_child(leaderboard_button)
		var privacy_button: Button = _button("Privacy options",_service_action.bind("privacy_options"),Color("afced7"))
		privacy_button.disabled = not android
		card.add_child(privacy_button)
	else:
		card.add_child(_paragraph("Online services are unavailable here. All resort progress remains playable offline."))
	for key in model.data.achievements:
		list.add_child(_label("★  " + String(key).replace("_"," ").capitalize(),18,TEAL))
	body.add_child(_button("← Back to lodge",_show_tab.bind("lodge"),Color("afced7")))

func _service_action(method: String) -> void:
	if services != null:
		services.call(method)

func _leaderboard() -> void:
	if services != null:
		services.open_leaderboards("best_slalom")

func _start_slalom() -> void:
	_play_click()
	active_tab = "slalom"
	busy = true
	_clear_body()
	nav.visible = false
	if services != null:
		services.set_menu_visible(false)
	_apply_banner_layout()
	_title("Fresh tracks", "Drag or hold anywhere to steer. Pass BETWEEN each pair of flags.")
	slalom = Slalom.new()
	slalom.custom_minimum_size.y = 450
	slalom.size_flags_vertical = Control.SIZE_EXPAND_FILL
	slalom.completed.connect(_slalom_finished)
	body.add_child(slalom)
	body.add_child(_button("Leave slope",_leave_slalom,Color("afced7")))
	_toast("Touch and drag to steer. Keyboard: ← →. A relaxed run lasts about 28 seconds.")

func _leave_slalom() -> void:
	_show_tab("resort")
	_toast("Back at the village. An unfinished outing earns no slalom prize.")

func _slalom_finished(score: int,gates: int,hits: int) -> void:
	if not busy:
		return
	busy = false
	last_slalom_prize = model.finish_slalom(score,gates,hits)
	reward_claimed = false
	_after_action("A lovely run. Your coins and XP are already saved.")
	if services != null:
		services.round_finished()
	_clear_body()
	nav.visible = true
	if services != null:
		services.set_menu_visible(true)
	_apply_banner_layout()
	_title("That mountain feeling", "A few fresh tracks, a little progress, and a warm chalet waiting.")
	var card: VBoxContainer = _card(body)
	card.add_child(_label("%d POINTS" % score,38,NAVY))
	card.add_child(_label("%d/12 gates  ·  %d missed" % [gates,hits],20,TEAL))
	card.add_child(_paragraph("Earned %d coins and %d XP.\nYour team kept the village running while you skied." % [last_slalom_prize,20+gates*3]))
	card.add_child(_button("Ski another run",_start_slalom,CORAL))
	var reward: Button = _button("Watch a rewarded ad · Double this prize",_double_prize,NAVY)
	reward.disabled = services == null or not services.can_reward()
	card.add_child(reward)
	card.add_child(_button("Back to village",_show_tab.bind("resort"),TEAL))

func _double_prize() -> void:
	if reward_claimed or services == null or not services.can_reward():
		_toast("Rewarded ads are unavailable. Your normal prize is already yours.")
		return
	reward_claimed = true
	var prize_amount: int = last_slalom_prize
	services.reward_requested("double_slalom",func(granted: bool):
		if granted:
			model.add_coins(prize_amount)
			_after_action("Reward earned! +%d extra coins." % prize_amount)
		else:
			reward_claimed = false
			_toast("No earned ad reward. Your original prize is safe."))

func _income_reward() -> void:
	if services == null or not services.can_reward():
		_toast("Rewarded ads are unavailable here.")
		return
	var amount: float = model.income_rate()*300
	services.reward_requested("village_lift",func(granted: bool):
		if granted:
			model.add_coins(amount)
			_after_action("Your village lift earned %s coins!" % _money(amount))
		else:
			_toast("No earned ad reward. The village keeps running."))

func _sync_achievements() -> void:
	var earned: Array[String] = model.earned_achievements()
	if services != null and capture_path.is_empty() and not test_mode:
		# Resend local achievements so configuration supplied later can catch up.
		for key in model.data.achievements:
			services.unlock(String(key))
		services.submit("lifetime_revenue",int(model.data.revenue))
		services.submit("best_slalom",int(model.data.best_slalom))
		services.submit("player_level",int(model.data.level))
		services.submit("ski_runs",int(model.data.slaloms))
	if not earned.is_empty():
		_toast("★ " + earned[0].replace("_"," ").capitalize() + " · Achievement earned!")

func _after_action(message: String) -> void:
	_play_click()
	_sync_achievements()
	_save()
	_toast(message)

func _load_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var value: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if value is Dictionary:
			model.load_data(value)

func _save() -> void:
	if not capture_path.is_empty() or test_mode:
		return
	model.data.last_seen = Time.get_unix_time_from_system()
	var file: FileAccess = FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(model.data))

func _toggle_sound() -> void:
	model.data.sound = not bool(model.data.sound)
	if _sound_enabled():
		music.play()
	else:
		music.stop()
	_save()
	_toast("Sound on" if bool(model.data.sound) else "Sound off")

func _play_click() -> void:
	if click_audio != null and _sound_enabled():
		click_audio.play()

func _sound_enabled() -> bool:
	return bool(model.data.sound) and not test_mode and DisplayServer.get_name()!="headless"

func _toast(message: String) -> void:
	if toast_label != null:
		toast_label.text = message

func _title(title: String, subtitle: String) -> void:
	body.add_child(_label(title,27,NAVY))
	body.add_child(_paragraph(subtitle))

func _label(text: String,font_size: int,color: Color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.add_theme_color_override("font_color",color)
	label.add_theme_font_size_override("font_size",font_size)
	return label

func _paragraph(text: String) -> Label:
	var label: Label = _label(text,16,Color("4f7383"))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _style(color: Color,radius: int=12) -> StyleBoxFlat:
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = color
	box.set_corner_radius_all(radius)
	box.content_margin_left = 14
	box.content_margin_right = 14
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	return box

func _button(text: String,callback: Callable,color: Color) -> Button:
	var button: Button = Button.new()
	button.mouse_filter = Control.MOUSE_FILTER_PASS if not busy else Control.MOUSE_FILTER_STOP
	button.text = text
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size",16)
	button.add_theme_color_override("font_color",WHITE if color==NAVY or color==TEAL else NAVY)
	button.add_theme_color_override("font_hover_color",WHITE if color==NAVY or color==TEAL else NAVY)
	button.add_theme_color_override("font_disabled_color",Color("728b96"))
	button.add_theme_stylebox_override("normal",_style(color))
	button.add_theme_stylebox_override("hover",_style(color.lightened(0.1)))
	button.add_theme_stylebox_override("pressed",_style(color.darkened(0.1)))
	button.add_theme_stylebox_override("disabled",_style(Color("c5dce2")))
	button.pressed.connect(callback)
	return button

func _card(parent: Node) -> VBoxContainer:
	var panel: PanelContainer = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS
	panel.add_theme_stylebox_override("panel",_style(WHITE,16))
	parent.add_child(panel)
	var content: VBoxContainer = VBoxContainer.new()
	content.add_theme_constant_override("separation",10)
	panel.add_child(content)
	return content

func _scroll_list() -> VBoxContainer:
	var scroll: ScrollContainer = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	var list: VBoxContainer = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation",12)
	scroll.add_child(list)
	return list

func _progress_row(parent: Node,title: String,value: int,target: int) -> void:
	parent.add_child(_label("%s   %s / %s" % [title,_money(value),_money(target)],18,NAVY))
	var progress: ProgressBar = ProgressBar.new()
	progress.max_value = target
	progress.value = value
	progress.custom_minimum_size.y = 12
	progress.show_percentage = false
	parent.add_child(progress)

func _money(value: float) -> String:
	if value>=1000000:
		return "%.1fm" % (value/1000000)
	if value>=10000:
		return "%.1fk" % (value/1000)
	return str(int(value))

func _capture() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var result: Error = image.save_png(capture_path)
	print("POWDER_PINES_CAPTURE ",capture_path," result=",result)
	captured = true
	get_tree().quit(0 if result==OK else 1)
