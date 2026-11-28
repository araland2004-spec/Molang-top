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
## 결제(광고 제거·시즌 팩)는 구현돼 있어요 — 플러그인만 넣으면 동작:
## 1. GodotGooglePlayBilling 3.x 를 addons/GodotGooglePlayBilling 에 넣고, Android 내보내기에서 gradle 빌드 + 플러그인 켜기
## 2. 플레이 콘솔 > 수익 창출 > 인앱 상품에 "no_ads" (일회성·비소모성) 등록, 가격 ₩4,900 → 가격은 콘솔 값이 상점에 그대로 떠요
## 3. 내부 테스트 트랙에 올리고 라이선스 테스터 계정으로 결제 시험 (테스트 카드라 돈이 안 나가요)
## 4. TEST 를 false 로 (웹 빌드에선 광고·구매 버튼이 숨어요)
## · 구매는 받자마자 확인(acknowledge)해요 (3일 안에 안 하면 자동 환불) · 켤 때마다 구매 내역을 다시 받아 복원해요
## 광고(AdMob)는 아직: _real_rewarded / _real_interstitial 를 AdMob 플러그인(Poing Studios)으로 채우기

const TEST := true                  # 플러그인 전: 웹·PC에서도 가짜 광고·가짜 구매로 흐름을 시험해요
const AD_STAGE_MAX := 3             # 하루에 광고로 늘릴 수 있는 스테이지 입장
const INTER_EVERY := 3              # 전면 광고: 판 N번에 한 번
const AD_UNIT := {"rewarded": "", "interstitial": ""}    # AdMob 광고 단위 id (등록 후 채우기)

const NO_ADS := "no_ads"
## 시즌 팩: 상품 id → 이름·설명·묶인 아이템 id(꾸미기 아이템)·판매 중인지·표시 가격(실제 가격은 플레이 콘솔 값을 받아서 씀)
const PACKS := {
	"pack_winter_2026": {"n": "겨울 시즌 팩", "d": "눈 내린 마을 장식 묶음 (에셋 준비 중)", "items": [], "on": true, "price": "₩2,900"},
}
const NO_ADS_PRICE := "₩4,900"     # 표시용 기본값. 실제 기기에선 플레이 콘솔에 등록한 가격(현지 통화)을 받아서 보여 줘요

signal changed      # 구매·복원 뒤 (상점·목록 다시 그리기)
signal notice(text: String)     # 결제 결과 안내 (대기 중·실패 등) → main 이 토스트로 보여 줘요

var _overlay: CanvasLayer
var _bc: Object             # 결제 클라이언트 (BillingClient.gd 래퍼 또는 플러그인 싱글턴)
var _ready_bc := false
var _prices := {}           # 상품 id → 플레이에서 받은 표시 가격 ("₩4,900")
var _want_restore := false


func iap() -> Dictionary:
	if not (Save.d.get("iap") is Dictionary):
		Save.d["iap"] = {}
	return Save.d["iap"]


func has_no_ads() -> bool:
	return bool(iap().get(NO_ADS, false))


func owns(pid: String) -> bool:
	return bool(iap().get(pid, false))


## 플러그인이 있는 진짜 기기인지 (안드로이드 + GodotGooglePlayBilling 플러그인)
func real() -> bool:
	return OS.has_feature("android") and (Engine.has_singleton(BILLING_SINGLETON) or ResourceLoader.exists(BILLING_WRAPPER))


## 상점에 보여 줄 가격: 플레이에서 받은 값이 있으면 그걸, 없으면 기본값
func price(pid: String) -> String:
	if _prices.has(pid):
		return str(_prices[pid])
	if pid == NO_ADS:
		return NO_ADS_PRICE
	return str(PACKS.get(pid, {}).get("price", ""))


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


func _real_buy(pid: String) -> void:
	if not _ensure_bc():
		notice.emit("결제를 준비하지 못했어요. 잠시 뒤 다시 해 주세요")
		return
	if not _ready_bc:
		notice.emit("스토어에 연결하는 중이에요. 잠시 뒤 다시 눌러 주세요")
		_bc_call(["start_connection", "startConnection"], [])
		return
	if _bc.has_method("purchase"):
		var r = _bc.callv("purchase", [pid, false]) if _arg_count("purchase") >= 2 else _bc.callv("purchase", [pid])
		if r is Dictionary and int(r.get("response_code", r.get("status", 0))) != 0:
			notice.emit("결제 창을 열지 못했어요")


func _real_restore() -> void:
	if not _ensure_bc():
		return
	if _ready_bc:
		_bc_call(["query_purchases", "queryPurchases"], ["inapp"])
	else:
		_want_restore = true


## 구매가 들어오면: 확인(acknowledge)하고 지급. 3일 안에 확인 안 하면 자동 환불돼요.
func _on_purchase(p: Dictionary) -> void:
	var ids: Array = p.get("product_ids", p.get("products", []))
	if ids.is_empty() and p.has("sku"):
		ids = [p["sku"]]
	var state := int(p.get("purchase_state", p.get("purchaseState", 1)))
	if state == 2:          # PENDING: 편의점 결제 등 — 돈이 들어오면 다시 알려 줘요
		notice.emit("결제가 확인되면 바로 지급돼요")
		return
	if state != 1:
		return
	var token := str(p.get("purchase_token", p.get("purchaseToken", "")))
	if not bool(p.get("is_acknowledged", p.get("isAcknowledged", false))) and token != "":
		_bc_call(["acknowledge_purchase", "acknowledgePurchase"], [token])
	for id in ids:
		if str(id) == NO_ADS or PACKS.has(str(id)):
			if not owns(str(id)):
				_grant(str(id))
				notice.emit("%s 구매 완료! 고마워요" % title(str(id)))


# 결제 클라이언트 준비: 애드온의 BillingClient.gd(플러그인 3.x, Godot 4.2+)가 있으면 그걸, 없으면 싱글턴을 바로 써요
const BILLING_SINGLETON := "GodotGooglePlayBilling"
const BILLING_WRAPPER := "res://addons/GodotGooglePlayBilling/BillingClient.gd"

func _ensure_bc() -> bool:
	if _bc:
		return true
	if not real():
		return false
	if ResourceLoader.exists(BILLING_WRAPPER):
		_bc = load(BILLING_WRAPPER).new()
		if _bc is Node:
			add_child(_bc)
	elif Engine.has_singleton(BILLING_SINGLETON):
		_bc = Engine.get_singleton(BILLING_SINGLETON)
	if not _bc:
		return false
	_sig(["connected"], _on_connected)
	_sig(["disconnected"], func(): _ready_bc = false)
	_sig(["connect_error"], func(_a = null, _b = null): _ready_bc = false)
	_sig(["on_purchase_updated", "purchases_updated"], _on_purchases_updated)
	_sig(["query_purchases_response"], _on_purchases_updated)
	_sig(["query_product_details_response", "product_details_query_completed", "sku_details_query_completed"], _on_details)
	_sig(["purchase_error"], func(code = 0, _msg = ""): _purchase_fail(int(code)))
	_bc_call(["start_connection", "startConnection"], [])
	return true


func _on_connected() -> void:
	_ready_bc = true
	var ids: Array = [NO_ADS]
	ids.append_array(PACKS.keys())
	_bc_call(["query_product_details", "queryProductDetails", "querySkuDetails"], [ids, "inapp"])
	_bc_call(["query_purchases", "queryPurchases"], ["inapp"])      # 켤 때마다 복원 (폰 바꿔도 돌아오게)
	_want_restore = false


## 구매·복원 응답: 3.x 는 {response_code, purchases:[...]}, 1.x 는 purchases 배열 그대로
func _on_purchases_updated(r = null) -> void:
	var list: Array = []
	if r is Dictionary:
		var code := int(r.get("response_code", r.get("status", 0)))
		if code != 0:
			_purchase_fail(code)
			return
		list = r.get("purchases", [])
	elif r is Array:
		list = r
	for p in list:
		if p is Dictionary:
			_on_purchase(p)


func _purchase_fail(code: int) -> void:
	match code:
		1: pass                                             # USER_CANCELED: 그냥 닫기
		7: _bc_call(["query_purchases", "queryPurchases"], ["inapp"])     # ITEM_ALREADY_OWNED: 복원
		_: notice.emit("결제에 실패했어요 (코드 %d)" % code)


## 상품 정보: 플레이 콘솔 가격을 받아 상점에 그대로 보여 줘요
func _on_details(r = null) -> void:
	var list: Array = []
	if r is Dictionary:
		list = r.get("product_details", r.get("details", []))
	elif r is Array:
		list = r
	for d in list:
		if not (d is Dictionary):
			continue
		var id := str(d.get("product_id", d.get("sku", "")))
		var pr := ""
		var off = d.get("one_time_purchase_offer_details", null)
		if off is Dictionary:
			pr = str(off.get("formatted_price", ""))
		if pr == "":
			pr = str(d.get("price", ""))
		if id != "" and pr != "":
			_prices[id] = pr
	changed.emit()


func _sig(names: Array, cb: Callable) -> void:
	for n in names:
		if _bc.has_signal(n):
			_bc.connect(n, cb)
			return


func _bc_call(names: Array, args: Array):
	for n in names:
		if _bc and _bc.has_method(n):
			return _bc.callv(n, args)
	return null


func _arg_count(m: String) -> int:
	if _bc is Object and _bc.get_script():
		for d in _bc.get_method_list():
			if d["name"] == m:
				return (d["args"] as Array).size()
	return 2


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
