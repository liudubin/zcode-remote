import UIKit

/// 设置页：会话页外观 + 后台保活 + 通知（对应 Android SettingsActivity）。
/// 每次变更即时回调 onChange → WebViewController 热更新页面，返回会话不用重进。
/// 注：iOS 版已强制禁用注入增强层，本页只保留对纯 WebView 仍有意义的开关。
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
            // 注：注入增强层已强制禁用，依赖注入的开关（滚动条/浮动输入/导航/通知等）
            // 一并移除，避免"开关无效"的困惑；恢复注入时随装配一起恢复这些行。
            (Section.page, Row(title: "文字缩放", subtitle: nil, boolKey: nil,
                               segmented: (items: ["75%", "100%", "125%", "150%"],
                                           get: { self.settings.textZoom },
                                           set: { self.settings.textZoom = $0 }))),

            (Section.background, Row(title: "后台保活", subtitle: "切后台静音音频维持网络",
                                     boolKey: ({ $0.keepAliveEnabled }, { $0.keepAliveEnabled = $1 }), segmented: nil)),
            (Section.background, Row(title: "保活时长", subtitle: nil, boolKey: nil,
                                     segmented: (items: ["10 分钟", "30 分钟", "不限"],
                                                 get: { self.settings.keepAliveMinutes <= 0 ? 2 : (self.settings.keepAliveMinutes <= 10 ? 0 : 1) },
                                                 set: { self.settings.keepAliveMinutes = $0 == 2 ? 0 : ($0 == 0 ? 10 : 30) }))),

            (Section.about, Row(title: "更新日志", subtitle: nil, boolKey: nil, segmented: nil)),
            (Section.about, Row(title: "诊断", subtitle: "最近的加载/重载/网络事件（可复制）", boolKey: nil, segmented: nil)),
            (Section.about, Row(title: Self.versionLine(), subtitle: "非智谱官方产品 · 链接即凭证，仅存本机", boolKey: nil, segmented: nil)),
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

    /// 版本行：显示 marketing 版本 + CI 构建号（排障对包用）
    private static func versionLine() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "ZCodeRemote for iOS \(v)（build \(b)）"
    }

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
        } else if row.title == "更新日志" || row.title == "诊断" {
            cell.selectionStyle = .default
            cell.accessoryType = .disclosureIndicator
        } else {
            cell.selectionStyle = .none
        }
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows(in: sectionOrder[indexPath.section])[indexPath.row].1
        guard row.title == "更新日志" || row.title == "诊断" else { return }
        tableView.deselectRow(at: indexPath, animated: true)
        if row.title == "更新日志" {
            navigationController?.pushViewController(ChangelogViewController(), animated: true)
            return
        }
        // 诊断：原生侧最近事件（加载/失败/重试/进程被杀重载），纯 native 不依赖注入
        let trace = Trace.shared.jsonString()
        let alert = UIAlertController(title: "诊断（最近事件）", message: trace, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "复制", style: .default) { _ in
            UIPasteboard.general.string = trace
        })
        alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
        present(alert, animated: true)
    }
}
