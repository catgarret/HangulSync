#!/bin/bash
# HangulSync 깃헙 배포 스크립트
#
# 사용법:
#   ./deploy.sh "커밋 메시지"           → 빌드 검증 + 커밋 + 푸시
#   ./deploy.sh "커밋 메시지" auto      → 위 과정 + 패치버전 자동 증가 태그 → GitHub Actions가 릴리즈 자동 생성
#   ./deploy.sh "커밋 메시지" v1.2.3    → 지정한 버전으로 태그 → 자동 릴리즈
#
# 릴리즈 zip 빌드와 릴리즈 노트 작성은 GitHub Actions(.github/workflows/release.yml)가
# 태그를 감지해서 자동으로 처리합니다.
set -e
cd "$(dirname "$0")"

MSG="$1"
VERSION="$2"

if [ -z "$MSG" ]; then
    echo "❌ 커밋 메시지가 필요합니다."
    echo "   예) ./deploy.sh \"Fix reconnect bug\""
    echo "   예) ./deploy.sh \"Add feature\" auto     (패치버전 자동 증가 + 릴리즈)"
    echo "   예) ./deploy.sh \"Add feature\" v1.1.0   (버전 지정 + 릴리즈)"
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

# 버전 자동 증가 (auto): 최신 태그의 패치 번호 +1
if [ "$VERSION" = "auto" ]; then
    LATEST=$(git describe --tags --abbrev=0 2>/dev/null || echo "v1.0.0")
    BASE="${LATEST#v}"
    MAJOR=$(echo "$BASE" | cut -d. -f1)
    MINOR=$(echo "$BASE" | cut -d. -f2)
    PATCH=$(echo "$BASE" | cut -d. -f3)
    # 태그가 하나도 없었으면 v1.0.0 그대로, 있으면 패치 +1
    if git rev-parse "$LATEST" >/dev/null 2>&1; then
        VERSION="v${MAJOR}.${MINOR}.$((PATCH + 1))"
    else
        VERSION="v1.0.0"
    fi
    echo "  ℹ️ 자동 버전: $VERSION (이전: $LATEST)"
fi

echo "▸ 4/4 태그 $VERSION 푸시 → GitHub Actions가 자동 릴리즈..."
git tag "$VERSION"
git push origin "$VERSION"

echo ""
echo "✅ 완료! 1~2분 뒤 자동으로 릴리즈가 등록됩니다 (zip + 자동 작성된 릴리즈 노트):"
echo "   https://github.com/catgarret/HangulSync/releases"
echo "   진행 상황: https://github.com/catgarret/HangulSync/actions"
