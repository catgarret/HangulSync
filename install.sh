#!/bin/bash
# HangulSync 빌드 + 설치 스크립트 (업데이트 시에도 이것만 실행하면 됨)
# 기존 앱을 지우고 새로 복사해야 서명이 깨지지 않습니다 (겹쳐 복사 금지!)
set -e
cd "$(dirname "$0")"

./build.sh

echo "▸ 기존 앱 종료·제거..."
pkill -f "HangulSync.app/Contents/MacOS/HangulSync" 2>/dev/null || true
sleep 1
rm -rf /Applications/HangulSync.app

echo "▸ 설치..."
cp -R build/HangulSync.app /Applications/
open /Applications/HangulSync.app

echo ""
echo "✅ 설치 완료 — 메뉴바 오른쪽을 확인하세요."
echo "   ℹ️ 기본 설정은 '원격 접속 중에만 동기화'라서 원격 세션이 없으면 아이콘이 흐리게 보입니다."
echo "   ℹ️ Dock 아이콘 표시/숨김은 메뉴바 아이콘 → 'Dock에 아이콘 표시'에서 변경."
