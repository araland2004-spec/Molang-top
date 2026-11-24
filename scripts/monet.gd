extends Node
## 광고·결제 (Monet): 게임 코드는 여기 함수만 불러요. 플러그인이 없는 곳(웹·PC)에선 테스트용 가짜로 동작해요.
## Save._ready() 에서 만들어 Save.monet 으로 써요 (project.godot 은 안 건드리려고 autoload 대신).
##
## 쓰는 곳
## · 보상형 광고: 스테이지 입장 +1 (하루 AD_STAGE_MAX 번) — game_screen 단계 목록
## · 전면 광고: 판이 끝날 때 INTER_EVERY 판에 한 번 — game_screen._on_finished (집·꾸미기 화면에는 안 넣어요)
## · 광고 제거(no_ads, 한 번 사면 끝): 전면 광고 없음 + 보상형 자리는 광고 없이 바로 보상
## · 시즌 팩(비소모성): 사면 묶인 꾸미기 아이템이 모은 장식(own)에 들어가요. 판매는 시즌 동안만, 산 건 계속 써요.
##
## 실제 출시 전 할 일 (3단계)
## 1. AdMob 플러그인(Poing Studios) + GodotGooglePlayBilling 플러그인을 넣고 Android 내보내기에서 gradle 빌드 켜기
## 2. 아래 AD_UNIT·상품 id 를 AdMob·플레이 콘솔에 등록한 값으로 바꾸고, _real_* 함수를 플러그인 API 로 채우기
## 3. TEST 를 false 로 (웹 빌드에선 광고·구매 버튼이 숨어요)
## 4. 구매는 3일 안에 확인(acknowledge)해야 환불되지 않아요 → _on_purchase 에서 바로 확인

const TEST := true                  # 플러그인 전: 웹·PC에서도 가짜 광고·가짜 구매로 흐름을 시험해요
const AD_STAGE_MAX := 3             # 하루에 광고로 늘릴 수 있는 스테이지 입장
const INTER_EVERY := 3              # 전면 광고: 판 N번에 한 번
const AD_UNIT := {"rewarded": "", "interstitial": ""}    # AdMob 광고 단위 id (등록 후 채우기)

const NO_ADS := "no_ads"
## 시즌 팩: 상품 id → 이름·설명·묶인 아이템 id(꾸미기 아이템)·판매 중인지·표시 가격(실제 가격은 플레이 콘솔 값을 받아서 씀)
const PACKS := {
	"pack_winter_2026": {"n": "겨울 시즌 팩", "d": "눈 내린 마을 장식 묶음 (에셋 준비 중)", "items": [], "on": true, "price": "₩2,900"},
}
const NO_ADS_PRICE := "₩3,900"

signal changed      # 구매·복원 뒤 (상점·목록 다시 그리기)

var _overlay: CanvasLayer


func iap() -> Dictionary:
	if not (Save.d.get("iap") is Dictionary):
		Save.d["iap"] = {}
	return Save.d["iap"]


func has_no_ads() -> bool:
	return bool(iap().get(NO_ADS, false))


func owns(pid: String) -> bool:
	return bool(iap().get(pid, false))


## 플러그인이 있는 진짜 기기인지 (지금은 플러그인을 아직 안 넣어서 늘 false)
func real() -> bool:
	return OS.has_feature("android") and Engine.has_singleton("GodotGooglePlayBilling")


## 광고·구매 버튼을 보여 줄지 (진짜 기기거나 테스트 중일 때만)
func available() -> bool:
	return real() or TEST


# ───────────────────────── 광고 ─────────────────────────

## 보상형: 다 보면 on_done(true). 광고 제거를 샀으면 광고 없이 바로 보상.
func rewarded(on_done: Callable) -> void:
	if has_no_ads():
		on_done.call(true)
		return
	if real():
		_real_rewarded(on_done)
	elif TEST:
		_fake_ad("보상형 광고 (테스트)", func(): on_done.call(true))
	else:
		on_done.call(false)


## 판이 끝날 때 불러요: INTER_EVERY 판에 한 번 전면 광고
func game_finished() -> void:
	Save.d["ad_games"] = int(Save.d.get("ad_games", 0)) + 1
	if has_no_ads() or int(Save.d["ad_games"]) % INTER_EVERY != 0:
		return
	if real():
		_real_interstitial()
	elif TEST:
		_fake_ad("전면 광고 (테스트)", func(): pass)


# ───────────────────────── 결제 ─────────────────────────

func buy(pid: String) -> void:
	if owns(pid):
		return
	if real():
		_real_buy(pid)
	elif TEST:
		_fake_ad("결제 창 (테스트) — %s" % title(pid), func(): _grant(pid))


## 구매 복원: 켤 때·상점에서. 폰을 바꾸거나 다시 깔아도 산 게 돌아오게 (진짜 기기에서만 의미 있음)
func restore() -> void:
	if real():
		_real_restore()


func title(pid: String) -> String:
	if pid == NO_ADS:
		return "광고 제거"
	return str(PACKS.get(pid, {}).get("n", pid))


func _grant(pid: String) -> void:
	iap()[pid] = true
	if PACKS.has(pid):
		var own: Dictionary = Save.home()["own"]
		for id in PACKS[pid]["items"]:
			own[id] = maxi(1, int(own.get(id, 0)))
	Save.save()
	changed.emit()


# ───────────────────────── 진짜 플러그인 (출시 전 채우기) ─────────────────────────
## TODO: AdMob 플러그인 — 보상형 광고 불러와서 보여 주고, 보상 신호에서 on_done(true), 닫히거나 실패하면 on_done(false)
func _real_rewarded(on_done: Callable) -> void:
	on_done.call(false)


## TODO: AdMob 플러그인 — 전면 광고 (미리 불러 두고, 준비됐을 때만 보여 주기)
func _real_interstitial() -> void:
	pass


## TODO: GodotGooglePlayBilling — purchase(pid) → 구매 신호에서 _on_purchase
func _real_buy(_pid: String) -> void:
	pass


## TODO: GodotGooglePlayBilling — query_purchases("inapp") → 받은 것마다 _on_purchase
func _real_restore() -> void:
	pass


## 구매가 들어오면: 확인(acknowledge)하고 지급. 3일 안에 확인 안 하면 자동 환불돼요.
func _on_purchase(pid: String) -> void:
	# TODO: billing.acknowledge_purchase(purchase_token)
	_grant(pid)


# ───────────────────────── 테스트용 가짜 화면 ─────────────────────────

func _fake_ad(text: String, done: Callable) -> void:
	if _overlay:
		return
	_overlay = CanvasLayer.new()
	_overlay.layer = 120
	add_child(_overlay)
	var bg := ColorRect.new()
	bg.color = Color(0.02, 0.05, 0.06, 0.92)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.add_child(bg)
	var l := Label.new()
	l.text = text + "\n\n잠시 뒤 닫혀요"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 34)
	bg.add_child(l)
	await get_tree().create_timer(1.6).timeout
	_overlay.queue_free()
	_overlay = null
	done.call()
