extends Control
## 몰랑탑 숫자 게임 화면 — 웹 버전 게임 화면(점수·버튼·판·아이템·결과 카드·단계 목록·가이드)을 옮긴 것.

const GameCore := preload("res://scripts/game_core.gd")
const Synth := preload("res://scripts/synth.gd")

# v4 밤 민트 테마 (docs/ui/tokens.json). 예전 회색 화면의 이름은 그대로 두고 값만 바꿈.
const PAGE := Color(0.063, 0.157, 0.173, 0.97)     # 카드 바탕 (sb_card_result)
const BTN := Color(0.494, 0.941, 0.784, 0.08)      # 보조 버튼 (sb_button_secondary)
const BTN2 := Color(0.494, 0.941, 0.784, 0.14)
const MILK := Color(0.914, 0.949, 0.933)           # 글자 · 「주 버튼」 표시용
const SOFT := Color(0.624, 0.737, 0.714)
const INK := Color(0.102, 0.063, 0.024)            # 호박색 주 버튼 위 글자
const CELL_DONE := Color(0.494, 0.941, 0.784, 0.12)
const CELL_JUMP := Color(0.725, 0.635, 1.0, 0.14)
# UI 시안 v4 (docs/ui/README.md). 시안 360 기준 → 이 화면 720 기준이라 MolStyle.S = 2배로 써요.
const UI := preload("res://scripts/ui/mol_ui.gd")
const Sty := preload("res://scripts/ui/mol_style.gd")
const Fx := preload("res://scripts/ui/press_fx.gd")
const ITEM_ICONS := {"shake": "ic_item_shake", "undo": "ic_item_undo", "hammer": "ic_item_hammer", "tilt": "ic_tilt_right", "x2": "ic_item_x2star"}  # 기울이기 아이템 전용 아이콘은 아직 없어서 임시로 기울임 화살표
const ITEM_NAMES := {"shake": "흔들기", "undo": "되돌리기", "hammer": "뿅망치", "tilt": "기울이기", "x2": "×2 별"}
const SECTIONS := {0: "기본", 5: "6단계부터 · 위로 던져서 합치기", 11: "12단계부터 · 섞어서 연습", 17: "18단계부터 · 흔들기", 22: "23단계부터 · 흔들기 게이지",
	25: "26단계부터 · 새 아이템 「되돌리기」", 29: "30단계부터 · 판 모양이 바뀌어요", 40: "41단계부터 · 새 아이템 「뿅망치」", 45: "46단계부터 · 장애물 + 뿅망치",
	55: "56단계부터 · 새 아이템 「기울이기」", 60: "61단계부터 · 장애물 + 기울이기", 70: "71단계부터 · 새 아이템 「×2 별」", 75: "76단계부터 · 모두 함께",
	85: "86단계부터 · 판 모양 섞기", 100: "101단계부터 · 2048 도전", 150: "151단계부터 · 마지막 구간"}

var core: GameCore
var synth: Node
var font_num: Font
var font_txt: Font
var font_bold: Font

var score_lbl: Label
var info_lbl: Label
var restart_btn: Button
var mute_btn: Button
var board_area: Control
var items_box: HBoxContainer
var item_btns := {}
var tilt_l: Button
var tilt_r: Button
var font_med: Font
var goal_box: Control
var goal_l: Label
var goal_r: Label
var goal_bg: Panel
var goal_fill: Panel
var goal_ticks: Array = []
var item_badges := {}
var item_rings := {}
var item_prev := {}
var hint_lbl: Label
var toast_lbl: Label
var toast_t := 0.0
var mission: PanelContainer
var mission_t := 0.0
var card: Control
var card_title: Label
var card_stars: Label
var card_stage: Label
var card_big: Label
var card_note: Label
var card_reward: Label
var card_main: Button
var card_menu: Button
var card_act := "retry"
var menu: Control
var menu_grid_box: VBoxContainer
var guide: Control
var guide_done: Callable
var armed_t := 0.0

var dragging := false
var drag_start := Vector2.ZERO
var acc := 0.0
var board_scale := 1.0


func _ready() -> void:
	font_num = load("res://assets/fonts/Poppins-Bold.ttf")
	font_txt = load("res://assets/fonts/NotoSansKR-Regular-subset.otf")
	font_med = load("res://assets/fonts/NotoSansKR-Medium-subset.otf")
	font_bold = load("res://assets/fonts/NotoSansKR-Bold-subset.otf")
	# Poppins 에는 한글이 없어서, 숫자와 한글이 섞인 글자(예: 「128 만들기」)는 Noto 로 대신 그려요.
	var fb: Array[Font] = [font_bold]
	(font_num as FontFile).fallbacks = fb
	# 바탕: 위쪽이 밝은 원형 그라데이션 (시안 v4 게임 화면)
	var grad := Gradient.new()
	grad.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	grad.colors = PackedColorArray([UI.NIGHT_GAME_BG_CENTER, UI.NIGHT_GAME_BG_MID, UI.NIGHT_GAME_BG_EDGE])
	var gt := GradientTexture2D.new()
	gt.gradient = grad
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.1)
	gt.fill_to = Vector2(1.05, 0.75)
	gt.width = 256
	gt.height = 256
	var bg := TextureRect.new()
	bg.texture = gt
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	synth = Synth.new()
	add_child(synth)
	synth.muted = bool(Save.d.get("muted", false))
	core = GameCore.new()
	core.num_font = font_num
	core.txt_font = font_txt
	core.synth = synth
	core.stages = Save.data.get("stages", [])
	var iu: Dictionary = Save.data.get("itemUnlock", {})
	if iu.has("stage"):
		core.item_at = iu["stage"]
		core.endless_at = iu["endless"]
	core.best = int(Save.d["best"])
	core.prog = int(Save.d["prog"])
	_build_ui()
	core.score_changed.connect(func(s):
		score_lbl.text = GameCore.score_text(s)
		info_lbl.text = _info_str()
		_refresh_goal())
	core.info_changed.connect(func():
		info_lbl.text = _info_str()
		_refresh_goal())
	core.toast.connect(_toast)
	core.items_changed.connect(_paint_items)
	core.finished.connect(_on_finished)
	core.buzz.connect(func(ms: int): Save.buzz(ms))
	resized.connect(_layout)
	_layout()
	var nm := Save.next_mode
	Save.next_mode = ""
	if OS.has_feature("web") and str(JavaScriptBridge.eval("location.hash")) == "#bench":
		_bench.call_deferred()
		return
	if nm.begins_with("stage:"):
		start_stage(int(nm.substr(6)))
	elif nm == "menu":
		core.new_game()
		show_menu()
	else:
		start_endless()


# ───────────────────────── UI 만들기 ─────────────────────────

func _style(bg: Color, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
	if bg.a < 0.99 or bg == PAGE:
		sb.border_color = Color(0.494, 0.941, 0.784, 0.14)
		sb.set_border_width_all(2)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	return sb


func _btn(text: String, bg := BTN, fg := MILK, size := 26) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_txt)
	b.add_theme_font_size_override("font_size", size)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color"]:
		b.add_theme_color_override(st, fg)
	# 주 버튼(예전 흰 버튼) = 호박색 꽉 찬 버튼, 나머지 = 민트 테두리 보조 버튼, 단계 칸은 칸 스타일
	var name := "sb_button_secondary"
	var kind: Dictionary = Fx.SOFT
	if bg == MILK:
		name = "sb_button_primary_solid"; kind = Fx.PRIMARY
		fg = INK
	elif bg == CELL_DONE:
		name = "sb_stage_cell_done"
	elif bg == CELL_JUMP or bg == BTN2:
		name = "sb_stage_cell"
	var sb := Sty.box(name)
	if bg == CELL_JUMP:
		sb.border_color = UI.VIOLET_BOSS
		sb.set_border_width_all(2)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, fg)
	b.add_theme_color_override("font_disabled_color", Color(fg.r, fg.g, fg.b, 0.35))
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	b.add_theme_stylebox_override("pressed", sb)
	var dis := sb.duplicate() as StyleBoxFlat
	dis.bg_color.a *= 0.4
	dis.border_color.a *= 0.5
	b.add_theme_stylebox_override("disabled", dis)
	Fx.attach(b, kind)
	return b


func _lbl(text: String, size: int, col := MILK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else font_txt)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


## 위쪽 아이콘 버튼(44 시안 → 88px). boxed 는 시안의 「목록」처럼 패널 바탕이 있는 버튼.
func _icon_btn(icon_name: String, boxed: bool) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	b.icon = Sty.icon(icon_name)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_CENTER
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.add_theme_constant_override("icon_max_width", 44)
	b.custom_minimum_size = Vector2(88, 88)
	var sb: StyleBox = Sty.box("sb_panel_night") if boxed else StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	Fx.attach(b, Fx.ICON)
	return b


func _paint_mute() -> void:
	var c := Color(1, 1, 1, 0.4 if synth.muted else 1.0)
	for st in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		mute_btn.add_theme_color_override(st, c)


## 정보줄 옆 작은 알약 버튼 (새 판 / 다시)
func _chip_btn(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_override("font", font_med)
	b.add_theme_font_size_override("font_size", 24)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, UI.NIGHT_TEXT_SUB)
	var sb := Sty.box("sb_chip")
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.custom_minimum_size = Vector2(0, 56)
	Fx.attach(b, Fx.SOFT)
	return b


## 아이템 버튼: 위 아이콘 + 아래 이름, 오른쪽 위 노란 개수 배지, 켜졌을 때 등불색 링(숨 쉬듯)
func _item_btn(k: String) -> Button:
	var b := Button.new()
	b.text = ITEM_NAMES[k]
	b.focus_mode = Control.FOCUS_NONE
	b.icon = Sty.icon(ITEM_ICONS[k])
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
	b.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	b.add_theme_constant_override("icon_max_width", 48)
	b.add_theme_constant_override("h_separation", 0)
	b.add_theme_font_override("font", font_med)
	b.add_theme_font_size_override("font_size", 24)
	for st in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(st, UI.NIGHT_TEXT)
	b.add_theme_color_override("font_disabled_color", Color(UI.NIGHT_TEXT.r, UI.NIGHT_TEXT.g, UI.NIGHT_TEXT.b, 0.38))
	b.add_theme_color_override("icon_disabled_color", Color(1, 1, 1, 0.38))
	var sb := Sty.box("sb_panel_night")
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	var dis := Sty.box("sb_panel_night")
	dis.bg_color.a *= 0.5
	b.add_theme_stylebox_override("disabled", dis)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.custom_minimum_size = Vector2(96, 148)
	b.clip_text = true          # 아이템이 많아도(기울이기 화살표까지) 줄이 화면 밖으로 안 넘치게
	# 켜짐 링
	var ring := Panel.new()
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	var rsb := Sty.box("sb_panel_night")
	rsb.bg_color = Color(0, 0, 0, 0)
	rsb.border_color = UI.AMBER_PRIMARY
	rsb.set_border_width_all(3)
	rsb.shadow_color = Color(UI.AMBER_PRIMARY.r, UI.AMBER_PRIMARY.g, UI.AMBER_PRIMARY.b, 0.3)
	rsb.shadow_size = 10
	ring.add_theme_stylebox_override("panel", rsb)
	ring.visible = false
	b.add_child(ring)
	Fx.pulse(ring)
	item_rings[k] = ring
	# 개수 배지
	var badge := Label.new()
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.add_theme_font_override("font", font_num)
	badge.add_theme_font_size_override("font_size", 22)
	badge.add_theme_color_override("font_color", INK)
	badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = UI.GOLD_STAR
	bsb.set_corner_radius_all(999)
	badge.add_theme_stylebox_override("normal", bsb)
	badge.custom_minimum_size = Vector2(40, 40)
	badge.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	badge.offset_left = -34
	badge.offset_right = 6
	badge.offset_top = -14
	badge.offset_bottom = 26
	b.add_child(badge)
	item_badges[k] = badge
	Fx.attach(b, Fx.SOFT)
	return b


## 기울이기 ◀ ▶ (꾹 누르는 동안만 기울어요)
func _tilt_btn(icon_name: String, dir: int) -> Button:
	var b := _icon_btn(icon_name, true)
	b.custom_minimum_size = Vector2(72, 148)
	var pst := Sty.box("sb_button_secondary")
	pst.content_margin_left = 0
	pst.content_margin_right = 0
	b.add_theme_stylebox_override("pressed", pst)
	b.button_down.connect(func(): core.tilt_btn = dir)
	b.button_up.connect(func(): core.tilt_btn = 0)
	return b


## 정보줄 한 줄: 「45단계 · 고비 · 던지기 31 남음」
func _info_str() -> String:
	var left := ("던지기 %d 남음" % core.throws_left) if (core.mode != "stage" or int(core.stages[core.stage_idx]["throws"])) else "던지기 무제한"
	if core.streak > 0:
		left += " · 연속 ×%s" % str(1.0 + core.streak * GameCore.STREAK_STEP)
	if core.momentum() > 0:
		left += " · 기세 +%d%%" % roundi(core.momentum() * 100)
	if core.mode != "stage":
		return "무한 모드 · " + left
	var i: int = core.stage_idx
	var jump := i >= 24 and (i + 1) % 5 == 0
	return "%d단계%s · %s" % [i + 1, " · 고비" if jump else "", left]


## 목표 막대: 스테이지는 목표 진행도, 무한 모드는 최고 기록 대비 점수
func _refresh_goal() -> void:
	if goal_box == null:
		return
	var cur := 0.0
	var tot := 1.0
	var right := ""
	if core.mode == "stage":
		var st: Dictionary = core.stages[core.stage_idx]
		match st["goal"]:
			"tier":
				goal_l.text = "목표"
				cur = float(core.board_tier); tot = float(maxi(1, int(st["t"])))
				right = core.goal_text(st)
			"up":
				goal_l.text = "목표 · 위로 합치기"
				cur = float(core.up_count); tot = float(maxi(1, int(st["v"])))
				right = "%d / %d" % [mini(core.up_count, int(st["v"])), int(st["v"])]
			"upTier":
				goal_l.text = "목표"
				cur = float(core.up_tier); tot = float(maxi(1, int(st["t"])))
				right = core.goal_text(st)
			_:
				goal_l.text = "목표 점수"
				cur = float(core.score); tot = float(maxi(1, int(st["v"])))
				right = "%s / %s" % [GameCore.score_text(core.score), GameCore.score_text(int(st["v"]))]
	else:
		goal_l.text = "최고 기록"
		cur = float(core.score); tot = float(maxi(1, core.best))
		right = "%s / %s" % [GameCore.score_text(core.score), GameCore.score_text(core.best)] if core.best > 0 else GameCore.score_text(core.score)
	goal_r.text = right
	goal_fill.set_meta("ratio", clampf(cur / tot, 0.0, 1.0))
	_place_goal()


func _place_goal() -> void:
	var w := goal_box.size.x
	goal_l.position = Vector2(0, 0)
	goal_r.position = Vector2(0, 0)
	goal_r.size = Vector2(w, 0)
	goal_bg.position = Vector2(0, 46)
	goal_bg.size = Vector2(w, 18)
	var ratio: float = goal_fill.get_meta("ratio", 0.0)
	goal_fill.position = Vector2(0, 46)
	goal_fill.size = Vector2(maxf(18.0, w * ratio) if ratio > 0.0 else 0.0, 18)
	for k in 3:
		var tk: ColorRect = goal_ticks[k]
		tk.position = Vector2(w * 0.25 * (k + 1) - 1, 44)
		tk.size = Vector2(2, 22)


func _build_ui() -> void:
	# 위: 점수 + 아이콘 버튼 3개 (시안 v4)
	var top := HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 8)
	add_child(top)
	score_lbl = _lbl("0", 76, UI.NIGHT_TEXT, font_num)
	score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(score_lbl)
	mute_btn = _icon_btn("ic_sound", false)
	mute_btn.pressed.connect(func():
		synth.muted = not synth.muted
		Save.d["muted"] = synth.muted
		Save.save()
		_paint_mute())
	top.add_child(mute_btn)
	_paint_mute()
	var hb := _icon_btn("ic_home", false)
	hb.pressed.connect(go_home)
	top.add_child(hb)
	var mb := _icon_btn("ic_list", true)
	mb.pressed.connect(func():
		persist()
		show_menu())
	top.add_child(mb)
	# 정보줄: 2줄로 고정(줄바꿈으로 숫자가 떨어지지 않게) + 새 판/다시 칩
	var info_row := HBoxContainer.new()
	info_row.name = "InfoRow"
	info_row.add_theme_constant_override("separation", 12)
	add_child(info_row)
	info_lbl = _lbl("", 26, UI.NIGHT_TEXT_SUB)
	info_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info_lbl.clip_text = true
	info_row.add_child(info_lbl)
	restart_btn = _chip_btn("새 판")
	restart_btn.pressed.connect(_on_restart)
	info_row.add_child(restart_btn)
	# 목표 막대: 왼쪽 「목표 점수」, 오른쪽 「현재 / 목표」, 25% 눈금
	goal_box = Control.new()
	goal_box.name = "Goal"
	goal_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(goal_box)
	goal_l = _lbl("목표 점수", 26, UI.NIGHT_TEXT_SUB)
	goal_box.add_child(goal_l)
	goal_r = _lbl("", 26, UI.NIGHT_TEXT, font_num)
	goal_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	goal_box.add_child(goal_r)
	goal_bg = Panel.new()
	goal_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_bg.add_theme_stylebox_override("panel", Sty.box("sb_progress_bg"))
	goal_box.add_child(goal_bg)
	goal_fill = Panel.new()
	goal_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	goal_fill.add_theme_stylebox_override("panel", Sty.box("sb_progress_fill"))
	goal_box.add_child(goal_fill)
	for k in 3:
		var tk := ColorRect.new()
		tk.color = Color(UI.NIGHT_TEXT.r, UI.NIGHT_TEXT.g, UI.NIGHT_TEXT.b, 0.22)
		tk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		goal_box.add_child(tk)
		goal_ticks.append(tk)

	# 판
	board_area = Control.new()
	# 웹 버전처럼 판 밖(아래 빈 곳 등) 어디를 눌러도 손가락과 가장 가까운 대기 숫자를 잡아요.
	# 판도 PASS 라서 눌림이 화면 전체(_gui_input)로 올라가 한곳에서 처리돼요.
	board_area.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(board_area)
	board_area.add_child(core)

	# 아래: 아이템 (아이콘 + 이름 + 개수 배지)
	items_box = HBoxContainer.new()
	items_box.add_theme_constant_override("separation", 12)
	add_child(items_box)
	tilt_l = _tilt_btn("ic_tilt_left", -1)
	items_box.add_child(tilt_l)
	for k in ["shake", "undo", "hammer", "tilt", "x2"]:
		var b := _item_btn(k)
		var kk: String = k
		b.pressed.connect(func(): _use_item(kk))
		items_box.add_child(b)
		item_btns[k] = b
	tilt_r = _tilt_btn("ic_tilt_right", 1)
	items_box.add_child(tilt_r)

	hint_lbl = _lbl("위에 있는 숫자 하나를 골라\n끌었다 놓으면 그 방향으로 날아가요.\n같은 숫자끼리 닿으면 합쳐져요.\n양쪽 반원이 납작해지면 끝나요.", 24, MILK)
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_lbl.visible = false
	add_child(hint_lbl)

	toast_lbl = _lbl("", 24, MILK)
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := _style(Color(0.1, 0.1, 0.11, 0.9), 22)
	toast_lbl.add_theme_stylebox_override("normal", tsb)
	toast_lbl.visible = false
	add_child(toast_lbl)

	# 단계 시작 배너
	mission = PanelContainer.new()
	mission.add_theme_stylebox_override("panel", _style(Color(0.16, 0.16, 0.17, 0.96), 18))
	mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission.visible = false
	add_child(mission)
	var mvb := VBoxContainer.new()
	mvb.alignment = BoxContainer.ALIGNMENT_CENTER
	mission.add_child(mvb)
	for i in 3:
		var l := _lbl("", [24, 34, 20][i], [SOFT, MILK, SOFT][i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mvb.add_child(l)

	# 결과 카드
	card = _overlay(Color(0, 0, 0, 0.45))
	var cp := PanelContainer.new()
	var cps := Sty.box("sb_card_result")
	cps.content_margin_left = 44; cps.content_margin_right = 44
	cps.content_margin_top = 40; cps.content_margin_bottom = 36
	cp.add_theme_stylebox_override("panel", cps)
	cp.custom_minimum_size = Vector2(600, 0)
	cp.set_anchors_preset(Control.PRESET_CENTER)
	cp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cp.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	cp.add_child(cv)
	card_stage = _lbl("", 22, UI.MINT_PROGRESS, font_num)      # 「STAGE 45 · 고비」
	card_title = _lbl("", 40, MILK, font_bold)
	card_stars = _lbl("", 52, UI.GOLD_STAR)
	card_big = _lbl("", 104, MILK, font_num)
	card_note = _lbl("", 24, SOFT)
	card_reward = _lbl("", 26, UI.JELLY, font_bold)
	var rsb := StyleBoxFlat.new()
	rsb.bg_color = Color(UI.JELLY.r, UI.JELLY.g, UI.JELLY.b, 0.1)
	rsb.border_color = Color(UI.JELLY.r, UI.JELLY.g, UI.JELLY.b, 0.35)
	rsb.set_border_width_all(2)
	rsb.set_corner_radius_all(40)
	rsb.content_margin_top = 10; rsb.content_margin_bottom = 10
	card_reward.add_theme_stylebox_override("normal", rsb)
	for l in [card_stage, card_title, card_stars, card_big, card_note]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 512
		cv.add_child(l)
	var dash := _lbl("- - - - - - - - - - - - - - - - - - - - - - - - - -", 16, Color(UI.MINT_PROGRESS.r, UI.MINT_PROGRESS.g, UI.MINT_PROGRESS.b, 0.28))
	dash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dash.clip_text = true
	dash.custom_minimum_size.x = 512
	cv.add_child(dash)
	card_reward.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_reward.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	card_reward.custom_minimum_size.x = 512
	cv.add_child(card_reward)
	card_main = _btn("다시 하기", MILK, INK, 30)
	card_main.custom_minimum_size.y = 92
	card_main.pressed.connect(_on_card_main)
	cv.add_child(card_main)
	card_menu = _btn("단계 목록", PAGE, MILK, 26)
	card_menu.pressed.connect(show_menu)
	cv.add_child(card_menu)
	var ch := _btn("집으로", PAGE, SOFT, 24)
	ch.flat = true
	for stn in ["normal", "hover", "focus", "pressed"]:
		ch.add_theme_stylebox_override(stn, StyleBoxEmpty.new())
	ch.pressed.connect(go_home)
	cv.add_child(ch)

	# 단계 목록
	menu = _overlay(Color(UI.NIGHT_BG_TOP.r, UI.NIGHT_BG_TOP.g, UI.NIGHT_BG_TOP.b, 0.98))
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = 30
	sc.offset_bottom = -30
	sc.offset_left = 30
	sc.offset_right = -30
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(sc)
	menu_grid_box = VBoxContainer.new()
	menu_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_grid_box.add_theme_constant_override("separation", 12)
	sc.add_child(menu_grid_box)

	# 가이드 카드
	guide = _overlay(Color(0, 0, 0, 0.55))


func _outline() -> StyleBoxFlat:
	var sb := _style(PAGE)
	sb.border_color = Color("#5a5a60")
	sb.set_border_width_all(2)
	return sb


func _overlay(col: Color) -> Control:
	var o := ColorRect.new()
	o.color = col
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.mouse_filter = Control.MOUSE_FILTER_STOP
	o.visible = false
	add_child(o)
	return o


func _layout() -> void:
	var vs := size
	var mx := 36.0
	var top: Control = get_node("Top")
	top.size = Vector2(vs.x - mx * 2, 0)
	top.position = Vector2(mx, 28)
	var info_row: Control = get_node("InfoRow")
	info_row.position = Vector2(mx, 140)
	info_row.size = Vector2(vs.x - mx * 2, 0)
	goal_box.position = Vector2(mx, 204)
	goal_box.size = Vector2(vs.x - mx * 2, 70)
	_place_goal()
	var top_h := 296.0
	var bottom_h := 220.0
	var avail := Vector2(vs.x - 48, vs.y - top_h - bottom_h - 20)
	board_scale = minf(avail.x / GameCore.W, avail.y / GameCore.H)
	var bw := GameCore.W * board_scale
	var bh := GameCore.H * board_scale
	board_area.position = Vector2((vs.x - bw) / 2, top_h + (avail.y - bh) / 2)
	board_area.size = Vector2(bw, bh)
	core.scale = Vector2.ONE * board_scale
	items_box.position = Vector2(mx, vs.y - 148 - 36)
	items_box.size = Vector2(vs.x - mx * 2, 148)
	hint_lbl.position = board_area.position + Vector2(0, bh * 0.38)
	hint_lbl.size = Vector2(bw, 0)
	mission.position = Vector2(vs.x * 0.1, board_area.position.y + 60)
	mission.size = Vector2(vs.x * 0.8, 0)


# ───────────────────────── 흐름 ─────────────────────────

func _apply_daily() -> void:
	var dl := {}
	for k in ITEM_NAMES:
		dl[k] = Save.daily_left(k) + Save.bag_count(k)
	core.daily_left = dl


func start_endless(resume := true) -> void:
	core.mode = "endless"
	_apply_daily()
	var run: Dictionary = Save.d.get("run", {})
	if resume and run.get("blobs", []).size() > 0 and not run.get("over", false) and int(run.get("throws_left", 0)) > 0:
		core.restore(run)
		_toast("하던 무한 모드를 이어서 해요")
	else:
		core.new_game()
	restart_btn.text = "새 판"
	_close_overlays()
	hint_lbl.visible = not bool(Save.d["seen_hint"])
	if not Save.d["guides"].has("endless"):
		show_guide("endless", func(): pass)


func start_stage(i: int) -> void:
	i = clampi(i, 0, core.stages.size() - 1)
	core.mode = "stage"
	core.stage_idx = i
	core.new_game()
	restart_btn.text = "다시"
	_close_overlays()
	var st: Dictionary = core.stages[i]
	if st.get("tip"):
		hint_lbl.text = str(st["tip"]).replace("<br>", "\n")
		hint_lbl.visible = true
	else:
		hint_lbl.visible = false
	var g = st.get("guide")
	if g and not Save.d["guides"].has(g):
		show_guide(g, func(): _show_mission(i))
	else:
		_show_mission(i)


func _close_overlays() -> void:
	card.visible = false
	menu.visible = false
	guide.visible = false


func _on_restart() -> void:
	if core.over:
		_restart_same()
		return
	if armed_t > 0:
		armed_t = 0
		_restart_same()
		return
	armed_t = 2.5
	restart_btn.text = "정말요?"


func _restart_same() -> void:
	if core.mode == "stage":
		start_stage(core.stage_idx)
	else:
		start_endless(false)


func persist() -> void:
	if core and core.mode != "stage":
		Save.d["run"] = core.snapshot()
		Save.save()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		persist()


func go_home() -> void:
	persist()
	get_tree().change_scene_to_file("res://scenes/main.tscn")


func _show_mission(i: int) -> void:
	var st: Dictionary = core.stages[i]
	var jump := i >= 24 and (i + 1) % 5 == 0
	var labels := mission.get_child(0).get_children()
	labels[0].text = "%d단계%s" % [i + 1, " · 고비!" if jump else ""]
	labels[0].add_theme_color_override("font_color", Color("#ff8fb1") if jump else SOFT)
	labels[1].text = core.goal_text(st)
	var has_items := false
	for k in core.item_at:
		if i + 1 >= int(core.item_at[k]):
			has_items = true
	labels[2].text = ("던지기 %d번" % int(st["throws"]) if int(st["throws"]) else "던지기 무제한") + (" · 아이템 각 1번" if has_items else "")
	mission.visible = true
	mission.modulate.a = 1
	mission_t = 2.9


func _toast(text: String) -> void:
	toast_lbl.text = text
	toast_lbl.visible = true
	toast_lbl.reset_size()
	toast_lbl.position = Vector2((size.x - toast_lbl.size.x) / 2, board_area.position.y + board_area.size.y * 0.55)
	toast_t = 1.65


func _paint_items() -> void:
	var any := false
	for k in item_btns:
		var b: Button = item_btns[k]
		var open: bool = core.item_open(k)
		b.visible = open
		any = any or open
		var left: int = {"shake": core.shake_left, "undo": core.undo_left, "hammer": core.hammer_left, "tilt": core.tilt_left, "x2": core.x2_left}[k]
		b.text = ITEM_NAMES[k]
		b.disabled = left <= 0 and not (k == "hammer" and core.hammer_armed) and not (k == "x2" and core.x2_armed)
		var on: bool = (k == "hammer" and core.hammer_armed) or (k == "x2" and core.x2_armed)
		item_rings[k].visible = on
		var badge: Label = item_badges[k]
		badge.text = str(left)
		badge.visible = open
		if item_prev.has(k) and left < int(item_prev[k]):
			Fx.pop(badge)   # 쓰면 배지가 톡 튀어요
		item_prev[k] = left
	var tilting: bool = core.tilt_t > 0
	tilt_l.visible = tilting
	tilt_r.visible = tilting
	if tilting:
		# 기울이는 동안은 「◀ N초 ▶」만: 화살표가 크게, 줄이 화면 밖으로 안 넘침
		for k in item_btns:
			if k != "tilt":
				item_btns[k].visible = false
		item_btns["tilt"].text = "%d초" % ceili(core.tilt_t)
	item_btns["tilt"].icon = null if tilting else Sty.icon(ITEM_ICONS["tilt"])
	items_box.visible = any
	# 컨테이너는 한 번 커지면 안 줄어들어요(처음엔 아이템이 다 보이는 상태로 잼) → 보이는 칸이 바뀔 때마다 너비를 다시 맞춤
	var w := get_viewport_rect().size.x - 72
	if items_box.size.x != w:
		items_box.size = Vector2(w, 148)


func _use_item(k: String) -> void:
	var endless: bool = core.mode != "stage"
	match k:
		"shake":
			if core.do_shake():
				Save.spend_item("shake", endless)
		"undo":
			if core.do_undo():
				Save.spend_item("undo", endless)
		"hammer":
			if core.hammer_left > 0 and not core.over:
				core.hammer_armed = not core.hammer_armed
				_toast("판 안의 숫자를 눌러요" if core.hammer_armed else "뿅망치를 내려놨어요")
		"tilt":
			if core.do_tilt():
				Save.spend_item("tilt", endless)
		"x2":
			if core.x2_left > 0 and not core.over:
				core.x2_armed = not core.x2_armed
				_toast("다음에 던지는 숫자가 별이 돼요" if core.x2_armed else "별을 내려놨어요")
	_paint_items()


# ───────────────────────── 입력 ─────────────────────────

func _gui_input(e: InputEvent) -> void:
	_board_input(e)


## e.position 은 화면(이 Control) 좌표
func _board_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var lp: Vector2 = (e.position - board_area.position) / board_scale
		if e.pressed:
			if core.over or core.clear_t > 0 or dragging:
				return
			if core.hammer_armed:
				if core.hammer_at(lp.x, lp.y) if board_area.get_rect().has_point(e.position) else false:
					Save.spend_item("hammer", core.mode != "stage")
					_paint_items()
				return
			if core.grab(lp.x):
				dragging = true
				drag_start = e.position
				Save.buzz(8)
		else:
			if dragging:
				dragging = false
				var used: String = core.release(true)
				Save.buzz(8)
				if used == "x2":
					Save.spend_item("x2", core.mode != "stage")
				if hint_lbl.visible and core.mode != "stage":
					hint_lbl.visible = false
					Save.d["seen_hint"] = true
					Save.save()
				elif hint_lbl.visible and core.score == 0:
					pass
				_paint_items()
	elif e is InputEventMouseMotion and dragging:
		var dv: Vector2 = (e.position - drag_start) / board_scale
		var l := dv.length()
		core.pull = minf(1, maxf(0, l - 12) / 150.0)
		if l > 12:
			core.aim = atan2(dv.x, dv.y)


# ───────────────────────── 매 프레임 ─────────────────────────

## 폰 기울기(좌우, 도 단위): 웹은 deviceorientation, 앱은 중력 센서
var tilt_js := false


func _read_tilt() -> void:
	if OS.has_feature("web"):
		if not tilt_js:
			tilt_js = true
			JavaScriptBridge.eval("""(function(){try{var f=function(){window.addEventListener('deviceorientation',function(e){if(e.gamma!=null)window.__tilt=e.gamma;});};
				if(window.DeviceOrientationEvent&&DeviceOrientationEvent.requestPermission){DeviceOrientationEvent.requestPermission().then(function(r){if(r=='granted')f();}).catch(function(){});}else f();}catch(e){}})()""")
		var v = JavaScriptBridge.eval("window.__tilt||0")
		core.tilt_deg = clampf(float(v), -50, 50)
	else:
		var g := Input.get_gravity()
		if g.length() > 1.0:
			core.tilt_deg = clampf(rad_to_deg(atan2(-g.x, -g.y if absf(g.y) > absf(g.z) else -g.z)), -50, 50)


func _process(delta: float) -> void:
	var dt := minf(0.05, delta)
	if core.tilt_t > 0:
		_read_tilt()
	if not card.visible and not menu.visible and not guide.visible:
		acc += dt
		var steps := 0
		while acc >= 1.0 / 60 and steps < 3:
			core.sim_step(1.0 / 60)
			acc -= 1.0 / 60
			steps += 1
		if steps == 3:
			acc = 0
	if card.visible or menu.visible or guide.visible:
		core.queue_redraw()
	if core.tilt_t > 0:
		_paint_items()
	if toast_t > 0:
		toast_t -= delta
		if toast_t <= 0:
			toast_lbl.visible = false
	if mission_t > 0:
		mission_t -= delta
		mission.modulate.a = clampf(mission_t * 2, 0, 1)
		if mission_t <= 0:
			mission.visible = false
	if armed_t > 0:
		armed_t -= delta
		if armed_t <= 0:
			restart_btn.text = "다시" if core.mode == "stage" else "새 판"


# ───────────────────────── 결과 ─────────────────────────

func _on_finished(kind: String, reason: String) -> void:
	dragging = false
	if core.mode != "stage":
		Save.d["run"] = {}
	if kind == "clear":
		_stage_clear()
	else:
		_game_over(reason)


func _game_over(reason: String) -> void:
	card_stars.text = ""
	if core.mode == "stage":
		var st: Dictionary = core.stages[core.stage_idx]
		var top := GameCore.num_text(core.top_tier())
		_show_card(reason, top, "목표 " + core.goal_text(st) + " · 가장 큰 숫자 " + top, "", "다시 하기", true)
		card_act = "retry"
	else:
		Save.d["best"] = maxi(int(Save.d["best"]), core.best)
		var reward := ""
		var j := 0
		if Save.endless_paid_left() > 0:
			j = Save.endless_jelly(core.score)
			var e: Dictionary = Save.d["erew"]
			if e.get("day", "") != Save.kst_day():
				e = {"day": Save.kst_day(), "n": 0}
			e["n"] = int(e["n"]) + 1
			Save.d["erew"] = e
			Save.add_jelly(j)
			reward = "무한 모드 보상 젤리 +%d" % j if j > 0 else ""
		else:
			reward = "오늘 보상 판(%d번)을 다 썼어요" % Save.ENDLESS_PAID
		Save.save()
		_show_card(reason, GameCore.score_text(core.score), "최고 기록 %s · 가장 큰 숫자 %s" % [GameCore.score_text(core.best), GameCore.num_text(core.max_tier)], reward, "다시 하기", false)
		card_act = "retry"


func _stage_clear() -> void:
	var i: int = core.stage_idx
	var st: Dictionary = core.stages[i]
	var last := i == core.stages.size() - 1
	var first := i + 1 > int(Save.d["prog"])
	Save.d["prog"] = maxi(int(Save.d["prog"]), i + 1)
	core.prog = int(Save.d["prog"])
	var j := Save.stage_jelly(i, first)
	Save.add_jelly(j)
	var extra := ""
	if first:
		var n := i + 1
		if n == 20:
			extra += " · 무한 모드 던지기 550번으로!"
		elif n > 20:
			extra += " · 무한 모드 던지기 %d번 늘었어요" % (roundi(550 + (n - 20) * 450.0 / 80) - roundi(550 + (n - 21) * 450.0 / 80))
		for k in core.endless_at:
			if int(core.endless_at[k]) == n:
				extra += " · 이제 무한 모드에서 %s를 하루 3번 쓸 수 있어요!" % ITEM_NAMES[k]
	var throws := int(st["throws"])
	var stars := 3
	if throws:
		stars = 3 if core.throws_left >= throws * 0.3 else (2 if core.throws_left >= throws * 0.12 else 1)
	var sd: Dictionary = Save.d["stars"]
	sd[str(i)] = maxi(int(sd.get(str(i), 0)), stars)
	Save.save()
	card_stars.text = "★".repeat(stars) + "☆".repeat(3 - stars)
	var big := GameCore.num_text(int(st["t"])) if st["goal"] == "tier" else GameCore.score_text(core.score)
	var note := ("던지기 %d번 남기고 성공" % core.throws_left if throws else "점수 " + GameCore.score_text(core.score)) + extra
	_show_card("모든 단계를 깼어요!" if last else "클리어!", big, note,
		("첫 클리어 보상" if first else "다시 깨기 보상") + "  젤리 +%d" % j, "목록으로" if last else "다음 단계 · %d" % (i + 2), not last)
	card_act = "menu" if last else "next"


func _show_card(title: String, big: String, note: String, reward: String, main: String, with_menu: bool) -> void:
	if core.mode == "stage":
		var i: int = core.stage_idx
		card_stage.text = "STAGE %d" % (i + 1) + (" · 고비" if i >= 24 and (i + 1) % 5 == 0 else "")
	else:
		card_stage.text = "ENDLESS"
	card_title.text = title
	card_big.text = big
	card_note.text = note
	card_reward.text = reward
	card_reward.visible = reward != ""
	card_main.text = main
	card_menu.visible = with_menu
	card.visible = true
	var cp: Control = card.get_child(0)
	cp.reset_size()
	Fx.appear(cp)


func _on_card_main() -> void:
	match card_act:
		"next": start_stage(core.stage_idx + 1)
		"menu": show_menu()
		_: _restart_same()


# ───────────────────────── 단계 목록 ─────────────────────────

func show_menu() -> void:
	core.over = true
	dragging = false
	core.sel = null
	for c in menu_grid_box.get_children():
		c.queue_free()
	var n_st: int = core.stages.size()
	var prog := int(Save.d["prog"])
	var nxt := mini(prog, n_st - 1)
	# 머리: 스테이지 · 깬 수 / 전체 + 무한 모드 · 집으로
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	menu_grid_box.add_child(head)
	var t := _lbl("스테이지", 40, MILK, font_bold)
	head.add_child(t)
	var cnt := _lbl("%d / %d" % [prog, n_st], 30, SOFT, font_num)
	cnt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	head.add_child(cnt)
	var eb := _btn("무한 모드", BTN, MILK, 22)
	eb.pressed.connect(start_endless)
	head.add_child(eb)
	var hb := _btn("집으로", BTN, MILK, 22)
	hb.pressed.connect(go_home)
	head.add_child(hb)
	# 이어하기 카드 (다음 단계 바로 시작)
	var cont := _btn("", BTN, MILK, 22)
	cont.custom_minimum_size.y = 190
	var cs := Sty.box("sb_button_primary")
	for stn in ["normal", "hover", "focus", "pressed"]:
		cont.add_theme_stylebox_override(stn, cs)
	cont.pressed.connect(func(): start_stage(nxt))
	menu_grid_box.add_child(cont)
	var crow := HBoxContainer.new()
	crow.set_anchors_preset(Control.PRESET_FULL_RECT)
	crow.offset_left = 36; crow.offset_right = -36
	crow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.add_child(crow)
	var cl := VBoxContainer.new()
	cl.alignment = BoxContainer.ALIGNMENT_CENTER
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(cl)
	cl.add_child(_lbl("이어하기" if prog < n_st else "다시 도전", 22, UI.AMBER_PRIMARY))
	var gl := _lbl(core.goal_text(core.stages[nxt]), 34, MILK, font_bold)
	cl.add_child(gl)
	var tags: Array = []
	if nxt >= 24 and (nxt + 1) % 5 == 0:
		tags.append("고비 판")
	for k in ["shake", "undo", "hammer", "tilt", "x2"]:
		if nxt + 1 >= int(core.item_at.get(k, 999)):
			tags.append(ITEM_NAMES[k])
	cl.add_child(_lbl(" · ".join(tags), 20, SOFT))
	var cr := VBoxContainer.new()
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crow.add_child(cr)
	var sl := _lbl("STAGE", 20, UI.AMBER_PRIMARY, font_num)
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cr.add_child(sl)
	var sn := _lbl(str(nxt + 1), 84, UI.AMBER_PRIMARY, font_num)
	sn.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cr.add_child(sn)
	if OS.has_feature("web"):
		var ib := _btn("원래 몰랑탑 기록 불러오기", BTN, SOFT, 18)
		ib.pressed.connect(_import_web)
		menu_grid_box.add_child(ib)
	# 챕터: 10단계씩. 지금 챕터만 펼치고 나머지는 누르면 펼침. 새 판·장애물 안내가 있는 챕터는 그 이름을 붙임
	var guides: Dictionary = Save.data.get("guides", {})
	var stars: Dictionary = Save.d.get("stars", {})
	var cur_ch := nxt / 10
	var chapters := ceili(n_st / 10.0)   # 앞으로 열릴 챕터는 숨김(시안처럼 지금 챕터가 맨 위)
	for chi in range(mini(cur_ch, chapters - 1), -1, -1):
		var a := chi * 10
		var b := mini(n_st, a + 10)
		var names: Array = []
		for i in range(a, b):
			var g = core.stages[i].get("guide")
			if g and guides.has(g) and str(guides[g].get("rib", "")).begins_with("새") and names.size() < 2:
				names.append(str(guides[g].get("title", "")))
		var done_n := 0
		var star_n := 0
		for i in range(a, b):
			if i < prog:
				done_n += 1
			star_n += int(stars.get(str(i), 0))
		var locked_ch := a > prog
		var card_p := PanelContainer.new()
		var ps := Sty.box("sb_card_result") if chi == cur_ch else Sty.box("sb_panel_night")
		ps.shadow_size = 0
		ps.content_margin_left = 28; ps.content_margin_right = 28
		ps.content_margin_top = 22; ps.content_margin_bottom = 22
		card_p.add_theme_stylebox_override("panel", ps)
		menu_grid_box.add_child(card_p)
		var cv := VBoxContainer.new()
		cv.add_theme_constant_override("separation", 16)
		card_p.add_child(cv)
		var hrow := HBoxContainer.new()
		cv.add_child(hrow)
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(18, 18)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var ds := StyleBoxFlat.new()
		ds.set_corner_radius_all(9)
		if chi == cur_ch:
			ds.bg_color = UI.AMBER_PRIMARY
			ds.shadow_color = Color(UI.AMBER_PRIMARY.r, UI.AMBER_PRIMARY.g, UI.AMBER_PRIMARY.b, 0.5); ds.shadow_size = 8
		elif done_n == b - a:
			ds.bg_color = UI.MINT_PROGRESS
		else:
			ds.bg_color = Color(0, 0, 0, 0); ds.border_color = UI.NIGHT_LINE_STRONG; ds.set_border_width_all(2)
		dot.add_theme_stylebox_override("panel", ds)
		hrow.add_child(dot)
		var title := "  %d–%d" % [a + 1, b] + ((" · " + "와 ".join(names)) if names.size() else (" · 기본" if chi == 0 else ""))
		var tl := _lbl(title, 26, MILK if not locked_ch else SOFT, font_bold)
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.clip_text = true
		hrow.add_child(tl)
		hrow.add_child(_lbl("%d/%d  ★%d" % [done_n, b - a, star_n], 22, SOFT, font_num))
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 14)
		grid.add_theme_constant_override("v_separation", 14)
		grid.visible = chi == cur_ch
		cv.add_child(grid)
		for i in range(a, b):
			var st: Dictionary = core.stages[i]
			var done := i < prog
			var now := i == prog
			var jump := i >= 24 and (i + 1) % 5 == 0
			var bg := CELL_DONE if done else (MILK if now else (CELL_JUMP if jump else BTN2))
			var cb := _btn(str(i + 1), bg, UI.MINT_PROGRESS if done else (MILK if not (i > prog) else SOFT), 28)
			cb.add_theme_font_override("font", font_num)
			cb.custom_minimum_size = Vector2(0, 96)
			cb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var idx: int = i
			if i > prog:
				# 잠긴 칸: 작아지지 않고 좌우로 흔들림 + 「○단계에 열려요」 (인터랙션 제안서 E)
				var lk := cb.get_theme_stylebox("disabled")
				for stn in ["normal", "hover", "focus", "pressed"]:
					cb.add_theme_stylebox_override(stn, lk)
				for sig in [cb.button_down, cb.button_up]:
					for c in sig.get_connections():
						sig.disconnect(c["callable"])
				cb.scale = Vector2.ONE
				cb.pressed.connect(func():
					Fx.shake(cb)
					_toast("%d단계를 깨면 열려요" % idx))
			else:
				for sig in [cb.button_down, cb.button_up]:
					for c in sig.get_connections():
						sig.disconnect(c["callable"])
				Fx.attach(cb, Fx.ICON)
				cb.pressed.connect(func(): start_stage(idx))
			grid.add_child(cb)
		if chi == cur_ch:
			# 다음 아이템 안내 (시안: 「다음 아이템 · 기울이기 56단계」)
			for k in ["shake", "undo", "hammer", "tilt", "x2"]:
				var at := int(core.item_at.get(k, 999))
				if at > nxt + 1:
					var nrow := HBoxContainer.new()
					cv.add_child(nrow)
					var nl := _lbl("다음 아이템 · " + ITEM_NAMES[k], 20, SOFT)
					nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
					nrow.add_child(nl)
					nrow.add_child(_lbl("%d단계" % at, 20, MILK, font_num))
					break
		else:
			# 접힌 챕터: 누르면 펼침
			var tog := Button.new()
			tog.flat = true
			tog.focus_mode = Control.FOCUS_NONE
			tog.set_anchors_preset(Control.PRESET_FULL_RECT)
			tog.mouse_filter = Control.MOUSE_FILTER_PASS
			card_p.add_child(tog)
			tog.pressed.connect(func():
				grid.visible = not grid.visible
				tog.visible = false)
	card.visible = false
	guide.visible = false
	hint_lbl.visible = false
	menu.visible = true


# ───────────────────────── 가이드 ─────────────────────────

func show_guide(k: String, done: Callable) -> void:
	var g: Dictionary = Save.data.get("guides", {}).get(k, {})
	if g.is_empty():
		done.call()
		return
	for c in guide.get_children():
		c.queue_free()
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _style(PAGE, 26))
	p.custom_minimum_size = Vector2(580, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	guide.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var rib := _lbl(str(g.get("rib", "")), 22, Color("#ff8fb1") if not g.get("ob") else Color("#7ab8ff"), font_bold)
	v.add_child(rib)
	var tt := _lbl(str(g.get("title", "")), 36)
	v.add_child(tt)
	var tx := _lbl(str(g.get("text", "")), 24, SOFT)
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.custom_minimum_size.x = 540
	v.add_child(tx)
	for s in g.get("steps", []):
		var sl := _lbl(str(s), 22, MILK)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size.x = 540
		v.add_child(sl)
	var ok := _btn("해 볼게요!", MILK, INK, 28)
	ok.custom_minimum_size.y = 84
	ok.pressed.connect(func():
		var arr: Array = Save.d["guides"]
		if not arr.has(k):
			arr.append(k)
		Save.save()
		guide.visible = false
		done.call())
	v.add_child(ok)
	guide.visible = true


## 성능 측정용 (주소 끝 #bench): 막 던지며 1200프레임 물리만 돌리고 결과를 window.__bench 에
func _bench() -> void:
	Save.d["guides"] = ["endless"]
	core.mode = "endless"
	_apply_daily()
	core.new_game()
	seed(5)
	var t0 := Time.get_ticks_usec()
	var worst := 0
	for f in 1200:
		if f % 40 == 0 and core.queue.size() and not core.over and core.busy <= 0:
			core.sel = core.queue[randi() % core.queue.size()]
			core.aim = randf_range(-0.6, 0.6)
			core.pull = randf_range(0.3, 0.9)
			core.release(true)
		var a := Time.get_ticks_usec()
		core.sim_step(1.0 / 60)
		worst = maxi(worst, Time.get_ticks_usec() - a)
	var ms := (Time.get_ticks_usec() - t0) / 1000.0 / 1200.0
	JavaScriptBridge.eval("window.__bench = '%.2f ms/step, worst %.1f ms, blobs %d'" % [ms, worst / 1000.0, core.blobs.size()])


## 웹 버전 「저장 백업」 코드 붙여넣기 (브라우저 입력 창)
func _import_web() -> void:
	var js := "(function(){var c=prompt('원래 몰랑탑 → 스테이지 목록 → 「저장 백업」에서 복사한 코드를 붙여 넣어 주세요');if(!c)return '';try{return decodeURIComponent(escape(atob(c.trim())));}catch(e){return 'ERR';}})()"
	var r := str(JavaScriptBridge.eval(js))
	if r == "":
		return
	if r != "ERR" and Save.import_web(r):
		core.prog = int(Save.d["prog"])
		core.best = int(Save.d["best"])
		_toast("불러왔어요! %d단계까지 깼고 젤리 %d개예요" % [int(Save.d["prog"]), int(Save.d["jelly"])])
		show_menu()
	else:
		_toast("코드가 올바르지 않아요")
