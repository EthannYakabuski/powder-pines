extends SceneTree
const Resort = preload("res://game/resort_model.gd")
const Slope = preload("res://game/slalom_view.gd")
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
	var resort: RefCounted = Resort.new()
	check(resort.unlocked_runs()==1,"A new resort starts with one playable run")
	var initial_rate: float = resort.income_rate()
	check(not resort.buy_run(11),"An unaffordable run does not unlock")
	check(resort.buy_run(1),"The starting balance affords a second run")
	check(resort.unlocked_runs()==2 and resort.income_rate()>initial_rate,"New runs increase both count and income")
	check(not resort.buy_run(-1) and not resort.buy_run(12),"Run bounds cannot alter economy")
	resort.data.coins = 1e8
	for i in range(20):
		resort.upgrade("staff")
	check(int(resort.data.staff)==20 and not resort.upgrade("staff"),"Team limit is enforced")
	check(not resort.upgrade("not_a_real_upgrade"),"Unknown upgrade types are rejected")
	for i in range(10):
		resort.buy_run(0)
	check(int(resort.data.runs[0])==5,"Piste grooming caps at level five")
	resort.data.last_seen = 1000.0
	var offline_rate: float = resort.income_rate()
	var offline: float = resort.apply_offline(1000.0+86400.0)
	check(is_equal_approx(offline,offline_rate*resort.offline_cap()*0.5),"Offline income respects the lodge cap and half-rate")
	check(resort.apply_offline(1000.0+86400.0)==0,"Offline earnings cannot be claimed twice")
	check(resort.apply_offline(500.0)==0,"A backwards clock does not create negative earnings")
	var daily: RefCounted = Resort.new()
	for day in range(7):
		check(daily.daily_claim((100.0+day)*86400.0)==Resort.LOGIN_REWARDS[day],"Seven-day reward value %d"%day)
		check(daily.daily_claim((100.0+day)*86400.0)==0,"Each daily gift is single claim %d"%day)
	check(int(daily.data.streak)==7,"Seven consecutive days complete the track")
	check(daily.daily_claim(108.0*86400.0)==80 and int(daily.data.streak)==1,"A missed day restarts rewards without removing progress")
	daily.ensure_quests(108.0*86400.0)
	daily.add_coins(400)
	check(daily.quest_progress(0)==1,"Earnings quest uses the UTC-day baseline")
	check(daily.claim_quest(0)==80 and daily.claim_quest(0)==0,"Quest reward is granted exactly once")
	daily.finish_slalom(1110,12,0)
	check(int(daily.data.best_slalom)==1110 and int(daily.data.gates)==12,"Slalom records score and gates")
	check(daily.quest_progress(1)==1 and daily.quest_progress(2)==0.5,"Slalom updates relevant quests")
	daily.ensure_quests(109.0*86400.0)
	check(daily.quest_progress(0)==0 and daily.data.quests_claimed.is_empty(),"UTC-day rollover starts fresh quests")
	var winter: RefCounted = Resort.new()
	winter.data.runs = [1,1,1,1,0,0,0,0,0,0,0,0]
	winter.data.season_revenue = 700.0
	winter.data.season_slaloms = 3
	var before: float = winter.income_rate()
	check(winter.can_advance_season() and winter.advance_season(),"Season goals unlock advancement")
	check(int(winter.data.season)==2 and winter.unlocked_runs()==4,"Season advancement preserves the developed mountain")
	check(winter.income_rate()>before and int(winter.data.season_slaloms)==0,"New season raises income and resets only season goals")
	check(not winter.advance_season(),"Season cannot advance repeatedly without goals")
	var earned: Array[String] = winter.earned_achievements()
	check("season_two" in earned and "run_builder" in earned,"Milestones produce the right achievements")
	check(winter.earned_achievements().is_empty(),"Local achievement grants are idempotent")
	var saved: Variant = JSON.parse_string(JSON.stringify(winter.data))
	var restored: RefCounted = Resort.new()
	restored.load_data(saved)
	check(restored.data==winter.data,"JSON save round-trip preserves progression")
	restored.load_data({"coins":-200,"runs":[-9,999],"staff":999,"achievements":null})
	check(restored.data.coins>=0 and int(restored.data.runs[0])==1 and int(restored.data.runs[1])==5,"Loaded economy and run levels are bounded")
	check(restored.data.runs.size()==12 and int(restored.data.staff)==20 and restored.data.achievements is Dictionary,"Corrupt optional save fields recover safely")
	var slope: Control = Slope.new()
	root.add_child(slope)
	slope.set_process(false)
	slope.size = Vector2(504,500)
	var completion: Array[int] = []
	slope.completed.connect(func(score: int,gates: int,hits: int): completion.append(score); completion.append(gates); completion.append(hits))
	for index in range(12):
		slope.distance = 299.0+float(index)*300.0
		slope.player_x = slope.gate_center(index)
		slope.target_x = slope.player_x
		slope._process(0.02)
	check(slope.gates==12 and slope.hits==0,"Correct steering passes every gate")
	slope.distance = 3999.0
	slope._process(0.02)
	slope._process(0.02)
	check(completion.size()==3 and completion[1]==12 and slope.finished,"Finish callback occurs exactly once")
	slope.queue_free()
	print(JSON.stringify({"suite":"powder-pines-model-and-slope","checks":checks,"failures":failures,"passed":failures.is_empty()}))
	quit(0 if failures.is_empty() else 1)
