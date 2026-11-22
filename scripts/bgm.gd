extends Node
## 배경 음악 (웹 버전 MOLBGM 12곡을 그대로 녹음해 둔 ogg). 플레이 25분마다 한 곡씩 열려요.
## 「차례대로」면 한 곡을 두 번 돈 뒤 다음 곡으로 넘어가요.

signal track_changed(i: int)
signal unlocked(name: String)

const NAMES := ["첫눈 오르골", "별빛 창가", "따뜻한 코코아", "반짝반짝 트리", "눈사람 왈츠", "종소리 골목",
	"벽난로 자장가", "선물 포장 중", "썰매 산책", "요정의 춤", "창밖 함박눈", "크리스마스 아침"]
const TRACK_MIN := 25

var player: AudioStreamPlayer
var cur := 0
var loops := 0
var last_open := 0


func _ready() -> void:
	player = AudioStreamPlayer.new()
	player.volume_db = 3.0
	add_child(player)
	player.finished.connect(_on_finished)
	cur = clampi(int(Save.d.get("bgm_track", 0)), 0, tracks_open() - 1)
	last_open = tracks_open()
	if is_on():
		_play(cur)


func is_on() -> bool:
	return bool(Save.d.get("bgm_on", true))


func seq() -> bool:
	return bool(Save.d.get("bgm_seq", true))


func tracks_open() -> int:
	return mini(NAMES.size(), 1 + int(float(Save.d.get("play_sec", 0.0)) / (TRACK_MIN * 60.0)))


func _play(i: int) -> void:
	cur = i
	loops = 0
	var st: AudioStream = load("res://assets/bgm/t%d.ogg" % i)
	player.stream = st
	player.play()
	track_changed.emit(i)


func _on_finished() -> void:
	loops += 1
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
		_play(cur)
	else:
		player.stop()


func toggle() -> void:
	set_on(not is_on())


func set_track(i: int) -> void:
	if i < 0 or i >= tracks_open():
		return
	Save.d["bgm_track"] = i
	Save.d["bgm_on"] = true
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
