extends RefCounted
## Deterministic, UI-independent economy. All calendar comparisons use UTC days.
const RUN_NAMES: Array[String] = ["Bunny Meadow", "Pine Ribbon", "Cloudline", "Sunbeam Bowl", "Summit Waltz", "Crystal Drop", "Fern Glade", "Moonlight Pass", "Fox Hollow", "Aurora Ridge", "Silver Cirque", "North Star"]
const LOGIN_REWARDS: Array[int] = [80, 100, 140, 190, 250, 340, 500]
const MAX_RUN_LEVEL: int = 5
var data: Dictionary = {}

func _init() -> void:
	reset()

func reset(now: float = 0.0) -> void:
	data = {"version":1,"coins":180.0,"xp":0,"level":1,"runs":[1,0,0,0,0,0,0,0,0,0,0,0],"chalet":1,"staff":0,"tickets":1,"season":1,"season_revenue":0.0,"season_slaloms":0,"revenue":0.0,"slaloms":0,"gates":0,"best_slalom":0,"login_day":-1,"streak":0,"last_seen":now,"quest_day":-1,"quest_base":{},"quests_claimed":[],"quests_total":0,"achievements":{},"sound":true}

func load_data(saved: Dictionary) -> void:
	reset()
	for key in data:
		if saved.has(key):
			data[key] = saved[key]
	var safe_runs: Array = []
	for i in range(12):
		var value: int = 0
		if data.runs is Array and i < data.runs.size():
			value = clampi(int(data.runs[i]), 0, MAX_RUN_LEVEL)
		safe_runs.append(value)

	safe_runs[0] = maxi(1, int(safe_runs[0]))
	data.runs = safe_runs
	data.coins = clampf(float(data.coins), 0.0, 1.0e15) if is_finite(float(data.coins)) else 180.0
	for key in ["revenue","season_revenue","last_seen"]:
		data[key] = maxf(0.0, float(data[key]))
	for key in ["version","xp","slaloms","gates","best_slalom","season_slaloms","quests_total","streak"]:
		data[key] = maxi(0, int(data[key]))
	data.login_day = int(data.login_day)
	data.quest_day = int(data.quest_day)
	data.level = maxi(1, int(data.level))
	data.chalet = clampi(int(data.chalet), 1, 8)
	data.staff = clampi(int(data.staff), 0, 20)
	data.tickets = clampi(int(data.tickets), 1, 8)
	data.season = maxi(1, int(data.season))
	if not data.achievements is Dictionary:
		data.achievements = {}
	if not data.quest_base is Dictionary:
		data.quest_base = {}
	if not data.quests_claimed is Array:
		data.quests_claimed = []
	var claimed: Array = []
	for value in data.quests_claimed:
		var index: int = int(value)
		if index >= 0 and index < 3 and not index in claimed:
			claimed.append(index)
	data.quests_claimed = claimed
	for key in data.quest_base:
		data.quest_base[key] = float(data.quest_base[key]) if key == "revenue" else int(data.quest_base[key])

func unlocked_runs() -> int:
	var count: int = 0
	for value in data.runs:
		if int(value) > 0:
			count += 1
	return count

func income_rate() -> float:
	var quality: float = 0.0
	for i in range(12):
		quality += float(data.runs[i]) * (1.0 + float(i) * 0.12)
	return quality * (0.55 + float(data.tickets) * 0.25) * (1.0 + float(data.staff) * 0.12) * (1.0 + float(data.chalet - 1) * 0.15) * (1.0 + float(data.season - 1) * 0.2)

func add_coins(amount: float, earned: bool = true) -> void:
	amount = maxf(0.0, amount)
	data.coins += amount
	if earned:
		data.revenue += amount
		data.season_revenue += amount

func tick(seconds: float) -> void:
	add_coins(income_rate() * clampf(seconds, 0.0, 60.0))

func offline_cap() -> float:
	return (4.0 + float(data.chalet - 1) * 2.0) * 3600.0

func apply_offline(now: float) -> float:
	var elapsed: float = clampf(now - float(data.last_seen), 0.0, offline_cap()) if float(data.last_seen) > 0.0 else 0.0
	var earned: float = elapsed * income_rate() * 0.5
	add_coins(earned)
	data.last_seen = now
	return earned

func run_cost(index: int) -> int:
	return int(round(65.0 * pow(1.48, index))) if int(data.runs[index]) == 0 else int(round(55.0 * (index + 1) * pow(1.65, int(data.runs[index]))))

func buy_run(index: int) -> bool:
	if index < 0 or index >= 12 or int(data.runs[index]) >= MAX_RUN_LEVEL:
		return false
	var cost: int = run_cost(index)
	if float(data.coins) < cost:
		return false
	data.coins -= cost
	data.runs[index] += 1
	award_xp(30 + index * 3)
	return true

func upgrade_cost(kind: String) -> int:
	match kind:
		"chalet": return int(round(140.0 * pow(1.8, int(data.chalet) - 1)))
		"staff": return 80 + int(data.staff) * 90
		"tickets": return int(round(110.0 * pow(1.7, int(data.tickets) - 1)))
	return 0

func upgrade(kind: String) -> bool:
	if not kind in ["chalet","staff","tickets"]:
		return false
	if (kind == "staff" and int(data.staff) >= 20) or (kind != "staff" and int(data[kind]) >= 8):
		return false
	var cost: int = upgrade_cost(kind)
	if float(data.coins) < cost:
		return false
	data.coins -= cost
	data[kind] += 1
	award_xp(35)
	return true

func xp_to_next() -> int:
	return 80 + (int(data.level) - 1) * 45

func award_xp(amount: int) -> void:
	data.xp += maxi(0, amount)
	while int(data.xp) >= xp_to_next():
		data.xp -= xp_to_next()
		data.level += 1
		add_coins(30 + int(data.level) * 10, false)

func daily_claim(now: float) -> int:
	var day: int = int(floor(now / 86400.0))
	var last_day: int = int(data.login_day)
	if day <= last_day:
		return 0
	data.streak = (int(data.streak) % 7) + 1 if day - last_day == 1 else 1
	data.login_day = day
	var prize: int = LOGIN_REWARDS[int(data.streak) - 1]
	add_coins(prize)
	award_xp(12)
	return prize

func ensure_quests(now: float) -> void:
	var day: int = int(floor(now / 86400.0))
	if day > int(data.quest_day):
		data.quest_day = day
		data.quest_base = {"revenue":data.revenue,"gates":data.gates,"slaloms":data.slaloms}
		data.quests_claimed = []

func quest_progress(index: int) -> float:
	var keys: Array = ["revenue","gates","slaloms"]
	var goals: Array = [400.0,12.0,2.0]
	return clampf((float(data[keys[index]]) - float(data.quest_base.get(keys[index], 0.0))) / float(goals[index]), 0.0, 1.0)

func claim_quest(index: int) -> int:
	if index < 0 or index > 2 or index in data.quests_claimed or quest_progress(index) < 1.0:
		return 0
	var prize: int = 80 + index * 40
	data.quests_claimed.append(index)
	data.quests_total += 1
	add_coins(prize)
	award_xp(25)
	return prize

func finish_slalom(score: int, gates: int, hits: int) -> int:
	data.slaloms += 1
	data.season_slaloms += 1
	data.gates += maxi(0, gates)
	data.best_slalom = maxi(int(data.best_slalom), score)
	var prize: int = 40 + maxi(0, gates) * 6 + (30 if hits == 0 else 0)
	add_coins(prize)
	award_xp(20 + maxi(0, gates) * 3)
	return prize

func season_goals() -> Dictionary:
	return {"runs":mini(12, int(data.season) * 3 + 1),"revenue":float(data.season) * 650.0,"slaloms":3}

func can_advance_season() -> bool:
	var goals: Dictionary = season_goals()
	return unlocked_runs() >= int(goals.runs) and float(data.season_revenue) >= float(goals.revenue) and int(data.season_slaloms) >= int(goals.slaloms)

func advance_season() -> bool:
	if not can_advance_season():
		return false
	data.season += 1
	data.season_revenue = 0.0
	data.season_slaloms = 0
	add_coins(250 + int(data.season) * 50, false)
	award_xp(100)
	return true

func earned_achievements() -> Array[String]:
	var checks: Dictionary = {"first_tracks":unlocked_runs() >= 2,"run_builder":unlocked_runs() >= 4,"backcountry":int(data.runs[6]) > 0,"full_mountain":unlocked_runs() == 12,"chalet_host":int(data.chalet) >= 2,"dream_chalet":int(data.chalet) >= 8,"team_spirit":int(data.staff) >= 1,"growing_team":int(data.staff) >= 5,"first_slalom":int(data.slaloms) >= 1,"clean_lines":int(data.best_slalom) >= 1000,"slope_regular":int(data.slaloms) >= 10,"winter_wealth":float(data.revenue) >= 1000.0,"alpine_tycoon":float(data.revenue) >= 100000.0,"season_two":int(data.season) >= 2,"season_three":int(data.season) >= 3,"mountain_legend":int(data.season) >= 5,"seven_days":int(data.streak) >= 7,"quest_keeper":int(data.quests_total) >= 7,"level_five":int(data.level) >= 5,"level_ten":int(data.level) >= 10}
	var newly_earned: Array[String] = []
	for key in checks:
		if checks[key] and not data.achievements.has(key):
			data.achievements[key] = true
			newly_earned.append(String(key))
	return newly_earned
