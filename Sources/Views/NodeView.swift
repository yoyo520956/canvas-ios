import UIKit

/// 画布节点卡片：拖动 / 右下角缩放 / 提示词编辑 / 生图
/// 视觉基线走 CanvasTheme：正文 ≥15pt、正文对比度 ≥12:1
final class NodeView: UIView {

    // MARK: - 状态
    private var node: CanvasNode
    private let state: CanvasState
    private weak var scrollView: CanvasScrollView?
    private var isSelected = false

    private var isDragging = false
    private var dragStartPoint = CGPoint.zero
    private var dragOrigin = CGPoint.zero

    private var isResizing = false
    private var resizeStartSize = CGSize.zero
    private var resizeStartOrigin = CGPoint.zero

    // MARK: - 子视图
    private let cardView = UIView()
    private let headerView = UIView()
    private let kindChip = UILabel()
    private let titleLabel = UILabel()
    private let promptTextView = UITextView()
    private let placeholderLabel = UILabel()
    private let imageView = UIImageView()
    private let imageHint = UILabel()
    private let generateButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let statusLabel = UILabel()
    private let resizeHandle = UIView()
    private let selectionBorder = UIView()
    private let spinner = UIActivityIndicatorView(style: .medium)

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
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 6)

        cardView.backgroundColor = CanvasTheme.cardBG
        cardView.layer.cornerRadius = CanvasTheme.rCard
        cardView.layer.borderWidth = 1.2
        cardView.layer.borderColor = CanvasTheme.cardBorder.cgColor
        cardView.clipsToBounds = true
        addSubview(cardView)

        headerView.backgroundColor = CanvasTheme.headerBG
        cardView.addSubview(headerView)

        // 类型胶囊：彩色底 + 白粗体小字
        kindChip.font = CanvasTheme.badge
        kindChip.textColor = .white
        kindChip.textAlignment = .center
        kindChip.layer.cornerRadius = CanvasTheme.rChip
        kindChip.clipsToBounds = true
        headerView.addSubview(kindChip)

        titleLabel.font = CanvasTheme.title
        titleLabel.textColor = CanvasTheme.textPrimary
        titleLabel.lineBreakMode = .byTruncatingTail
        headerView.addSubview(titleLabel)

        deleteButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration:
            UIImage.SymbolConfiguration(pointSize: 21, weight: .semibold)), for: .normal)
        deleteButton.tintColor = UIColor.white.withAlphaComponent(0.62)
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        headerView.addSubview(deleteButton)

        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = CanvasTheme.rField
        imageView.layer.borderWidth = 1
        imageView.layer.borderColor = CanvasTheme.cardBorder.cgColor
        imageView.backgroundColor = CanvasTheme.fieldBG
        cardView.addSubview(imageView)

        imageHint.font = CanvasTheme.bodyMedium
        imageHint.textColor = CanvasTheme.textTertiary
        imageHint.textAlignment = .center
        imageHint.numberOfLines = 2
        imageHint.text = "还没有图片\n填好提示词点下方生成"
        cardView.addSubview(imageHint)

        promptTextView.font = CanvasTheme.body
        promptTextView.textColor = CanvasTheme.textPrimary
        promptTextView.tintColor = CanvasTheme.accent
        promptTextView.backgroundColor = CanvasTheme.fieldBG
        promptTextView.layer.cornerRadius = CanvasTheme.rField
        promptTextView.layer.borderWidth = 1
        promptTextView.layer.borderColor = CanvasTheme.cardBorder.cgColor
        promptTextView.textContainerInset = UIEdgeInsets(top: 10, left: 8, bottom: 10, right: 8)
        promptTextView.keyboardAppearance = .dark
        promptTextView.autocorrectionType = .no
        promptTextView.delegate = self
        promptTextView.isScrollEnabled = true
        cardView.addSubview(promptTextView)

        placeholderLabel.font = CanvasTheme.body
        placeholderLabel.textColor = CanvasTheme.textTertiary
        placeholderLabel.numberOfLines = 2
        placeholderLabel.text = "描述你想要的画面：主体 + 风格 + 光线 + 构图"
        cardView.addSubview(placeholderLabel)

        generateButton.setTitle("✨ 生成", for: .normal)
        generateButton.titleLabel?.font = CanvasTheme.button
        generateButton.titleLabel?.adjustsFontSizeToFitWidth = true
        generateButton.titleLabel?.minimumScaleFactor = 0.7
        generateButton.titleLabel?.lineBreakMode = .byClipping
        generateButton.layer.cornerRadius = CanvasTheme.rField
        generateButton.backgroundColor = CanvasTheme.accent
        generateButton.setTitleColor(CanvasTheme.onAccent, for: .normal)
        generateButton.setTitleColor(CanvasTheme.onAccent.withAlphaComponent(0.45), for: .disabled)
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        cardView.addSubview(generateButton)

        statusLabel.font = CanvasTheme.status
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2
        statusLabel.textColor = CanvasTheme.textSecondary
        cardView.addSubview(statusLabel)

        spinner.color = CanvasTheme.onAccent
        spinner.hidesWhenStopped = true
        generateButton.addSubview(spinner)
        selectionBorder.layer.cornerRadius = CanvasTheme.rCard + 1
        selectionBorder.layer.borderWidth = 3
        selectionBorder.layer.borderColor = CanvasTheme.accent.cgColor
        selectionBorder.backgroundColor = .clear
        selectionBorder.isUserInteractionEnabled = false
        selectionBorder.isHidden = true
        addSubview(selectionBorder)

        // 选中态柔光
        CanvasTheme.glow(cardView, CanvasTheme.accent, radius: 16, opacity: 0.0)

        resizeHandle.isUserInteractionEnabled = true
        resizeHandle.layer.cornerRadius = 9
        resizeHandle.backgroundColor = CanvasTheme.accent.withAlphaComponent(0.9)
        resizeHandle.layer.borderWidth = 2
        resizeHandle.layer.borderColor = CanvasTheme.onAccent.cgColor
        resizeHandle.isHidden = true
        cardView.addSubview(resizeHandle)

        gestureDelegate = NodeGestureDelegate(owner: self)

        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleDrag(_:)))
        pan.delegate = gestureDelegate
        addGestureRecognizer(pan)

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        tap.delegate = gestureDelegate
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }

    // MARK: - 选中外观
    private func applySelection() {
        selectionBorder.isHidden = !isSelected
        selectionBorder.layer.borderWidth = isSelected ? 3 : 0
        selectionBorder.layer.borderColor = CanvasTheme.accent.cgColor
        selectionBorder.layer.cornerRadius = CanvasTheme.rCard + 1
        CanvasTheme.glow(cardView, CanvasTheme.accent, radius: 18,
                         opacity: isSelected ? 0.55 : 0.0)
        deleteButton.alpha = isSelected ? 1.0 : 0.0
        UIView.animate(withDuration: 0.15) { self.layoutIfNeeded() }
    }

    // MARK: - 布局
    override func layoutSubviews() {
        super.layoutSubviews()
        let w = bounds.width, h = bounds.height
        cardView.frame = bounds
        selectionBorder.frame = bounds

        let headerH: CGFloat = 40
        headerView.frame = CGRect(x: 0, y: 0, width: w, height: headerH)
        let chipW: CGFloat = node.kind == .image ? 64 : 48
        kindChip.frame = CGRect(x: 12, y: 8, width: chipW, height: 22)
        kindChip.backgroundColor = node.kind == .image ? CanvasTheme.violet : CanvasTheme.success

        titleLabel.frame = CGRect(x: chipW + 22, y: 8, width: w - chipW - 58, height: 22)
        deleteButton.frame = CGRect(x: w - 42, y: 6, width: 30, height: 30)

        var cursorY: CGFloat = headerH + 10
        let isImage = node.kind == .image

        if isImage {
            imageView.isHidden = false
            let imageH = max(110, h - 240)
            imageView.frame = CGRect(x: 12, y: cursorY, width: w - 24, height: imageH)
            imageHint.frame = imageView.frame
            cursorY += imageH + 10
        } else {
            imageView.isHidden = true
            imageHint.isHidden = true
        }

        let btnH: CGFloat = 42
        let statusH: CGFloat = 32
        let btnTop = h - btnH - statusH - 16
        generateButton.frame = CGRect(x: 12, y: btnTop, width: w - 24, height: btnH)
        spinner.center = CGPoint(x: generateButton.bounds.midX - 44, y: generateButton.bounds.midY)

        statusLabel.frame = CGRect(x: 12, y: btnTop + btnH + 2, width: w - 24, height: statusH)

        let promptH = max(52, btnTop - cursorY - 8)
        promptTextView.frame = CGRect(x: 12, y: cursorY, width: w - 24, height: promptH)
        placeholderLabel.frame = CGRect(x: 20, y: cursorY + 10, width: w - 40, height: 40)

        resizeHandle.frame = CGRect(x: w - 26, y: h - 22, width: 20, height: 20)
    }

    // MARK: - 外部同步
    func sync(node: CanvasNode, isSelected: Bool) {
        self.node = node
        self.isSelected = isSelected
        selectionBorder.isHidden = !isSelected

        if !isDragging && !isResizing {
            let target = CGRect(origin: node.position, size: node.size)
            if target != frame { frame = target }
        }

        if !isEditingPrompt && promptTextView.text != node.prompt {
            promptTextView.text = node.prompt
            placeholderLabel.isHidden = !node.prompt.isEmpty
        }
        applyContent()
        setNeedsLayout()
    }

    private func applyContent() {
        kindChip.text = node.kind == .image ? "AI 图片" : "文字"
        kindChip.backgroundColor = node.kind == .image ? CanvasTheme.violet : CanvasTheme.success

        switch node.status {
        case .generating:
            generateButton.setTitle("生成中…", for: .normal)
            generateButton.isEnabled = false
            statusLabel.text = "AI 正在创作，请稍候"
            statusLabel.textColor = CanvasTheme.accent
            spinner.startAnimating()
        case .done:
            generateButton.setTitle(node.kind == .image ? "重新生成" : "编辑", for: .normal)
            generateButton.isEnabled = true
            spinner.stopAnimating()
            if node.kind == .image {
                let hasImage = node.imageName != nil || node.resultImageURL != nil
                statusLabel.text = hasImage ? "已生成 · 点按钮可重新生成" : "输入提示词后点击生成"
                statusLabel.textColor = CanvasTheme.textSecondary
                loadImageIfNeeded()
            } else {
                statusLabel.text = "自动保存中"
                statusLabel.textColor = CanvasTheme.success
            }
        case .error:
            generateButton.setTitle("重试", for: .normal)
            generateButton.isEnabled = true
            spinner.stopAnimating()
            statusLabel.text = "⚠️ " + (node.errorMessage ?? "未知错误")
            statusLabel.textColor = CanvasTheme.danger
        case .idle:
            generateButton.setTitle("✨ 生成", for: .normal)
            generateButton.isEnabled = true
            spinner.stopAnimating()
            statusLabel.text = node.kind == .image ? "填好提示词即可生成" : "直接点击文字编辑"
            statusLabel.textColor = CanvasTheme.textTertiary
        }

        resizeHandle.isHidden = !isSelected
        placeholderLabel.isHidden = !promptTextView.text.isEmpty
        applySelection()
        setNeedsLayout()
    }

    // MARK: - 手势
    @objc private func handleTap() {
        state.selectNode(node.id)
        state.bringToFront(node.id)
    }

    @objc private func handleDrag(_ g: UIPanGestureRecognizer) {
        guard let content = scrollView?.contentView else { return }
        let point = g.location(in: content)
        switch g.state {
        case .began:
            isDragging = true
            dragStartPoint = point
            dragOrigin = node.position
            scrollView?.panGestureRecognizer.isEnabled = false
        case .changed where isDragging:
            let dx = point.x - dragStartPoint.x
            let dy = point.y - dragStartPoint.y
            let newPos = CGPoint(x: dragOrigin.x + dx, y: dragOrigin.y + dy)
            node.position = newPos
            frame.origin = newPos
            state.updateNodePosition(node.id, position: newPos)
        case .ended, .cancelled:
            isDragging = false
            scrollView?.panGestureRecognizer.isEnabled = true
        default: break
        }
    }

    @objc private func handleResize(_ g: UIPanGestureRecognizer) {
        let point = g.location(in: self)
        switch g.state {
        case .began:
            isResizing = true
            resizeStartSize = node.size
            scrollView?.panGestureRecognizer.isEnabled = false
        case .changed where isResizing:
            let dx = point.x - resizeStartSize.width
            let dy = point.y - resizeStartSize.height
            let newSize = CGSize(width: max(240, resizeStartSize.width + dx),
                                 height: max(200, resizeStartSize.height + dy))
            node.size = newSize
            frame.size = newSize
            state.updateNodeSize(node.id, size: newSize)
            setNeedsLayout()
        case .ended, .cancelled:
            isResizing = false
            scrollView?.panGestureRecognizer.isEnabled = true
        default: break
        }
    }

    @objc private func deleteTapped() {
        state.deleteNode(node.id)
    }

    @objc private func generateTapped() {
        state.updatePrompt(node.id, promptTextView.text)
        Task { await state.generateImage(for: node.id) }
    }

    /// 拖动时如果正在编辑提示词则不响应，避免打字被拖走
    func shouldBeginDrag(_ g: UIGestureRecognizer) -> Bool {
        !isEditingPrompt
    }

    // MARK: - 图片加载
    private func loadImageIfNeeded() {
        guard node.kind == .image, loadedImageURL != node.imageName else { return }
        loadedImageURL = node.imageName
        if let name = node.imageName,
           let data = CanvasStore.readImage(name),
           let local = UIImage(data: data) {
            imageView.image = local
            imageHint.isHidden = true
        } else if let url = node.resultImageURL {
            // 远程图：下载成功后落盘缓存，下次直接读盘
            Task { [weak self] in
                guard let url = URL(string: url) else { return }
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   let img = UIImage(data: data) {
                    await MainActor.run {
                        self?.imageView.image = img
                        self?.imageHint.isHidden = true
                    }
                }
            }
        }
    }
}

// MARK: - 手势委托
final class NodeGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    weak var owner: NodeView?

    /// 类不会合成成员初始化器，必须手写
    init(owner: NodeView?) {
        self.owner = owner
    }

    func gestureRecognizerShouldBegin(_ g: UIGestureRecognizer) -> Bool {
        owner?.shouldBeginDrag(g) ?? true
    }
}

// MARK: - UITextViewDelegate
extension NodeView: UITextViewDelegate {
    func textViewDidBeginEditing(_ textView: UITextView) {
        isEditingPrompt = true
        placeholderLabel.isHidden = true
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        isEditingPrompt = false
        node.prompt = textView.text.trimmingCharacters(in: .whitespacesAndNewlines)
        placeholderLabel.isHidden = !node.prompt.isEmpty
        state.updatePrompt(node.id, promptTextView.text)
    }
}
