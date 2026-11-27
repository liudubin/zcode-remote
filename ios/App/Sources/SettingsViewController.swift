import PhotosUI
import UIKit

/// 设置页（v3 重设计）：左缘主色图标芯片 + 卡片行 + 分区头脚样式。
/// 每次变更即时回调 onChange → WebViewController 热更新页面，返回会话不用重进。
/// diagnostics：会话内提供（异步拉取页面侧+原生 Trace）；入口页进入时无会话，置 nil。
final class SettingsViewController: UITableViewController {
    let settings = SettingsStore.shared
    let onChange: () -> Void
    let diagnostics: ((@escaping (String) -> Void) -> Void)?

    init(onChange: @escaping () -> Void,
         diagnostics: ((@escaping (String) -> Void) -> Void)? = nil) {
        self.onChange = onChange
        self.diagnostics = diagnostics
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
        tableView.backgroundColor = .clear
        tableView.register(SettingsCell.self, forCellReuseIdentifier: "settings")
    }

    @objc private func onDone() {
        dismiss(animated: true)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        onChange()
    }

    // MARK: - 行定义

    /// 压暗档位表（百分比）
    static let wpDimValues = [25, 45, 65, 85]

    struct Row {
        let title: String
        let subtitle: String?
        let icon: String        // SF Symbol 名（左缘芯片）
        let boolKey: ((SettingsStore) -> Bool, (SettingsStore, Bool) -> Void)?
        let segmented: (items: [String], get: () -> Int, set: (Int) -> Void)?
        let opensDetail: Bool
        var tint: UIColor? = nil
    }

    enum Section { case wp, page, background, about }

    var rows: [(Section, Row)] {
        [
            (Section.wp, Row(title: "选择背景图",
                             subtitle: settings.hasWallpaper ? "已设置 · 点按更换" : "会话页消息区背景（存本机）",
                             icon: "photo.on.rectangle.angled",
                             boolKey: nil, segmented: nil, opensDetail: true)),
            (Section.wp, Row(title: "背景压暗",
                             subtitle: "烘焙进图里，越深消息区越沉",
                             icon: "sun.min",
                             boolKey: nil,
                             segmented: (items: ["25%", "45%", "65%", "85%"],
                                         get: { Self.wpDimValues.firstIndex(of: self.settings.wpDim) ?? 1 },
                                         set: { self.settings.wpDim = Self.wpDimValues[max(0, min(Self.wpDimValues.count - 1, $0))] }),
                             opensDetail: false)),
            (Section.wp, Row(title: "清除背景图",
                             subtitle: settings.hasWallpaper ? nil : "未设置",
                             icon: "trash",
                             boolKey: nil, segmented: nil, opensDetail: false,
                             tint: Theme.destructive)),

            (Section.page, Row(title: "隐藏滚动条", subtitle: "关 = 3px 细滚动条", icon: "line.3.horizontal.decrease",
                               boolKey: ({ $0.hideScrollbar }, { $0.hideScrollbar = $1 }), segmented: nil, opensDetail: false)),
            (Section.page, Row(title: "对话问题导航", subtitle: "左缘三滑唤出", icon: "list.bullet",
                               boolKey: ({ $0.turnNavigator }, { $0.turnNavigator = $1 }), segmented: nil, opensDetail: false)),
            (Section.page, Row(title: "浮动输入框", subtitle: "增强 UI 总开关", icon: "keyboard",
                               boolKey: ({ $0.floatingInput }, { $0.floatingInput = $1 }), segmented: nil, opensDetail: false)),
            (Section.page, Row(title: "滑到底部恢复输入框", subtitle: nil, icon: "arrow.down.to.line",
                               boolKey: ({ $0.restoreOnBottom }, { $0.restoreOnBottom = $1 }), segmented: nil, opensDetail: false)),
            (Section.page, Row(title: "发送后自动收纳", subtitle: nil, icon: "paperplane",
                               boolKey: ({ $0.sendMinimize }, { $0.sendMinimize = $1 }), segmented: nil, opensDetail: false)),
            (Section.page, Row(title: "纯黑 AMOLED", subtitle: "实验", icon: "moon.fill",
                               boolKey: ({ $0.amoledBlack }, { $0.amoledBlack = $1 }), segmented: nil, opensDetail: false)),
            (Section.page, Row(title: "文字缩放", subtitle: nil, icon: "textformat.size", boolKey: nil,
                               segmented: (items: ["75%", "100%", "125%", "150%"],
                                           get: { self.settings.textZoom },
                                           set: { self.settings.textZoom = $0 }), opensDetail: false)),

            (Section.background, Row(title: "新回复通知", subtitle: "切出后弹系统通知", icon: "bell.fill",
                                     boolKey: ({ $0.notifyReply }, { $0.notifyReply = $1 }), segmented: nil, opensDetail: false)),
            (Section.background, Row(title: "后台保活", subtitle: "静音音频维持连接", icon: "waveform",
                                     boolKey: ({ $0.keepAliveEnabled }, { $0.keepAliveEnabled = $1 }), segmented: nil, opensDetail: false)),
            (Section.background, Row(title: "保活时长", subtitle: nil, icon: "clock", boolKey: nil,
                                     segmented: (items: ["10 分钟", "30 分钟", "不限"],
                                                 get: { self.settings.keepAliveMinutes <= 0 ? 2 : (self.settings.keepAliveMinutes <= 10 ? 0 : 1) },
                                                 set: { self.settings.keepAliveMinutes = $0 == 2 ? 0 : ($0 == 0 ? 10 : 30) }), opensDetail: false)),

            (Section.about, Row(title: "注入档位（诊断）", subtitle: "最小=只装桥不注增强，改后重进会话", icon: "wrench.and.screwdriver.fill", boolKey: nil,
                                segmented: (items: ["完整", "最小"],
                                            get: { self.settings.injectLevel == .full ? 0 : 1 },
                                            set: { self.settings.injectLevel = $0 == 0 ? .full : .minimal }), opensDetail: false)),
            (Section.about, Row(title: "禁用注入增强层", subtitle: "诊断：连不上时对照，改后重进", icon: "power",
                                boolKey: ({ $0.bareWebview }, { $0.bareWebview = $1 }), segmented: nil, opensDetail: false)),
            (Section.about, Row(title: "更新日志", subtitle: nil, icon: "doc.text", boolKey: nil, segmented: nil, opensDetail: true)),
            (Section.about, Row(title: "注入诊断", subtitle: "最近的注入/页面错误与回复链路事件", icon: "stethoscope", boolKey: nil, segmented: nil, opensDetail: true)),
            (Section.about, Row(title: Self.versionLine(), subtitle: "非智谱官方产品 · 链接即凭证，仅存本机", icon: "info.circle", boolKey: nil, segmented: nil, opensDetail: false)),
        ]
    }

    func sectionTitle(_ s: Section) -> String {
        switch s {
        case .wp: return "个性化"
        case .page: return "会话页"
        case .background: return "后台与通知"
        case .about: return "关于"
        }
    }

    func sectionFooter(_ s: Section) -> String? {
        switch s {
        case .wp: return "背景只在本机生效；建议搭配深色主题，压暗越深消息区越沉。"
        case .page: return "以上改动即时生效并热更新当前会话页。"
        case .background: return "保活在 App 进入后台时维持连接，到设定时长自动停止。"
        case .about: return "注入层只改网页观感与行为，不收集任何数据。"
        }
    }

    func rows(in s: Section) -> [(Int, Row)] {
        rows.enumerated().filter { $0.element.0 == s }.map { ($0.offset, $0.element.1) }
    }

    var sectionOrder: [Section] { [.wp, .page, .background, .about] }

    /// 版本行：显示 marketing 版本 + CI 构建号（排障对包用）
    static func versionLine() -> String {
        let v = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let b = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "ZCodeRemote for iOS \(v)（build \(b)）"
    }

    /// 行右缘控件形态（值在 cellForRowAt 现取，热更后重刷）
    func accessory(for row: Row) -> SettingsCell.Accessory {
        if let (get, set) = row.boolKey {
            return .toggle(isOn: get(settings), setter: { [weak self] v in
                guard let self else { return }
                set(self.settings, v)
                self.onChange()
            })
        }
        if let seg = row.segmented {
            return .segments(items: seg.items, selected: seg.get(), setter: { [weak self] i in
                guard let self else { return }
                seg.set(i)
                self.onChange()
            })
        }
        return .plain
    }

    // MARK: - 表格

    override func numberOfSections(in tableView: UITableView) -> Int { sectionOrder.count }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        sectionTitle(sectionOrder[section])
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        sectionFooter(sectionOrder[section])
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let h = view as? UITableViewHeaderFooterView {
            h.textLabel?.textColor = Theme.accent
            h.textLabel?.font = .systemFont(ofSize: 12, weight: .bold)
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        if let f = view as? UITableViewHeaderFooterView {
            f.textLabel?.textColor = Theme.textSecondary
            f.textLabel?.font = .systemFont(ofSize: 11)
        }
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        rows(in: sectionOrder[section]).count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "settings", for: indexPath) as! SettingsCell
        let row = rows(in: sectionOrder[indexPath.section])[indexPath.row].1
        cell.configure(
            title: row.title,
            subtitle: row.subtitle,
            icon: row.icon,
            opensDetail: row.opensDetail,
            accessory: accessory(for: row),
            tint: row.tint
        )
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let row = rows(in: sectionOrder[indexPath.section])[indexPath.row].1
        // 壁纸动作行
        if row.title == "选择背景图" {
            tableView.deselectRow(at: indexPath, animated: true)
            presentWallpaperPicker()
            return
        }
        if row.title == "清除背景图" {
            tableView.deselectRow(at: indexPath, animated: true)
            guard settings.hasWallpaper else { return }
            settings.clearWallpaper()
            tableView.reloadData()
            onChange()
            return
        }
        guard row.opensDetail else {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }
        tableView.deselectRow(at: indexPath, animated: true)
        if row.title == "更新日志" {
            navigationController?.pushViewController(ChangelogViewController(), animated: true)
            return
        }
        // 注入诊断：原生 Trace + 页面侧状态（boot 时序/内部错误收集器/关键节点），异步拉取
        if let fetch = diagnostics {
            fetch { [weak self] text in
                let alert = UIAlertController(title: "注入诊断", message: text, preferredStyle: .actionSheet)
                alert.addAction(UIAlertAction(title: "复制", style: .default) { _ in
                    UIPasteboard.general.string = text
                })
                alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
                self?.present(alert, animated: true)
            }
        } else {
            let trace = Trace.shared.jsonString()
            let alert = UIAlertController(title: "注入诊断（最近事件）", message: trace, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "复制", style: .default) { _ in
                UIPasteboard.general.string = trace
            })
            alert.addAction(UIAlertAction(title: "关闭", style: .cancel))
            present(alert, animated: true)
        }
    }
}

/// 自定义设置行：左缘主色芯片图标 + 标题/副标题 + 右缘开关/分段/箭头。
final class SettingsCell: UITableViewCell {
    enum Accessory {
        case plain
        case toggle(isOn: Bool, setter: (Bool) -> Void)
        case segments(items: [String], selected: Int, setter: (Int) -> Void)
    }

    let chip = UIView()
    let chipIcon = UIImageView()
    let titleLabel = UILabel()
    let subLabel = UILabel()
    let seg = UISegmentedControl(items: [])
    let sw = UISwitch()
    var toggleAction: UIAction?
    var segAction: UIAction?

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)

        backgroundColor = Theme.card
        selectedBackgroundView = UIView()
        selectedBackgroundView?.backgroundColor = Theme.input

        chip.layer.cornerRadius = 9
        chip.backgroundColor = Theme.accent.withAlphaComponent(0.14)
        chip.translatesAutoresizingMaskIntoConstraints = false
        chipIcon.tintColor = Theme.accent
        chipIcon.contentMode = .center
        chipIcon.translatesAutoresizingMaskIntoConstraints = false
        chip.addSubview(chipIcon)

        titleLabel.font = .systemFont(ofSize: 15, weight: .medium)
        titleLabel.textColor = Theme.text
        subLabel.font = .systemFont(ofSize: 11)
        subLabel.textColor = Theme.textSecondary
        subLabel.numberOfLines = 2

        sw.onTintColor = Theme.accent
        seg.selectedSegmentTintColor = Theme.accent
        seg.setTitleTextAttributes(
            [.foregroundColor: UIColor.black, .font: UIFont.systemFont(ofSize: 12, weight: .semibold)],
            for: .selected
        )
        seg.setTitleTextAttributes(
            [.foregroundColor: Theme.textSecondary, .font: UIFont.systemFont(ofSize: 12)],
            for: .normal
        )
        seg.translatesAutoresizingMaskIntoConstraints = false
        sw.translatesAutoresizingMaskIntoConstraints = false

        let texts = UIStackView(arrangedSubviews: [titleLabel, subLabel])
        texts.axis = .vertical
        texts.spacing = 2
        texts.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(chip)
        contentView.addSubview(texts)
        contentView.addSubview(seg)
        contentView.addSubview(sw)

        NSLayoutConstraint.activate([
            chip.leadingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.leadingAnchor),
            chip.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            chip.widthAnchor.constraint(equalToConstant: 30),
            chip.heightAnchor.constraint(equalToConstant: 30),
            chipIcon.centerXAnchor.constraint(equalTo: chip.centerXAnchor),
            chipIcon.centerYAnchor.constraint(equalTo: chip.centerYAnchor),

            texts.leadingAnchor.constraint(equalTo: chip.trailingAnchor, constant: 12),
            texts.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            texts.topAnchor.constraint(greaterThanOrEqualTo: contentView.layoutMarginsGuide.topAnchor),
            texts.bottomAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.bottomAnchor),
            texts.trailingAnchor.constraint(lessThanOrEqualTo: contentView.layoutMarginsGuide.trailingAnchor),

            seg.leadingAnchor.constraint(greaterThanOrEqualTo: texts.trailingAnchor, constant: 8),
            seg.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            seg.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            seg.widthAnchor.constraint(greaterThanOrEqualToConstant: 150),

            sw.leadingAnchor.constraint(greaterThanOrEqualTo: texts.trailingAnchor, constant: 8),
            sw.trailingAnchor.constraint(equalTo: contentView.layoutMarginsGuide.trailingAnchor),
            sw.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
        contentView.layoutMargins = UIEdgeInsets(top: 10, left: 16, bottom: 10, right: 16)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    func configure(title: String, subtitle: String?, icon: String,
                   opensDetail: Bool, accessory: Accessory, tint: UIColor? = nil) {
        let c = tint ?? Theme.accent
        titleLabel.text = title
        titleLabel.textColor = tint ?? Theme.text
        subLabel.text = subtitle
        subLabel.isHidden = (subtitle ?? "").isEmpty
        chipIcon.image = UIImage(
            systemName: icon,
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
        )
        selectionStyle = opensDetail ? .default : .none
        accessoryType = opensDetail ? .disclosureIndicator : .none
        tintColor = Theme.textSecondary

        // 复用池：先摘掉上一行的动作再挂新的
        if let a = toggleAction { sw.removeAction(a, for: .valueChanged) }
        if let a = segAction { seg.removeAction(a, for: .valueChanged) }
        toggleAction = nil
        segAction = nil

        switch accessory {
        case .plain:
            sw.isHidden = true
            seg.isHidden = true
        case .toggle(let isOn, let setter):
            sw.isOn = isOn
            sw.isHidden = false
            seg.isHidden = true
            let action = UIAction { [weak sw] _ in setter(sw?.isOn ?? false) }
            sw.addAction(action, for: .valueChanged)
            toggleAction = action
        case .segments(let items, let selected, let setter):
            while seg.numberOfSegments < items.count {
                seg.insertSegment(withTitle: nil, at: seg.numberOfSegments, animated: false)
            }
            while seg.numberOfSegments > items.count {
                seg.removeSegment(at: seg.numberOfSegments - 1, animated: false)
            }
            for (i, t) in items.enumerated() { seg.setTitle(t, forSegmentAt: i) }
            seg.selectedSegmentIndex = selected
            seg.isHidden = false
            sw.isHidden = true
            let action = UIAction { [weak seg] _ in setter(seg?.selectedSegmentIndex ?? 0) }
            seg.addAction(action, for: .valueChanged)
            segAction = action
        }
    }
}
