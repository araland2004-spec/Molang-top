extends Node
## 저장(웹 버전 localStorage 대신). 집 화면과 숫자 게임이 같이 씀. 웹 빌드에선 브라우저 저장소에 남아요.

const PATH := "user://molang_save.json"
const DAILY_MAX := 3
const ENDLESS_PAID := 5

var d := {
	"best": 0, "prog": 0, "seen_hint": false, "guides": [], "jelly": 100, "muted": false,
	"daily": {"day": "", "used": {}}, "bag": {}, "erew": {"day": "", "n": 0}, "stars": {},
}
var next_mode := ""      # 집 → 게임으로 넘어갈 때: "endless" | "menu" | "stage:N"
var data := {}           # mollang_data.json


func _ready() -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string("res://data/mollang_data.json"))
	if parsed is Dictionary:
		data = parsed
	if FileAccess.file_exists(PATH):
		var s = JSON.parse_string(FileAccess.get_file_as_string(PATH))
		if s is Dictionary:
			for k in s:
				d[k] = s[k]


func save() -> void:
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


static func kst_day() -> String:
	var t := int(Time.get_unix_time_from_system()) + 9 * 3600
	return Time.get_date_string_from_unix_time(t)


func daily_left(k: String) -> int:
	var dd: Dictionary = d["daily"]
	if dd.get("day", "") != kst_day():
		return DAILY_MAX
	return maxi(0, DAILY_MAX - int(dd["used"].get(k, 0)))


func bag_count(k: String) -> int:
	return int(d["bag"].get(k, 0))


## 무한 모드 아이템: 하루 3번 먼저, 그다음 가방
func spend_item(k: String, endless: bool) -> void:
	if not endless:
		return
	var dd: Dictionary = d["daily"]
	if dd.get("day", "") != kst_day():
		dd = {"day": kst_day(), "used": {}}
		d["daily"] = dd
	var used := int(dd["used"].get(k, 0))
	if used < DAILY_MAX:
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
			if h.get("inv") is Dictionary:
				d["bag"] = h["inv"]
			d["home_web"] = h
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
