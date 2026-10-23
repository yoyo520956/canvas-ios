import SwiftUI

struct CanvasView: UIViewRepresentable {
    @ObservedObject var state: CanvasState
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = UIColor(white: 0.06, alpha: 1)
        scrollView.minimumZoomScale = 0.1
        scrollView.maximumZoomScale = 4.0
        scrollView.delegate = context.coordinator
        scrollView.showsVerticalScrollIndicator = true
        scrollView.showsHorizontalScrollIndicator = true
        scrollView.alwaysBounceVertical = true
        scrollView.alwaysBounceHorizontal = true
        
        // Dot pattern background
        let dotSize: CGFloat = 20
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: dotSize, height: dotSize))
        let dotImg = renderer.image { ctx in
            UIColor(white: 0.35, alpha: 1).setFill()
            ctx.fill(CGRect(x: dotSize/2-1, y: dotSize/2-1, width: 2, height: 2))
        }
        scrollView.backgroundView = UIImageView(image: dotImg)
        
        // Store reference
        context.coordinator.scrollView = scrollView
        
        return scrollView
    }
    
    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.state = state
        context.coordinator.rebuildNodes(scrollView: scrollView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var state: CanvasState
        var scrollView: UIScrollView?
        var nodeViews: [String: NodeView] = [:]
        
        init(state: CanvasState) {
            self.state = state
        }
        
        func rebuildNodes(scrollView: UIScrollView) {
            // Remove old node views
            for sub in scrollView.subviews where sub is NodeView {
                sub.removeFromSuperview()
            }
            nodeViews.removeAll()
            
            // Calculate content size
            var maxW: CGFloat = 4000
            var maxH: CGFloat = 4000
            for node in state.nodes {
                let right = node.position.x + node.size.width
                let bottom = node.position.y + node.size.height
                if right > maxW { maxW = right }
                if bottom > maxH { maxH = bottom }
            }
            scrollView.contentSize = CGSize(width: maxW, height: maxH)
            
            // Rebuild nodes
            for node in state.nodes {
                let nv = NodeView(node: node, state: state)
                nodeViews[node.id] = nv
                scrollView.addSubview(nv)
                
                if node.id == state.selectedNodeId {
                    nv.setSelected(true)
                }
            }
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // Update node frames based on scroll offset
            // Nodes are already positioned absolutely in content coordinates
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            nil
        }
    }
}
