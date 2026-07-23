import Foundation

/// 시스템 언어에 따른 UI 문자열 (ko, en, ja, zh-Hans, zh-Hant, th, ru, it)
enum L10n {
    enum Key: String {
        case connectedMacs, pauseSync, resumeSync, launchAtLogin, quit
        case loginErrorTitle, loginErrorBody, onlyDuringRemote, showInDock
    }

    private static let lang: String = {
        for preferred in Locale.preferredLanguages {
            let p = preferred.lowercased()
            if p.hasPrefix("ko") { return "ko" }
            if p.hasPrefix("ja") { return "ja" }
            if p.hasPrefix("zh") {
                if p.contains("hant") || p.contains("tw") || p.contains("hk") || p.contains("mo") {
                    return "zh-Hant"
                }
                return "zh-Hans"
            }
            if p.hasPrefix("th") { return "th" }
            if p.hasPrefix("ru") { return "ru" }
            if p.hasPrefix("it") { return "it" }
            if p.hasPrefix("en") { return "en" }
        }
        return "en"
    }()

    static func t(_ key: Key) -> String {
        table[lang]?[key] ?? table["en"]![key]!
    }

    static func connectedMacs(_ count: Int) -> String {
        String(format: t(.connectedMacs), count)
    }

    private static let table: [String: [Key: String]] = [
        "en": [
            .showInDock: "Show Icon in Dock",
            .onlyDuringRemote: "Sync Only During Remote Sessions",
            .connectedMacs: "Connected Macs: %d",
            .pauseSync: "Pause Syncing",
            .resumeSync: "Resume Syncing",
            .launchAtLogin: "Launch at Login",
            .quit: "Quit",
            .loginErrorTitle: "Failed to enable Launch at Login",
            .loginErrorBody: "Move the app to the /Applications folder and try again.",
        ],
        "ko": [
            .showInDock: "Dock에 아이콘 표시",
            .onlyDuringRemote: "원격 접속 중에만 동기화",
            .connectedMacs: "연결된 Mac: %d대",
            .pauseSync: "동기화 일시정지",
            .resumeSync: "동기화 재개",
            .launchAtLogin: "로그인 시 자동 실행",
            .quit: "종료",
            .loginErrorTitle: "자동 실행 설정 실패",
            .loginErrorBody: "앱을 /Applications 폴더로 옮긴 뒤 다시 시도해 주세요.",
        ],
        "ja": [
            .showInDock: "Dockにアイコンを表示",
            .onlyDuringRemote: "リモート接続中のみ同期",
            .connectedMacs: "接続中のMac: %d台",
            .pauseSync: "同期を一時停止",
            .resumeSync: "同期を再開",
            .launchAtLogin: "ログイン時に自動起動",
            .quit: "終了",
            .loginErrorTitle: "自動起動の設定に失敗しました",
            .loginErrorBody: "アプリを /Applications フォルダに移動してからもう一度お試しください。",
        ],
        "zh-Hans": [
            .showInDock: "在程序坞中显示图标",
            .onlyDuringRemote: "仅在远程会话期间同步",
            .connectedMacs: "已连接的 Mac:%d 台",
            .pauseSync: "暂停同步",
            .resumeSync: "恢复同步",
            .launchAtLogin: "登录时自动启动",
            .quit: "退出",
            .loginErrorTitle: "自动启动设置失败",
            .loginErrorBody: "请将应用移动到 /Applications 文件夹后重试。",
        ],
        "zh-Hant": [
            .showInDock: "在 Dock 中顯示圖示",
            .onlyDuringRemote: "僅在遠端工作階段期間同步",
            .connectedMacs: "已連接的 Mac:%d 台",
            .pauseSync: "暫停同步",
            .resumeSync: "繼續同步",
            .launchAtLogin: "登入時自動啟動",
            .quit: "結束",
            .loginErrorTitle: "自動啟動設定失敗",
            .loginErrorBody: "請將應用程式移至 /Applications 資料夾後再試一次。",
        ],
        "th": [
            .showInDock: "แสดงไอคอนใน Dock",
            .onlyDuringRemote: "ซิงค์เฉพาะระหว่างการเชื่อมต่อระยะไกล",
            .connectedMacs: "Mac ที่เชื่อมต่อ: %d เครื่อง",
            .pauseSync: "หยุดการซิงค์ชั่วคราว",
            .resumeSync: "ทำการซิงค์ต่อ",
            .launchAtLogin: "เปิดอัตโนมัติเมื่อเข้าสู่ระบบ",
            .quit: "ออก",
            .loginErrorTitle: "ตั้งค่าเปิดอัตโนมัติไม่สำเร็จ",
            .loginErrorBody: "ย้ายแอปไปยังโฟลเดอร์ /Applications แล้วลองอีกครั้ง",
        ],
        "ru": [
            .showInDock: "Показывать значок в Dock",
            .onlyDuringRemote: "Синхронизировать только во время удалённого сеанса",
            .connectedMacs: "Подключено Mac: %d",
            .pauseSync: "Приостановить синхронизацию",
            .resumeSync: "Возобновить синхронизацию",
            .launchAtLogin: "Запускать при входе",
            .quit: "Выйти",
            .loginErrorTitle: "Не удалось включить автозапуск",
            .loginErrorBody: "Переместите приложение в папку /Applications и повторите попытку.",
        ],
        "it": [
            .showInDock: "Mostra icona nel Dock",
            .onlyDuringRemote: "Sincronizza solo durante le sessioni remote",
            .connectedMacs: "Mac connessi: %d",
            .pauseSync: "Sospendi sincronizzazione",
            .resumeSync: "Riprendi sincronizzazione",
            .launchAtLogin: "Avvia al login",
            .quit: "Esci",
            .loginErrorTitle: "Impossibile attivare l'avvio al login",
            .loginErrorBody: "Sposta l'app nella cartella /Applications e riprova.",
        ],
    ]
}
