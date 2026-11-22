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


func _ready() -> void:
	font_num = load("res://assets/fonts/Poppins-Light.ttf")
	font_txt = load("res://assets/fonts/NotoSansKR-Light-sub.otf")
	font_bold = load("res://assets/fonts/NotoSansKR-Bold-sub.otf")
	var bg := ColorRect.new()
	bg.color = PAGE
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
	core.score_changed.connect(func(s): score_lbl.text = GameCore.score_text(s))
	core.info_changed.connect(func(): info_lbl.text = core.info_text())
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


# ───────────────────────── UI 만들기 ─────────────────────────

func _style(bg: Color, radius := 12) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.set_corner_radius_all(radius)
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
	b.add_theme_stylebox_override("normal", _style(bg))
	b.add_theme_stylebox_override("hover", _style(bg))
	b.add_theme_stylebox_override("focus", _style(bg))
	b.add_theme_stylebox_override("pressed", _style(bg.lightened(0.12)))
	b.add_theme_stylebox_override("disabled", _style(bg.darkened(0.3)))
	return b


func _lbl(text: String, size: int, col := MILK, font: Font = null) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font if font else font_txt)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	return l


func _build_ui() -> void:
	# 위: 점수·안내·버튼
	var top := HBoxContainer.new()
	top.name = "Top"
	top.position = Vector2(24, 24)
	top.add_theme_constant_override("separation", 10)
	add_child(top)
	var sv := VBoxContainer.new()
	sv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sv.add_theme_constant_override("separation", -6)
	top.add_child(sv)
	score_lbl = _lbl("0", 64, MILK, font_num)
	sv.add_child(score_lbl)
	info_lbl = _lbl("", 22, MILK)
	sv.add_child(info_lbl)
	var bb := HBoxContainer.new()
	bb.add_theme_constant_override("separation", 8)
	top.add_child(bb)
	mute_btn = _btn("소리 끔" if synth.muted else "소리", BTN, MILK, 22)
	mute_btn.pressed.connect(func():
		synth.muted = not synth.muted
		Save.d["muted"] = synth.muted
		Save.save()
		mute_btn.text = "소리 끔" if synth.muted else "소리")
	bb.add_child(mute_btn)
	var mb := _btn("목록", BTN, MILK, 22)
	mb.pressed.connect(func():
		persist()
		show_menu())
	bb.add_child(mb)
	restart_btn = _btn("새 판", BTN, MILK, 22)
	restart_btn.pressed.connect(_on_restart)
	bb.add_child(restart_btn)
	var hb := _btn("집", BTN, MILK, 22)
	hb.pressed.connect(go_home)
	bb.add_child(hb)

	# 판
	board_area = Control.new()
	board_area.mouse_filter = Control.MOUSE_FILTER_STOP
	board_area.gui_input.connect(_board_input)
	add_child(board_area)
	board_area.add_child(core)

	# 아래: 아이템
	items_box = HBoxContainer.new()
	items_box.add_theme_constant_override("separation", 10)
	add_child(items_box)
	tilt_l = _btn("◀", BTN, MILK, 28)
	tilt_l.button_down.connect(func(): core.tilt_btn = -1)
	tilt_l.button_up.connect(func(): core.tilt_btn = 0)
	items_box.add_child(tilt_l)
	for k in ["shake", "undo", "hammer", "tilt", "x2"]:
		var b := _btn(ITEM_NAMES[k], BTN2, MILK, 22)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var kk: String = k
		b.pressed.connect(func(): _use_item(kk))
		items_box.add_child(b)
		item_btns[k] = b
	tilt_r = _btn("▶", BTN, MILK, 28)
	tilt_r.button_down.connect(func(): core.tilt_btn = 1)
	tilt_r.button_up.connect(func(): core.tilt_btn = 0)
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
	cp.add_theme_stylebox_override("panel", _style(PAGE, 26))
	cp.custom_minimum_size = Vector2(560, 0)
	cp.set_anchors_preset(Control.PRESET_CENTER)
	cp.grow_horizontal = Control.GROW_DIRECTION_BOTH
	cp.grow_vertical = Control.GROW_DIRECTION_BOTH
	card.add_child(cp)
	var cv := VBoxContainer.new()
	cv.add_theme_constant_override("separation", 14)
	cp.add_child(cv)
	card_title = _lbl("", 36)
	card_stars = _lbl("", 40, Color("#ffd45c"))
	card_big = _lbl("", 84, MILK, font_num)
	card_note = _lbl("", 24, SOFT)
	card_reward = _lbl("", 28, Color("#ff8fb1"), font_bold)
	for l in [card_title, card_stars, card_big, card_note, card_reward]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size.x = 520
		cv.add_child(l)
	card_main = _btn("다시 하기", MILK, INK, 30)
	card_main.custom_minimum_size.y = 92
	card_main.pressed.connect(_on_card_main)
	cv.add_child(card_main)
	card_menu = _btn("단계 목록", PAGE, MILK, 26)
	card_menu.add_theme_stylebox_override("normal", _outline())
	card_menu.pressed.connect(show_menu)
	cv.add_child(card_menu)
	var ch := _btn("집으로", PAGE, MILK, 26)
	ch.add_theme_stylebox_override("normal", _outline())
	ch.pressed.connect(go_home)
	cv.add_child(ch)

	# 단계 목록
	menu = _overlay(Color(0.16, 0.16, 0.17, 0.97))
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
	var top: Control = get_node("Top")
	top.size = Vector2(vs.x - 48, 0)
	top.position = Vector2(24, 24)
	var top_h := 170.0
	var bottom_h := 120.0
	var avail := Vector2(vs.x - 48, vs.y - top_h - bottom_h - 30)
	board_scale = minf(avail.x / GameCore.W, avail.y / GameCore.H)
	var bw := GameCore.W * board_scale
	var bh := GameCore.H * board_scale
	board_area.position = Vector2((vs.x - bw) / 2, top_h + (avail.y - bh) / 2)
	board_area.size = Vector2(bw, bh)
	core.scale = Vector2.ONE * board_scale
	items_box.position = Vector2(24, vs.y - bottom_h + 10)
	items_box.size = Vector2(vs.x - 48, 90)
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
		b.text = "%s %d" % [ITEM_NAMES[k], left]
		b.disabled = left <= 0 and not (k == "hammer" and core.hammer_armed) and not (k == "x2" and core.x2_armed)
		var on: bool = (k == "hammer" and core.hammer_armed) or (k == "x2" and core.x2_armed)
		b.add_theme_stylebox_override("normal", _style(Color("#e2574c") if on else BTN2))
	var tilting: bool = core.tilt_t > 0
	tilt_l.visible = tilting
	tilt_r.visible = tilting
	if tilting:
		item_btns["tilt"].text = "기울이기 %d초" % ceili(core.tilt_t)
	items_box.visible = any


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
	_show_card("모든 단계를 깼어요" if last else "%d단계 클리어" % (i + 1), big, note,
		("첫 클리어 보상" if first else "다시 깨기 보상") + " 젤리 +%d" % j, "목록으로" if last else "다음 단계", not last)
	card_act = "menu" if last else "next"


func _show_card(title: String, big: String, note: String, reward: String, main: String, with_menu: bool) -> void:
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
	var head := HBoxContainer.new()
	menu_grid_box.add_child(head)
	var t := _lbl("스테이지 · 베타 200단계", 34)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var eb := _btn("무한 모드", MILK, INK, 24)
	eb.pressed.connect(start_endless)
	head.add_child(eb)
	var hb := _btn("집으로", BTN, MILK, 24)
	hb.pressed.connect(go_home)
	head.add_child(hb)
	if OS.has_feature("web"):
		var ib := _btn("원래 몰랑탑 기록 불러오기", BTN, SOFT, 20)
		ib.pressed.connect(_import_web)
		menu_grid_box.add_child(ib)
	var prog := int(Save.d["prog"])
	var grid: GridContainer = null
	for i in core.stages.size():
		if SECTIONS.has(i):
			var s := _lbl(SECTIONS[i], 20, SOFT)
			menu_grid_box.add_child(s)
			grid = GridContainer.new()
			grid.columns = 4
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 10)
			grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			menu_grid_box.add_child(grid)
		var st: Dictionary = core.stages[i]
		var done := i < prog
		var jump := i >= 24 and (i + 1) % 5 == 0
		var bg := Color("#2e4a35") if done else (Color("#4a3540") if jump else BTN)
		var b := _btn("%d\n%s" % [i + 1, "완료" if done else core.goal_text(st)], bg, MILK, 20)
		b.custom_minimum_size = Vector2(0, 120)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.disabled = i > prog
		var idx: int = i
		b.pressed.connect(func(): start_stage(idx))
		grid.add_child(b)
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
