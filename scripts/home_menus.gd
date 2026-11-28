extends Node
## 홈 화면의 창들: 몰랑이 도감 · 랭킹(주간 리그·오늘의 판) · 퀘스트 · 음악 · 설정 · 말풍선 · 처음 안내

const GameCore := preload("res://scripts/game_core.gd")

var main: Node3D
var ui: Control
var sheet: Control
var dev_taps := 0
var rank_tab := "week"


func setup(m: Node3D, ui_root: Control) -> void:
	main = m
	ui = ui_root


# ───────────────────────── 창 공통 ─────────────────────────

func close_sheet() -> void:
	if sheet:
		main.hud_blocks.erase(sheet)
		sheet.queue_free()
		sheet = null
		main.refresh_ui()


func _sheet(title: String, width := 640) -> VBoxContainer:
	close_sheet()
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(dim)
	main.hud_blocks.append(dim)
	sheet = dim
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Mol.card(40))
	p.set_anchors_preset(Control.PRESET_CENTER)
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	p.grow_vertical = Control.GROW_DIRECTION_BOTH
	p.custom_minimum_size = Vector2(minf(width, ui.get_viewport_rect().size.x - 32), 0)
	dim.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	v.add_child(main._label(title, 32, main.C_INK, false))
	p.scale = Vector2.ONE * 0.94
	p.modulate.a = 0.0
	(func():
		p.pivot_offset = p.size / 2
		var tw := p.create_tween().set_parallel()
		tw.tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(p, "modulate:a", 1.0, 0.14)).call_deferred()
	return v


func _wrap(text: String, size := 20, col: Color = Mol.TEXT_SUB, width := 560) -> Label:
	var l: Label = main._label(text, size, col, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size.x = minf(width, ui.get_viewport_rect().size.x - 110)
	return l


func _close_btn(v: VBoxContainer) -> void:
	var cb: Button = main._px_btn("닫기", main.C_CREAM, 22)
	cb.pressed.connect(close_sheet)
	v.add_child(cb)


func _scroll(v: VBoxContainer, h: float) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = minf(h, ui.get_viewport_rect().size.y * 0.5)
	sc.scroll_deadzone = 12
	v.add_child(sc)
	var inner := VBoxContainer.new()
	inner.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_theme_constant_override("separation", 6)
	sc.add_child(inner)
	return inner


func notice(title: String, text: String, ok: String, cb: Callable) -> void:
	var v := _sheet(title, 600)
	v.add_child(_wrap(text, 22))
	var b: Button = main._px_btn(ok, main.C_YELLOW, 24)
	b.pressed.connect(func():
		close_sheet()
		cb.call())
	v.add_child(b)


func ask_name(title: String, def: String, cb: Callable) -> void:
	if OS.has_feature("web"):
		var r = JavaScriptBridge.eval("prompt(%s, %s)" % [JSON.stringify(title), JSON.stringify(def)])
		var nm := str(r).strip_edges() if r != null else ""
		cb.call(nm if nm != "" else def)
		return
	var v := _sheet(title, 600)
	var le := LineEdit.new()
	le.text = def
	le.max_length = 10
	le.add_theme_font_size_override("font_size", 26)
	v.add_child(le)
	var b: Button = main._px_btn("좋아요", main.C_YELLOW, 24)
	b.pressed.connect(func():
		var nm := le.text.strip_edges()
		close_sheet()
		cb.call(nm if nm != "" else def))
	v.add_child(b)


# ───────────────────────── 말풍선 ─────────────────────────

func say(lines: Array, done: Callable) -> void:
	close_sheet()
	var ov := Control.new()
	ov.set_anchors_preset(Control.PRESET_FULL_RECT)
	ov.mouse_filter = Control.MOUSE_FILTER_STOP
	ui.add_child(ov)
	main.hud_blocks.append(ov)
	sheet = ov
	for c in main.hud_groups:
		c.visible = false
	if main.empty_hint:
		main.empty_hint.visible = false
	var p := PanelContainer.new()
	var st := Mol.sb(Mol.PANEL_SOLID, Color(0.494, 0.941, 0.784, 0.22), 36, Vector2(26, 24))
	st.shadow_color = Color(0, 0, 0, 0.35)
	st.shadow_size = 24
	p.add_theme_stylebox_override("panel", st)
	var w := ui.get_viewport_rect().size.x
	p.anchor_left = 0.5 if w > 900 else 0.0
	p.anchor_right = 0.5 if w > 900 else 1.0
	p.offset_left = -380 if w > 900 else 16
	p.offset_right = 380 if w > 900 else -16
	p.anchor_top = 1.0
	p.anchor_bottom = 1.0
	p.offset_bottom = -40
	p.grow_vertical = Control.GROW_DIRECTION_BEGIN
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ov.add_child(p)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 20)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(hb)
	var av: Control = main.face(92)
	av.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	hb.add_child(av)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	v.add_child(Mol.lbl("몰랑이", 22, Mol.AMBER, "b"))
	var tl := Mol.lbl("", 27, Mol.TEXT, "m")
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(100, 110)
	tl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tl)
	var nx := Mol.lbl("눌러서 계속 ▸", 18, Mol.TEXT_DIM, "r")
	nx.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	nx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(nx)
	var blink := nx.create_tween().set_loops()
	blink.tween_property(nx, "modulate:a", 0.3, 0.6)
	blink.tween_property(nx, "modulate:a", 1.0, 0.6)
	var state := {"i": 0, "tw": null, "end": false}
	var show_line := func():
		tl.text = str(lines[state["i"]])
		tl.visible_ratio = 0.0
		var tw := tl.create_tween()
		tw.tween_property(tl, "visible_ratio", 1.0, tl.text.length() * 0.035)
		state["tw"] = tw
		main.synth_tone(620 + state["i"] * 40, 760 + state["i"] * 40, 0.06, 0.05)
	ov.gui_input.connect(func(e: InputEvent):
		# 터치·마우스가 둘 다 들어와서 마우스 버튼만 받아요 (한 번 누를 때 두 줄 넘어가던 것)
		var tap: bool = e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT
		if not tap or state["end"]:
			return
		if tl.visible_ratio < 1.0:
			if state["tw"]:
				(state["tw"] as Tween).kill()
			tl.visible_ratio = 1.0
			return
		state["i"] = int(state["i"]) + 1
		if int(state["i"]) >= lines.size():
			state["end"] = true
			if sheet == ov:
				close_sheet()
			done.call()
			return
		show_line.call())
	show_line.call()


# ───────────────────────── 처음 안내 ─────────────────────────
## 이름(랭킹에 보이는 이름) → 첫 퀘스트(스테이지 5단계)로. Save.d["onb"]: "" · name · done

func run_onboarding() -> bool:
	var ob := str(Save.d.get("onb", ""))
	if ob == "done":
		return false
	if ob != "" and ob != "name" and ob != "story":
		Save.d["onb"] = "done"       # 예전 안내(상자·꾸미기) 중이던 사람은 끝난 걸로
		Save.save()
		return false
	Save.d["onb"] = "name"
	Save.save()
	say(["안녕! 나는 몰랑이야.", "같은 숫자 몰랑이를 던져서 합치면 더 큰 몰랑이가 돼.", "새 숫자를 만들 때마다 친구들이 이 섬에 놀러 와!", "먼저 랭킹에 보일 이름을 지어 줄래?"], func():
		ask_name("내 이름 (랭킹에 보여요)", "몰랑", func(nm: String):
			Save.home()["name"] = nm.left(10)
			Save.d["onb"] = "done"
			Save.d["quest"] = 0
			Save.save()
			main.refresh_names()
			say(["「%s」, 반가워!" % Save.home()["name"],
				"섬을 손가락으로 밀면 빙글 돌고, 두 손가락으로 벌리면 커져.",
				"몰랑이를 누르면 좋아해!"], func(): quest_intro(0))))
	return true


# ───────────────────────── 퀘스트 ─────────────────────────

func quest_greet() -> bool:
	if str(Save.d.get("onb", "")) != "done" or not Save.quest_ready():
		return false
	say(["퀘스트를 깼어요! 「%s」" % Save.quest_cur()["t"], "퀘스트 창에서 보석을 받아요."], func(): open_quests())
	return true


func quest_intro(i: int) -> void:
	if i >= Save.QUESTS.size():
		say(["지금 준비된 퀘스트는 여기까지예요!", "오늘의 판과 주간 리그에서 순위를 올려 봐요."], func(): pass)
		return
	var q: Dictionary = Save.QUESTS[i]
	match str(q["kind"]):
		"prog":
			say(["퀘스트: %s!" % q["t"], "스테이지는 판마다 목표가 있는 퍼즐이에요.", "깨면 젤리와 무한 모드에서 쓸 아이템을 받아요."], func(): main._go_game("stage:%d" % mini(int(Save.d["prog"]), 196)))
		"endless":
			say(["이번엔 무한 모드예요!", "양쪽 반원이 다 눌리기 전까지 계속 점수를 쌓아요.",
				"무한 모드 이번 주 최고 점수로 「주간 리그」 순위가 정해져요."], func(): main._go_game("endless"))
		"daily":
			say(["오늘의 판은 하루에 딱 한 번!", "모두 같은 순서로 몰랑이가 나와서, 실력으로 겨뤄요.", "날마다 규칙이 바뀌어요. 랭킹에서 오늘 순위를 볼 수 있어요."], func(): main.open_daily_or_rank())
		"dex":
			say(["몰랑이 도감을 채워 봐요!", "처음 만든 숫자는 도감에 등록되고, 섬에 놀러 와요.", "큰 숫자일수록 젤리를 많이 줘요."], func(): open_dex())
		_:
			pass


func _after_claim(q: Dictionary) -> void:
	var lines: Array = ["보석 %d개를 받았어요!" % int(q.get("gem", 0))]
	if q["id"] == "stage5":
		lines.append_array(["보석은 스테이지 입장 횟수를 늘리는 데 써요.",
			"스테이지는 하루 %d번인데, 보석 %d개로 1번 더 들어갈 수 있어요." % [Save.STAGE_DAILY, Save.STAGE_ENTRY_GEM]])
	say(lines, func(): quest_intro(Save.quest_idx()))


func open_quests() -> void:
	var v := _sheet("퀘스트", 640)
	var gh := HBoxContainer.new()
	gh.add_theme_constant_override("separation", 10)
	v.add_child(gh)
	var gi := TextureRect.new()
	gi.texture = main.gem_icon()
	gi.custom_minimum_size = Vector2(36, 36)
	gi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	gi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	gh.add_child(gi)
	gh.add_child(Mol.lbl("보석 %d개 · 스테이지 입장 +1 (보석 %d개)" % [Save.gem(), Save.STAGE_ENTRY_GEM], 22, Mol.TEXT_SUB, "m"))
	var idx := Save.quest_idx()
	for i in Save.QUESTS.size():
		var q: Dictionary = Save.QUESTS[i]
		var done := i < idx
		var cur := i == idx
		if i > idx + 1:
			break
		if done and i < idx - 2:
			continue
		var p := PanelContainer.new()
		p.add_theme_stylebox_override("panel", Mol.sb(Color(0.494, 0.941, 0.784, 0.12) if cur else Color(0.02, 0.07, 0.08, 0.6), Mol.MINT if cur else Color(0.494, 0.941, 0.784, 0.14), 24, Vector2(22, 14), 3 if cur else 2))
		v.add_child(p)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		p.add_child(row)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(col)
		col.add_child(Mol.lbl(("✓ " if done else "") + str(q["t"]), 22, Mol.TEXT if cur else Mol.TEXT_DIM, "b" if cur else "m"))
		var rw := "보석 %d" % int(q.get("gem", 0))
		if cur:
			col.add_child(Mol.lbl("%d / %d · 보상 %s" % [mini(Save.quest_val(q), int(q["need"])), int(q["need"]), rw], 18, Mol.AMBER, "r"))
		elif not done:
			col.add_child(Mol.lbl("다음 퀘스트 · 보상 %s" % rw, 18, Mol.TEXT_DIM, "r"))
		if cur:
			var ready := Save.quest_ready()
			var b := Mol.btn("받기" if ready else "하러 가기", "primary" if ready else "sec", 22)
			b.custom_minimum_size = Vector2(150, 64)
			b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			b.pressed.connect(func():
				if Save.quest_ready():
					var got := Save.quest_claim()
					close_sheet()
					main.synth_tone(660, 1320, 0.12, 0.12)
					Save.buzz(30)
					_after_claim(got)
				else:
					close_sheet()
					quest_intro(Save.quest_idx()))
			row.add_child(b)
	if idx >= Save.QUESTS.size():
		v.add_child(_wrap("준비된 퀘스트를 모두 깼어요! 곧 새 퀘스트가 생겨요.", 20))
	_close_btn(v)


# ───────────────────────── 몰랑이 도감 ─────────────────────────

class DexCell extends Control:
	var t := 1
	var got := false
	var shiny := false
	var font: Font
	func _draw() -> void:
		var c := size / 2 + Vector2(0, -6)
		var rr := minf(size.x, size.y) * 0.36
		if got:
			if shiny:
				draw_circle(c, rr + 6, Color("#ffd84a"))
			draw_circle(c, rr, GameCore.tier_color(t))
			var txt := GameCore.num_text(t)
			var fs := int(rr * (0.7 if txt.length() <= 3 else 0.5))
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
			draw_string(font, c + Vector2(-w / 2, fs * 0.35), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("#2a2533"))
		else:
			draw_circle(c, rr, Color(0.1, 0.14, 0.16, 0.9))
			draw_arc(c, rr, 0, TAU, 40, Color(0.494, 0.941, 0.784, 0.25), 2.0)
			var fs2 := int(rr * 0.7)
			var w2 := font.get_string_size("?", HORIZONTAL_ALIGNMENT_CENTER, -1, fs2).x
			draw_string(font, c + Vector2(-w2 / 2, fs2 * 0.35), "?", HORIZONTAL_ALIGNMENT_LEFT, -1, fs2, Color(0.494, 0.941, 0.784, 0.45))


func open_dex() -> void:
	var v := _sheet("몰랑이 도감", 660)
	var total := Save.DEX_TO - Save.DEX_FROM + 1
	var sh := 0
	for k in Save.dex():
		if int(Save.dex()[k].get("s", 0)) > 0:
			sh += 1
	v.add_child(_wrap("모은 몰랑이 %d/%d · 반짝이 %d · 처음 만든 숫자는 섬에 놀러 와요" % [Save.dex_count(), total, sh], 20))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	v.add_child(grid)
	var font := load("res://assets/fonts/Poppins-Light.ttf") as Font
	var next_t := -1
	for t in range(Save.DEX_FROM, Save.DEX_TO + 1):
		var e: Dictionary = Save.dex().get(str(t), {})
		var got := int(e.get("n", 0)) > 0
		if not got and next_t < 0:
			next_t = t
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(140, 0)
		cell.add_theme_constant_override("separation", 0)
		var dc := DexCell.new()
		dc.t = t
		dc.got = got
		dc.shiny = int(e.get("s", 0)) > 0
		dc.font = font
		dc.custom_minimum_size = Vector2(130, 108)
		cell.add_child(dc)
		var sub := ("%d번%s" % [int(e["n"]), (" · ✦%d" % int(e["s"])) if int(e.get("s", 0)) > 0 else ""]) if got else ("젤리 +%d" % Save.dex_reward(t) if Save.dex_reward(t) > 0 else "???")
		var l := Mol.lbl(sub, 17, Mol.AMBER if (got and int(e.get("s", 0)) > 0) else (Mol.TEXT_SUB if got else Mol.TEXT_DIM), "m")
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(l)
		grid.add_child(cell)
	if next_t > 0:
		v.add_child(_wrap("다음 목표: %s 만들기 · 젤리 +%d" % [GameCore.num_text(next_t), Save.dex_reward(next_t)], 20, Mol.AMBER))
	v.add_child(_wrap("반짝이 몰랑이: 합칠 때 아주 가끔 금빛 몰랑이가 나와요. 반짝이끼리 합치면 더 잘 나와요.", 18, Mol.TEXT_DIM))
	_close_btn(v)


# ───────────────────────── 랭킹 ─────────────────────────

func open_rank(tab := "") -> void:
	if tab != "":
		rank_tab = tab
	var L = Save.league
	var v := _sheet("랭킹", 660)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	v.add_child(tabs)
	for td in [["week", "주간 리그"], ["daily", "오늘의 판"]]:
		var tb: Button = main._px_btn(td[1], main.C_YELLOW if rank_tab == td[0] else main.C_CREAM, 22)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var k: String = td[0]
		tb.pressed.connect(func(): open_rank(k))
		tabs.add_child(tb)
	if not L.online():
		v.add_child(_wrap("연습 리그 · 랭킹 서버를 연결하기 전이라 이 기기의 연습 상대와 겨뤄요", 17, Mol.TEXT_DIM))
	if rank_tab == "week":
		await L.refresh_week()
		if sheet == null or not is_instance_valid(v):
			return
		_week_view(v)
	else:
		await L.refresh_daily()
		if sheet == null or not is_instance_valid(v):
			return
		_daily_view(v)
	_close_btn(v)


func _tier_badge(t: int) -> Label:
	var L = Save.league
	var col := Color(L.TIER_COL[t])
	var b := Mol.lbl(" %s 리그 " % L.TIERS[t], 26, col, "b")
	b.add_theme_stylebox_override("normal", Mol.sb(Color(col, 0.14), Color(col, 0.6), 999, Vector2(18, 6)))
	b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	return b


func _week_view(v: VBoxContainer) -> void:
	var L = Save.league
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	v.add_child(head)
	head.add_child(_tier_badge(L.tier()))
	var lt := Mol.lbl("남은 시간 " + L.left_text(L.week_left_sec()), 20, Mol.TEXT_SUB, "m")
	lt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	head.add_child(lt)
	var rows: Array = L.board
	var z: Vector2i = L.zones(rows.size())
	var mr: int = L.my_rank()
	v.add_child(_wrap("무한 모드 이번 주 최고 점수로 겨뤄요 · 내 기록 %s%s\n%s" % [GameCore.score_text(L.my_best()), (" · %d등" % mr) if (mr > 0 and L.my_best() > 0) else "",
		("위 %d명 승급" % z.x if z.x > 0 else "맨 위 리그") + (" · 아래 %d명 강등" % z.y if z.y > 0 else "")], 19))
	var list := _scroll(v, 640)
	for i in rows.size():
		var r: Dictionary = rows[i]
		var zone := "up" if i < z.x else ("down" if (z.y > 0 and i >= rows.size() - z.y) else "")
		list.add_child(_rank_row(i + 1, str(r["name"]), int(r["score"]), bool(r["me"]), zone))
	var go: Button = main._px_btn("무한 모드로 기록 올리기", main.C_YELLOW, 24)
	go.pressed.connect(func():
		close_sheet()
		main._go_game("endless"))
	v.add_child(go)


func _daily_view(v: VBoxContainer) -> void:
	var L = Save.league
	var ru: Dictionary = L.rule()
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", Mol.sb(Color(1.0, 0.757, 0.443, 0.1), Color(1.0, 0.757, 0.443, 0.4), 24, Vector2(20, 14)))
	v.add_child(box)
	var bv := VBoxContainer.new()
	box.add_child(bv)
	bv.add_child(Mol.lbl("오늘의 규칙 · " + str(ru["n"]), 26, Mol.AMBER, "b"))
	var dl := Mol.lbl(str(ru["d"]), 20, Mol.TEXT, "r")
	dl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bv.add_child(dl)
	var stk: int = L.streak()
	bv.add_child(Mol.lbl(("오늘 기록 %s" % GameCore.score_text(L.today_score())) if L.played_today() else "아직 안 했어요 · 하루 한 번만 기록돼요", 20, Mol.TEXT_SUB, "m"))
	if stk > 0:
		bv.add_child(Mol.lbl("%d일 연속 · 7일마다 보석 30" % stk, 18, Mol.MINT, "m"))
	var list := _scroll(v, 560)
	var rows: Array = L.daily_board
	if rows.is_empty():
		list.add_child(_wrap("아직 아무도 안 했어요. 첫 번째가 되어 봐요!", 20))
	for i in rows.size():
		var r: Dictionary = rows[i]
		list.add_child(_rank_row(i + 1, str(r["name"]), int(r["score"]), bool(r["me"]), ""))
	var go: Button = main._px_btn("오늘의 판 도전" if not L.played_today() else "내일 또 만나요", main.C_YELLOW, 24)
	go.disabled = L.played_today()
	go.pressed.connect(func():
		close_sheet()
		main._go_game("daily"))
	v.add_child(go)


func _rank_row(n: int, nm: String, sc: int, me: bool, zone: String) -> Control:
	var p := PanelContainer.new()
	var bg := Color(0.02, 0.07, 0.08, 0.55)
	var ln := Color(0.494, 0.941, 0.784, 0.1)
	if zone == "up":
		bg = Color(0.494, 0.941, 0.784, 0.1)
	elif zone == "down":
		bg = Color(1.0, 0.45, 0.45, 0.1)
	if me:
		bg = Color(1.0, 0.757, 0.443, 0.2)
		ln = Mol.AMBER
	p.add_theme_stylebox_override("panel", Mol.sb(bg, ln, 18, Vector2(18, 8), 2 if me else 1))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var nl := Mol.lbl(str(n), 24, Mol.AMBER if n <= 3 else Mol.TEXT_SUB, "num")
	nl.custom_minimum_size.x = 54
	nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(nl)
	var name_l := Mol.lbl(nm + ("  (나)" if me else ""), 22, Mol.TEXT, "b" if me else "m")
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_l.clip_text = true
	row.add_child(name_l)
	var arrow := "▲ " if zone == "up" else ("▼ " if zone == "down" else "")
	var sl := Mol.lbl(arrow + (GameCore.score_text(sc) if sc > 0 else "-"), 22, Mol.MINT if zone == "up" else (Mol.ALERT if zone == "down" else Mol.TEXT), "num")
	row.add_child(sl)
	return p


## 지난주 리그 결과 (새 주 첫 방문 때 한 번)
func show_league_result() -> bool:
	var L = Save.league
	var s: Dictionary = L.st()
	if not (s.get("result") is Dictionary):
		return false
	var r: Dictionary = s["result"]
	s.erase("result")
	Save.save()
	var title := "지난주 리그 결과"
	var line := "%s 리그 %d등 (%d명 중) · 최고 %s" % [L.TIERS[int(r["from"])], int(r["rank"]), int(r["size"]), GameCore.score_text(int(r["best"]))]
	match str(r["moved"]):
		"up": line += "\n%s 리그로 승급했어요!" % L.TIERS[int(r["to"])]
		"down": line += "\n%s 리그로 내려갔어요. 이번 주에 다시 올라가 봐요!" % L.TIERS[int(r["to"])]
		_: line += "\n이번 주도 %s 리그예요." % L.TIERS[int(r["to"])]
	if int(r["gem"]) > 0:
		line += "\n보석 +%d" % int(r["gem"])
	notice(title, line, "좋아요", func(): main.refresh_ui())
	return true


# ───────────────────────── 음악 · 설정 ─────────────────────────

func open_music() -> void:
	var v := _sheet("음악", 600)
	var open: int = Bgm.tracks_open()
	var au: Button = main._px_btn(("✓ " if Bgm.auto() else "") + "시간대에 맞춰 듣기 (아침·낮·저녁·밤)", main.C_YELLOW if Bgm.auto() else main.C_CREAM, 20)
	au.pressed.connect(func():
		Bgm.set_auto(not Bgm.auto())
		open_music())
	v.add_child(au)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	var on_b: Button = main._px_btn("♪ 켜짐" if Bgm.is_on() else "♪ 꺼짐", main.C_YELLOW if Bgm.is_on() else main.C_CREAM, 22)
	on_b.pressed.connect(func():
		Bgm.toggle()
		open_music())
	top.add_child(on_b)
	var sq_b: Button = main._px_btn("차례대로 듣기" if Bgm.seq() else "한 곡만 듣기", main.C_CREAM, 22)
	sq_b.pressed.connect(func():
		Bgm.set_seq(not Bgm.seq())
		open_music())
	top.add_child(sq_b)
	v.add_child(top)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	for i in Bgm.NAMES.size():
		var idx: int = i
		var playing: bool = Bgm.is_on() and Bgm.cur == i
		var label: String = (("▶ " if playing else "%d. " % (i + 1)) + Bgm.NAMES[i]) if i < open else "잠김"
		var b: Button = main._px_btn(label, main.C_YELLOW if playing else main.C_CREAM, 20)
		b.custom_minimum_size = Vector2(270, 56)
		b.disabled = i >= open
		b.pressed.connect(func():
			Bgm.set_track(idx)
			open_music())
		grid.add_child(b)
	v.add_child(grid)
	_close_btn(v)


func open_settings() -> void:
	var v := _sheet("설정", 600)
	v.add_child(_wrap("깬 단계 %d/%d · 도감 %d/%d · 플레이 %d분" % [int(Save.d["prog"]), Save.data.get("stages", []).size(), Save.dex_count(), Save.DEX_TO - Save.DEX_FROM + 1, int(float(Save.d["play_sec"]) / 60)], 21))
	var nb: Button = main._px_btn("이름 바꾸기 (%s)" % Save.home()["name"], main.C_CREAM, 22)
	nb.pressed.connect(func():
		ask_name("내 이름 (랭킹에 보여요)", str(Save.home()["name"]), func(nm: String):
			Save.home()["name"] = nm.left(10)
			Save.save()
			main.refresh_names()
			open_settings()))
	v.add_child(nb)
	var mb: Button = main._px_btn("효과음 %s" % ("꺼짐" if Save.d.get("muted", false) else "켜짐"), main.C_CREAM, 22)
	mb.pressed.connect(func():
		Save.d["muted"] = not bool(Save.d.get("muted", false))
		Save.save()
		open_settings())
	v.add_child(mb)
	var vb: Button = main._px_btn("진동 %s" % ("켜짐" if bool(Save.d.get("vibe", true)) else "꺼짐"), main.C_CREAM, 22)
	vb.pressed.connect(func():
		Save.d["vibe"] = not bool(Save.d.get("vibe", true))
		Save.save()
		Save.buzz(20)
		open_settings())
	v.add_child(vb)
	var bb: Button = main._px_btn("배경 음악 %s" % ("켜짐" if Bgm.is_on() else "꺼짐"), main.C_CREAM, 22)
	bb.pressed.connect(func():
		Bgm.toggle()
		open_settings())
	v.add_child(bb)
	var pb: Button = main._px_btn("도트 화면 %s" % ("켜짐" if bool(Save.d.get("pixel_art", true)) else "꺼짐"), main.C_CREAM, 22)
	pb.pressed.connect(func():
		Save.d["pixel_art"] = not bool(Save.d.get("pixel_art", true))
		Save.save()
		main.apply_pixel_art()
		open_settings())
	v.add_child(pb)
	var rb: Button = main._px_btn("처음부터 새로 하기", main.C_CREAM, 22)
	rb.add_theme_color_override("font_color", Mol.ALERT)
	rb.pressed.connect(_ask_reset)
	v.add_child(rb)
	var ver: Button = main._px_btn("몰랑탑 베타 · 고닷 버전", main.C_CREAM, 18)
	ver.flat = true
	ver.pressed.connect(func():
		dev_taps += 1
		if dev_taps >= 7:
			dev_taps = 0
			open_dev())
	v.add_child(ver)
	_close_btn(v)


func _ask_reset() -> void:
	var v := _sheet("처음부터 새로 할까요?", 600)
	v.add_child(_wrap("깬 단계·별·젤리·보석·도감·랭킹 기록이 모두 지워지고 처음 안내부터 다시 시작해요. 되돌릴 수 없어요.", 21, Mol.ALERT))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var no: Button = main._px_btn("그만둘래요", main.C_CREAM, 22)
	no.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	no.pressed.connect(open_settings)
	row.add_child(no)
	var yes: Button = main._px_btn("모두 지우고 새로", main.C_YELLOW, 22)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	yes.pressed.connect(func():
		close_sheet()
		Save.reset_all()
		main.get_tree().change_scene_to_file("res://scenes/main.tscn"))
	row.add_child(yes)


## 숨은 개발자 메뉴 (버전 글씨 7번)
func open_dev() -> void:
	var v := _sheet("개발자 메뉴", 600)
	var acts := [
		["젤리 +99,999", func(): Save.d["jelly"] = int(Save.d["jelly"]) + 99999],
		["보석 +500", func(): Save.d["gem"] = Save.gem() + 500],
		["상점 아이템 각 20개", func():
			for k in ["undo", "hammer", "tilt", "x2", "shake"]:
				Save.d["bag"][k] = Save.bag_count(k) + 20],
		["스테이지 전부 열기", func(): Save.d["prog"] = Save.data.get("stages", []).size()],
		["도감 전부 + 반짝이", func():
			for t in range(Save.DEX_FROM, Save.DEX_TO + 1):
				Save.dex()[str(t)] = {"n": 1, "s": 1 if t % 3 == 0 else 0}],
		["오늘의 판 다시 하기", func(): Save.league.dst()["played"] = false],
	]
	for a in acts:
		var b: Button = main._px_btn(a[0], main.C_YELLOW, 20)
		var f: Callable = a[1]
		b.pressed.connect(func():
			f.call()
			Save.save()
			main.spawn_molangs()
			main.toast("했어요: " + str(a[0])))
		v.add_child(b)
	_close_btn(v)
