import UIKit

/// 画布节点卡片：支持拖动 / 右下角缩放 / 提示词编辑 / 生图
final class NodeView: UIView {

    // MARK: - 状态
    private var node: CanvasNode
    private let state: CanvasState
    private weak var scrollView: CanvasScrollView?
    private var isSelected = false

    // 拖拽
    private var isDragging = false
    private var dragStartPoint = CGPoint.zero
    private var dragOrigin = CGPoint.zero

    // 缩放
    private var isResizing = false
    private var resizeStartSize = CGSize.zero
    private var resizeStartOrigin = CGPoint.zero

    // MARK: - 子视图
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let promptTextView = UITextView()
    private let imageView = UIImageView()
    private let generateButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let resizeHandle = UIView()
    private let selectionBorder = UIView()

    private var loadedImageURL: String?
    private var isEditingPrompt = false
    private var gestureDelegate: NodeGestureDelegate?

    // MARK: - 初始化
    init(node: CanvasNode, state: CanvasState, scrollView: CanvasScrollView?) {
        self.node = node
        self.state = state
        self.scrollView = scrollView
        super.init(frame: CGRect(origin: node.position, size: node.size))
        setupUI()
        applyContent()
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - UI 构建
    private func setupUI() {
        backgroundColor = .clear

        cardView.backgroundColor = UIColor(white: 0.115, alpha: 1)
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 1
        cardView.layer.borderColor = UIColor(white: 0.24, alpha: 1).cgColor
        cardView.layer.shadowColor = UIColor.black.cgColor
        cardView.layer.shadowOpacity = 0.45
        cardView.layer.shadowRadius = 10
        cardView.layer.shadowOffset = CGSize(width: 0, height: 4)
        addSubview(cardView)

        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = UIColor(white: 0.72, alpha: 1)
        cardView.addSubview(titleLabel)

        deleteButton.setTitle("✕", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
        deleteButton.tintColor = UIColor(white: 0.65, alpha: 1)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        cardView.addSubview(deleteButton)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.backgroundColor = UIColor(white: 0.19, alpha: 1)
        cardView.addSubview(imageView)

        promptTextView.font = .systemFont(ofSize: 13)
        promptTextView.textColor = .label
        promptTextView.backgroundColor = UIColor(white: 0.17, alpha: 1)
        promptTextView.layer.cornerRadius = 8
        promptTextView.textContainerInset = UIEdgeInsets(top: 6, left: 4, bottom: 6, right: 4)
        promptTextView.delegate = self
        promptTextView.isScrollEnabled = true
        cardView.addSubview(promptTextView)

        generateButton.setTitle("✨ 生成", for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        generateButton.layer.cornerRadius = 10
        generateButton.backgroundColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        generateButton.setTitleColor(.black, for: .normal)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        cardView.addSubview(generateButton)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textAlignment = .center
        statusLabel.textColor = UIColor(white: 0.55, alpha: 1)
        statusLabel.numberOfLines = 1
        cardView.addSubview(statusLabel)

        resizeHandle.backgroundColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 0.85)
        resizeHandle.layer.cornerRadius = 5
        resizeHandle.isUserInteractionEnabled = true
        resizeHandle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(handleResize(_:))))
        cardView.addSubview(resizeHandle)

        selectionBorder.layer.cornerRadius = 16
        selectionBorder.layer.borderWidth = 2.5
        selectionBorder.layer.borderColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1).cgColor
        selectionBorder.backgroundColor = .clear
        selectionBorder.isUserInteractionEnabled = false
        selectionBorder.isHidden = true
        addSubview(selectionBorder)

        gestureDelegate = NodeGestureDelegate(owner: self)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        pan.delegate = gestureDelegate
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.delegate = gestureDelegate
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    // MARK: - 布局
    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width
        let h = bounds.height
        cardView.frame = bounds
        selectionBorder.frame = bounds

        titleLabel.frame = CGRect(x: 14, y: 10, width: w - 54, height: 20)
        deleteButton.frame = CGRect(x: w - 40, y: 7, width: 30, height: 30)

        let isImage = node.kind == .image
        var cursorY: CGFloat = 36

        if isImage {
            imageView.isHidden = false
            let imageH = max(90, h - 210)
            imageView.frame = CGRect(x: 12, y: cursorY, width: w - 24, height: imageH)
            cursorY += imageH + 10
        } else {
            imageView.isHidden = true
            imageView.image = nil
        }

        let btnH: CGFloat = 38
        let statusH: CGFloat = 16
        let btnTop = h - btnH - statusH - 18
        generateButton.frame = CGRect(x: 12, y: btnTop, width: w - 24, height: btnH)
        statusLabel.frame = CGRect(x: 12, y: btnTop + btnH + 2, width: w - 24, height: statusH)

        let promptH = max(44, btnTop - cursorY - 8)
        promptTextView.frame = CGRect(x: 12, y: cursorY, width: w - 24, height: promptH)

        resizeHandle.frame = CGRect(x: w - 22, y: h - 22, width: 18, height: 18)
    }

    // MARK: - 外部同步
    func sync(node: CanvasNode, isSelected: Bool) {
        self.node = node
        self.isSelected = isSelected
        selectionBorder.isHidden = !isSelected
        deleteButton.alpha = isSelected ? 1.0 : 0.35

        // 拖拽/缩放过程中不覆写 frame（避免抖动）
        if !isDragging && !isResizing {
            let target = CGRect(origin: node.position, size: node.size)
            if target != frame { frame = target }
        }

        if !isEditingPrompt && promptTextView.text != node.prompt {
            promptTextView.text = node.prompt
        }
        applyContent()
    }

    private func applyContent() {
        titleLabel.text = node.kind == .image ? "🖼️ AI 图片" : "📝 文字"

        switch node.status {
        case .generating:
            generateButton.setTitle("⏳ 生成中...", for: .normal)
            generateButton.isEnabled = false
            statusLabel.text = "AI 正在创作中…"
            statusLabel.textColor = UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)
        case .done:
            generateButton.setTitle("✨ 重新生成", for: .normal)
            generateButton.isEnabled = true
            if node.kind == .image {
                let hasImage = node.imageName != nil || node.resultImageURL != nil
                statusLabel.text = hasImage ? "已完成" : "输入提示词后点击生成"
                statusLabel.textColor = UIColor(white: 0.55, alpha: 1)
                loadImageIfNeeded()
            } else {
                statusLabel.text = "文字节点"
                statusLabel.textColor = UIColor(white: 0.55, alpha: 1)
            }
        case .error:
            generateButton.setTitle("✨ 重试", for: .normal)
            generateButton.isEnabled = true
            statusLabel.text = "❌ " + (node.errorMessage ?? "未知错误")
            statusLabel.textColor = .systemRed
        case .idle:
            generateButton.setTitle("✨ 生成", for: .normal)
            generateButton.isEnabled = true
            statusLabel.text = "输入提示词后点击生成"
            statusLabel.textColor = UIColor(white: 0.55, alpha: 1)
        }
    }

    // MARK: - 图片加载
    private func loadImageIfNeeded() {
        guard node.kind == .image else { return }
        // 1) 本地缓存优先（离线可看、重启不丢、不用重复下载）
        if let name = node.imageName, CanvasStore.readImage(name) != nil {
            let key = "local:" + name
            guard loadedImageURL != key else { return }
            loadedImageURL = key
            let data = CanvasStore.readImage(name)
            imageView.image = data.flatMap { UIImage(data: $0) }
            setNeedsLayout()
            return
        }
        guard let raw = node.resultImageURL,
              loadedImageURL != raw else { return }
        loadedImageURL = raw
        let apiKey = state.config.apiKey
        let nodeID = node.id

        Task { [weak self] in
            guard let self else { return }
            var image: UIImage?
            if raw.hasPrefix("data:") {
                if let comma = raw.firstIndex(of: ",") {
                    let payload = String(raw[raw.index(after: raw.startIndex)..<comma])
                    let body = String(raw[raw.index(after: comma)...])
                    if payload.contains("base64"), let data = Data(base64Encoded: body) {
                        image = UIImage(data: data)
                    }
                }
            } else if let url = URL(string: raw) {
                var request = URLRequest(url: url)
                request.timeoutInterval = 30
                if !apiKey.isEmpty {
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                }
                if let (data, _) = try? await URLSession.shared.data(for: request) {
                    image = UIImage(data: data)
                    // 下载成功 → 回填本地缓存，下次直接读盘
                    if image != nil {
                        await MainActor.run { self.state.cacheImage(data, for: nodeID) }
                    }
                }
            }
            await MainActor.run {
                self.imageView.image = image
                self.setNeedsLayout()
            }
        }
    }

    // MARK: - 手势处理
    @objc private func handleDrag(_ pan: UIPanGestureRecognizer) {
        guard let container = scrollView?.contentView else { return }
        // 编辑提示词时不触发拖拽
        if isEditingPrompt && pan.state == .began { return }

        let point = pan.location(in: container)
        switch pan.state {
        case .began:
            isDragging = true
            dragStartPoint = point
            dragOrigin = node.position
            scrollView?.panGestureRecognizer.isEnabled = false
            state.selectNode(node.id)
        case .changed where isDragging:
            let dx = point.x - dragStartPoint.x
            let dy = point.y - dragStartPoint.y
            let newPos = CGPoint(x: dragOrigin.x + dx, y: dragOrigin.y + dy)
            node.position = newPos
            frame.origin = newPos
            state.updateNodePosition(node.id, position: newPos)
        case .ended, .cancelled, .failed:
            isDragging = false
            scrollView?.panGestureRecognizer.isEnabled = true
        default:
            break
        }
    }

    @objc private func handleResize(_ pan: UIPanGestureRecognizer) {
        guard let container = scrollView?.contentView else { return }
        let point = pan.location(in: container)
        switch pan.state {
        case .began:
            isResizing = true
            resizeStartSize = node.size
            resizeStartOrigin = node.position
            scrollView?.panGestureRecognizer.isEnabled = false
        case .changed where isResizing:
            let dx = point.x - (resizeStartOrigin.x + resizeStartSize.width)
            let dy = point.y - (resizeStartOrigin.y + resizeStartSize.height)
            let newSize = CGSize(width: max(200, resizeStartSize.width + dx),
                                height: max(180, resizeStartSize.height + dy))
            node.size = newSize
            frame.size = newSize
            state.updateNodeSize(node.id, size: newSize)
        case .ended, .cancelled, .failed:
            isResizing = false
            scrollView?.panGestureRecognizer.isEnabled = true
        default:
            break
        }
    }

    @objc private func handleTap() {
        state.selectNode(node.id)
    }

    @objc private func generateTapped() {
        state.updatePrompt(node.id, promptTextView.text)
        Task { await state.generateImage(for: node.id) }
    }

    @objc private func deleteTapped() {
        state.deleteNode(node.id)
    }

    // MARK: - 手势判定（供 NodeGestureDelegate 调用）
    func shouldBeginDrag(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer is UIPanGestureRecognizer {
            // 正在编辑提示词 → 不拖拽
            if isEditingPrompt { return false }
            // 点在按钮/输入框上 → 不拖拽
            if let view = gestureRecognizer.view {
                let point = gestureRecognizer.location(in: view)
                if let touched = view.hitTest(point, with: nil),
                   touched is UIControl || touched === promptTextView {
                    return false
                }
            }
        }
        return true
    }
}

/// 手势代理：独立成对象，避免与 UIView 自带的 gestureRecognizerShouldBegin 冲突
private final class NodeGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var owner: NodeView?

    init(owner: NodeView) {
        self.owner = owner
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        return owner?.shouldBeginDrag(gestureRecognizer) ?? true
    }

    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}

// MARK: - UITextViewDelegate
extension NodeView: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isEditingPrompt = true
        state.selectNode(node.id)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        isEditingPrompt = false
        state.updatePrompt(node.id, textView.text)
    }

    func textViewDidChange(_ textView: UITextView) {
        state.updatePrompt(node.id, textView.text)
    }
}
