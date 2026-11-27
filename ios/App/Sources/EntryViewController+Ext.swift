//
//  EntryViewController+Ext.swift — 由 EntryViewController.swift 拆分（推送体积约束）
//
import UIKit

extension EntryViewController {
    func buildFooter() -> UIView {
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

        // 卡片容器（圆角），上下留 5pt 形成卡片间距
        let card = cell.viewWithTag(1001) ?? {
            let c = UIView()
            c.tag = 1001
            c.backgroundColor = Theme.card
            c.layer.cornerRadius = 14
            c.layer.borderWidth = 1
            c.layer.borderColor = UIColor.white.withAlphaComponent(0.04).cgColor
            c.translatesAutoresizingMaskIntoConstraints = false
            cell.contentView.addSubview(c)
            NSLayoutConstraint.activate([
                c.topAnchor.constraint(equalTo: cell.contentView.topAnchor, constant: 5),
                c.bottomAnchor.constraint(equalTo: cell.contentView.bottomAnchor, constant: -5),
                c.leadingAnchor.constraint(equalTo: cell.contentView.leadingAnchor),
                c.trailingAnchor.constraint(equalTo: cell.contentView.trailingAnchor),
            ])
            // 会话状态点：主色小圆
            let dot = UIView()
            dot.tag = 1007
            dot.backgroundColor = Theme.accent
            dot.layer.cornerRadius = 4
            dot.translatesAutoresizingMaskIntoConstraints = false
            c.addSubview(dot)
            NSLayoutConstraint.activate([
                dot.widthAnchor.constraint(equalToConstant: 8),
                dot.heightAnchor.constraint(equalToConstant: 8),
                dot.leadingAnchor.constraint(equalTo: c.leadingAnchor, constant: 14),
                dot.centerYAnchor.constraint(equalTo: c.centerYAnchor),
            ])
            let title = UILabel()
            title.tag = 1002
            title.font = .systemFont(ofSize: 15, weight: .semibold)
            title.textColor = Theme.text
            let sub = UILabel()
            sub.tag = 1003
            sub.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
            sub.textColor = Theme.textSecondary
            let texts = UIStackView(arrangedSubviews: [title, sub])
            texts.tag = 1004
            texts.axis = .vertical
            texts.spacing = 3
            let chevron = UIImageView(image: UIImage(
                systemName: "chevron.right",
                withConfiguration: UIImage.SymbolConfiguration(pointSize: 12, weight: .semibold)
            ))
            chevron.tag = 1005
            chevron.tintColor = Theme.textSecondary
            chevron.contentMode = .center
            let row = UIStackView(arrangedSubviews: [dot, texts, chevron])
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
            texts.translatesAutoresizingMaskIntoConstraints = false
            texts.widthAnchor.constraint(lessThanOrEqualTo: c.widthAnchor, multiplier: 0.8).isActive = true
            return c
        }()

        let row = card.viewWithTag(1006) as! UIStackView
        let texts = row.arrangedSubviews[1] as! UIStackView
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

    static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MM-dd HH:mm"
        return f
    }()

    // MARK: - 键盘避让

    func setupKeyboardAvoidance() {
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

    // MARK: - 动作

    @objc func onPaste() {
        let text = UIPasteboard.general.string?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if text.isEmpty {
            toast("剪贴板是空的")
        } else if Self.looksLikeRemoteLink(text) {
            openUrl(text)
        } else {
            inputUrl.text = text
        }
    }

    @objc func onScan() {
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

    @objc func openSettingsUI() {
        let vc = SettingsViewController { }
        present(UINavigationController(rootViewController: vc), animated: true)
    }

    func presentScanner() {
        let vc = QRScannerViewController()
        vc.modalPresentationStyle = .fullScreen
        vc.onFound = { [weak self] text in self?.openUrl(text) }
        present(vc, animated: true)
    }

    @objc func onOpen() {
        openUrl(inputUrl.text ?? "")
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        onOpen()
        return true
    }

    /// 冷启动时如果最近有会话，直接进入，省去每次再点一下
    func autoResumeLastSession() {
        guard !Self.autoJumpedOnce else { return }
        Self.autoJumpedOnce = true
        guard let last = store.load().first else { return }
        toast("已恢复上次会话")
        launchWeb(last.url)
    }

    func openUrl(_ raw: String) {
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

    func launchWeb(_ url: String) {
        store.upsert(url)
        navigationController?.pushViewController(WebViewController(url: url), animated: true)
    }

    func refreshRecents() {
        recents = store.load()
        recentsTable.reloadData()
        // 嵌在外层 ScrollView 里：表格高度随条目数走（每行 68）
        recentsTableHeight.constant = CGFloat(recents.count) * 68
        let empty = recents.isEmpty
        recentsTable.isHidden = empty
        recentsEmpty.isHidden = !empty
        recentsTitleRow.isHidden = false
    }

    func requestNotifPermissionOnce() {
        guard !SettingsStore.shared.notifPermissionAsked else { return }
        SettingsStore.shared.notifPermissionAsked = true
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func toast(_ text: String) {
        toastLabel.text = "  \(text)  "
        UIView.animate(withDuration: 0.2) { self.toastLabel.alpha = 1 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { [weak self] in
            UIView.animate(withDuration: 0.3) { self?.toastLabel.alpha = 0 }
        }
    }

    /// 远控链接判定。zcode.z.ai 已加语言前缀路由（/remote 会 307 到 /cn/remote 等），
    /// 桌面端二维码里的链接可能是 /cn/remote、/en/remote 形态——旧的 contains 判定
    /// 会把新版二维码误报成"非远控链接"，重新扫码配对时多一道吓人的确认框。
    static func looksLikeRemoteLink(_ url: String) -> Bool {
        guard url.hasPrefix("https://") else { return false }
        if url.contains("zcode.z.ai/remote") { return true }
        guard let u = URL(string: url), u.host?.lowercased() == "zcode.z.ai" else { return false }
        let path = u.path
        if path == "/remote" || path.hasPrefix("/remote/") { return true }
        return localeRemotePath.firstMatch(in: path, range: NSRange(path.startIndex..., in: path)) != nil
    }

    /// /cn/remote、/en/remote、/zh-cn/remote 等语言前缀形态
    static let localeRemotePath = try! NSRegularExpression(
        pattern: "^/[a-z]{2}(-[a-z]{2})?/remote(/|$)"
    )
}