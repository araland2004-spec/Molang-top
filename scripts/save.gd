extends Node
## 저장(웹 버전 localStorage 대신). 집 화면과 숫자 게임이 같이 씀. 웹 빌드에선 브라우저 저장소에 남아요.

const PATH := "user://molang_save.json"
const DAILY_MAX := 3
const ENDLESS_PAID := 5
const STAGE_DAILY := 5     # 스테이지는 하루 5번 입장 (무한 모드에서 쓸 아이템을 모으는 곳)

var d := {
	"best": 0, "prog": 0, "seen_hint": false, "guides": [], "jelly": 100, "muted": false,
	"daily": {"day": "", "used": {}}, "bag": {}, "erew": {"day": "", "n": 0}, "stars": {},
	"play_sec": 0.0, "work_total": 0,
	"home": {"own": {}, "put": {}, "lvl": 1, "orn": 0, "fairies": [], "pets": [], "events": [], "name": "몰랑이네", "floors_in": {}, "seen_box": 0},
}
signal jelly_changed

var next_mode := ""
var home_view := {}      # 집 → 게임으로 갈 때 몰랑이 자리·카메라 (돌아오면 그대로, 앱을 껐다 켜면 처음 자리)
var jelly_seen := -1     # 집 화면이 마지막으로 보여 준 젤리 수 (돌아왔을 때 「+N」 연출용)
var work_carry := 0.0
var save_t := 0.0      # 집 → 게임으로 넘어갈 때: "endless" | "menu" | "stage:N"
var data := {}           # mollang_data.json


var DEFAULTS := {}


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


## 공방(웹 버전과 같게): 화면이 켜져 있는 동안 1분에 0.5 + 0.1 × 깬 단계 젤리. 플레이 시간도 여기서 셈.
func work_rate() -> float:
	# 기본(단계) × 편안함(꾸미기, 최대 ×2) × 완성한 트리마다 +10%
	var ws := 1.5 if home().get("workshop_at") is Array else 1.0      # 공방을 지으면 ×1.5
	return (0.5 + 0.1 * int(d["prog"])) * (1.0 + comfort() / 100.0) * (1.0 + 0.1 * int(home().get("trees", 0))) * ws


## 집 편안함 0~100: 놓아 둔 가구 ×3 · 넓힌 땅 칸 ×1 · 함께 사는 펫 ×10 · 완성한 트리 ×10
func comfort() -> int:
	var h := home()
	var c := 0
	for id in h["put"]:
		if h["put"][id] and int(h["own"].get(id, 0)) > 0:
			c += 3
	if h.get("land_own") is Array:
		c += maxi(0, (h["land_own"] as Array).size() - 30)
	c += 10 * (h["pets"] as Array).size()
	c += 10 * int(h.get("trees", 0))
	return mini(100, c)


func _process(delta: float) -> void:
	var dt := minf(delta, 5.0)
	d["play_sec"] = float(d.get("play_sec", 0.0)) + dt
	work_carry += work_rate() * dt / 60.0
	if work_carry >= 1.0:
		var n := int(work_carry)
		work_carry -= n
		d["jelly"] = int(d["jelly"]) + n
		d["work_total"] = int(d.get("work_total", 0)) + n
		jelly_changed.emit()
	save_t += delta
	if save_t > 30.0:      # 웹에선 저장할 때마다 브라우저 저장소를 맞춰서, 너무 자주 하면 잠깐씩 끊겨요
		save_t = 0
		save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		save()


## 처음부터 새로: 기록·젤리·집을 모두 지우고 맨 처음 상태로 (안내도 처음부터)
func reset_all() -> void:
	d = DEFAULTS.duplicate(true)
	d["stage_rev"] = int(data.get("stageRev", {}).get("rev", 1))
	jelly_seen = -1
	next_mode = ""
	home_view = {}
	save()
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://home3.json"))


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
	{"id": "box1", "t": "선물 상자 1번 열기", "kind": "box", "need": 1, "gem": 20},
	{"id": "endless1", "t": "무한 모드 1판 하기", "kind": "endless", "need": 1, "gem": 20},
	{"id": "stage20", "t": "스테이지 20단계까지 깨기", "kind": "prog", "need": 20, "gem": 50},
	{"id": "deco1", "t": "방이나 섬 꾸미기 (장식 1개 놓기)", "kind": "place", "need": 1, "gem": 30},
	{"id": "stage30", "t": "스테이지 30단계까지 깨기", "kind": "prog", "need": 30, "gem": 50, "block": 1},
	{"id": "floor1", "t": "땅 편집으로 바닥 블록 바꾸기", "kind": "floor", "need": 1, "gem": 30},
]


func gem() -> int:
	return int(d.get("gem", 0))


func add_gem(n: int) -> void:
	d["gem"] = gem() + n
	save()


## 횟수 기록: box(상자 연 수) · endless(무한 모드 끝낸 판) · place(장식 놓기) · floor(바닥 바꾸기)
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
	var sd: Dictionary = d.get("sday", {})
	if sd.get("day", "") != kst_day():
		sd = {"day": kst_day(), "n": 0}
	sd["n"] = int(sd.get("n", 0)) - 1
	d["sday"] = sd
	save()
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
			for k in ["own", "put", "lvl", "orn", "fairies", "pets", "events", "name"]:
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
	var h: Dictionary = d["home"]
	for k in ["own", "put", "floors_in"]:
		if not (h.get(k) is Dictionary):
			h[k] = {}
	for k in ["fairies", "pets", "events"]:
		if not (h.get(k) is Array):
			h[k] = []
	if not h.has("lvl"): h["lvl"] = 1
	if not h.has("orn"): h["orn"] = 0
	if not h.has("trees"): h["trees"] = 0                # 완성한 트리 수
	if not h.has("orn_total"): h["orn_total"] = int(h["orn"]) + 10 * int(h["trees"])   # 지금까지 단 오너먼트 (트리가 바뀌어도 이어짐)
	if not h.has("keys"): h["keys"] = 0                  # 선물 상자 열쇠 (오너먼트 보상)
	if not (h.get("props") is Dictionary): h["props"] = {}      # 심어 둔 자연 장식 "x,z" → 모델 이름
	if not (h.get("colors") is Dictionary): h["colors"] = {}    # 자연 장식마다 열린 색 수
	if not (h.get("orn_day") is Dictionary): h["orn_day"] = {"day": "", "n": 0}
	if not (h.get("gift") is Dictionary): h["gift"] = {"day": "", "n": 0, "t": 0.0}
	if not h.has("name"): h["name"] = "몰랑이네"
	if not h.has("no"): h["no"] = 1
	if not (h.get("past") is Dictionary): h["past"] = {}
	# 예전엔 도감을 다 채워 새 집으로 넘어가면 장식을 비웠어요 → 그때 모은·놓은 장식을 되돌려 줘요 (한 번만)
	if not h.get("past_merged", false):
		h["past_merged"] = true
		for k in h["past"]:
			var pv = h["past"][k]
			if not (pv is Dictionary):
				continue
			if pv.get("own") is Dictionary:
				for id in pv["own"]:
					h["own"][id] = int(h["own"].get(id, 0)) + int(pv["own"][id])
			if pv.get("put") is Dictionary:
				for id in pv["put"]:
					if not h["put"].has(id):
						h["put"][id] = pv["put"][id]
	return h


## 오너먼트: 플레이 30분마다 1개 (웹과 같게). 받을 수 있는 수 = 누적 − 지금까지 단 수.
## 켜 두기만으로 끝없이 벌지 않게 하루 6개(3시간)까지만 달 수 있어요.
const ORN_DAY_MAX := 6


func orn_ready() -> int:
	var h := home()
	var od: Dictionary = h["orn_day"]
	var used_today := int(od.get("n", 0)) if od.get("day", "") == kst_day() else 0
	var by_time := maxi(0, int(float(d.get("play_sec", 0.0)) / 1800.0) - int(h["orn_total"]))
	return mini(by_time, maxi(0, ORN_DAY_MAX - used_today))


func orn_hung() -> void:
	var h := home()
	h["orn_total"] = int(h["orn_total"]) + 1
	var od: Dictionary = h["orn_day"]
	if od.get("day", "") != kst_day():
		od["day"] = kst_day(); od["n"] = 0
	od["n"] = int(od["n"]) + 1
