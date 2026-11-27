import AVFoundation
import UIKit
import UserNotifications

/// 入口页（v3 重设计）：墨绿黑底 + 霓虹渐变主 CTA + 卡片化会话列表。
/// 头部品牌区（徽标带辉光）、链接卡、扫码主按钮、最近会话（左滑删除）、底部声明。
/// 远控链接即凭证，只保存在本机 UserDefaults，绝不上传。
final class EntryViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {
    /// 进程内只自动跳转一次，避免从远控页返回入口后又被弹回去；
    /// internal：AppDelegate 的 -zcodeURL 直进会置 true 压掉自动恢复
    static var autoJumpedOnce = false

    let store = RecentStore.shared
    var recents: [Recent] = []

    let scrollView = UIScrollView()
    let contentStack = UIStackView()
    let recentsTable = UITableView(frame: .zero, style: .plain)
    var recentsTableHeight: NSLayoutConstraint!
    let recentsTitleRow = UIStackView()
    let recentsHeader = UILabel()
    let recentsEmpty = UILabel()
    let inputUrl = UITextField()
    let toastLabel = UILabel()
    var keyboardObservers: [NSObjectProtocol] = []

    deinit {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildUI()
        // 启动时如果剪贴板里正好是一条远控链接，直接预填，省一步
        if let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines),
           Self.looksLikeRemoteLink(text) {
            inputUrl.text = text
        }
        setupKeyboardAvoidance()
        requestNotifPermissionOnce()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        refreshRecents()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        autoResumeLastSession()
    }

    // MARK: - UI

    func buildUI() {
        // 顶部氛围光：主色渐变贴着页顶淡淡的铺一层，给纯黑页面一点纵深
        let glow = UIImageView(image: Theme.gradientImage(
            size: CGSize(width: 8, height: 260),
            colors: [Theme.accent.withAlphaComponent(0.14), UIColor.clear],
            start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1)
        ))
        glow.contentMode = .scaleToFill
        glow.translatesAutoresizingMaskIntoConstraints = false
        glow.isUserInteractionEnabled = false
        view.addSubview(glow)

        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 18
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            glow.topAnchor.constraint(equalTo: view.topAnchor),
            glow.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            glow.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            glow.heightAnchor.constraint(equalToConstant: 260),

            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
        ])

        contentStack.addArrangedSubview(buildHeader())
        contentStack.setCustomSpacing(24, after: contentStack.arrangedSubviews[0])
        contentStack.addArrangedSubview(buildPrimaryScanButton())
        contentStack.addArrangedSubview(buildLinkCard())
        contentStack.addArrangedSubview(buildRecentsSection())
        contentStack.addArrangedSubview(buildFooter())

        toastLabel.alpha = 0
        toastLabel.font = .systemFont(ofSize: 13, weight: .medium)
        toastLabel.textColor = Theme.text
        toastLabel.backgroundColor = Theme.cardRaised
        toastLabel.layer.cornerRadius = 17
        toastLabel.layer.borderWidth = 1
        toastLabel.layer.borderColor = Theme.accent.withAlphaComponent(0.25).cgColor
        toastLabel.clipsToBounds = true
        toastLabel.textAlignment = .center
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            toastLabel.heightAnchor.constraint(equalToConstant: 34),
        ])
    }

    /// 品牌头部：终端窗徽标（辉光）+ 名称 + 副标题 + 右上角设置
    func buildHeader() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center

        // 品牌徽标：与新 App 图标同款终端窗卡（IconSymbol imageset）
        let badge = UIImageView(image: UIImage(named: "IconSymbol"))
        badge.contentMode = .scaleAspectFit
        badge.clipsToBounds = false
        badge.layer.shadowColor = Theme.accent.cgColor
        badge.layer.shadowOpacity = 0.35
        badge.layer.shadowRadius = 14
        badge.layer.shadowOffset = CGSize(width: 0, height: 5)
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 60).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 60).isActive = true

        let titles = UIStackView()
        titles.axis = .vertical
        titles.spacing = 3
        let name = UILabel()
        let rich = NSMutableAttributedString(
            string: "ZCode",
            attributes: [.font: UIFont.systemFont(ofSize: 24, weight: .bold), .foregroundColor: Theme.text]
        )
        rich.append(NSAttributedString(
            string: "Remote",
            attributes: [
                .font: UIFont.systemFont(ofSize: 24, weight: .bold),
                .foregroundColor: Theme.accent,
            ]
        ))
        name.attributedText = rich
        let sub = UILabel()
        sub.text = "手机远控你的 AI 编程智能体"
        sub.font = .systemFont(ofSize: 13)
        sub.textColor = Theme.textSecondary
        titles.addArrangedSubview(name)
        titles.addArrangedSubview(sub)

        let gear = UIButton(type: .system)
        let gearCfg = UIImage.SymbolConfiguration(pointSize: 16, weight: .semibold)
        gear.setImage(UIImage(systemName: "gearshape", withConfiguration: gearCfg), for: .normal)
        gear.tintColor = Theme.textSecondary
        gear.addTarget(self, action: #selector(openSettingsUI), for: .touchUpInside)
        gear.translatesAutoresizingMaskIntoConstraints = false
        gear.widthAnchor.constraint(equalToConstant: 40).isActive = true
        gear.heightAnchor.constraint(equalToConstant: 40).isActive = true

        row.addArrangedSubview(badge)
        row.addArrangedSubview(titles)
        row.addArrangedSubview(gear)
        return row
    }

    /// 扫码主 CTA：渐变填充 + 辉光投影
    func buildPrimaryScanButton() -> UIView {
        let scan = UIButton(type: .system)
        scan.setTitle("扫桌面端二维码", for: .normal)
        scan.setTitleColor(UIColor(red: 0.02, green: 0.09, blue: 0.06, alpha: 1), for: .normal)
        scan.tintColor = UIColor(red: 0.02, green: 0.09, blue: 0.06, alpha: 1)
        scan.titleLabel?.font = .systemFont(ofSize: 16, weight: .bold)
        scan.setBackgroundImage(Theme.accentButtonImage, for: .normal)
        // 图标独立贴右缘：UIButton.setImage 会让 [图标][文字] 组合居中，把文字挤偏右 ~11pt
        let scanIcon = UIImageView(
            image: UIImage(systemName: "qrcode.viewfinder", withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold))
        )
        scanIcon.tintColor = UIColor(red: 0.02, green: 0.09, blue: 0.06, alpha: 1)
        scanIcon.contentMode = .center
        scanIcon.translatesAutoresizingMaskIntoConstraints = false
        scan.addSubview(scanIcon)
        scan.layer.cornerRadius = 16
        scan.layer.masksToBounds = true
        scan.heightAnchor.constraint(equalToConstant: 52).isActive = true
        scanIcon.centerYAnchor.constraint(equalTo: scan.centerYAnchor).isActive = true
        scanIcon.trailingAnchor.constraint(equalTo: scan.trailingAnchor, constant: -16).isActive = true
        scan.addTarget(self, action: #selector(onScan), for: .touchUpInside)

        // 辉光：外层容器承载阴影（按钮自身 masksToBounds 会杀掉阴影）
        let glowWrap = UIView()
        glowWrap.backgroundColor = .clear
        glowWrap.layer.shadowColor = Theme.accent.cgColor
        glowWrap.layer.shadowOpacity = 0.4
        glowWrap.layer.shadowRadius = 16
        glowWrap.layer.shadowOffset = CGSize(width: 0, height: 8)
        scan.translatesAutoresizingMaskIntoConstraints = false
        glowWrap.addSubview(scan)
        NSLayoutConstraint.activate([
            scan.topAnchor.constraint(equalTo: glowWrap.topAnchor),
            scan.bottomAnchor.constraint(equalTo: glowWrap.bottomAnchor),
            scan.leadingAnchor.constraint(equalTo: glowWrap.leadingAnchor),
            scan.trailingAnchor.constraint(equalTo: glowWrap.trailingAnchor),
        ])

        let hint = UILabel()
        hint.text = "桌面端 ZCode 左下角「手机图标」→ 显示远控二维码"
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = Theme.textSecondary
        hint.textAlignment = .center

        let wrap = UIStackView()
        wrap.axis = .vertical
        wrap.spacing = 10
        wrap.addArrangedSubview(glowWrap)
        wrap.addArrangedSubview(hint)
        return wrap
    }

    /// 链接卡：区块标题 + 输入框（内嵌粘贴胶囊）+ 进入按钮
    func buildLinkCard() -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 10
        card.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.backgroundColor = Theme.card
        card.layer.cornerRadius = 18
        card.layer.borderWidth = 1
        card.layer.borderColor = UIColor.white.withAlphaComponent(0.05).cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        card.isLayoutMarginsRelativeArrangement = true

        let sectionTitle = UILabel()
        sectionTitle.text = "或用链接进入"
        sectionTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        sectionTitle.textColor = Theme.textSecondary

        inputUrl.placeholder = "https://zcode.z.ai/remote/…"
        inputUrl.backgroundColor = Theme.input
        inputUrl.textColor = Theme.text
        inputUrl.attributedPlaceholder = NSAttributedString(
            string: inputUrl.placeholder ?? "", attributes: [.foregroundColor: Theme.textSecondary]
        )
        inputUrl.layer.cornerRadius = 12
        inputUrl.autocorrectionType = .no
        inputUrl.autocapitalizationType = .none
        inputUrl.keyboardType = .URL
        inputUrl.returnKeyType = .go
        inputUrl.delegate = self
        // 右侧已有"粘贴"overlay，清除按钮走 overlay 前的编辑区，避免二者重叠
        inputUrl.clearButtonMode = .never
        inputUrl.font = .monospacedSystemFont(ofSize: 13, weight: .regular)
        inputUrl.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        inputUrl.leftViewMode = .always

        let pasteOverlay = UIButton(type: .system)
        pasteOverlay.setTitle("粘贴", for: .normal)
        pasteOverlay.setTitleColor(Theme.accent, for: .normal)
        pasteOverlay.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        pasteOverlay.backgroundColor = Theme.accentWash
        pasteOverlay.layer.cornerRadius = 8
        pasteOverlay.contentEdgeInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        pasteOverlay.addTarget(self, action: #selector(onPaste), for: .touchUpInside)
        inputUrl.rightView = pasteOverlay
        inputUrl.rightViewMode = .always

        let go = UIButton(type: .system)
        go.setTitle("进入会话", for: .normal)
        go.setTitleColor(Theme.accent, for: .normal)
        go.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        go.backgroundColor = Theme.input
        // 同 scan：图标独立贴右缘，title 真居中（setImage 组合居中会把文字挤偏）
        let goIcon = UIImageView(
            image: UIImage(systemName: "arrow.right", withConfiguration: UIImage.SymbolConfiguration(pointSize: 13, weight: .semibold))
        )
        goIcon.tintColor = Theme.accent
        goIcon.contentMode = .center
        goIcon.translatesAutoresizingMaskIntoConstraints = false
        go.addSubview(goIcon)
        go.layer.cornerRadius = 12
        go.heightAnchor.constraint(equalToConstant: 44).isActive = true
        goIcon.centerYAnchor.constraint(equalTo: go.centerYAnchor).isActive = true
        goIcon.trailingAnchor.constraint(equalTo: go.trailingAnchor, constant: -14).isActive = true
        go.addTarget(self, action: #selector(onOpen), for: .touchUpInside)

        inputUrl.translatesAutoresizingMaskIntoConstraints = false
        inputUrl.heightAnchor.constraint(equalToConstant: 44).isActive = true
        card.addArrangedSubview(sectionTitle)
        card.addArrangedSubview(inputUrl)
        card.addArrangedSubview(go)
        return card
    }

    /// 最近会话：标题行 + 卡片列表/空态
    func buildRecentsSection() -> UIView {
        recentsHeader.text = "最近会话"
        recentsHeader.font = .systemFont(ofSize: 17, weight: .bold)
        recentsHeader.textColor = Theme.text

        recentsTitleRow.axis = .horizontal
        recentsTitleRow.alignment = .center
        recentsTitleRow.addArrangedSubview(recentsHeader)

        // 最近会话：UITableView 承载（原生左滑删除），禁滚动、高度随条目数走，
        // 嵌在外层 ScrollView 里只作列表渲染
        recentsTable.dataSource = self
        recentsTable.delegate = self
        recentsTable.register(UITableViewCell.self, forCellReuseIdentifier: "recent")
        recentsTable.separatorStyle = .none
        recentsTable.isScrollEnabled = false
        recentsTable.backgroundColor = .clear
        recentsTable.rowHeight = 68
        recentsTable.translatesAutoresizingMaskIntoConstraints = false
        recentsTableHeight = recentsTable.heightAnchor.constraint(equalToConstant: 0)
        recentsTableHeight.isActive = true

        recentsEmpty.text = "还没有会话。扫桌面端二维码开始第一次连接。"
        recentsEmpty.font = .systemFont(ofSize: 12)
        recentsEmpty.textColor = Theme.textSecondary
        recentsEmpty.textAlignment = .center

        let section = UIStackView()
        section.axis = .vertical
        section.spacing = 10
        section.addArrangedSubview(recentsTitleRow)
        section.addArrangedSubview(recentsTable)
        section.addArrangedSubview(recentsEmpty)
        return section
    }

}