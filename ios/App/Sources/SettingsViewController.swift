import UIKit

/// 设置页：会话页外观 + 后台保活 + 通知（对应 Android SettingsActivity）。
/// 每次变更即时回调 onChange → WebViewController 热更新页面，返回会话不用重进。
final class SettingsViewController: UITableViewController {
    private let settings = SettingsStore.shared
    private let onChange: () -> Void

    init(onChange: @escaping () -> Void) {
        self.onChange = onChange
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "设置"
        view.backgroundColor = Theme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成", style: .done, target: self, action: #selector(onDone)
        )
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
    }

    @objc private func onDone() {
        dismiss(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onChange()
    }

    // MARK: - 行定义

    private struct Row {
        let title: String
        let subtitle: String?
        let boolKey: ((SettingsStore) -> Bool, (SettingsStore, Bool) -> Void)?
        let segmented: (items: [String], get: () -> Int, set: (Int) -> Void)?
    }

    private enum Section { case page, background, about }

    private var rows: [(Section, Row)] {
        [
            (Section.page, Row(title: "隐藏滚动条", subtitle: "内容占满全宽；关= 3px 细滚动条",
                               boolKey: ({ $0.hideScrollbar }, { $0.hideScrollbar = $1 }), segmented: nil)),
            (Section.page, Row(title: "对话问题导航", subtitle: "左缘三滑唤出问题列表",
                               boolKey: ({ $0.turnNavigator }, { $0.turnNavigator = $1 }), segmented: nil)),
            (Section.page, Row(title: "浮动输入框", subtitle: "增强 UI 总开关：关= 纯网页观感",
                               boolKey: ({ $0.floatingInput }, { $0.floatingInput = $1 }), segmented: nil)),
            (Section.page, Row(title: "滑到底部恢复输入框", subtitle: nil,
                               boolKey: ({ $0.restoreOnBottom }, { $0.restoreOnBottom = $1 }), segmented: nil)),
            (Section.page, Row(title: "发送后自动收纳", subtitle: "回复全屏阅读，点图标再唤出",
                               boolKey: ({ $0.sendMinimize }, { $0.sendMinimize = $1 }), segmented: nil)),
            (Section.page, Row(title: "纯黑 AMOLED（实验）", subtitle: "注入层换纯黑 token",
                               boolKey: ({ $0.amoledBlack }, { $0.amoledBlack = $1 }), segmented: nil)),
            (Section.page, Row(title: "文字缩放", subtitle: nil, boolKey: nil,
                               segmented: (items: ["75%", "100%", "125%", "150%"],
                                           get: { self.settings.textZoom },
                                           set: { self.settings.textZoom = $0 }))),

            (Section.background, Row(title: "新回复通知", subtitle: "切出 App 后收到回复弹系统通知",
                                     boolKey: ({ $0.notifyReply }, { $0.notifyReply = $1 }), segmented: nil)),
            (Section.background, Row(title: "后台保活", subtitle: "切后台静音音频维持连接（后台音频模式）",
                                     boolKey: ({ $0.keepAliveEnabled }, { $0.keepAliveEnabled = $1 }), segmented: nil)),
            (Section.background, Row(title: "保活时长", subtitle: "超时自动停止省电", boolKey: nil,
                                     segmented: (items: ["10 分钟", "30 分钟", "不限"],
                                                 get: { self.settings.keepAliveMinutes <= 0 ? 2 : (self.settings.keepAliveMinutes <= 10 ? 0 : 1) },
                                                 set: { self.settings.keepAliveMinutes = $0 == 2 ? 0 : ($0 == 0 ? 10 : 30) }))),

            (Section.about, Row(title: "禁用注入增强层（诊断）", subtitle: "纯 WebView 对照：开启后回退重进会话。若这样能连上，问题在增强层；仍连不上则对照 Safari 判断网络/系统",
                                boolKey: ({ $0.bareWebview }, { $0.bareWebview = $1 }), segmented: nil)),
            (Section.about, Row(title: "ZCodeRemote for iOS", subtitle: "非智谱官方产品，仅供个人学习使用。远控链接即凭证，只保存在本机。", boolKey: nil, segmented: nil)),
        ]
    }

    private func sectionTitle(_ s: Section) -> String {
        switch s {
        case .page: return "会话页"
        case .background: return "后台与通知"
        case .about: return "关于"
        }
    }

    private func rows(in s: Section) -> [(Int, Row)] {
        rows.enumerated().filter { $0.element.0 == s }.map { ($0.offset, $0.element.1) }
    }

    private var sectionOrder: [Section] { [.page, .background, .about] }

    // MARK: - 表格

    override func numberOfSections(in tableView: UITableView) -> Int { sectionOrder.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionTitle(sectionOrder[section])
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows(in: sectionOrder[section]).count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let row = rows(in: sectionOrder[indexPath.section])[indexPath.row].1
        var cfg = cell.defaultContentConfiguration()
        cfg.text = row.title
        cfg.textProperties.color = Theme.text
        cfg.secondaryText = row.subtitle
        cfg.secondaryTextProperties.color = Theme.textSecondary
        cfg.secondaryTextProperties.font = .systemFont(ofSize: 11)
        cell.contentConfiguration = cfg
        cell.backgroundColor = Theme.card

        cell.accessoryView = nil
        if let (get, set) = row.boolKey {
            let sw = UISwitch()
            sw.isOn = get(settings)
            sw.onTintColor = Theme.accent
            sw.addAction(UIAction { [weak self, weak sw] _ in
                guard let self, let sw else { return }
                set(self.settings, sw.isOn)
                self.onChange()
            }, for: .valueChanged)
            cell.accessoryView = sw
            cell.selectionStyle = .none
        } else if let (titles, get, set) = row.segmented {
            let seg = UISegmentedControl(items: titles)
            seg.selectedSegmentIndex = get()
            seg.selectedSegmentTintColor = Theme.accent
            seg.setTitleTextAttributes([.foregroundColor: UIColor.black], for: .selected)
            seg.setTitleTextAttributes([.foregroundColor: Theme.textSecondary], for: .normal)
            seg.addAction(UIAction { [weak self, weak seg] _ in
                guard let self, let seg else { return }
                set(seg.selectedSegmentIndex)
                self.onChange()
            }, for: .valueChanged)
            cell.accessoryView = seg
            cell.selectionStyle = .none
        } else {
            cell.selectionStyle = .none
        }
        return cell
    }
}
