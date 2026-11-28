extends Node
## 저장(웹 버전 localStorage 대신). 홈 화면(바닥·몰랑이)과 숫자 게임이 같이 씀. 웹 빌드에선 브라우저 저장소에 남아요.

const PATH := "user://molang_save.json"
const DAILY_MAX := 3
const ENDLESS_PAID := 5
const STAGE_DAILY := 5     # 스테이지는 하루 5번 입장 (무한 모드에서 쓸 아이템을 모으는 곳)

var d := {
	"best": 0, "prog": 0, "seen_hint": false, "guides": [], "jelly": 100, "muted": false,
	"daily": {"day": "", "used": {}}, "bag": {}, "erew": {"day": "", "n": 0}, "stars": {},
	"play_sec": 0.0,
	"home": {"events": [], "name": "몰랑이네"},
	"dex": {},          # 몰랑이 도감: 숫자 단계(문자열) → {"n": 만든 수, "s": 반짝이 수}
}
signal jelly_changed

var next_mode := ""
var next_items: Array = []   # 스테이지 입장 팝업에서 고른 가방 아이템 (게임 시작 때 꺼내 씀)
var home_popup := ""         # 게임 → 집으로 돌아오며 열 창 ("stage" = 스테이지 입장 팝업)
var home_view := {}      # 홈 → 게임으로 갈 때 카메라 방향·확대 (돌아오면 그대로)
var jelly_seen := -1     # 홈 화면이 마지막으로 보여 준 젤리 수 (돌아왔을 때 「+N」 연출용)
var save_t := 0.0
var data := {}           # mollang_data.json


var DEFAULTS := {}


var monet: Node      # 광고·결제
var league: Node     # 오늘의 판 · 주간 리그 랭킹


func _ready() -> void:
	DEFAULTS = d.duplicate(true)
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/mollang_data.json"))
	if parsed is Dictionary:
		data = parsed
	if FileAccess.file_exists(PATH):
		var s = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if s is Dictionary:
			for k in s:
				d[k] = s[k]
	_migrate_stages()
	# 광고·결제 (scripts/monet.gd): Save.monet 으로 써요
	monet = preload("res://scripts/monet.gd").new()
	add_child(monet)
	monet.restore.call_deferred()
	league = preload("res://scripts/league.gd").new()
	add_child(league)


## 겹치던 단계를 빼서 번호가 당겨졌을 때(stageRev): 깬 단계 수·별 기록을 새 번호로 옮김
func _migrate_stages() -> void:
	var rev: Dictionary = data.get("stageRev", {})
	if rev.is_empty() or int(d.get("stage_rev", 1)) >= int(rev.get("rev", 1)):
		return
	var removed: Array = rev.get("removed", [])
	var prog := int(d.get("prog", 0))
	var cut := 0
	for r in removed:
		if int(r) <= prog:
			cut += 1
	d["prog"] = maxi(0, prog - cut)
	var old: Dictionary = d.get("stars", {})
	var nw := {}
	for k in old:
		var n := int(k) + 1
		if removed.has(n):
			continue
		var m := n
		for r in removed:
			if int(r) < n:
				m -= 1
		nw[str(m - 1)] = old[k]
	d["stars"] = nw
	d["run"] = {}
	d["stage_rev"] = int(rev.get("rev", 1))


func _process(delta: float) -> void:
	var dt := minf(delta, 5.0)
	d["play_sec"] = float(d.get("play_sec", 0.0)) + dt
	save_t += delta
	if save_t > 30.0:      # 웹에선 저장할 때마다 브라우저 저장소를 맞춰서, 너무 자주 하면 잠깐씩 끊겨요
		save_t = 0
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		save()


## 처음부터 새로: 기록·젤리·도감을 모두 지우고 맨 처음 상태로 (안내도 처음부터)
func reset_all() -> void:
	var iap = d.get("iap")      # 산 것(광고 제거·시즌 팩)은 처음부터 새로 해도 남겨요
	d = DEFAULTS.duplicate(true)
	if iap is Dictionary:
		d["iap"] = iap
	d["stage_rev"] = int(data.get("stageRev", {}).get("rev", 1))
	jelly_seen = -1
	next_mode = ""
	home_view = {}
	save()


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


## 진동 (웹 버전 navigator.vibrate 와 같은 길이, ms). 설정에서 끌 수 있어요.
func buzz(ms: int) -> void:
	if bool(d.get("vibe", true)):
		Input.vibrate_handheld(ms)


static func kst_day() -> String:
	var t := int(Time.get_unix_time_from_system()) + 9 * 3600
	return Time.get_date_string_from_unix_time(t)


func daily_left(k: String) -> int:
	var dd: Dictionary = d["daily"]
	if dd.get("day", "") != kst_day():
		return DAILY_MAX
	return maxi(0, DAILY_MAX - int(dd["used"].get(k, 0)))


## 오늘 남은 스테이지 입장 횟수 (한국 날짜로 매일 다시 5번)
func stage_left() -> int:
	var sd: Dictionary = d.get("sday", {})
	if sd.get("day", "") != kst_day():
		return STAGE_DAILY
	return maxi(0, STAGE_DAILY - int(sd.get("n", 0)))


func use_stage_entry() -> bool:
	if stage_left() <= 0:
		return false
	var sd: Dictionary = d.get("sday", {})
	if sd.get("day", "") != kst_day():
		sd = {"day": kst_day(), "n": 0}
	sd["n"] = int(sd.get("n", 0)) + 1
	d["sday"] = sd
	save()
	return true


# ───────────────────────── 보석 · 퀘스트 ─────────────────────────
## 보석: 퀘스트를 깨면 받는 재화. 지금은 스테이지 입장 +1(보석 10개)에 써요.
## 퀘스트는 한 줄로 이어져요(앞의 걸 받아야 다음이 열림). 진행은 깬 단계 수(prog) 또는 횟수 기록(cnt)으로 셈.
const STAGE_ENTRY_GEM := 10
const QUESTS := [
	{"id": "stage5", "t": "스테이지 5단계까지 깨기", "kind": "prog", "need": 5, "gem": 30},
	{"id": "endless1", "t": "무한 모드 1판 하기", "kind": "endless", "need": 1, "gem": 20},
	{"id": "daily1", "t": "오늘의 판 1번 하기", "kind": "daily", "need": 1, "gem": 20},
	{"id": "dex6", "t": "몰랑이 도감 6칸 채우기 (128 만들기)", "kind": "dex", "need": 6, "gem": 30},
	{"id": "stage20", "t": "스테이지 20단계까지 깨기", "kind": "prog", "need": 20, "gem": 50},
	{"id": "daily3", "t": "오늘의 판 3번 하기", "kind": "daily", "need": 3, "gem": 40},
	{"id": "dex10", "t": "몰랑이 도감 10칸 채우기 (2048 만들기)", "kind": "dex", "need": 10, "gem": 60},
	{"id": "stage30", "t": "스테이지 30단계까지 깨기", "kind": "prog", "need": 30, "gem": 50},
	{"id": "dex13", "t": "몰랑이 도감 13칸 채우기 (8192 만들기)", "kind": "dex", "need": 13, "gem": 100},
]


func gem() -> int:
	return int(d.get("gem", 0))


func add_gem(n: int) -> void:
	d["gem"] = gem() + n
	save()


## 횟수 기록: endless(무한 모드 끝낸 판) · daily(오늘의 판 한 수)
func bump(kind: String, n := 1) -> void:
	if not (d.get("cnt") is Dictionary):
		d["cnt"] = {}
	d["cnt"][kind] = int(d["cnt"].get(kind, 0)) + n


func quest_idx() -> int:
	return int(d.get("quest", 0))


func quest_cur() -> Dictionary:
	var i := quest_idx()
	return QUESTS[i] if i < QUESTS.size() else {}


func quest_val(q: Dictionary) -> int:
	if q.is_empty():
		return 0
	if q["kind"] == "prog":
		return int(d["prog"])
	if q["kind"] == "dex":
		return dex_count()
	var c: Dictionary = d.get("cnt", {}) if d.get("cnt") is Dictionary else {}
	return int(c.get(q["kind"], 0))


func quest_ready() -> bool:
	var q := quest_cur()
	return not q.is_empty() and quest_val(q) >= int(q["need"])


## 보상 받기: 보석 더하고 다음 퀘스트로. 받은 퀘스트를 돌려줘요 (없으면 빈 것)
func quest_claim() -> Dictionary:
	if not quest_ready():
		return {}
	var q := quest_cur()
	add_gem(int(q.get("gem", 0)))
	d["quest"] = quest_idx() + 1
	save()
	return q


## 보석으로 오늘 스테이지 입장 1번 더
func buy_stage_entry() -> bool:
	if gem() < STAGE_ENTRY_GEM:
		return false
	d["gem"] = gem() - STAGE_ENTRY_GEM
	_add_stage_entry()
	return true


func _add_stage_entry() -> void:
	var sd: Dictionary = d.get("sday", {})
	if sd.get("day", "") != kst_day():
		sd = {"day": kst_day(), "n": 0}
	sd["n"] = int(sd.get("n", 0)) - 1
	d["sday"] = sd
	save()


## 광고(보상형)로 오늘 스테이지 입장 1번 더: 하루 monet.AD_STAGE_MAX 번까지
func ad_stage_left() -> int:
	var a: Dictionary = d.get("ad_stage", {})
	var used := int(a.get("n", 0)) if a.get("day", "") == kst_day() else 0
	return maxi(0, int(monet.AD_STAGE_MAX) - used)


func ad_stage_entry() -> bool:
	if ad_stage_left() <= 0:
		return false
	var a: Dictionary = d.get("ad_stage", {})
	if a.get("day", "") != kst_day():
		a = {"day": kst_day(), "n": 0}
	a["n"] = int(a.get("n", 0)) + 1
	d["ad_stage"] = a
	_add_stage_entry()
	return true


func bag_count(k: String) -> int:
	return int(d["bag"].get(k, 0))


## 무한 모드에서 하루 3번 쓰는 아이템이 열렸는지 (단계를 깨면 열림). 안 열렸어도 가방에 있으면 쓸 수 있어요.
func endless_open(k: String) -> bool:
	var e: Dictionary = data.get("itemUnlock", {}).get("endless", {})
	return int(d["prog"]) >= int(e.get(k, 9999))


## 무한 모드 아이템: 하루 3번 먼저(열린 것만), 그다음 가방
func spend_item(k: String, endless: bool) -> void:
	if not endless:
		return
	var dd: Dictionary = d["daily"]
	if dd.get("day", "") != kst_day():
		dd = {"day": kst_day(), "used": {}}
		d["daily"] = dd
	var used := int(dd["used"].get(k, 0))
	if endless_open(k) and used < DAILY_MAX:
		dd["used"][k] = used + 1
	elif bag_count(k) > 0:
		d["bag"][k] = bag_count(k) - 1
	save()


func stage_jelly(i: int, first: bool) -> int:
	if not first:
		return 10
	var n := i + 1
	if n <= 20:
		return 60 if n % 5 == 0 else 40
	return 150 if n % 5 == 0 else 60


func endless_paid_left() -> int:
	var e: Dictionary = d["erew"]
	return maxi(0, ENDLESS_PAID - int(e.get("n", 0))) if e.get("day", "") == kst_day() else ENDLESS_PAID


func endless_jelly(sc: int) -> int:
	var k := sc / 10000
	var m := sc / 100000
	return 5 * k * (k + 1) / 2 + 5 * k + 150 * m * (m + 1) / 2


func add_jelly(n: int) -> void:
	d["jelly"] = int(d["jelly"]) + n
	save()
	jelly_changed.emit()


## 원래 몰랑탑(웹)의 「저장 백업」 코드에서 진행도·젤리·가방·가이드를 가져옴. 집 꾸미기 기록은 나중에 옮길 때 쓰려고 통째로 보관.
func import_web(json_str: String) -> bool:
	var o = JSON.parse_string(json_str)
	if not (o is Dictionary):
		return false
	var ok := false
	if o.has("mollang.v6"):
		var g = JSON.parse_string(str(o["mollang.v6"]))
		if g is Dictionary:
			d["prog"] = maxi(int(d["prog"]), int(g.get("prog", 0)))
			d["best"] = maxi(int(d["best"]), int(g.get("best", 0)))
			d["seen_hint"] = bool(g.get("seenHint", d["seen_hint"]))
			ok = true
	if o.has("mollang.home"):
		var h = JSON.parse_string(str(o["mollang.home"]))
		if h is Dictionary:
			d["jelly"] = int(h.get("jelly", d["jelly"]))
			d["play_sec"] = maxf(float(d.get("play_sec", 0.0)), float(h.get("playSec", 0.0)))
			if h.get("inv") is Dictionary:
				d["bag"] = h["inv"]
			d["home_web"] = h
			var hm: Dictionary = d["home"]
			for k in ["events", "name"]:
				if h.has(k) and h[k] != null:
					hm[k] = h[k]
			ok = true
	if o.has("mollang.guides"):
		var gs = JSON.parse_string(str(o["mollang.guides"]))
		if gs is Array:
			for k in gs:
				if not d["guides"].has(k):
					d["guides"].append(k)
	if o.has("mollang.daily"):
		var dd = JSON.parse_string(str(o["mollang.daily"]))
		if dd is Dictionary:
			d["daily"] = dd
	if ok:
		save()
	return ok


func home() -> Dictionary:
	if not (d.get("home") is Dictionary):
		d["home"] = {}
	var h: Dictionary = d["home"]
	if not (h.get("events") is Array):
		h["events"] = []
	if not h.has("name"):
		h["name"] = "몰랑이네"
	return h


# ───────────────────────── 몰랑이 도감 ─────────────────────────
## 게임에서 숫자를 처음 만들면 도감에 등록되고 홈 바닥에 그 몰랑이가 나와 돌아다녀요.
## 반짝이: 합칠 때 아주 낮은 확률로 반짝이는 몰랑이가 나와요 (도감에 따로 기록).
const DEX_FROM := 1          # 2 부터
const DEX_TO := 14           # 16384 까지
const SHINY_P := 0.004       # 합칠 때 반짝이가 나올 확률 (250번에 한 번쯤)


func dex() -> Dictionary:
	if not (d.get("dex") is Dictionary):
		d["dex"] = {}
	return d["dex"]


func dex_has(t: int) -> bool:
	return int(dex().get(str(t), {}).get("n", 0)) > 0


func dex_count() -> int:
	var c := 0
	for t in range(DEX_FROM, DEX_TO + 1):
		if dex_has(t):
			c += 1
	return c


## 처음 만든 숫자의 보상 젤리 (큰 숫자일수록 많이)
static func dex_reward(t: int) -> int:
	return 0 if t < 4 else (10 * (t - 3) * (t - 3))


## 만든 숫자 기록. 처음이면 보상 젤리를 돌려줘요 (아니면 0)
func dex_add(t: int, shiny := false) -> int:
	if t < DEX_FROM or t > DEX_TO:
		return 0
	var k := str(t)
	var e: Dictionary = dex().get(k, {"n": 0, "s": 0})
	var first := int(e.get("n", 0)) == 0
	e["n"] = int(e.get("n", 0)) + 1
	if shiny:
		e["s"] = int(e.get("s", 0)) + 1
	dex()[k] = e
	var r := dex_reward(t) if first else 0
	if r > 0:
		d["jelly"] = int(d["jelly"]) + r
		jelly_changed.emit()
	return r
