import Foundation

/// GitHub Releases에서 새 버전 확인 (6시간 주기, 실행 직후 1회)
/// 새 버전이 있으면 메뉴·설정 창에 업데이트 링크가 나타난다.
final class UpdateChecker {

    private static let releaseAPI = URL(string: "https://api.github.com/repos/catgarret/HangulSync/releases/latest")!
    static let releasesPage = URL(string: "https://github.com/catgarret/HangulSync/releases/latest")!

    private(set) var latestVersion: String? // 예: "1.0.2" (v 제거된 형태)
    private(set) var latestURL: URL?
    var onUpdateFound: (() -> Void)?
    private var timer: Timer?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return Self.version(latest, isNewerThan: currentVersion)
    }

    func start() {
        check()
        let t = Timer(timeInterval: 6 * 3600, repeats: true) { [weak self] _ in self?.check() }
        t.tolerance = 600 // OS가 타이머를 묶어 처리할 수 있게 여유 부여 (전력 절약)
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    private func check() {
        var req = URLRequest(url: Self.releaseAPI)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.cachePolicy = .reloadIgnoringLocalCacheData
        URLSession.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self, let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String else { return }
            guard SemanticVersion(tag) != nil else { return }
            DispatchQueue.main.async {
                self.latestVersion = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                self.latestURL = (obj["html_url"] as? String).flatMap(URL.init) ?? Self.releasesPage
                if self.updateAvailable { self.onUpdateFound?() }
            }
        }.resume()
    }

    /// 단순 semver 비교 (1.2.10 > 1.2.9)
    static func version(_ a: String, isNewerThan b: String) -> Bool {
        guard let av = SemanticVersion(a), let bv = SemanticVersion(b) else { return false }
        return av > bv
    }
}
