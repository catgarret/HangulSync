import Foundation
import Carbon

/// macOS 텍스트 입력 소스(한/영) 조회·변경 유틸리티
enum InputSourceManager {

    struct State {
        let id: String
        let isKorean: Bool
    }

    /// 현재 선택된 키보드 입력 소스
    static func current() -> State? {
        guard let src = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else { return nil }
        guard let id = stringProperty(src, kTISPropertyInputSourceID) else { return nil }
        return State(id: id, isKorean: isKorean(src))
    }

    /// 원격에서 받은 상태를 이 맥에 적용.
    /// 동일 ID가 있으면 그대로 선택, 없으면(예: 구름입력기 vs 기본 두벌식) 한/영 언어 기준으로 폴백.
    @discardableResult
    static func apply(id: String, isKorean korean: Bool) -> Bool {
        let sources = selectableKeyboardSources()

        if let exact = sources.first(where: { stringProperty($0, kTISPropertyInputSourceID) == id }) {
            return select(exact)
        }
        if korean {
            if let ko = sources.first(where: { isKorean($0) }) { return select(ko) }
        } else {
            // 영문은 ABC 우선, 없으면 비한국어 아무 레이아웃
            if let abc = sources.first(where: { stringProperty($0, kTISPropertyInputSourceID) == "com.apple.keylayout.ABC" }) {
                return select(abc)
            }
            if let en = sources.first(where: { !isKorean($0) }) { return select(en) }
        }
        return false
    }

    // MARK: - Private

    private static func select(_ src: TISInputSource) -> Bool {
        TISSelectInputSource(src) == noErr
    }

    /// 현재 활성화(사용자 목록에 등록)된 선택 가능한 키보드 입력 소스들
    private static func selectableKeyboardSources() -> [TISInputSource] {
        guard let cfList = TISCreateInputSourceList(nil, false)?.takeRetainedValue() else { return [] }
        let nsList = cfList as NSArray
        var result: [TISInputSource] = []
        for item in nsList {
            let src = item as! TISInputSource

            if let capPtr = TISGetInputSourceProperty(src, kTISPropertyInputSourceIsSelectCapable) {
                let capable = Unmanaged<CFBoolean>.fromOpaque(capPtr).takeUnretainedValue()
                if !CFBooleanGetValue(capable) { continue }
            } else {
                continue
            }
            guard let category = stringProperty(src, kTISPropertyInputSourceCategory),
                  category == (kTISCategoryKeyboardInputSource as String) else { continue }
            result.append(src)
        }
        return result
    }

    private static func isKorean(_ src: TISInputSource) -> Bool {
        guard let ptr = TISGetInputSourceProperty(src, kTISPropertyInputSourceLanguages) else { return false }
        let langs = Unmanaged<CFArray>.fromOpaque(ptr).takeUnretainedValue() as NSArray
        for lang in langs {
            if let s = lang as? String, s.hasPrefix("ko") { return true }
        }
        // 구름입력기 등 언어 메타데이터가 없는 경우 ID로 추정
        if let id = stringProperty(src, kTISPropertyInputSourceID)?.lowercased() {
            return id.contains("korean") || id.contains("hangul") || id.contains("gureum")
        }
        return false
    }

    private static func stringProperty(_ src: TISInputSource, _ key: CFString) -> String? {
        guard let ptr = TISGetInputSourceProperty(src, key) else { return nil }
        return Unmanaged<CFString>.fromOpaque(ptr).takeUnretainedValue() as String
    }
}
