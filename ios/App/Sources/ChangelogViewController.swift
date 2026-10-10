import UIKit

/// 更新日志页：读 bundle 内的 CHANGELOG.md，极简 Markdown 渲染
/// （# 标题 / ## 小节标题 / - 列表项 / 空行分段），只服务这一个文件，不引第三方。
final class ChangelogViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = Theme.background
        title = "更新日志"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成", style: .done, target: self, action: #selector(onDone)
        )
        buildUI()
    }

    @objc private func onDone() {
        dismiss(animated: true)
    }

    private func buildUI() {
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            textView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        textView.attributedText = Self.render(Self.loadMarkdown())
    }

    private static func loadMarkdown() -> String {
        guard let url = Bundle.main.url(forResource: "CHANGELOG", withExtension: "md"),
              let raw = try? String(contentsOf: url, encoding: .utf8) else {
            return "# 更新日志\n\n（未找到 CHANGELOG.md）"
        }
        return raw
    }

    /// 极简渲染：# → 大标题，## → 小节，- → 列表项，其余正文
    private static func render(_ md: String) -> NSAttributedString {
        let para: [NSAttributedString.Key: Any] = [
            .foregroundColor: Theme.text,
            .font: UIFont.systemFont(ofSize: 14),
        ]
        let out = NSMutableAttributedString()
        for line in md.components(separatedBy: "\n") {
            let s = line.trimmingCharacters(in: .whitespaces)
            if s.isEmpty { continue }
            if s.hasPrefix("## ") {
                out.append(NSAttributedString(string: s.dropFirst(3) + "\n", attributes: [
                    .foregroundColor: Theme.accent,
                    .font: UIFont.systemFont(ofSize: 17, weight: .bold),
                ]))
                out.append(NSAttributedString(string: "\n", attributes: para))
            } else if s.hasPrefix("# ") {
                out.append(NSAttributedString(string: s.dropFirst(2) + "\n", attributes: [
                    .foregroundColor: Theme.text,
                    .font: UIFont.systemFont(ofSize: 22, weight: .bold),
                ]))
                out.append(NSAttributedString(string: "\n", attributes: para))
            } else if s.hasPrefix("- ") {
                out.append(NSAttributedString(string: "• " + s.dropFirst(2) + "\n", attributes: para))
            } else {
                out.append(NSAttributedString(string: s + "\n", attributes: para))
            }
        }
        out.addAttributes([
            .paragraphStyle: {
                let p = NSMutableParagraphStyle()
                p.lineSpacing = 5
                return p
            }(),
        ], range: NSRange(location: 0, length: out.length))
        return out
    }
}
