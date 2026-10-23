import UIKit

class NodeView: UIView {
    private let node: CanvasNode
    private let state: CanvasState
    private var isSelected = false
    private var isDragging = false
    private var dragStartPoint = CGPoint.zero
    private var dragNodeStartPos = CGPoint.zero
    private var isResizing = false
    private var resizeCorner: ResizeCorner = .bottomRight
    private var resizeStartSize = CGSize.zero
    private var resizeStartPos = CGPoint.zero
    
    enum ResizeCorner: String { case bottomRight = "bottomRight" }
    
    // Subviews
    private let cardView = UIView()
    private let titleLabel = UILabel()
    private let promptTextView = UITextView()
    private let imageView = UIImageView()
    private let statusLabel = UILabel()
    private let generateButton = UIButton(type: .system)
    private let deleteButton = UIButton(type: .system)
    private let resizeHandle = UIView()
    private let selectionOverlay = UIView()
    
    init(node: CanvasNode, state: CanvasState) {
        self.node = node
        self.state = state
        super.init(frame: CGRect(origin: node.position, size: node.size))
        setupUI()
        applyNode()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setupUI() {
        // Card background
        cardView.backgroundColor = UIColor(white: 0.12, alpha: 1)
        cardView.layer.cornerRadius = 16
        cardView.layer.borderWidth = 2
        cardView.layer.borderColor = UIColor.systemGray5.cgColor
        cardView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(cardView)
        
        NSLayoutConstraint.activate([
            cardView.topAnchor.constraint(equalTo: topAnchor),
            cardView.leadingAnchor.constraint(equalTo: leadingAnchor),
            cardView.trailingAnchor.constraint(equalTo: trailingAnchor),
            cardView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Title
        titleLabel.text = node.kind == .image ? "🖼️ AI 图片" : "📝 文字"
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        titleLabel.textColor = .secondaryLabel
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(titleLabel)
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 12),
            titleLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14)
        ])
        
        // Delete button (top right)
        deleteButton.setTitle("✕", for: .normal)
        deleteButton.titleLabel?.font = .systemFont(ofSize: 14)
        deleteButton.tintColor = .secondaryLabel
        deleteButton.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.addTarget(self, action: #selector(deleteTapped), for: .touchUpInside)
        cardView.addSubview(deleteButton)
        
        NSLayoutConstraint.activate([
            deleteButton.topAnchor.constraint(equalTo: cardView.topAnchor, constant: 8),
            deleteButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -10),
            deleteButton.widthAnchor.constraint(equalToConstant: 28),
            deleteButton.heightAnchor.constraint(equalToConstant: 28)
        ])
        
        // Image view
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.layer.cornerRadius = 10
        imageView.backgroundColor = UIColor(white: 0.2, alpha: 1)
        imageView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(imageView)
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 10),
            imageView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            imageView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            imageView.heightAnchor.constraint(equalToConstant: 200),
            imageView.bottomAnchor.constraint(equalTo: generateButton.topAnchor, constant: -8)
        ])
        
        // Prompt text view
        promptTextView.text = node.prompt
        promptTextView.font = .systemFont(ofSize: 13)
        promptTextView.textColor = .label
        promptTextView.backgroundColor = UIColor(white: 0.18, alpha: 1)
        promptTextView.layer.cornerRadius = 8
        promptTextView.layer.borderWidth = 1
        promptTextView.layer.borderColor = UIColor.separator.cgColor
        promptTextView.isScrollEnabled = true
        promptTextView.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(promptTextView)
        
        NSLayoutConstraint.activate([
            promptTextView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            promptTextView.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            promptTextView.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            promptTextView.bottomAnchor.constraint(equalTo: generateButton.topAnchor, constant: -6)
        ])
        
        // Generate button
        generateButton.setTitle("✨ 生成", for: .normal)
        generateButton.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        generateButton.layer.cornerRadius = 10
        generateButton.backgroundColor = UIColor(systemColor: 0x00D4FF)
        generateButton.setTitleColor(.white, for: .normal)
        generateButton.translatesAutoresizingMaskIntoConstraints = false
        generateButton.addTarget(self, action: #selector(generateTapped), for: .touchUpInside)
        cardView.addSubview(generateButton)
        
        NSLayoutConstraint.activate([
            generateButton.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            generateButton.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14),
            generateButton.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -12),
            generateButton.heightAnchor.constraint(equalToConstant: 40)
        ])
        
        // Status label
        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabel
        statusLabel.textAlignment = .center
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        cardView.addSubview(statusLabel)
        
        NSLayoutConstraint.activate([
            statusLabel.topAnchor.constraint(equalTo: generateButton.bottomAnchor, constant: 4),
            statusLabel.leadingAnchor.constraint(equalTo: cardView.leadingAnchor, constant: 14),
            statusLabel.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -14)
        ])
        
        // Resize handle (bottom-right corner)
        resizeHandle.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        resizeHandle.layer.cornerRadius = 4
        resizeHandle.translatesAutoresizingMaskIntoConstraints = false
        resizeHandle.addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(resizePan(_:))))
        cardView.addSubview(resizeHandle)
        
        NSLayoutConstraint.activate([
            resizeHandle.trailingAnchor.constraint(equalTo: cardView.trailingAnchor, constant: -6),
            resizeHandle.bottomAnchor.constraint(equalTo: cardView.bottomAnchor, constant: -6),
            resizeHandle.widthAnchor.constraint(equalToConstant: 18),
            resizeHandle.heightAnchor.constraint(equalToConstant: 18)
        ])
        
        // Selection overlay
        selectionOverlay.layer.cornerRadius = 16
        selectionOverlay.layer.borderWidth = 2
        selectionOverlay.layer.borderColor = UIColor.systemBlue.cgColor
        selectionOverlay.backgroundColor = .clear
        selectionOverlay.isHidden = true
        selectionOverlay.translatesAutoresizingMaskIntoConstraints = false
        insertSubview(selectionOverlay, aboveSubview: cardView)
        
        NSLayoutConstraint.activate([
            selectionOverlay.topAnchor.constraint(equalTo: topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
        
        // Pan gesture for dragging
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        addGestureRecognizer(pan)
        
        // Tap to select
        let tap = UITapGestureRecognizer(target: self, action: #selector(tapSelected))
        tap.cancelsTouchesInView = false
        addGestureRecognizer(tap)
    }
    
    func applyNode() {
        frame = CGRect(origin: node.position, size: node.size)
        promptTextView.text = node.prompt
        updateUI()
    }
    
    func updateUI() {
        switch node.status {
        case .generating:
            generateButton.setTitle("⏳ 生成中...", for: .normal)
            generateButton.isEnabled = false
            statusLabel.text = "AI 正在创作中..."
            statusLabel.textColor = .systemBlue
            if node.resultImageURL != nil {
                loadImage(node.resultImageURL!)
            }
        case .done:
            generateButton.setTitle("✨ 重新生成", for: .normal)
            generateButton.isEnabled = !node.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            statusLabel.text = node.resultImageURL != nil ? "已完成" : "输入提示词后点击生成"
            statusLabel.textColor = .secondaryLabel
            if let url = node.resultImageURL {
                loadImage(url)
            } else {
                imageView.image = nil
            }
        case .error:
            generateButton.setTitle("✨ 重试", for: .normal)
            generateButton.isEnabled = true
            statusLabel.text = "❌ " + (node.errorMessage ?? "未知错误")
            statusLabel.textColor = .systemRed
        case .idle:
            generateButton.setTitle("✨ 生成", for: .normal)
            generateButton.isEnabled = !node.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            statusLabel.text = "输入提示词后点击生成"
            statusLabel.textColor = .secondaryLabel
            imageView.image = nil
        }
        
        // Update delete button visibility based on selection
        deleteButton.alpha = isSelected ? 1.0 : 0.4
    }
    
    func setSelected(_ selected: Bool) {
        isSelected = selected
        selectionOverlay.isHidden = !selected
        deleteButton.alpha = selected ? 1.0 : 0.4
        updateUI()
    }
    
    private func loadImage(_ url: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            var image: UIImage?
            if url.starts(with: "data:") {
                if let data = Data(base64Encoded: String(url.dropFirst("data:image/png;base64,".count))) {
                    image = UIImage(data: data)
                }
            } else {
                if let data = try? Data(contentsOf: URL(string: url)!),
                   let img = UIImage(data: data) {
                    image = img
                }
            }
            DispatchQueue.main.async {
                self.imageView.image = image
                self.layoutIfNeeded()
            }
        }
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handlePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: superview)
        
        switch pan.state {
        case .began:
            isDragging = true
            dragStartPoint = location
            dragNodeStartPos = node.position
        case .changed where isDragging:
            let delta = CGPoint(x: location.x - dragStartPoint.x, y: location.y - dragStartPoint.y)
            let newPos = CGPoint(x: dragNodeStartPos.x + delta.x, y: dragNodeStartPos.y + delta.y)
            state.updateNodePosition(node.id, position: newPos)
            frame.origin = newPos
        case .ended, .cancelled:
            isDragging = false
        default:
            break
        }
    }
    
    @objc private func resizePan(_ pan: UIPanGestureRecognizer) {
        let location = pan.location(in: superview)
        switch pan.state {
        case .began:
            isResizing = true
            resizeStartSize = node.size
            resizeStartPos = node.position
        case .changed where isResizing:
            let delta = CGPoint(x: location.x - frame.maxX, y: location.y - frame.maxY)
            let newSize = CGSize(
                width: max(160, resizeStartSize.width + delta.x),
                height: max(100, resizeStartSize.height + delta.y)
            )
            state.updateNodeSize(node.id, size: newSize)
            frame.size = newSize
        case .ended, .cancelled:
            isResizing = false
        default:
            break
        }
    }
    
    @objc private func tapSelected() {
        state.selectNode(node.id)
        setSelected(true)
    }
    
    @objc private func generateTapped() {
        state.generateImage(for: node.id)
    }
    
    @objc private func deleteTapped() {
        state.deleteNode(node.id)
        removeFromSuperview()
    }
}
