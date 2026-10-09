import AVFoundation
import UIKit
import UserNotifications

/// 入口页：扫码 / 粘贴获取 ZCode 远控链接，展示最近会话卡片。
/// 远控链接即凭证，只保存在本机 UserDefaults，绝不上传。
final class EntryViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, UITextFieldDelegate {
    /// 进程内只自动跳转一次，避免从远控页返回入口后又被弹回去
    private static var autoJumpedOnce = false

    private let store = RecentStore.shared
    private var recents: [Recent] = []

    private let titleLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let inputUrl = UITextField()
    private let recentsHeader = UILabel()
    private let recentsEmpty = UILabel()
    private let toastLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)

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
        let header = UIStackView()
        header.axis = .vertical
        header.spacing = 6
        header.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(header)

        titleLabel.text = "ZCodeRemote"
        titleLabel.font = .systemFont(ofSize: 30, weight: .bold)
        titleLabel.textColor = Theme.text

        subtitleLabel.text = "把 ZCode 桌面端的「手机远控」网页，变成顺手的 iOS App"
        subtitleLabel.font = .systemFont(ofSize: 13)
        subtitleLabel.textColor = Theme.textSecondary
        subtitleLabel.numberOfLines = 0

        header.addArrangedSubview(titleLabel)
        header.addArrangedSubview(subtitleLabel)

        // 链接输入 + 操作按钮
        inputUrl.placeholder = "粘贴远控链接（https://zcode.z.ai/remote/...）"
        inputUrl.backgroundColor = Theme.input
        inputUrl.textColor = Theme.text
        inputUrl.attributedPlaceholder = NSAttributedString(
            string: inputUrl.placeholder ?? "",
            attributes: [.foregroundColor: Theme.textSecondary]
        )
        inputUrl.layer.cornerRadius = 10
        inputUrl.autocorrectionType = .no
        inputUrl.autocapitalizationType = .none
        inputUrl.keyboardType = .URL
        inputUrl.returnKeyType = .go
        inputUrl.delegate = self
        inputUrl.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 12, height: 1))
        inputUrl.leftViewMode = .always
        inputUrl.font = .systemFont(ofSize: 13)
        inputUrl.translatesAutoresizingMaskIntoConstraints = false
        inputUrl.heightAnchor.constraint(equalToConstant: 42).isActive = true
        view.addSubview(inputUrl)

        let pasteBtn = actionButton("粘贴", selector: #selector(onPaste))
        let scanBtn = actionButton("扫码", selector: #selector(onScan))
        let openBtn = actionButton("进入", selector: #selector(onOpen))
        openBtn.backgroundColor = Theme.accent
        openBtn.setTitleColor(.black, for: .normal)
        openBtn.titleLabel?.font = .boldSystemFont(ofSize: 15)

        let buttons = UIStackView(arrangedSubviews: [pasteBtn, scanBtn, openBtn])
        buttons.axis = .horizontal
        buttons.distribution = .fillEqually
        buttons.spacing = 10
        buttons.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(buttons)

        // 最近会话
        recentsHeader.text = "最近会话"
        recentsHeader.font = .boldSystemFont(ofSize: 15)
        recentsHeader.textColor = Theme.text
        recentsHeader.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recentsHeader)

        recentsEmpty.text = "还没有会话。扫描桌面端 ZCode 左下角「手机图标」的二维码开始。"
        recentsEmpty.font = .systemFont(ofSize: 13)
        recentsEmpty.textColor = Theme.textSecondary
        recentsEmpty.numberOfLines = 0
        recentsEmpty.textAlignment = .center
        recentsEmpty.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(recentsEmpty)

        tableView.dataSource = self
        tableView.delegate = self
        tableView.backgroundColor = .clear
        tableView.separatorColor = Theme.separator
        tableView.rowHeight = 64
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")
        tableView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(tableView)

        toastLabel.alpha = 0
        toastLabel.font = .systemFont(ofSize: 13)
        toastLabel.textColor = .black
        toastLabel.backgroundColor = Theme.accent
        toastLayer(toastLabel)

        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 20),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            inputUrl.topAnchor.constraint(equalTo: header.bottomAnchor, constant: 18),
            inputUrl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            inputUrl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

            buttons.topAnchor.constraint(equalTo: inputUrl.bottomAnchor, constant: 12),
            buttons.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            buttons.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            buttons.heightAnchor.constraint(equalToConstant: 42),

            recentsHeader.topAnchor.constraint(equalTo: buttons.bottomAnchor, constant: 24),
            recentsHeader.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),

            tableView.topAnchor.constraint(equalTo: recentsHeader.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),

            recentsEmpty.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recentsEmpty.topAnchor.constraint(equalTo: recentsHeader.bottomAnchor, constant: 30),
            recentsEmpty.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            recentsEmpty.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),

            toastLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            toastLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -30),
        ])
    }

    private func actionButton(_ title: String, selector: Selector) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(Theme.text, for: .normal)
        b.backgroundColor = Theme.card
        b.layer.cornerRadius = 10
        b.addTarget(self, action: selector, for: .touchUpInside)
        return b
    }

    private func toastLayer(_ label: UILabel) {
        label.layer.cornerRadius = 8
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        view.addSubview(label)
    }

    private func toast(_ text: String) {
        toastLabel.text = " \(text) "
        UIView.animate(withDuration: 0.2) { self.toastLabel.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
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
            inputUrl.becomeFirstResponder()
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
        let empty = recents.isEmpty
        recentsHeader.isHidden = empty
        recentsEmpty.isHidden = !empty
        tableView.isHidden = empty
        tableView.reloadData()
    }

    private func requestNotifPermissionOnce() {
        guard !SettingsStore.shared.notifPermissionAsked else { return }
        SettingsStore.shared.notifPermissionAsked = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - 表格

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int { recents.count }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)
        let r = recents[indexPath.row]
        var cfg = cell.defaultContentConfiguration()
        cfg.text = r.displayLabel()
        cfg.textProperties.color = Theme.text
        cfg.textProperties.font = .systemFont(ofSize: 15, weight: .medium)
        cfg.secondaryText = r.url
        cfg.secondaryTextProperties.color = Theme.textSecondary
        cfg.secondaryTextProperties.font = .systemFont(ofSize: 11)
        cfg.secondaryTextProperties.lineBreakMode = .byTruncatingMiddle
        cfg.textToSecondaryTextVerticalPadding = 4
        cell.contentConfiguration = cfg
        cell.backgroundColor = Theme.card
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        openUrl(recents[indexPath.row].url)
    }

    func tableView(_ tableView: UITableView,
                   trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let item = recents[indexPath.row]
        let del = UIContextualAction(style: .destructive, title: "删除") { [weak self] _, _, done in
            let alert = UIAlertController(
                title: "删除最近会话？", message: item.displayLabel(), preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: "删除", style: .destructive) { _ in
                self?.store.remove(item.url)
                self?.refreshRecents()
            })
            alert.addAction(UIAlertAction(title: "取消", style: .cancel))
            self?.present(alert, animated: true)
            done(false)
        }
        del.backgroundColor = Theme.destructive
        return UISwipeActionsConfiguration(actions: [del])
    }

    private static func looksLikeRemoteLink(_ url: String) -> Bool {
        url.hasPrefix("https://") && url.contains("zcode.z.ai/remote")
    }
}
