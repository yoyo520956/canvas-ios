import Foundation
import Combine

@MainActor
final class CanvasState: ObservableObject {
    @Published var nodes: [CanvasNode] = []
    @Published var selectedNodeId: String?
    @Published var contentSize = CGSize(width: 8000, height: 8000)
    @Published var generatingIds: Set<String> = []

    @Published var config: AgnesConfig {
        didSet { saveConfig() }
    }

    private let configKey = "infinite_canvas_config"

    init() {
        loadConfig()
        let welcome = CanvasNode(
            kind: .text,
            prompt: "欢迎使用无限画布 🎨\n\n1. 点下方「图片」按钮新建 AI 生图节点\n2. 输入提示词，点「✨ 生成」\n3. 单指拖动画布，双指捏合缩放\n4. 拖节点右下角蓝点可调整尺寸",
            position: CGPoint(x: 3700, y: 3700),
            size: CGSize(width: 320, height: 220)
        )
        nodes.append(welcome)
    }

    // MARK: - 节点操作

    func addNode(kind: NodeKind, prompt: String = "") {
        let size: CGSize = kind == .image
            ? CGSize(width: 300, height: 400)
            : CGSize(width: 300, height: 180)
        let node = CanvasNode(
            kind: kind,
            prompt: prompt,
            position: centerPoint,
            size: size
        )
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

    func updatePrompt(_ id: String, _ prompt: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        guard nodes[idx].prompt != prompt else { return }
        nodes[idx].prompt = prompt
    }

    func clearAll() {
        nodes.removeAll()
        selectedNodeId = nil
    }

    // MARK: - 生图

    func generateImage(for nodeId: String) async {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeId }) else { return }

        let prompt = nodes[idx].prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else {
            nodes[idx].setError("请先输入提示词")
            return
        }

        nodes[idx].startGenerating()
        generatingIds.insert(nodeId)

        do {
            let result = try await ImageGenService.shared.generateImage(config: config, prompt: prompt)
            guard let cur = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
            nodes[cur].setDone(imageURL: result)
        } catch {
            guard let cur = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
            nodes[cur].setError(Self.friendlyError(error))
        }

        generatingIds.remove(nodeId)
    }

    private static func friendlyError(_ error: Error) -> String {
        if let urlError = error as? URLError {
            switch urlError.code {
            case .notConnectedToInternet: return "网络未连接"
            case .timedOut: return "请求超时"
            case .cannotFindHost: return "无法连接服务器"
            default: return urlError.localizedDescription
            }
        }
        if let apiError = error as? APIError {
            return apiError.message
        }
        return error.localizedDescription
    }

    // MARK: - 位置计算

    private var centerPoint: CGPoint {
        CGPoint(
            x: contentSize.width / 2 - 150 + CGFloat.random(in: -120...120),
            y: contentSize.height / 2 - 200 + CGFloat.random(in: -120...120)
        )
    }

    // MARK: - 配置持久化

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
