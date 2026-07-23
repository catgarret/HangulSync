import Foundation

/// 시스템 언어에 따른 UI 문자열 (ko, en, ja, zh-Hans, zh-Hant, th, ru, it)
enum L10n {
    enum Key: String {
        case connectedMacs, pauseSync, resumeSync, launchAtLogin, quit
        case loginErrorTitle, loginErrorBody, onlyDuringRemote, showInDock, settings
        case tagline, statusSyncing, statusStandby, statusPaused, dockHint
        case viaLocalNetwork, viaTailscale, viaIncoming, noPeers, statusNotConnected
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
            .statusNotConnected: "No Macs connected — run HangulSync on your other Mac too",
            .viaLocalNetwork: "local network",
            .viaTailscale: "Tailscale",
            .viaIncoming: "incoming",
            .noPeers: "No Macs found yet",
            .tagline: "Keeps the Korean/English input state in sync between your Macs.",
            .statusSyncing: "Active — Korean/English switching is synced with connected Macs",
            .statusStandby: "Standby — activates automatically when a remote desktop app is running",
            .statusPaused: "Paused",
            .dockHint: "Even when hidden from the Dock, you can open Settings from the menu bar icon.",
            .settings: "Settings…",
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
            .statusNotConnected: "연결된 Mac 없음 — 상대 Mac에서도 HangulSync를 실행하세요",
            .viaLocalNetwork: "같은 네트워크",
            .viaTailscale: "Tailscale",
            .viaIncoming: "수신 연결",
            .noPeers: "아직 발견된 Mac 없음",
            .tagline: "Mac 간 한/영 입력 상태를 자동으로 맞춰줍니다.",
            .statusSyncing: "작동 중 — 연결된 Mac과 한/영 전환이 동기화됩니다",
            .statusStandby: "대기 중 — 원격 데스크탑 앱을 실행하면 자동으로 작동합니다",
            .statusPaused: "일시정지됨",
            .dockHint: "Dock에서 숨겨도 메뉴바 아이콘으로 설정을 열 수 있습니다.",
            .settings: "설정…",
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
            .statusNotConnected: "接続中の Mac なし — もう一台の Mac でも HangulSync を実行してください",
            .viaLocalNetwork: "同一ネットワーク",
            .viaTailscale: "Tailscale",
            .viaIncoming: "受信接続",
            .noPeers: "まだ Mac が見つかりません",
            .tagline: "Mac 間の韓国語/英語入力状態を自動で揃えます。",
            .statusSyncing: "作動中 — 接続中の Mac と入力切替が同期されています",
            .statusStandby: "待機中 — リモートデスクトップアプリを実行すると自動で作動します",
            .statusPaused: "一時停止中",
            .dockHint: "Dock から隠しても、メニューバーアイコンから設定を開けます。",
            .settings: "設定…",
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
            .statusNotConnected: "没有已连接的 Mac — 请在另一台 Mac 上也运行 HangulSync",
            .viaLocalNetwork: "同一网络",
            .viaTailscale: "Tailscale",
            .viaIncoming: "传入连接",
            .noPeers: "尚未发现 Mac",
            .tagline: "自动保持多台 Mac 之间的韩语/英语输入状态一致。",
            .statusSyncing: "运行中 — 正在与已连接的 Mac 同步输入切换",
            .statusStandby: "待机 — 运行远程桌面应用时自动开始工作",
            .statusPaused: "已暂停",
            .dockHint: "即使从程序坞隐藏,也可通过菜单栏图标打开设置。",
            .settings: "设置…",
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
            .statusNotConnected: "沒有已連接的 Mac — 請在另一台 Mac 上也執行 HangulSync",
            .viaLocalNetwork: "同一網路",
            .viaTailscale: "Tailscale",
            .viaIncoming: "傳入連線",
            .noPeers: "尚未發現 Mac",
            .tagline: "自動保持多台 Mac 之間的韓語/英語輸入狀態一致。",
            .statusSyncing: "運作中 — 正在與已連接的 Mac 同步輸入切換",
            .statusStandby: "待機 — 執行遠端桌面應用時自動開始運作",
            .statusPaused: "已暫停",
            .dockHint: "即使從 Dock 隱藏,也可透過選單列圖示開啟設定。",
            .settings: "設定…",
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
            .statusNotConnected: "ไม่มี Mac ที่เชื่อมต่อ — โปรดเปิด HangulSync บน Mac อีกเครื่องด้วย",
            .viaLocalNetwork: "เครือข่ายเดียวกัน",
            .viaTailscale: "Tailscale",
            .viaIncoming: "การเชื่อมต่อขาเข้า",
            .noPeers: "ยังไม่พบเครื่อง Mac",
            .tagline: "ซิงค์สถานะการป้อนภาษาเกาหลี/อังกฤษระหว่างเครื่อง Mac โดยอัตโนมัติ",
            .statusSyncing: "กำลังทำงาน — ซิงค์การสลับภาษากับ Mac ที่เชื่อมต่อ",
            .statusStandby: "สแตนด์บาย — จะทำงานอัตโนมัติเมื่อเปิดแอปรีโมตเดสก์ท็อป",
            .statusPaused: "หยุดชั่วคราว",
            .dockHint: "แม้ซ่อนจาก Dock ก็เปิดการตั้งค่าได้จากไอคอนบนเมนูบาร์",
            .settings: "การตั้งค่า…",
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
            .statusNotConnected: "Нет подключённых Mac — запустите HangulSync и на втором Mac",
            .viaLocalNetwork: "локальная сеть",
            .viaTailscale: "Tailscale",
            .viaIncoming: "входящее",
            .noPeers: "Mac пока не найдены",
            .tagline: "Автоматически согласует корейский/английский ввод между вашими Mac.",
            .statusSyncing: "Работает — переключение ввода синхронизируется с подключёнными Mac",
            .statusStandby: "Ожидание — включится автоматически при запуске удалённого рабочего стола",
            .statusPaused: "Приостановлено",
            .dockHint: "Даже если значок скрыт из Dock, настройки доступны через значок в строке меню.",
            .settings: "Настройки…",
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
            .statusNotConnected: "Nessun Mac connesso — esegui HangulSync anche sull'altro Mac",
            .viaLocalNetwork: "rete locale",
            .viaTailscale: "Tailscale",
            .viaIncoming: "in entrata",
            .noPeers: "Nessun Mac trovato",
            .tagline: "Mantiene sincronizzato lo stato di input coreano/inglese tra i tuoi Mac.",
            .statusSyncing: "Attivo — il cambio di lingua è sincronizzato con i Mac connessi",
            .statusStandby: "In attesa — si attiva automaticamente quando è in esecuzione un'app di desktop remoto",
            .statusPaused: "In pausa",
            .dockHint: "Anche se nascosta dal Dock, puoi aprire le Impostazioni dall'icona nella barra dei menu.",
            .settings: "Impostazioni…",
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
