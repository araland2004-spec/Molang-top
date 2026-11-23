extends Control
## 몰랑탑 숫자 게임 화면 — 웹 버전 게임 화면(점수·버튼·판·아이템·결과 카드·단계 목록·가이드)을 옮긴 것.

const GameCore := preload("res://scripts/game_core.gd")
const Synth := preload("res://scripts/synth.gd")

const PAGE := Color("#29292c")
const BTN := Color("#38383d")
const BTN2 := Color("#4a4a50")
const MILK := Color("#f4f4f2")
const SOFT := Color("#a3a3a8")
const INK := Color("#111113")
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
var hint_lbl: Label
var toast_lbl: Label
var toast_t := 0.0
var mission: PanelContainer
var mission_t := 0.0
var card: Control
var card_title: Label
var card_stars: Label
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


var input_guard := 0.0


func _ready() -> void:
	# 화면이 바뀔 때 손을 뗀 터치가 새 화면 버튼에 눌리지 않게 잠깐 입력을 막아요
	get_viewport().gui_disable_input = true
	get_tree().create_timer(0.35).timeout.connect(func(): get_viewport().gui_disable_input = false)
	input_guard = 0.35
	font_num = Mol.font("num")
	font_txt = Mol.font("r")
	font_bold = Mol.font("b")
	var bg := TextureRect.new()
	bg.texture = _bg_tex()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
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
	core.score_changed.connect(func(s): score_lbl.text = GameCore.score_text(s))
	core.info_changed.connect(_paint_info)
	core.toast.connect(_toast)
	core.items_changed.connect(_paint_items)
	core.finished.connect(_on_finished)
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


# ───────────────────────── UI 만들기 (UI 리뉴얼 v4) ─────────────────────────

const ITEM_ICON := {"shake": "item_shake", "undo": "item_undo", "hammer": "item_hammer", "tilt": "tilt_right", "x2": "item_x2star"}
var stage_lbl: Label
var throws_lbl: Label
var goal_row: Control
var goal_name: Label
var goal_val: Label
var goal_bar: Control
var goal_frac := 0.0
var item_badges := {}
var card_head: Label
var card_chips: HBoxContainer
var card_retry: Button
var card_links: HBoxContainer


func _btn(text: String, _bg := BTN, _fg := MILK, size := 26) -> Button:
	return Mol.btn(text, "sec", size)


func _lbl(text: String, size: int, col := Mol.TEXT, font: Font = null) -> Label:
	var l := Mol.lbl(text, size, col, "r")
	if font:
		l.add_theme_font_override("font", font)
	return l


class GoalBar extends Control:
	var frac := 0.0
	func _draw() -> void:
		var r := Rect2(0, 0, size.x, size.y)
		draw_rect(r, Color(0.494, 0.941, 0.784, 0.10))
		var w := size.x * clampf(frac, 0, 1)
		if w > 0:
			for k in 8:
				var t0 := float(k) / 8
				var c := Color("#4CC6B1").lerp(Color("#7EF0C8"), t0)
				draw_rect(Rect2(w * t0, 0, w / 8 + 1, size.y), c)
			draw_rect(Rect2(0, -3, w, size.y + 6), Color(0.494, 0.941, 0.784, 0.12))
		for k in [1, 2, 3]:
			var x: float = size.x * k / 4.0
			draw_line(Vector2(x, -6), Vector2(x, size.y + 6), Color(0.494, 0.941, 0.784, 0.35), 2)


func _build_ui() -> void:
	# 위: 점수 + 아이콘 버튼
	var top := HBoxContainer.new()
	top.name = "Top"
	top.add_theme_constant_override("separation", 12)
	add_child(top)
	score_lbl = Mol.lbl("0", 76, Mol.TEXT, "num")
	score_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(score_lbl)
	mute_btn = Mol.square_icon("sound")
	mute_btn.modulate.a = 0.4 if synth.muted else 1.0
	mute_btn.pressed.connect(func():
		synth.muted = not synth.muted
		Save.d["muted"] = synth.muted
		Save.save()
		mute_btn.modulate.a = 0.4 if synth.muted else 1.0
		_toast("효과음 꺼짐" if synth.muted else "효과음 켜짐"))
	top.add_child(mute_btn)
	var hb := Mol.square_icon("home")
	hb.pressed.connect(go_home)
	top.add_child(hb)
	var mb := Mol.square_icon("list", true)
	mb.pressed.connect(func():
		persist()
		show_menu())
	top.add_child(mb)
	restart_btn = Mol.btn("새 판", "sec", 24)     # 단계 목록 안에서 씀
	restart_btn.pressed.connect(_on_restart)
	# 한 줄 정보: 「45단계 · 고비 ‑‑ 던지기 31 남음」
	var info := HBoxContainer.new()
	info.name = "Info"
	info.add_theme_constant_override("separation", 16)
	add_child(info)
	stage_lbl = Mol.lbl("", 30, Mol.TEXT_SUB, "m")
	info.add_child(stage_lbl)
	var dl := Mol.DashLine.new(Color(0.494, 0.941, 0.784, 0.28))
	dl.custom_minimum_size = Vector2(56, 4)
	dl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	info.add_child(dl)
	throws_lbl = Mol.lbl("", 30, Mol.TEXT_SUB, "m")
	info.add_child(throws_lbl)
	info_lbl = Label.new()      # 예전 코드 호환용 (보이지 않음)
	info_lbl.visible = false
	add_child(info_lbl)
	# 목표 막대
	goal_row = VBoxContainer.new()
	goal_row.name = "Goal"
	goal_row.add_theme_constant_override("separation", 10)
	add_child(goal_row)
	var gh := HBoxContainer.new()
	goal_row.add_child(gh)
	goal_name = Mol.lbl("목표 점수", 26, Mol.TEXT_SUB, "r")
	goal_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	gh.add_child(goal_name)
	goal_val = Mol.lbl("", 28, Mol.TEXT, "num")
	gh.add_child(goal_val)
	goal_bar = GoalBar.new()
	goal_bar.custom_minimum_size.y = 18
	goal_row.add_child(goal_bar)

	# 판
	board_area = Control.new()
	board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	board_area.gui_input.connect(_board_input)
	add_child(board_area)
	board_area.add_child(core)

	# 아래: ◀ · 아이템(아이콘 + 이름 + 개수 배지) · ▶
	items_box = HBoxContainer.new()
	items_box.add_theme_constant_override("separation", 12)
	add_child(items_box)
	tilt_l = Mol.icon_btn("tilt_left", "", false, 148)
	tilt_l.button_down.connect(func(): core.tilt_btn = -1)
	tilt_l.button_up.connect(func(): core.tilt_btn = 0)
	items_box.add_child(tilt_l)
	for k in ["shake", "undo", "hammer", "tilt", "x2"]:
		var b := Mol.icon_btn(ITEM_ICON[k], ITEM_NAMES[k], false, 148)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kk: String = k
		b.pressed.connect(func(): _use_item(kk))
		var badge := Mol.lbl("1", 24, Color("#3a2408"), "num")
		badge.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_stylebox_override("normal", Mol.sb(Mol.STAR, Color(0, 0, 0, 0), 999, Vector2(6, 0)))
		badge.custom_minimum_size = Vector2(44, 44)
		badge.position = Vector2(0, 8)
		b.add_child(badge)
		item_badges[k] = badge
		b.resized.connect(func(): badge.position = Vector2(b.size.x * 0.5 + 14, 8))
		items_box.add_child(b)
		item_btns[k] = b
	tilt_r = Mol.icon_btn("tilt_right", "", false, 148)
	tilt_r.button_down.connect(func(): core.tilt_btn = 1)
	tilt_r.button_up.connect(func(): core.tilt_btn = 0)
	items_box.add_child(tilt_r)

	hint_lbl = Mol.lbl("위에 있는 숫자 하나를 골라\n끌었다 놓으면 그 방향으로 날아가요.\n같은 숫자끼리 닿으면 합쳐져요.\n양쪽 반원이 납작해지면 끝나요.", 26, Mol.TEXT_SUB, "r")
	hint_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_lbl.visible = false
	add_child(hint_lbl)

	toast_lbl = Mol.lbl("", 26, Mol.TEXT, "m")
	toast_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_lbl.add_theme_stylebox_override("normal", Mol.sb(Color(0.03, 0.09, 0.1, 0.92), Color(0.494, 0.941, 0.784, 0.22), 999, Vector2(32, 14)))
	toast_lbl.visible = false
	add_child(toast_lbl)

	# 단계 시작 배너
	mission = PanelContainer.new()
	mission.add_theme_stylebox_override("panel", Mol.card(36))
	mission.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mission.visible = false
	add_child(mission)
	var mvb := VBoxContainer.new()
	mvb.alignment = BoxContainer.ALIGNMENT_CENTER
	mvb.add_theme_constant_override("separation", 6)
	mission.add_child(mvb)
	for i in 3:
		var l := Mol.lbl("", [26, 40, 24][i], [Mol.MINT, Mol.TEXT, Mol.TEXT_SUB][i], ["num_m", "b", "r"][i])
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		mvb.add_child(l)

	# 결과 카드 (반지름 24, 위 테두리 민트 하이라이트, 점선 구분선, 주 버튼만 발광)
	card = _overlay(Color(0.01, 0.04, 0.05, 0.72))
	var cp := PanelContainer.new()
	cp.add_theme_stylebox_override("panel", Mol.card(48))
	cp.custom_minimum_size = Vector2(604, 0)
	cp.set_anchors_preset(Control.PRESET_CENTER)
	cp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cp.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 18)
	cp.add_child(cv)
	var hl := HBoxContainer.new()
	hl.alignment = BoxContainer.ALIGNMENT_CENTER
	hl.add_theme_constant_override("separation", 14)
	cv.add_child(hl)
	var g1 := Mol.GradLine.new(Color(0.494, 0.941, 0.784, 0.4))
	g1.custom_minimum_size.x = 100
	hl.add_child(g1)
	card_head = Mol.lbl("", 26, Mol.MINT, "num_m")
	hl.add_child(card_head)
	var g2 := Mol.GradLine.new(Color(0.494, 0.941, 0.784, 0.4))
	g2.custom_minimum_size.x = 100
	hl.add_child(g2)
	card_title = Mol.lbl("", 44, Mol.TEXT, "b")
	card_stars = Mol.lbl("", 56, Mol.STAR, "b")
	card_big = Mol.lbl("", 104, Mol.TEXT, "num")
	card_note = Mol.lbl("", 26, Mol.TEXT_SUB, "r")
	for l in [card_title, card_stars, card_big, card_note]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 520
		cv.add_child(l)
	var dsh := Mol.DashLine.new()
	cv.add_child(dsh)
	card_chips = HBoxContainer.new()
	card_chips.alignment = BoxContainer.ALIGNMENT_CENTER
	card_chips.add_theme_constant_override("separation", 14)
	cv.add_child(card_chips)
	card_reward = Mol.lbl("", 30, Mol.JELLY, "num")   # 칩 안 글자
	card_main = Mol.btn("다시 하기", "primary", 32)
	card_main.custom_minimum_size.y = 104
	card_main.pressed.connect(_on_card_main)
	cv.add_child(card_main)
	card_retry = Mol.btn("다시 하기", "sec", 30)
	card_retry.custom_minimum_size.y = 100
	card_retry.pressed.connect(_restart_same)
	cv.add_child(card_retry)
	card_links = HBoxContainer.new()
	card_links.alignment = BoxContainer.ALIGNMENT_CENTER
	cv.add_child(card_links)
	card_menu = Mol.btn("단계 목록", "ghost", 26)
	card_menu.pressed.connect(show_menu)
	card_links.add_child(card_menu)
	card_links.add_child(Mol.lbl("·", 26, Mol.TEXT_DIM))
	var ch := Mol.btn("집으로", "ghost", 26)
	ch.pressed.connect(go_home)
	card_links.add_child(ch)

	# 단계 목록 (스테이지 지도)
	menu = _overlay(Color(0.02, 0.07, 0.08, 1.0))
	var mbg := TextureRect.new()
	mbg.texture = _bg_tex()
	mbg.set_anchors_preset(Control.PRESET_FULL_RECT)
	mbg.stretch_mode = TextureRect.STRETCH_SCALE
	mbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	mbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(mbg)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.offset_top = 40
	sc.offset_bottom = -30
	sc.offset_left = 40
	sc.offset_right = -40
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu.add_child(sc)
	menu_grid_box = VBoxContainer.new()
	menu_grid_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_grid_box.add_theme_constant_override("separation", 24)
	sc.add_child(menu_grid_box)

	# 가이드 카드
	guide = _overlay(Color(0.01, 0.04, 0.05, 0.72))


func _bg_tex() -> GradientTexture2D:
	var g := Gradient.new()
	g.set_color(0, Mol.GAME_CENTER)
	g.add_point(0.55, Mol.GAME_MID)
	g.set_color(g.get_point_count() - 1, Mol.GAME_EDGE)
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.0)
	t.fill_to = Vector2(1.1, 1.0)
	t.width = 64
	t.height = 128
	return t


func _outline() -> StyleBoxFlat:
	return Mol.secondary()


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
	var mx := 44.0
	var top: Control = get_node("Top")
	top.position = Vector2(mx, 40)
	top.size = Vector2(vs.x - mx * 2, 96)
	var info: Control = get_node("Info")
	info.position = Vector2(mx, 132)
	info.size = Vector2(vs.x - mx * 2, 40)
	var goal: Control = get_node("Goal")
	goal.position = Vector2(mx, 190)
	goal.size = Vector2(vs.x - mx * 2, 60)
	var top_h := 270.0 if goal_row.visible else 200.0
	var bottom_h := 200.0 if items_box.visible else 40.0
	var avail := Vector2(vs.x - mx * 2 - 24, vs.y - top_h - bottom_h - 24)
	board_scale = minf(avail.x / GameCore.W, avail.y / GameCore.H)
	var bw := GameCore.W * board_scale
	var bh := GameCore.H * board_scale
	board_area.position = Vector2((vs.x - bw) / 2, top_h + maxf(0, (avail.y - bh) * 0.35))
	board_area.size = Vector2(bw, bh)
	core.scale = Vector2.ONE * board_scale
	items_box.position = Vector2(mx, vs.y - 180)
	items_box.size = Vector2(vs.x - mx * 2, 148)
	hint_lbl.position = board_area.position + Vector2(0, bh * 0.38)
	hint_lbl.size = Vector2(bw, 0)
	mission.position = Vector2(vs.x * 0.1, board_area.position.y + 120)
	mission.size = Vector2(vs.x * 0.8, 0)


## 점수·정보줄·목표 막대 갱신
func _paint_info() -> void:
	if core.mode != "stage":
		stage_lbl.text = "무한 모드"
		throws_lbl.text = "던지기 %d 남음 · 최고 %s" % [core.throws_left, GameCore.score_text(core.best)]
		goal_row.visible = false
	else:
		var i: int = core.stage_idx
		var st: Dictionary = core.stages[i]
		var jump := i >= 24 and (i + 1) % 5 == 0
		stage_lbl.text = "%d단계%s" % [i + 1, " · 고비" if jump else ""]
		throws_lbl.text = ("던지기 %d 남음" % core.throws_left) if int(st["throws"]) else "던지기 무제한"
		goal_row.visible = true
		match str(st["goal"]):
			"score":
				goal_name.text = "목표 점수"
				goal_val.text = "%s / %s" % [GameCore.score_text(core.score), GameCore.score_text(int(st["v"]))]
				goal_frac = float(core.score) / maxf(1.0, float(st["v"]))
			"tier":
				goal_name.text = "목표 · " + GameCore.num_text(int(st["t"])) + " 만들기"
				goal_val.text = "%s / %s" % [GameCore.num_text(maxi(0, core.board_tier)), GameCore.num_text(int(st["t"]))]
				goal_frac = pow(2.0, core.board_tier - int(st["t"]))
			"up":
				goal_name.text = "목표 · 대기줄 합치기"
				goal_val.text = "%d / %d" % [mini(core.up_count, int(st["v"])), int(st["v"])]
				goal_frac = float(core.up_count) / maxf(1.0, float(st["v"]))
			_:
				goal_name.text = "목표 · 대기줄에서 " + GameCore.num_text(int(st["t"]))
				goal_val.text = "%s / %s" % [GameCore.num_text(maxi(0, core.up_tier)), GameCore.num_text(int(st["t"]))]
				goal_frac = pow(2.0, core.up_tier - int(st["t"]))
		goal_bar.frac = goal_frac
		goal_bar.queue_redraw()
	_layout()


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
	_paint_info()
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
	_paint_info()
	var st: Dictionary = core.stages[i]
	var tips: Array = Save.d.get("tips_seen", [])
	if st.get("tip") and not tips.has(i):
		# 단계 안내문은 그 단계를 처음 할 때만
		hint_lbl.text = str(st["tip"]).replace("<br>", "\n")
		hint_lbl.visible = true
		tips.append(i)
		Save.d["tips_seen"] = tips
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
	labels[0].text = "STAGE %d%s" % [i + 1, " · 고비" if jump else ""]
	labels[0].add_theme_color_override("font_color", Mol.VIOLET if jump else Mol.MINT)
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
		item_badges[k].text = str(left)
		item_badges[k].visible = left > 0
		b.disabled = left <= 0 and not (k == "hammer" and core.hammer_armed) and not (k == "x2" and core.x2_armed)
		var on: bool = (k == "hammer" and core.hammer_armed) or (k == "x2" and core.x2_armed) or (k == "tilt" and core.tilt_t > 0)
		b.add_theme_stylebox_override("normal", Mol.primary() if on else Mol.secondary())
		var tl: Label = b.find_child("Text", true, false)
		if tl:
			tl.text = ("기울이기 %d초" % ceili(core.tilt_t)) if (k == "tilt" and core.tilt_t > 0) else ITEM_NAMES[k]
	var tilting: bool = core.tilt_t > 0
	tilt_l.visible = tilting
	tilt_r.visible = tilting
	if items_box.visible != any:
		items_box.visible = any
		_layout()


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

func _board_input(e: InputEvent) -> void:
	if input_guard > 0:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		var lp: Vector2 = e.position / board_scale
		if e.pressed:
			if core.over or core.clear_t > 0 or dragging:
				return
			if core.hammer_armed:
				if core.hammer_at(lp.x, lp.y):
					Save.spend_item("hammer", core.mode != "stage")
					_paint_items()
				return
			if core.grab(lp.x):
				dragging = true
				drag_start = e.position
		else:
			if dragging:
				dragging = false
				var used: String = core.release(true)
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
	if input_guard > 0:
		input_guard -= delta
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
	card_stars.visible = true
	var big := GameCore.num_text(int(st["t"])) if st["goal"] == "tier" else GameCore.score_text(core.score)
	var note := ("던지기 %d번 남기고 성공" % core.throws_left if throws else "점수 " + GameCore.score_text(core.score)) + extra
	_show_card("모든 단계를 깼어요!" if last else "클리어!", big, note,
		("첫 클리어 " if first else "다시 깨기 ") + "젤리 +%d" % j, "목록으로" if last else "다음 단계 · %d" % (i + 2), not last)
	card_act = "menu" if last else "next"
	card_retry.visible = true


func _show_card(title: String, big: String, note: String, reward: String, main: String, with_menu: bool) -> void:
	if core.mode == "stage":
		var i: int = core.stage_idx
		var jump := i >= 24 and (i + 1) % 5 == 0
		card_head.text = "STAGE %d%s" % [i + 1, " · 고비" if jump else ""]
	else:
		card_head.text = "ENDLESS"
	card_title.text = title
	card_big.text = big
	card_note.text = note
	card_stars.visible = card_stars.text != ""
	for c in card_chips.get_children():
		c.queue_free()
	if reward != "":
		var chip := PanelContainer.new()
		chip.add_theme_stylebox_override("panel", Mol.chip())
		var cl := Mol.lbl(reward, 26, Mol.JELLY, "b")
		chip.add_child(cl)
		card_chips.add_child(chip)
	card_chips.visible = reward != ""
	card_main.text = main
	card_retry.visible = card_act == "next" or main != "다시 하기"
	card_menu.visible = true
	card.visible = true
	var cp: Control = card.get_child(0)
	cp.reset_size()


func _on_card_main() -> void:
	match card_act:
		"next": start_stage(core.stage_idx + 1)
		"menu": show_menu()
		_: _restart_same()


# ───────────────────────── 단계 목록 ─────────────────────────

var open_chapter := -1


func _chapter_name(start: int) -> String:
	var bk := -1
	for k in SECTIONS:
		if int(k) <= start + 4 and int(k) > bk:
			bk = int(k)
	var n: String = SECTIONS.get(bk, "기본")
	var cut := n.find("· ")
	return n.substr(cut + 2) if cut >= 0 else n


func show_menu() -> void:
	core.over = true
	dragging = false
	core.sel = null
	for c in menu_grid_box.get_children():
		c.queue_free()
	var prog := int(Save.d["prog"])
	var total: int = core.stages.size()
	var cur := mini(prog, total - 1)
	if open_chapter < 0:
		open_chapter = cur / 10
	# 머리
	var head := HBoxContainer.new()
	menu_grid_box.add_child(head)
	var t := Mol.lbl("스테이지", 48, Mol.TEXT, "b")
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	head.add_child(Mol.lbl("%d" % prog, 40, Mol.TEXT, "num"))
	head.add_child(Mol.lbl(" / %d" % total, 40, Mol.TEXT_SUB, "num_m"))
	menu_grid_box.add_child(Mol.GradLine.new(Color(0.494, 0.941, 0.784, 0.35), true))
	# 이어하기 카드 (주 버튼)
	var st: Dictionary = core.stages[cur]
	var cont := Button.new()
	cont.focus_mode = Control.FOCUS_NONE
	for k in ["normal", "hover", "focus", "pressed", "hover_pressed"]:
		cont.add_theme_stylebox_override(k, Mol.primary(36))
	cont.custom_minimum_size.y = 192
	cont.pressed.connect(func(): start_stage(cur))
	menu_grid_box.add_child(cont)
	var ch := HBoxContainer.new()
	ch.set_anchors_preset(Control.PRESET_FULL_RECT)
	ch.offset_left = 36
	ch.offset_right = -36
	ch.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cont.add_child(ch)
	var cl := VBoxContainer.new()
	cl.alignment = BoxContainer.ALIGNMENT_CENTER
	cl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cl)
	cl.add_child(Mol.lbl("이어하기", 26, Color(Mol.AMBER, 0.8), "r"))
	cl.add_child(Mol.lbl(core.goal_text(st), 36, Mol.AMBER, "b"))
	var items_txt: Array = []
	var jump := cur >= 24 and (cur + 1) % 5 == 0
	if jump:
		items_txt.append("고비 판")
	for k in ["shake", "undo", "hammer", "tilt", "x2"]:
		if cur + 1 >= int(core.item_at.get(k, 9999)):
			items_txt.append(ITEM_NAMES[k])
	cl.add_child(Mol.lbl(" · ".join(items_txt) if items_txt.size() else ("던지기 %d번" % int(st["throws"]) if int(st["throws"]) else "던지기 무제한"), 24, Color(Mol.AMBER, 0.75), "r"))
	var cr := VBoxContainer.new()
	cr.alignment = BoxContainer.ALIGNMENT_CENTER
	cr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ch.add_child(cr)
	var sl := Mol.lbl("STAGE", 20, Color(Mol.AMBER, 0.8), "num_m")
	sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cr.add_child(sl)
	var nl := Mol.lbl(str(cur + 1), 76, Mol.AMBER, "num")
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cr.add_child(nl)
	# 다른 버튼
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	menu_grid_box.add_child(row)
	var eb := Mol.btn("무한 모드", "sec", 26)
	eb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eb.pressed.connect(start_endless)
	row.add_child(eb)
	if not core.blobs.is_empty() and not card.visible:
		var rb := Mol.btn("이 판 다시", "sec", 26)
		rb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rb.pressed.connect(_restart_same)
		row.add_child(rb)
	var hb := Mol.btn("집으로", "sec", 26)
	hb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.pressed.connect(go_home)
	row.add_child(hb)
	# 챕터 (10단계씩, 지금 챕터만 펼침) — 위에서부터 최근 챕터
	var stars: Dictionary = Save.d.get("stars", {})
	var chapters := ceili(total / 10.0)
	var top_ch := mini(chapters - 1, cur / 10 + 1)
	for ci in range(top_ch, -1, -1):
		var a := ci * 10
		var b := mini(total, a + 10)
		var done_n := clampi(prog - a, 0, b - a)
		var star_n := 0
		for k in range(a, b):
			star_n += int(stars.get(str(k), 0))
		var rowc := HBoxContainer.new()
		rowc.add_theme_constant_override("separation", 18)
		menu_grid_box.add_child(rowc)
		var dot := Control.new()
		dot.custom_minimum_size = Vector2(28, 0)
		var is_cur := ci == cur / 10
		var dot_col: Color = Mol.AMBER if is_cur else (Mol.LINE if done_n == b - a else Color(0.494, 0.941, 0.784, 0.25))
		dot.draw.connect(func():
			dot.draw_line(Vector2(14, 0), Vector2(14, dot.size.y), Color(0.494, 0.941, 0.784, 0.25), 2)
			dot.draw_circle(Vector2(14, 46), 12, dot_col)
			if is_cur:
				dot.draw_circle(Vector2(14, 46), 20, Color(Mol.AMBER, 0.2)))
		rowc.add_child(dot)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		panel.add_theme_stylebox_override("panel", Mol.sb(Color(0.03, 0.09, 0.1, 0.7), Color(0.494, 0.941, 0.784, 0.14), 36, Vector2(36, 28)))
		rowc.add_child(panel)
		var pv := VBoxContainer.new()
		pv.add_theme_constant_override("separation", 20)
		panel.add_child(pv)
		var hh := Button.new()
		hh.flat = true
		hh.focus_mode = Control.FOCUS_NONE
		hh.custom_minimum_size.y = 40
		var hrow := HBoxContainer.new()
		hrow.set_anchors_preset(Control.PRESET_FULL_RECT)
		hrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hh.add_child(hrow)
		var expanded := ci == open_chapter
		var tl := Mol.lbl("%d–%d · %s" % [a + 1, b, _chapter_name(a)], 30, Mol.TEXT if expanded else Mol.TEXT_SUB, "b")
		tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tl.clip_text = true
		hrow.add_child(tl)
		hrow.add_child(Mol.lbl("%d/%d ★%d%s" % [done_n, b - a, star_n, "" if expanded else " ›"], 26, Mol.TEXT_SUB, "num_m"))
		var cc := ci
		hh.pressed.connect(func():
			open_chapter = cc
			show_menu())
		pv.add_child(hh)
		if not expanded:
			continue
		var grid := GridContainer.new()
		grid.columns = 5
		grid.add_theme_constant_override("h_separation", 16)
		grid.add_theme_constant_override("v_separation", 16)
		pv.add_child(grid)
		for k in range(a, b):
			var done := k < prog
			var now := k == prog
			var boss := k >= 24 and (k + 1) % 5 == 0
			var bt := Button.new()
			bt.focus_mode = Control.FOCUS_NONE
			bt.text = str(k + 1)
			bt.add_theme_font_override("font", Mol.font("num"))
			bt.add_theme_font_size_override("font_size", 30)
			bt.custom_minimum_size = Vector2(0, 80)
			bt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			var bg := Color(1.0, 0.757, 0.443) if now else (Color(0.494, 0.941, 0.784, 0.12) if done else Color(0.02, 0.07, 0.08, 0.6))
			var ln := Mol.VIOLET if boss else Color(0.494, 0.941, 0.784, 0.18)
			var stl := Mol.sb(bg, ln, 24, Vector2(4, 4), 3 if boss else 2)
			if now:
				stl.shadow_color = Color(1.0, 0.757, 0.443, 0.3)
				stl.shadow_size = 14
			for sname in ["normal", "hover", "focus", "pressed", "hover_pressed", "disabled"]:
				bt.add_theme_stylebox_override(sname, stl)
			var fc := Color("#3a2408") if now else (Mol.MINT if done else Mol.TEXT_DIM)
			for cn in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color"]:
				bt.add_theme_color_override(cn, fc)
			bt.disabled = k > prog
			var idx: int = k
			bt.pressed.connect(func(): start_stage(idx))
			grid.add_child(bt)
		var nd := Mol.DashLine.new()
		pv.add_child(nd)
		var nx := ""
		for kk in ["shake", "undo", "hammer", "tilt", "x2"]:
			var at := int(core.item_at.get(kk, 9999))
			if at > b and nx == "":
				nx = kk
		var ft := HBoxContainer.new()
		pv.add_child(ft)
		var fl := Mol.lbl(("다음 아이템 · " + ITEM_NAMES[nx]) if nx != "" else "아이템을 모두 열었어요", 24, Mol.TEXT_SUB, "r")
		fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		ft.add_child(fl)
		if nx != "":
			ft.add_child(Mol.lbl("%d단계" % int(core.item_at[nx]), 24, Mol.TEXT, "num"))
	if OS.has_feature("web"):
		var ib := Mol.btn("원래 몰랑탑 기록 불러오기", "ghost", 22)
		ib.pressed.connect(_import_web)
		menu_grid_box.add_child(ib)
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
	p.add_theme_stylebox_override("panel", Mol.card(48))
	p.custom_minimum_size = Vector2(604, 0)
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	guide.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	var rib := Mol.lbl(str(g.get("rib", "")), 24, Mol.JELLY if not g.get("ob") else Mol.MINT, "b")
	v.add_child(rib)
	var tt := Mol.lbl(str(g.get("title", "")), 40, Mol.TEXT, "b")
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
	var ok := Mol.btn("해 볼게요!", "primary", 30)
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
