#!/bin/bash
# HangulSync 깃헙 배포 스크립트
#
# 사용법:
#   ./deploy.sh "커밋 메시지"              → 빌드 검증 + 커밋 + 푸시
#   ./deploy.sh "커밋 메시지" v1.0.1       → 위 과정 + 태그 + zip + GitHub Release
#
set -e
cd "$(dirname "$0")"

MSG="$1"
VERSION="$2"

if [ -z "$MSG" ]; then
    echo "❌ 커밋 메시지가 필요합니다."
    echo "   예) ./deploy.sh \"Fix reconnect bug\""
    echo "   예) ./deploy.sh \"Add feature\" v1.0.1   (릴리즈까지)"
    exit 1
fi

echo "▸ 1/4 빌드 검증..."
./build.sh > /dev/null
echo "  ✅ 빌드 성공"

echo "▸ 2/4 비공개 파일 확인..."
if git ls-files --error-unmatch DEV-NOTES.md >/dev/null 2>&1; then
    echo "  ❌ DEV-NOTES.md가 git에 추적되고 있습니다! 배포 중단."
    echo "     git rm --cached DEV-NOTES.md 실행 후 다시 시도하세요."
    exit 1
fi
echo "  ✅ DEV-NOTES.md 제외 확인"

echo "▸ 3/4 커밋 & 푸시..."
git add -A
if git diff --cached --quiet; then
    echo "  ℹ️ 변경 사항 없음 (커밋 생략)"
else
    git commit -m "$MSG"
fi
git push origin main
echo "  ✅ 푸시 완료"

if [ -z "$VERSION" ]; then
    echo "▸ 4/4 릴리즈 생략 (버전 인자 없음)"
    echo ""
    echo "✅ 배포 완료: https://github.com/catgarret/HangulSync"
    exit 0
fi

echo "▸ 4/4 릴리즈 $VERSION 생성..."
ZIP="build/HangulSync-${VERSION#v}.zip"
(cd build && ditto -c -k --sequesterRsrc --keepParent HangulSync.app "$(basename "$ZIP")")

git tag "$VERSION" 2>/dev/null || echo "  ℹ️ 태그 $VERSION 이미 존재"
git push origin "$VERSION"

if command -v gh >/dev/null 2>&1; then
    gh release create "$VERSION" "$ZIP" \
        --title "HangulSync ${VERSION#v}" \
        --notes "$MSG" \
        || gh release upload "$VERSION" "$ZIP" --clobber
    echo "  ✅ 릴리즈 완료"
else
    echo "  ⚠️ gh CLI가 없어 릴리즈는 수동으로:"
    echo "     https://github.com/catgarret/HangulSync/releases/new?tag=$VERSION"
    echo "     → $ZIP 파일을 첨부하세요."
fi

echo ""
echo "✅ 배포 완료: https://github.com/catgarret/HangulSync/releases"
