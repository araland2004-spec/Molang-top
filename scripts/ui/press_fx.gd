# 몰랑탑 눌림·반응 효과 (Godot 4)
# 사용: PressFx.attach($Button)  /  PressFx.attach($PlayButton, PressFx.PRIMARY)
# 값은 인터랙션 제안서의 표와 같아요.
class_name PressFx
extends RefCounted

const FAST := 0.07      # 누르는 순간
const BASE := 0.16      # 일반 복귀
const SPRING := 0.24    # 튕기며 복귀
const SLOW := 0.40      # 화면 전환·페이드

const SOFT := {"down": 0.96, "over": 1.03, "dim": 0.92}
const PRIMARY := {"down": 0.97, "over": 1.02, "dim": 0.90}
const ICON := {"down": 0.92, "over": 1.06, "dim": 0.90}

static func attach(btn: BaseButton, kind: Dictionary = SOFT, haptic := true) -> void:
	_center(btn)
	btn.resized.connect(_center.bind(btn))
	btn.button_down.connect(_on_down.bind(btn, kind, haptic))
	btn.button_up.connect(_on_up.bind(btn, kind))

static func _on_down(btn: BaseButton, kind: Dictionary, haptic: bool) -> void:
	_kill(btn)
	var tw := btn.create_tween().set_parallel(true)
	tw.tween_property(btn, "scale", Vector2.ONE * kind.down, FAST).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "modulate", Color(kind.dim, kind.dim, kind.dim), FAST)
	btn.set_meta("_fx", tw)
	if haptic:
		_buzz(8)

static func _on_up(btn: BaseButton, kind: Dictionary) -> void:
	_kill(btn)
	var tw := btn.create_tween()
	tw.tween_property(btn, "modulate", Color.WHITE, FAST)
	tw.tween_property(btn, "scale", Vector2.ONE * kind.over, 0.09).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(btn, "scale", Vector2.ONE, BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	btn.set_meta("_fx", tw)

## 잠긴 버튼을 눌렀을 때: 좌우로 3번 흔들기
static func shake(n: Control, px := 5.0) -> void:
	var x := n.position.x
	var tw := n.create_tween()
	for d in [px, -px, px * .6, -px * .6, 0.0]:
		tw.tween_property(n, "position:x", x + d, 0.05)
	_buzz(20)

## 배지·숫자가 톡 튀기
static func pop(n: Control, peak := 1.35) -> void:
	_center(n)
	n.scale = Vector2.ONE * peak
	n.create_tween().tween_property(n, "scale", Vector2.ONE, SPRING).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

## 새로 생기는 것: 0 → 1.18 → 1
static func appear(n: Control) -> void:
	_center(n)
	n.scale = Vector2.ZERO
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector2.ONE * 1.18, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(n, "scale", Vector2.ONE, 0.12)

## 숫자 올라가기 (젤리 개수, 점수)
static func count_up(label: Label, from: int, to: int, dur := 0.6) -> void:
	label.create_tween().tween_method(func(v: float): label.text = _comma(int(v)), float(from), float(to), dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

## 아이템을 다 썼을 때 흐리게
static func dim_out(n: CanvasItem) -> void:
	n.create_tween().tween_property(n, "modulate:a", 0.38, 0.25)

## 켜져 있는 아이템(뿅망치 대기 등): 링이 숨 쉬듯
static func pulse(n: CanvasItem) -> Tween:
	var tw := n.create_tween().set_loops()
	tw.tween_property(n, "modulate:a", 0.35, 0.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(n, "modulate:a", 1.0, 0.5).set_trans(Tween.TRANS_SINE)
	return tw

static func _center(n: Control) -> void:
	n.pivot_offset = n.size / 2

static func _kill(n: Node) -> void:
	if n.has_meta("_fx"):
		var t: Tween = n.get_meta("_fx")
		if t and t.is_valid(): t.kill()

static func _comma(v: int) -> String:
	var s := str(v)
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return s + out


## 진동: 설정의 「진동 끄기」를 따름 (Save 자동 로드가 있으면)
static func _buzz(ms: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	var sv = tree.root.get_node_or_null("Save") if tree else null
	if sv and sv.has_method("buzz"):
		sv.buzz(ms)
	else:
		Input.vibrate_handheld(ms)
