extends Node
## 오늘의 판 · 주간 리그 랭킹 (Save.league 로 써요)
##
## 오늘의 판: 하루 한 번만 기록되는 판. 모두 같은 순서로 몰랑이가 나오고(날짜 씨앗), 날마다 규칙이 하나씩 바뀌어요.
## 주간 리그: 무한 모드 이번 주 최고 점수로 비슷한 사람 30명 안에서 순위를 겨뤄요. 월요일 0시(한국)에 끝나고
##   위쪽은 다음 리그로 올라가고(승급), 아래쪽은 내려가요(강등). 순위만큼 보석을 받아요.
##
## 서버: Supabase (무료 요금제로 충분). SUPA_URL·SUPA_KEY 를 채우면 진짜 랭킹, 비어 있으면 「연습 리그」
##   (이 기기에서만 도는 연습 상대와 겨뤄요 — 화면에 「연습」이라고 표시). 테이블 만드는 SQL: docs/랭킹-서버.md

const SUPA_URL := ""        # 예: https://abcdefgh.supabase.co
const SUPA_KEY := ""        # Project Settings → API → anon public key (공개돼도 괜찮은 키)

const TIERS := ["브론즈", "실버", "골드", "플래티넘", "다이아", "몰랑"]
const TIER_COL := ["#d39a6a", "#c9d3dc", "#ffd166", "#7ee0d0", "#8fc8ff", "#ff9dbb"]
const GROUP := 30

## 오늘의 판 규칙: 날짜마다 차례로
const RULES := [
	{"id": "basic", "n": "기본", "d": "모두 같은 순서로 몰랑이가 나와요 · 아이템 각 1개"},
	{"id": "noitem", "n": "맨손", "d": "아이템 없이 실력만으로!"},
	{"id": "throws", "n": "150번 던지기", "d": "던지기 150번 안에 최고 점수"},
	{"id": "big", "n": "큰 몰랑이 날", "d": "큰 숫자가 자주 나와요 · 아이템 각 1개"},
	{"id": "shake", "n": "흔들흔들", "d": "흔들기만 3개 · 다른 아이템은 없어요"},
]

const BOT_NAMES := ["말랑콩", "젤리곰", "모찌모찌", "콩떡이", "푸딩", "뭉게", "솜사탕", "토실이", "쫀득이", "꼬물이",
	"방울이", "몽실", "치즈볼", "호떡", "두부", "보들이", "구름빵", "찹쌀", "말캉", "탱글이", "포동", "누룽지",
	"감자칩", "망고", "라떼", "꿀떡", "만두", "콩순", "도토리", "별사탕", "새싹", "버터"]

signal updated      # 리그·오늘의 판 목록을 새로 받았을 때

var board: Array = []        # 이번 주 리그: [{name, score, me, bot}] 점수 순
var daily_board: Array = []  # 오늘의 판: 같은 모양
var loading := false
var last_error := ""
var _access := ""
var _exp := 0.0


func _ready() -> void:
	ensure_week()


func online() -> bool:
	return SUPA_URL != "" and SUPA_KEY != ""


func st() -> Dictionary:
	if not (Save.d.get("league") is Dictionary):
		Save.d["league"] = {"week": week_key(), "tier": 0, "best": 0}
	return Save.d["league"]


func nick() -> String:
	return str(Save.home().get("name", "몰랑이네"))


# ───────────────────────── 날짜 (한국 시간) ─────────────────────────

static func _kst() -> int:
	return int(Time.get_unix_time_from_system()) + 9 * 3600


## 몇 번째 주인지 (월요일 시작). 1970-01-01 은 목요일이라 +3
static func week_no() -> int:
	return int(floor((_kst() / 86400.0 + 3.0) / 7.0))


static func week_key() -> String:
	return "W%d" % week_no()


static func week_left_sec() -> int:
	var next := (week_no() + 1) * 7 * 86400 - 3 * 86400
	return maxi(0, next - _kst())


static func week_progress() -> float:
	return clampf(1.0 - week_left_sec() / (7.0 * 86400.0), 0.0, 1.0)


static func left_text(sec: int) -> String:
	if sec >= 86400:
		return "%d일 %d시간" % [sec / 86400, (sec % 86400) / 3600]
	return "%d시간 %d분" % [sec / 3600, (sec % 3600) / 60]


# ───────────────────────── 주간 리그 ─────────────────────────

func tier() -> int:
	return clampi(int(st().get("tier", 0)), 0, TIERS.size() - 1)


func tier_name(t := -1) -> String:
	return TIERS[tier() if t < 0 else t]


## 몇 등까지 승급 · 몇 등부터 강등 (맨 위·맨 아래 리그는 한쪽 없음)
func zones(size: int) -> Vector2i:
	var up := 0 if tier() >= TIERS.size() - 1 else (ceili(size * 0.2) if size >= 10 else (1 if size >= 3 else 0))
	var down := 0 if tier() == 0 else (floori(size * 0.17) if size >= 10 else 0)
	return Vector2i(up, down)


## 새 주가 됐으면 지난주를 정산: 순위로 승급·강등 + 보석. 결과는 st()["result"] 에 (홈에서 한 번 보여 줌)
func ensure_week() -> void:
	var s := st()
	var wk := week_key()
	if str(s.get("week", "")) == wk:
		return
	var old := str(s.get("week", ""))
	var best := int(s.get("best", 0))
	if old != "" and best > 0:
		var rank := 0
		var size := GROUP
		if online() and s.has("rank_week") and str(s["rank_week"]) == old:
			rank = int(s.get("rank", 0))
			size = int(s.get("rank_size", GROUP))
		else:
			var b := _bot_board(old, tier(), best, 1.0)
			for i in b.size():
				if b[i]["me"]:
					rank = i + 1
			size = b.size()
		if rank > 0:
			var z := zones(size)
			var t0 := tier()
			var gem := 5
			var moved := "stay"
			if rank <= z.x:
				s["tier"] = t0 + 1
				moved = "up"
				gem = 20
			elif z.y > 0 and rank > size - z.y:
				s["tier"] = t0 - 1
				moved = "down"
				gem = 0
			if rank == 1:
				gem = 50
			elif rank <= 3:
				gem = maxi(gem, 30)
			Save.d["gem"] = Save.gem() + gem
			s["result"] = {"rank": rank, "size": size, "from": t0, "to": int(s["tier"]), "moved": moved, "gem": gem, "best": best}
	s["week"] = wk
	s["best"] = 0
	Save.save()


## 무한 모드 판이 끝날 때: 이번 주 최고면 올려요
func submit_week(score: int) -> void:
	ensure_week()
	var s := st()
	if score <= int(s.get("best", 0)):
		return
	s["best"] = score
	Save.save()
	if online():
		_push_week(score)


func my_best() -> int:
	ensure_week()
	return int(st().get("best", 0))


## 리그 목록 새로 고침 (서버면 받아 오고, 아니면 연습 상대로)
func refresh_week() -> void:
	ensure_week()
	if online():
		await _fetch_week()
	else:
		board = _bot_board(week_key(), tier(), my_best(), week_progress())
		_cache_rank()
	updated.emit()


func _cache_rank() -> void:
	var s := st()
	for i in board.size():
		if board[i]["me"]:
			s["rank"] = i + 1
			s["rank_size"] = board.size()
			s["rank_week"] = week_key()


func my_rank() -> int:
	for i in board.size():
		if board[i]["me"]:
			return i + 1
	return 0


## 연습 상대: 주·리그마다 늘 같은 이름·실력. 주가 지날수록 점수가 차오르는 것처럼 보여요
func _bot_board(wk: String, t: int, my: int, prog: float) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash(wk + ":" + str(t))
	var base := maxf(30000.0, float(Save.d.get("best", 0)) * 0.55) * (1.0 + 0.45 * t)
	var names := BOT_NAMES.duplicate()
	for i in names.size():
		var j := r.randi() % names.size()
		var tmp = names[i]
		names[i] = names[j]
		names[j] = tmp
	var out: Array = []
	for i in GROUP - 1:
		var skill := r.randf_range(0.2, 1.9) * base
		var active := clampf(prog * r.randf_range(0.9, 3.0), 0.0, 1.0)     # 이번 주에 얼마나 했나
		var sc := roundi(skill * active / 10.0) * 10
		out.append({"name": names[i % names.size()], "score": sc, "me": false, "bot": true})
	out.append({"name": nick(), "score": my, "me": true, "bot": false})
	out.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]) or (int(a["score"]) == int(b["score"]) and a["me"]))
	return out


# ───────────────────────── 오늘의 판 ─────────────────────────

func dst() -> Dictionary:
	if not (Save.d.get("daily_ch") is Dictionary):
		Save.d["daily_ch"] = {"day": "", "played": false, "score": 0, "streak": 0, "best": 0}
	return Save.d["daily_ch"]


static func day_no() -> int:
	return int(floor(_kst() / 86400.0))


func rule() -> Dictionary:
	return RULES[day_no() % RULES.size()]


## 오늘의 판에서 쓸 수 있는 아이템 (규칙대로, 가방·하루 횟수와 상관없이 모두 같게)
func rule_items() -> Dictionary:
	match str(rule()["id"]):
		"noitem", "throws":
			return {}
		"shake":
			return {"shake": 3}
	return {"shake": 1, "undo": 1, "hammer": 1, "tilt": 1, "x2": 1}


func played_today() -> bool:
	var d := dst()
	return str(d.get("day", "")) == Save.kst_day() and bool(d.get("played", false))


func today_score() -> int:
	return int(dst().get("score", 0)) if str(dst().get("day", "")) == Save.kst_day() else 0


func streak() -> int:
	var d := dst()
	var last := str(d.get("last", ""))
	# 어제나 오늘 했으면 이어지는 중
	var y := Time.get_date_string_from_unix_time(_kst() - 86400)
	return int(d.get("streak", 0)) if (last == Save.kst_day() or last == y) else 0


## 들어갈 때 바로 한 번 쓴 걸로 (나갔다 다시 하기 막기)
func start_daily() -> bool:
	if played_today():
		return false
	var d := dst()
	var y := Time.get_date_string_from_unix_time(_kst() - 86400)
	d["streak"] = (int(d.get("streak", 0)) + 1) if str(d.get("last", "")) == y else 1
	d["last"] = Save.kst_day()
	d["day"] = Save.kst_day()
	d["played"] = true
	d["score"] = 0
	Save.bump("daily")
	Save.save()
	return true


## 판이 끝나면: 점수 기록 + 보상(젤리 · 7일 연속마다 보석 30). 받은 것 설명을 돌려줘요
func finish_daily(score: int) -> String:
	var d := dst()
	d["score"] = maxi(int(d.get("score", 0)), score)
	d["best"] = maxi(int(d.get("best", 0)), score)
	var j := 30 + Save.endless_jelly(score)
	Save.add_jelly(j)
	var txt := "젤리 +%d" % j
	if streak() > 0 and streak() % 7 == 0:
		Save.add_gem(30)
		txt += " · %d일 연속 보석 +30" % streak()
	Save.save()
	if online():
		_push_daily(int(d["score"]))
	return txt


func refresh_daily() -> void:
	if online():
		await _fetch_daily()
	else:
		var r := RandomNumberGenerator.new()
		r.seed = hash(Save.kst_day() + "daily")
		var base := maxf(25000.0, float(Save.d.get("best", 0)) * 0.5)
		var hr := clampf((_kst() % 86400) / 86400.0, 0.05, 1.0)
		daily_board = []
		var names := BOT_NAMES.duplicate()
		for i in names.size():
			var j := r.randi() % names.size()
			var tmp = names[i]
			names[i] = names[j]
			names[j] = tmp
		for i in 19:
			if r.randf() > hr * 1.3:
				continue        # 아직 안 한 사람
			daily_board.append({"name": names[i], "score": roundi(r.randf_range(0.2, 1.8) * base / 10.0) * 10, "me": false, "bot": true})
		if played_today():
			daily_board.append({"name": nick(), "score": today_score(), "me": true, "bot": false})
		daily_board.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	updated.emit()


# ───────────────────────── 서버 (Supabase REST) ─────────────────────────

func _http(method: int, url: String, headers: PackedStringArray, body := "") -> Array:
	var h := HTTPRequest.new()
	h.timeout = 8.0
	add_child(h)
	if h.request(url, headers, method, body) != OK:
		h.queue_free()
		return [0, null]
	var r: Array = await h.request_completed
	h.queue_free()
	var txt := (r[3] as PackedByteArray).get_string_from_utf8()
	return [int(r[1]), JSON.parse_string(txt) if txt != "" else null]


## 익명 로그인: 처음 한 번 가입(계정 없이), 그 뒤엔 refresh token 으로 이어서. 내 줄만 고칠 수 있게 (서버 규칙)
func _auth() -> bool:
	if _access != "" and Time.get_unix_time_from_system() < _exp - 60:
		return true
	var s := st()
	var hd := PackedStringArray(["apikey: " + SUPA_KEY, "Content-Type: application/json"])
	var res: Array
	if str(s.get("rt", "")) != "":
		res = await _http(HTTPClient.METHOD_POST, SUPA_URL + "/auth/v1/token?grant_type=refresh_token", hd, JSON.stringify({"refresh_token": s["rt"]}))
		if int(res[0]) != 200:
			s["rt"] = ""
	if str(s.get("rt", "")) == "":
		res = await _http(HTTPClient.METHOD_POST, SUPA_URL + "/auth/v1/signup", hd, "{}")
	if int(res[0]) == 200 and res[1] is Dictionary and res[1].has("access_token"):
		_access = str(res[1]["access_token"])
		_exp = Time.get_unix_time_from_system() + float(res[1].get("expires_in", 3600))
		s["rt"] = str(res[1].get("refresh_token", ""))
		s["uid"] = str(res[1].get("user", {}).get("id", s.get("uid", "")))
		Save.save()
		last_error = ""
		return true
	last_error = "서버에 연결하지 못했어요"
	return false


func _hd() -> PackedStringArray:
	return PackedStringArray(["apikey: " + SUPA_KEY, "Authorization: Bearer " + _access, "Content-Type: application/json",
		"Prefer: resolution=merge-duplicates,return=minimal"])


func _push_week(score: int) -> void:
	if not await _auth():
		return
	var row := {"week": week_key(), "uid": st()["uid"], "name": nick(), "tier": tier(), "score": score}
	await _http(HTTPClient.METHOD_POST, SUPA_URL + "/rest/v1/league_scores?on_conflict=week,uid", _hd(), JSON.stringify(row))


func _push_daily(score: int) -> void:
	if not await _auth():
		return
	var row := {"day": Save.kst_day(), "uid": st()["uid"], "name": nick(), "score": score}
	await _http(HTTPClient.METHOD_POST, SUPA_URL + "/rest/v1/daily_scores?on_conflict=day,uid", _hd(), JSON.stringify(row))


func _rows_to_board(rows, my: int, include_me: bool) -> Array:
	var out: Array = []
	var uid := str(st().get("uid", ""))
	var found := false
	if rows is Array:
		for r in rows:
			var me: bool = str(r.get("uid", "")) == uid
			found = found or me
			out.append({"name": str(r.get("name", "?")), "score": int(r.get("score", 0)), "me": me, "bot": false})
	if include_me and not found:
		out.append({"name": nick(), "score": my, "me": true, "bot": false})
	out.sort_custom(func(a, b): return int(a["score"]) > int(b["score"]))
	return out


func _fetch_week() -> void:
	loading = true
	if await _auth():
		var q := "/rest/v1/league_scores?week=eq.%s&tier=eq.%d&select=uid,name,score&order=score.desc&limit=100" % [week_key(), tier()]
		var res: Array = await _http(HTTPClient.METHOD_GET, SUPA_URL + q, _hd())
		if int(res[0]) == 200:
			board = _rows_to_board(res[1], my_best(), true)
			_cache_rank()
		else:
			last_error = "랭킹을 불러오지 못했어요"
	loading = false


func _fetch_daily() -> void:
	loading = true
	if await _auth():
		var q := "/rest/v1/daily_scores?day=eq.%s&select=uid,name,score&order=score.desc&limit=50" % Save.kst_day()
		var res: Array = await _http(HTTPClient.METHOD_GET, SUPA_URL + q, _hd())
		if int(res[0]) == 200:
			daily_board = _rows_to_board(res[1], today_score(), played_today())
		else:
			last_error = "랭킹을 불러오지 못했어요"
	loading = false
