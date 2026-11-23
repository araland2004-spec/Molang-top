extends Node
## 배경 음악.
## 앞 4곡(c0~c3)은 동숲처럼 잔잔한 곡 (1분 반 길이 반복, 처음부터 열림). 기본은 「시간대에 맞춰」: 아침·낮·저녁·밤마다 바뀌어요.
## 그 뒤 12곡은 웹 버전 MOLBGM 을 녹음해 둔 짧은 곡(t0~t11)으로, 플레이 25분마다 한 곡씩 열려요.
## 「차례대로」면 한 곡을 두 번 돈 뒤 다음 곡으로 넘어가요.

signal track_changed(i: int)
signal unlocked(name: String)

const CALM := ["아침 산책", "오후의 낮잠", "바닷가 오솔길", "별 보는 밤"]
const NAMES := ["아침 산책", "오후의 낮잠", "바닷가 오솔길", "별 보는 밤",
	"첫눈 오르골", "별빛 창가", "따뜻한 코코아", "반짝반짝 트리", "눈사람 왈츠", "종소리 골목",
	"벽난로 자장가", "선물 포장 중", "썰매 산책", "요정의 춤", "창밖 함박눈", "크리스마스 아침"]
const TRACK_MIN := 25
const CALM_DB := -9.0      # 잔잔한 곡: 말소리·효과음을 가리지 않게 작게
const OLD_DB := 3.0

var player: AudioStreamPlayer
var cur := 0
var loops := 0
var last_open := 0


func _ready() -> void:
	player = AudioStreamPlayer.new()
	add_child(player)
	player.finished.connect(_on_finished)
	if not Save.d.has("bgm_v2"):
		# 잔잔한 곡 4개가 앞에 생겨서 예전 번호를 뒤로 밀고, 모두 「시간대에 맞춰」로 시작
		Save.d["bgm_track"] = int(Save.d.get("bgm_track", 0)) + CALM.size()
		Save.d["bgm_auto"] = true
		Save.d["bgm_v2"] = true
	cur = clampi(int(Save.d.get("bgm_track", 0)), 0, tracks_open() - 1)
	last_open = tracks_open()
	if is_on():
		_play(time_track() if auto() else cur)


func is_on() -> bool:
	return bool(Save.d.get("bgm_on", true))


func seq() -> bool:
	return bool(Save.d.get("bgm_seq", true))


## 시간대에 맞춰 듣기 (기본 켜짐)
func auto() -> bool:
	return bool(Save.d.get("bgm_auto", true))


## 지금 시각(한국)에 맞는 잔잔한 곡: 6~11시 아침 · 11~17시 낮 · 17~21시 저녁 · 그 밖은 밤
func time_track() -> int:
	var h := int(Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 9 * 3600)["hour"])
	if h >= 6 and h < 11:
		return 0
	if h >= 11 and h < 17:
		return 1
	if h >= 17 and h < 21:
		return 2
	return 3


func tracks_open() -> int:
	return mini(NAMES.size(), CALM.size() + int(float(Save.d.get("play_sec", 0.0)) / (TRACK_MIN * 60.0)))


func _path(i: int) -> String:
	return "res://assets/bgm/c%d.ogg" % i if i < CALM.size() else "res://assets/bgm/t%d.ogg" % (i - CALM.size())


func _play(i: int) -> void:
	cur = i
	loops = 0
	var st: AudioStream = load(_path(i))
	player.stream = st
	player.volume_db = CALM_DB if i < CALM.size() else OLD_DB
	player.play()
	track_changed.emit(i)


func _on_finished() -> void:
	loops += 1
	if auto():
		var t := time_track()
		if t != cur:
			_play(t)
		else:
			player.play()
		return
	var open := tracks_open()
	if seq() and open > 1 and loops >= 2:
		_play((cur + 1) % open)
		Save.d["bgm_track"] = cur
	else:
		player.play()


func set_on(v: bool) -> void:
	Save.d["bgm_on"] = v
	Save.save()
	if v:
		_play(time_track() if auto() else cur)
	else:
		player.stop()


func toggle() -> void:
	set_on(not is_on())


func set_auto(v: bool) -> void:
	Save.d["bgm_auto"] = v
	Save.d["bgm_on"] = true
	Save.save()
	_play(time_track() if v else cur)


func set_track(i: int) -> void:
	if i < 0 or i >= tracks_open():
		return
	Save.d["bgm_track"] = i
	Save.d["bgm_on"] = true
	Save.d["bgm_auto"] = false
	Save.save()
	_play(i)


func set_seq(v: bool) -> void:
	Save.d["bgm_seq"] = v
	Save.save()


func _process(_dt: float) -> void:
	var o := tracks_open()
	if o > last_open:
		last_open = o
		unlocked.emit(NAMES[o - 1])
