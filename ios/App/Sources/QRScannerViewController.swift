import AVFoundation
import UIKit

/// 扫码页（v3 重设计）：取景框四角括号 + 暗遮罩挖孔 + 玻璃提示卡。
/// AVFoundation 元数据识别，只认二维码。
final class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onFound: ((String) -> Void)?

    private let session = AVCaptureSession()
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let hintLabel = UILabel()
    private let closeButton = UIButton(type: .system)
    private let maskLayer = CAShapeLayer()
    private let bracketLayer = CAShapeLayer()
    private let sessionQueue = DispatchQueue(label: "zcode.qr.session")

    /// 扫码不工作的根因修复：setupSession/startRunning 从未被调用（拆分时丢了接线）。
    /// viewDidAppear 里启动（bounds 已定型，取景框挖孔几何正确）；
    /// startRunning 放后台队列避免主线程卡顿；previewLayer 已存在则不重复建 session。
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if previewLayer == nil { setupSession() }
        guard !session.isRunning else { return }
        let s = session
        sessionQueue.async {
            s.startRunning()
        }
    }

    /// 取景框（挖孔区）
    private var viewfinderRect: CGRect {
        let side = min(view.bounds.width, view.bounds.height) * 0.66
        let cx = view.bounds.midX
        let cy = view.bounds.midY - view.safeAreaInsets.top * 0.3
        return CGRect(x: cx - side / 2, y: cy - side / 2, width: side, height: side)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        // 关闭钮：右上角玻璃圆
        let cfg = UIImage.SymbolConfiguration(pointSize: 14, weight: .bold)
        closeButton.setImage(UIImage(systemName: "xmark", withConfiguration: cfg), for: .normal)
        closeButton.tintColor = .white
        closeButton.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        closeButton.layer.cornerRadius = 21
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(onClose), for: .touchUpInside)
        view.addSubview(closeButton)

        // 提示卡：半透明玻璃胶囊
        let hintCard = UIView()
        hintCard.backgroundColor = UIColor(white: 0.08, alpha: 0.72)
        hintCard.layer.cornerRadius = 14
        hintCard.layer.borderWidth = 1
        hintCard.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
        hintCard.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintCard)

        hintLabel.text = "对准桌面端 ZCode 左下角「手机图标」弹出的二维码"
        hintLabel.textColor = UIColor(white: 0.92, alpha: 1)
        hintLabel.font = .systemFont(ofSize: 13, weight: .medium)
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 0
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintCard.addSubview(hintLabel)

        NSLayoutConstraint.activate([
            closeButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            closeButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            closeButton.widthAnchor.constraint(equalToConstant: 42),
            closeButton.heightAnchor.constraint(equalToConstant: 42),

            hintCard.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 28),
            hintCard.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -28),
            hintCard.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -36),

            hintLabel.topAnchor.constraint(equalTo: hintCard.topAnchor, constant: 12),
            hintLabel.bottomAnchor.constraint(equalTo: hintCard.bottomAnchor, constant: -12),
            hintLabel.leadingAnchor.constraint(equalTo: hintCard.leadingAnchor, constant: 16),
            hintLabel.trailingAnchor.constraint(equalTo: hintCard.trailingAnchor, constant: -16),
        ])

        // 暗遮罩 + 取景框挖孔（even-odd）
        maskLayer.fillRule = .evenOdd
        maskLayer.fillColor = UIColor.black.withAlphaComponent(0.55).cgColor
        view.layer.addSublayer(maskLayer)

        // 四角括号：主色圆头描边
        bracketLayer.fillColor = UIColor.clear.cgColor
        bracketLayer.strokeColor = Theme.accent.cgColor
        bracketLayer.lineWidth = 3.5
        bracketLayer.lineCap = .round
        view.layer.addSublayer(bracketLayer)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
        refreshOverlay()
    }

    private func refreshOverlay() {
        let hole = viewfinderRect.insetBy(dx: 10, dy: 10)
        let big = UIBezierPath(rect: view.bounds)
        big.append(UIBezierPath(roundedRect: hole, cornerRadius: 18))
        maskLayer.path = big.cgPath

        // 括号画在挖孔矩形四角，臂长 26
        let arm: CGFloat = 26
        let p = UIBezierPath()
        let corners: [(CGPoint, CGPoint, CGPoint)] = [
            // (起点, 折点, 终点)：水平臂→竖直臂
            (CGPoint(x: hole.minX + arm, y: hole.minY), CGPoint(x: hole.minX, y: hole.minY), CGPoint(x: hole.minX, y: hole.minY + arm)),
            (CGPoint(x: hole.maxX - arm, y: hole.minY), CGPoint(x: hole.maxX, y: hole.minY), CGPoint(x: hole.maxX, y: hole.minY + arm)),
            (CGPoint(x: hole.minX + arm, y: hole.maxY), CGPoint(x: hole.minX, y: hole.maxY), CGPoint(x: hole.minX, y: hole.maxY - arm)),
            (CGPoint(x: hole.maxX - arm, y: hole.maxY), CGPoint(x: hole.maxX, y: hole.maxY), CGPoint(x: hole.maxX, y: hole.maxY - arm)),
        ]
        for (a, b, c) in corners {
            p.move(to: a)
            p.addLine(to: b)
            p.addLine(to: c)
        }
        bracketLayer.path = p.cgPath
    }

    @objc private func onClose() {
        // 停会话关摄像头（不停的话返回后指示灯常亮）
        let s = session
        sessionQueue.async {
            if s.isRunning { s.stopRunning() }
        }
        dismiss(animated: true)
    }

    private func setupSession() {
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { [weak self] in
                self?.hintLabel.text = "无法访问相机"
            }
            return
        }
        session.beginConfiguration()
        session.addInput(input)
        let output = AVCaptureMetadataOutput()
        guard session.canAddOutput(output) else {
            session.commitConfiguration()
            return
        }
        session.addOutput(output)
        output.setMetadataObjectsDelegate(self, queue: .main)
        output.metadataObjectTypes = [.qr]
        session.commitConfiguration()

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let layer = AVCaptureVideoPreviewLayer(session: self.session)
            layer.videoGravity = .resizeAspectFill
            layer.frame = self.view.bounds
            self.view.layer.insertSublayer(layer, at: 0)
            self.previewLayer = layer
            self.refreshOverlay()
            self.view.bringSubviewToFront(self.closeButton)
            self.view.bringSubviewToFront(self.hintLabel.superview ?? self.hintLabel)
        }
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput,
                        didOutput metadataObjects: [AVMetadataObject],
                        from connection: AVCaptureConnection) {
        guard let obj = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              obj.type == .qr, let value = obj.stringValue else { return }
        guard !isClosing else { return }
        isClosing = true
        session.stopRunning()
        // 必须先关扫码页再回调:fullScreen modal 盖着时立即 push 会话页,
        // push 转场会被随后的 dismiss 打断,表现为扫码后界面不动(真机踩坑)
        let found = onFound
        dismiss(animated: true) { found?(value) }
    }

    private var isClosing = false
}
