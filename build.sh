#!/bin/bash
# HangulSync 빌드 스크립트 — 실행하면 build/HangulSync.app 이 만들어집니다.
# 필요: Xcode Command Line Tools (xcode-select --install)
set -e
cd "$(dirname "$0")"

echo "▸ 빌드 중..."
swift build -c release

APP="build/HangulSync.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/HangulSync "$APP/Contents/MacOS/HangulSync"
cp Resources/Info.plist "$APP/Contents/Info.plist"

# 최신 git 태그가 있으면 앱 버전으로 주입 (업데이트 확인 기능이 비교에 사용)
GIT_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
if [ -n "$GIT_VERSION" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $GIT_VERSION" "$APP/Contents/Info.plist" 2>/dev/null || true
fi

# 앱 아이콘 (.icns 생성)
if [ -d "assets/AppIcon.iconset" ]; then
    mkdir -p "$APP/Contents/Resources"
    iconutil -c icns assets/AppIcon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
fi

# 메뉴바 템플릿 아이콘
if ls assets/menubar/*.png >/dev/null 2>&1; then
    mkdir -p "$APP/Contents/Resources"
    cp assets/menubar/*.png "$APP/Contents/Resources/"
fi

# ad-hoc 서명 (로컬 네트워크 권한·로그인 항목 등록에 필요)
codesign --force --sign - "$APP"

echo ""
echo "✅ 완료: $(pwd)/$APP"
echo ""
echo "설치하려면 (기존 앱 위에 겹쳐 복사 금지 — 서명이 깨집니다):"
echo "  ./install.sh"
