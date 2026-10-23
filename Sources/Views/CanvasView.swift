import SwiftUI
import UIKit

/// 点阵网格背景（缩放时随内容一起缩放）
final class DotGridView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) { fatalError() }

    override func draw(_ rect: CGRect) {
        guard let ctx = UIGraphicsGetCurrentContext() else { return }
        ctx.setFillColor(UIColor(white: 0.26, alpha: 1).cgColor)
        let step: CGFloat = 32
        var y = rect.minY
        while y < rect.maxY {
            var x = rect.minX
            while x < rect.maxX {
                ctx.fillEllipse(in: CGRect(x: x - 1, y: y - 1, width: 2, height: 2))
                x += step
            }
            y += step
        }
    }
}

/// 画布宿主：UIScrollView + 固定尺寸内容层（支持双指缩放 / 单指平移）
final class CanvasScrollView: UIScrollView {
    let contentView = UIView()
    let canvasSize = CGSize(width: 8000, height: 8000)

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    private func setup() {
        backgroundColor = UIColor(white: 0.055, alpha: 1)
        minimumZoomScale = 0.15
        maximumZoomScale = 4.0
        bouncesZoom = true
        decelerationRate = .fast
        showsHorizontalScrollIndicator = true
        showsVerticalScrollIndicator = true
        alwaysBounceVertical = true
        alwaysBounceHorizontal = true
        contentInsetAdjustmentBehavior = .never

        let grid = DotGridView()
        grid.frame = CGRect(origin: .zero, size: canvasSize)
        contentView.addSubview(grid)

        contentView.frame = CGRect(origin: .zero, size: canvasSize)
        contentView.backgroundColor = .clear
        addSubview(contentView)
        contentSize = canvasSize

        let bgTap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        bgTap.cancelsTouchesInView = false
        addGestureRecognizer(bgTap)
    }

    /// 点空白处取消选中（点在节点上时不触发）
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: contentView)
        if contentView.hitTest(point, with: nil) === contentView {
            onTapBackground?()
        }
    }

    var onTapBackground: (() -> Void)?

    /// 首屏把视口对准指定内容坐标
    private var didCenter = false
    var centerTarget: CGPoint?

    override func layoutSubviews() {
        super.layoutSubviews()
        guard !didCenter, let target = centerTarget, bounds.width > 0, bounds.height > 0 else { return }
        didCenter = true
        let x = target.x * zoomScale - bounds.width / 2
        let y = target.y * zoomScale - bounds.height / 2
        contentOffset = CGPoint(x: max(0, x), y: max(0, y))
    }
}

struct CanvasView: UIViewRepresentable {
    @ObservedObject var state: CanvasState

    func makeUIView(context: Context) -> CanvasScrollView {
        let scroll = CanvasScrollView()
        scroll.delegate = context.coordinator
        context.coordinator.scrollView = scroll
        context.coordinator.state = state
        context.coordinator.sync(scrollView: scroll)
        scroll.onTapBackground = { [weak state] in
            state?.selectNode(nil)
        }
        // 首屏对准第一个节点，避免落在空白角落
        if let first = state.nodes.first {
            scroll.centerTarget = CGPoint(x: first.position.x + first.size.width / 2,
                                         y: first.position.y + first.size.height / 2)
        }
        return scroll
    }

    func updateUIView(_ scrollView: CanvasScrollView, context: Context) {
        context.coordinator.state = state
        context.coordinator.sync(scrollView: scrollView)
    }

    func makeCoordinator() -> Coordinator { Coordinator(state: state) }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        var state: CanvasState
        weak var scrollView: CanvasScrollView?
        var nodeViews: [String: NodeView] = [:]

        init(state: CanvasState) { self.state = state }

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            (scrollView as? CanvasScrollView)?.contentView
        }

        /// 增量同步：只增删改有变化的节点视图，避免每次状态刷新重建导致拖拽中断/图片闪烁
        func sync(scrollView: CanvasScrollView) {
            let container = scrollView.contentView
            let liveIds = Set(state.nodes.map(\.id))

            // 1. 删除已消失的节点
            let deadIds = nodeViews.keys.filter { !liveIds.contains($0) }
            for id in deadIds {
                nodeViews[id]?.removeFromSuperview()
                nodeViews.removeValue(forKey: id)
            }

            // 2. 更新已有 / 创建新的
            for node in state.nodes {
                if let view = nodeViews[node.id] {
                    view.sync(node: node, isSelected: node.id == state.selectedNodeId)
                } else {
                    let view = NodeView(node: node, state: state, scrollView: scrollView)
                    view.frame = CGRect(origin: node.position, size: node.size)
                    container.addSubview(view)
                    nodeViews[node.id] = view
                }
            }

            // 3. 更新内容尺寸（仅在变化时写入，避免 @Published 触发渲染回环）
            var maxX = scrollView.canvasSize.width
            var maxY = scrollView.canvasSize.height
            for node in state.nodes {
                maxX = max(maxX, node.position.x + node.size.width + 400)
                maxY = max(maxY, node.position.y + node.size.height + 400)
            }
            let newSize = CGSize(width: maxX, height: maxY)
            if state.contentSize != newSize {
                state.contentSize = newSize
            }
        }

        func scrollViewDidZoom(_ scrollView: UIScrollView) {
            (scrollView as? CanvasScrollView)?.contentView.setNeedsDisplay()
        }
    }
}
