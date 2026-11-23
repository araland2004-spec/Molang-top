# 몰랑탑 (Godot 4.7)

소프트바디 2048 머지 + 블록 집꾸미기. 지금은 블록 땅 프로토타입이에요.

## 작업 일지
- [2026-11-23](docs/작업일지/2026-11-23.md)

## 폴더
- `scenes/main.tscn`, `scripts/main.gd` — 집 앞마당(웹 버전 크리스마스 마을 집 화면을 옮기는 중): 시간 따라 바뀌는 하늘·별·눈, 빨간 지붕 오두막 + 처마 전구 + 굴뚝 연기, 도트 블록 바닥, 몰랑이·햄스터, 웹 버전과 같은 도트 UI
- `scenes/seat.tscn`, `scripts/seat.gd` — 앉는 의자. **SitPoint** = 앉는 자리(파란 화살표 반대쪽을 봄), **ViewCamera** = 앉았을 때 고정되는 카메라
- `scenes/player.tscn` — 몰랑이(임시 상자 모델)
- `assets/blocks/` — 도트 블록 glb 18종 (바닥 편집용)
- `assets/house/cottage.glb` — 웹 버전 꼬마집 모델
- `data/mollang_data.json` — 웹 버전 스테이지 200개·확률·아이템 데이터 (숫자 게임 판 옮길 때 사용)

## 조작
- 바닥 탭 = 몰랑이가 걸어감(집은 돌아서), 의자 탭 = 가서 앉고 그 의자 카메라로 천천히 바뀜, 「일어나기」로 돌아옴
- 끌기 = 화면 이동, 두 손가락 = 확대·축소
- 「땅 편집」 = 바닥 칸을 고른 블록으로 바꾸기(톡 튀어올랐다 내려앉음), ↺↻ 회전은 편집 중에만

## 앉은 시점 카메라 맞추는 법
1. 고닷에서 `scenes/main.tscn` 열기 → `Seats/FrontChair` 선택 (의자 자체를 옮기려면 이 노드를 이동·회전)
2. 오른쪽 위 인스펙터 아래 **Editable Children** 켜기(또는 씬 트리에서 우클릭 → Editable Children)
3. `ViewCamera` 선택 → 3D 화면 위 **Preview** 체크 → 원하는 구도가 될 때까지 이동·회전, 인스펙터에서 FOV 조절
4. 저장하고 GitHub 에 올리면 자동 빌드. 의자를 더 두려면 `scenes/seat.tscn` 을 `Seats` 아래에 끌어다 놓기

## 확인하는 법
- **웹 링크:** main 에 올리면 자동으로 빌드돼서 `https://<아이디>.github.io/<저장소>/` 에 올라가요.
- **APK (베타 때):** GitHub → Actions → build → Run workflow → apk 켜기. 끝나면 Releases 의 `apk-latest` 에서 받아요.

## 컴퓨터에서 열기
Godot **4.7.2** 로 이 폴더(`project.godot`)를 열면 돼요. 버전을 맞춰야 자동 빌드와 똑같이 보여요.
