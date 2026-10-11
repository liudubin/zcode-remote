import AVFoundation
import UIKit
import UserNotifications

/// 入口页（重设计版）：滚动容器 + 键盘避让；头部品牌区、链接卡、扫码主按钮、
/// 最近会话列表（UITableView 卡片样式，**左滑删除**，点按进入）、底部设置入口。
/// 远控链接即凭证，只保存在本机 UserDefaults，绝不上传。
final class EntryViewController: UIViewController, UITextFieldDelegate, UITableViewDataSource, UITableViewDelegate {
    /// 进程内只自动跳转一次，避免从远控页返回入口后又被弹回去；
    /// internal：AppDelegate 的 -zcodeURL 直进会置 true 压掉自动恢复
    static var autoJumpedOnce = false

    private let store = RecentStore.shared
    private var recents: [Recent] = []

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let recentsTable = UITableView(frame: .zero, style: .plain)
    private var recentsTableHeight: NSLayoutConstraint!
    private let recentsTitleRow = UIStackView()
    private let recentsHeader = UILabel()
    private let recentsEmpty = UILabel()
    private let inputUrl = UITextField()
    private let toastLabel = UILabel()
    private var keyboardObservers: [NSObjectProtocol] = []

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

    private func buildUI() {
        scrollView.keyboardDismissMode = .interactive
        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)

        contentStack.axis = .vertical
        contentStack.spacing = 14
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(contentStack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 20),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -20),
        ])

        contentStack.addArrangedSubview(buildHeader())
        contentStack.addArrangedSubview(buildLinkCard())
        contentStack.addArrangedSubview(buildPrimaryScanButton())
        contentStack.addArrangedSubview(buildRecentsSection())
        contentStack.addArrangedSubview(buildFooter())

        toastLabel.alpha = 0
        toastLabel.font = .systemFont(ofSize: 13)
        toastLabel.textColor = .black
        toastLabel.backgroundColor = Theme.accent
        toastLabel.layer.cornerRadius = 8
        toastLabel.clipsToBounds = true
        toastLabel.textAlignment = .center
        toastLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(toastLabel)
        NSLayoutConstraint.activate([
            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    /// 品牌头部：绿色闪电 + 名称 + 副标题
    private func buildHeader() -> UIView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 14
        row.alignment = .center

        // 品牌徽标：与新 App 图标同款的 >_ 渐变符号（IconSymbol imageset）
        let badge = UIImageView(image: UIImage(named: "IconSymbol"))
        badge.contentMode = .scaleAspectFit
        badge.layer.cornerRadius = 16
        badge.clipsToBounds = true
        badge.backgroundColor = Theme.card
        badge.translatesAutoresizingMaskIntoConstraints = false
        badge.widthAnchor.constraint(equalToConstant: 56).isActive = true
        badge.heightAnchor.constraint(equalToConstant: 56).isActive = true

        let titles = UIStackView()
        titles.axis = .vertical
        titles.spacing = 3
        let name = UILabel()
        name.text = "ZCodeRemote"
        name.font = .systemFont(ofSize: 24, weight: .bold)
        name.textColor = Theme.text
        let sub = UILabel()
        sub.text = "手机远控你的 AI 编程智能体"
        sub.font = .systemFont(ofSize: 13)
        sub.textColor = Theme.textSecondary
        titles.addArrangedSubview(name)
        titles.addArrangedSubview(sub)

        row.addArrangedSubview(badge)
        row.addArrangedSubview(titles)
        return row
    }

    /// 链接卡：输入框（内嵌粘贴按钮）+ 进入按钮
    private func buildLinkCard() -> UIView {
        let card = UIStackView()
        card.axis = .vertical
        card.spacing = 10
        card.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        card.isLayoutMarginsRelativeArrangement = true
        card.backgroundColor = Theme.card
        card.layer.cornerRadius = 16
        card.translatesAutoresizingMaskIntoConstraints = false
        card.isLayoutMarginsRelativeArrangement = true

        inputUrl.placeholder = "https://zcode.z.ai/remote/…"
        inputUrl.backgroundColor = Theme.input
        inputUrl.textColor = Theme.text
        inputUrl.attributedPlaceholder = NSAttributedString(
            string: inputUrl.placeholder ?? "", attributes: [.foregroundColor: Theme.textSecondary]
        )
        inputUrl.layer.cornerRadius = 10
        inputUrl.autocorrectionType = .no
        inputUrl.autocapitalizationType = .none
        inputUrl.keyboardType = .URL
        inputUrl.returnKeyType = .go
        inputUrl.delegate = self
        // 右侧已有"粘贴"overlay，清除按钮走 overlay 前的编辑区，避免二者重叠
        inputUrl.clearButtonMode = .never
        inputUrl.font = .systemFont(ofSize: 14)
        inputUrl.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 10, height: 1))
        inputUrl.leftViewMode = .always

        let pasteOverlay = UIButton(type: .system)
        pasteOverlay.setTitle("粘贴", for: .normal)
        pasteOverlay.setTitleColor(Theme.accent, for: .normal)
        pasteOverlay.titleLabel?.font = .systemFont(ofSize: 13, weight: .medium)
        pasteOverlay.backgroundColor = Theme.card
        pasteOverlay.layer.cornerRadius = 7
        pasteOverlay.contentEdgeInsets = UIEdgeInsets(top: 5, left: 10, bottom: 5, right: 10)
        pasteOverlay.addTarget(self, action: #selector(onPaste), for: .touchUpInside)
        inputUrl.rightView = pasteOverlay
        inputUrl.rightViewMode = .always

        let go = UIButton(type: .system)
        go.setTitle("用链接进入", for: .normal)
        go.setTitleColor(Theme.text, for: .normal)
        go.backgroundColor = Theme.input
        go.layer.cornerRadius = 10
        go.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        go.heightAnchor.constraint(equalToConstant: 40).isActive = true
        go.addTarget(self, action: #selector(onOpen), for: .touchUpInside)

        inputUrl.translatesAutoresizingMaskIntoConstraints = false
        inputUrl.heightAnchor.constraint(equalToConstant: 40).isActive = true
        card.addArrangedSubview(inputUrl)
        card.addArrangedSubview(go)
        return card
    }

    /// 扫码主按钮
    private func buildPrimaryScanButton() -> UIView {
        let scan = UIButton(type: .system)
        scan.setTitle("扫桌面端二维码", for: .normal)
        scan.setTitleColor(.black, for: .normal)
        scan.titleLabel?.font = .systemFont(ofSize: 16, weight: .semibold)
        scan.backgroundColor = Theme.accent
        scan.layer.cornerRadius = 14
        scan.heightAnchor.constraint(equalToConstant: 48).isActive = true
        scan.addTarget(self, action: #selector(onScan), for: .touchUpInside)

        let hint = UILabel()
        hint.text = "桌面端 ZCode 左下角「手机图标」→ 显示远控二维码"
        hint.font = .systemFont(ofSize: 11)
        hint.textColor = Theme.textSecondary
        hint.textAlignment = .center

        let wrap = UIStackView()
        wrap.axis = .vertical
        wrap.spacing = 8
        wrap.addArrangedSubview(scan)
        wrap.addArrangedSubview(hint)
        return wrap
    }

    /// 最近会话：标题行 + 卡片列表/空态
    private func buildRecentsSection() -> UIView {
        recentsHeader.text = "最近会话"
        recentsHeader.font = .boldSystemFont(ofSize: 15)
        recentsHeader.textColor = Theme.text

        let clearAll = UIButton(type: .system)
        clearAll.setTitle("设置", for: .normal)
        clearAll.setTitleColor(Theme.textSecondary, for: .normal)
        clearAll.titleLabel?.font = .systemFont(ofSize: 13)
        clearAll.addTarget(self, action: #selector(openSettingsUI), for: .touchUpInside)

        recentsTitleRow.axis = .horizontal
        recentsTitleRow.alignment = .center
        recentsTitleRow.addArrangedSubview(recentsHeader)
        // spacer 把"设置"推到最右（否则紧贴标题，视觉错位）
        let spacer = UIView()
        spacer.setContentHuggingPriority(.init(249), for: .horizontal)
        recentsTitleRow.addArrangedSubview(spacer)
        recentsTitleRow.addArrangedSubview(clearAll)

        // 最近会话：UITableView 承载（原生左滑删除），禁滚动、高度随条目数走，
        // 嵌在外层 ScrollView 里只作列表渲染
        recentsTable.dataSource = self
        recentsTable.delegate = self
        recentsTable.register(UITableViewCell.self, forCellReuseIdentifier: "recent")
        recentsTable.separatorStyle = .none
        recentsTable.isScrollEnabled = false
        recentsTable.backgroundColor = .clear
        recentsTable.rowHeight = 64
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

    private func buildFooter() -> UIView {
        let foot = UILabel()
        foot.text = "非智谱官方产品 · 链接即凭证，仅存本机"
        foot.font = .systemFont(ofSize: 10)
        foot.textColor = Theme.textSecondary
        foot.textAlignment = .center
        return foot
    }

    // MARK: - 最近会话表格（卡片样式 + 左滑删除）

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recents.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "recent", for: indexPath)
        let r = recents[indexPath.row]
        cell.backgroundColor = .clear
        cell.selectionStyle = .default
        cell.selectedBackgroundView = UIView()
        cell.selectedBackgroundView?.backgroundColor = Theme.input

        // 卡片容器（圆角），上下留 4pt 形成卡片间距
        let card = cell.viewWithTag(1001) ?? {
            let c = UIView()
            c.tag = 1001
            c.backgroundColor = Theme.card
            c.layer.cornerRadius = 12
            c.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(c)
            NSLayoutConstraint.activate([
                c.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 4),
                c.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -4),
                c.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                c.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            ])
            let title = UILabel()
            title.tag = 1002
            title.font = .systemFont(ofSize: 15, weight: .medium)
            title.textColor = Theme.text
            let sub = UILabel()
            sub.tag = 1003
            sub.font = .systemFont(ofSize: 11)
            sub.textColor = Theme.textSecondary
            let texts = UIStackView(arrangedSubviews: [title, sub])
            texts.tag = 1004
            texts.axis = .vertical
            texts.spacing = 3
            let chevron = UILabel()
            chevron.tag = 1005
            chevron.text = "›"
            chevron.textColor = Theme.textSecondary
            chevron.font = .systemFont(ofSize: 18)
            let row = UIStackView(arrangedSubviews: [texts, chevron])
            row.tag = 1006
            row.axis = .horizontal
            row.spacing = 10
            row.alignment = .center
            row.layoutMargins = UIEdgeInsets(top: 8, left: 14, bottom: 8, right: 14)
            row.isLayoutMarginsRelativeArrangement = true
            row.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(row)
            NSLayoutConstraint.activate([
                row.topAnchor.constraint(equalTo: c.topAnchor),
                row.bottomAnchor.constraint(equalTo: c.bottomAnchor),
                row.leadingAnchor.constraint(equalTo: c.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: c.trailingAnchor),
            ])
            return c
        }()

        let texts = card.viewWithTag(1004) as! UIStackView
        let title = texts.arrangedSubviews[0] as! UILabel
        let sub = texts.arrangedSubviews[1] as! UILabel
        title.text = r.displayLabel()
        let time = Self.timeFormatter.string(from: Date(timeIntervalSince1970: r.last / 1000))
        sub.text = "\(URL(string: r.url)?.host ?? r.url) · \(time)"
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openUrl(recents[indexPath.row].url)
    }

    /// 左滑删除（原生 swipe action，直接删除不二次确认）
    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let del = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            guard let self else { done(false); return }
            self.store.remove(self.recents[indexPath.row].url)
            self.refreshRecents()
            self.toast("已删除")
            done(true)
        }
        del.backgroundColor = Theme.destructive
        return UISwipeActionsConfiguration(actions: [del])
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    // MARK: - 键盘避让

    private func setupKeyboardAvoidance() {
        let willShow = NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillChangeFrameNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let info = note.userInfo,
                  let end = (info[UIApplication.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue else { return }
            let overlap = max(0, self.view.bounds.maxY - self.view.convert(end, from: nil).minY)
            UIView.animate(withDuration: 0.25) {
                self.scrollView.contentInset.bottom = overlap
                self.scrollView.verticalScrollIndicatorInsets.bottom = overlap
            }
            if overlap > 0, self.inputUrl.isFirstResponder {
                self.scrollView.scrollRectToVisible(self.inputUrl.frame.insetBy(dx: -10, dy: -10), animated: true)
            }
        }
        keyboardObservers.append(willShow)
        let willHide = NotificationCenter.default.addObserver(
            forName: UIApplication.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            UIView.animate(withDuration: 0.25) {
                self.scrollView.contentInset.bottom = 0
                self.scrollView.verticalScrollIndicatorInsets.bottom = 0
            }
        }
        keyboardObservers.append(willHide)
    }

    deinit {
        keyboardObservers.forEach { NotificationCenter.default.removeObserver($0) }
    }

    // MARK: - 动作

    @objc private func onPaste() {
        let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            toast("剪贴板是空的")
        } else if Self.looksLikeRemoteLink(text) {
            openUrl(text)
        } else {
            inputUrl.text = text
        }
    }

    @objc private func onScan() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            presentScanner()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.presentScanner() : self?.toast("相机权限被拒绝")
                }
            }
        default:
            toast("请在系统设置里允许使用相机")
        }
    }

    @objc private func openSettingsUI() {
        let vc = SettingsViewController { }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    private func presentScanner() {
        let vc = QRScannerViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onFound = { [weak self] text in self?.openUrl(text) }
        present(vc, animated: true)
    }

    @objc private func onOpen() {
        openUrl(inputUrl.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        onOpen()
        return true
    }

    /// 冷启动时如果最近有会话，直接进入，省去每次再点一下
    private func autoResumeLastSession() {
        guard !Self.autoJumpedOnce else { return }
        Self.autoJumpedOnce = true
        guard let last = store.load().first else { return }
        toast("已恢复上次会话")
        launchWeb(last.url)
    }

    private func openUrl(_ raw: String) {
        var url = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if url.hasPrefix("zcode.z.ai") { url = "https://" + url }
        if url.isEmpty {
            toast("先粘贴或扫描远控链接")
            return
        }
        guard url.hasPrefix("http://") || url.hasPrefix("https://") else {
            toast("不是有效链接")
            return
        }
        if Self.looksLikeRemoteLink(url) {
            launchWeb(url)
            return
        }
        let alert = UIAlertController(
            title: "打开非远控链接？", message: url, preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "仍然打开", style: .default) { [weak self] _ in self?.launchWeb(url) })
        alert.addAction(UIAlertAction(title: "取消", style: .cancel))
        present(alert, animated: true)
    }

    private func launchWeb(_ url: String) {
        store.upsert(url)
        navigationController?.pushViewController(WebViewController(url: url), animated: true)
    }

    private func refreshRecents() {
        recents = store.load()
        recentsTable.reloadData()
        // 嵌在外层 ScrollView 里：表格高度随条目数走（每行 64）
        recentsTableHeight.constant = CGFloat(recents.count) * 64
        let empty = recents.isEmpty
        recentsTable.isHidden = empty
        recentsEmpty.isHidden = !empty
        recentsTitleRow.isHidden = false
    }

    private func requestNotifPermissionOnce() {
        guard !SettingsStore.shared.notifPermissionAsked else { return }
        SettingsStore.shared.notifPermissionAsked = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    private func toast(_ text: String) {
        toastLabel.text = " \(text) "
        UIView.animate(withDuration: 0.2) { self.toastLabel.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
    }

    private static func looksLikeRemoteLink(_ url: String) -> Bool {
        url.hasPrefix("https://") && url.contains("zcode.z.ai/remote")
    }
}
