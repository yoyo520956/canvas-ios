import Foundation
import Combine

@MainActor
class CanvasState: ObservableObject {
    @Published var nodes: [CanvasNode] = []
    @Published var selectedNodeId: String?
    @Published var contentSize = CGSize(width: 4000, height: 4000)
    @Published var generatingIds: Set<String> = []
    
    var config = AgnesConfig.default {
        didSet { saveConfig() }
    }
    
    private let configKey = "infinite_canvas_config"
    
    init() {
        loadConfig()
        // Add a welcome node
        let welcome = CanvasNode(
            kind: .text,
            prompt: "欢迎使用无限画布！\n点击下方 + 按钮添加节点，输入提示词生成 AI 图片。",
            position: CGPoint(x: 1800, y: 1800),
            size: CGSize(width: 300, height: 150)
        )
        nodes.append(welcome)
    }
    
    func addNode(kind: NodeKind, prompt: String = "") {
        let node = CanvasNode(kind: kind, prompt: prompt, position: centerOfScreen, size: kind == .image ? CGSize(width: 280, height: 360) : CGSize(width: 280, height: 120))
        nodes.append(node)
        selectedNodeId = node.id
    }
    
    func selectNode(_ id: String?) {
        selectedNodeId = id
    }
    
    func deleteNode(_ id: String) {
        nodes.removeAll { $0.id == id }
        if selectedNodeId == id { selectedNodeId = nil }
    }
    
    func updateNodePosition(_ id: String, position: CGPoint) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].position = position
    }
    
    func updateNodeSize(_ id: String, size: CGSize) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].size = size
    }
    
    func generateImage(for nodeId: String) async {
        guard let node = nodes.first(where: { $0.id == nodeId }) else { return }
        guard !node.prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            var n = node
            n.setError("请先输入提示词")
            nodes[nodes.firstIndex(where: { $0.id == nodeId })!] = n
            return
        }
        
        var n = node
        n.startGenerating()
        nodes[nodes.firstIndex(where: { $0.id == nodeId })!] = n
        generatingIds.insert(nodeId)
        
        do {
            let url = try await ImageGenService.shared.generateImage(config: config, prompt: node.prompt)
            var updated = node
            updated.setDone(imageURL: url)
            if let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                nodes[idx] = updated
            }
        } catch {
            var updated = node
            updated.setError(error.localizedDescription)
            if let idx = nodes.firstIndex(where: { $0.id == nodeId }) {
                nodes[idx] = updated
            }
        }
        
        generatingIds.remove(nodeId)
    }
    
    private var centerOfScreen: CGPoint {
        // Place new node near center of current viewport
        CGPoint(x: contentSize.width / 2 - 140 + CGFloat.random(in: -100...100),
                y: contentSize.height / 2 - 180 + CGFloat.random(in: -100...100))
    }
    
    // MARK: - Config persistence
    
    private func saveConfig() {
        if let encoded = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(encoded, forKey: configKey)
        }
    }
    
    private func loadConfig() {
        if let data = UserDefaults.standard.data(forKey: configKey),
           let decoded = try? JSONDecoder().decode(AgnesConfig.self, from: data) {
            config = decoded
        }
    }
}
