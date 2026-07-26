#!/bin/bash
# HangulSync 진단 스크립트 — 아이콘이 안 보일 때 실행하고 출력 전체를 복사해서 공유하세요.
APP="/Applications/HangulSync.app"

echo "===== 1. 앱 파일 확인"
ls -la "$APP/Contents/MacOS" 2>&1
echo
echo "===== 2. 리소스 (아이콘 파일들)"
ls "$APP/Contents/Resources" 2>&1
echo
echo "===== 3. 지금 실행 중인지"
pgrep -fl HangulSync && echo "→ 실행 중임 (메뉴바 오른쪽/노치 뒤를 확인하세요)" || echo "→ 실행 중 아님"
echo
echo "===== 4. 서명 상태"
codesign -dv "$APP" 2>&1
echo
echo "===== 5. Gatekeeper 격리 속성 (com.apple.quarantine이 있으면 차단 원인)"
xattr "$APP" 2>&1
echo
echo "===== 6. 최근 크래시 리포트"
shopt -s nullglob nocaseglob
crash_reports=("$HOME"/Library/Logs/DiagnosticReports/*hangul*)
shopt -u nullglob nocaseglob
if ((${#crash_reports[@]})); then
    stat -f '%m %N' "${crash_reports[@]}" |
        sort -rn |
        head -3 |
        cut -d' ' -f2-
else
    echo "없음"
fi
echo
echo "===== 7. 직접 실행 테스트"
echo "지금부터 앱을 터미널에서 직접 실행합니다."
echo "메뉴바 오른쪽에 아이콘(⇄한, 흐릴 수 있음)이 뜨는지 확인하세요."
echo "확인 후 Ctrl+C 로 종료하면 됩니다. 에러가 나면 그 메시지를 복사해주세요."
echo "-----------------------------------------------"
pkill -f HangulSync 2>/dev/null
sleep 1
"$APP/Contents/MacOS/HangulSync" 2>&1
