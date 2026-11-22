# 몰랑탑 (Godot 4.7)

소프트바디 2048 머지 + 블록 집꾸미기. 지금은 블록 땅 프로토타입이에요.

## 폴더
- `scenes/main.tscn`, `scripts/main.gd` — 블록 땅 (이동·확대, 편집 때 쌓기/지우기/회전)
- `assets/blocks/` — `D:\Molang\Modeling\Ground` 의 블록 glb 14종 (겹치는 것 정리됨)
- `assets/fonts/` — Noto Sans KR 굵게 (한글 2,350자만 담은 작은 버전)
- `data/mollang_data.json` — 웹 버전에서 옮겨 온 스테이지 200개·확률·아이템 데이터

## 확인하는 법
- **웹 링크:** main 에 올리면 자동으로 빌드돼서 `https://<아이디>.github.io/<저장소>/` 에 올라가요.
- **APK (베타 때):** GitHub → Actions → build → Run workflow → apk 켜기. 끝나면 Releases 의 `apk-latest` 에서 받아요.

## 컴퓨터에서 열기
Godot **4.7.2** 로 이 폴더(`project.godot`)를 열면 돼요. 버전을 맞춰야 자동 빌드와 똑같이 보여요.
