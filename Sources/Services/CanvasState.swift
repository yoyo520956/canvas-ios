import Foundation
import Combine
import UIKit

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

    private var saveTask: Task<Void, Never>?
    /// 撤销栈：只存结构性变更前后的整表快照，封顶 25 步
    private var undoStack: [[CanvasNode]] = []

    init() {
        // 必须先给 config 赋值，否则 loadConfig() 会访问未初始化属性
        config = AgnesConfig.default
        loadConfig()
        let saved = CanvasStore.loadNodes()
        if !saved.isEmpty {
            nodes = saved
            return
        }
        let welcome = CanvasNode(
            kind: .text,
            prompt: "欢迎使用无限画布 🎨\n\n1. 点下方「图片」按钮新建 AI 生图节点\n2. 输入提示词，点「✨ 生成」\n3. 单指拖动画布，双指捏合缩放\n4. 拖节点右下角蓝点可调整尺寸",
            position: CGPoint(x: 3700, y: 3700),
            size: CGSize(width: 320, height: 220)
        )
        nodes.append(welcome)
    }

    // MARK: - 节点操作

    // MARK: - 撤销

    private func pushUndo() {
        undoStack.append(nodes)
        if undoStack.count > 25 { undoStack.removeFirst(undoStack.count - 25) }
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        nodes = last
        selectedNodeId = nil
        scheduleSave()
    }

    var canUndo: Bool { !undoStack.isEmpty }

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
        pushUndo()
        nodes.append(node)
        selectedNodeId = node.id
        scheduleSave()
    }

    /// 从相册/分享导入一张图片，直接成为已完成节点
    func addImageNode(data: Data) {
        guard let image = UIImage(data: data) else { return }
        // 大图降采样：iOS 内存 = 宽×高×4 字节，4000px 照片 ≈ 60MB
        let maxSide: CGFloat = 1400
        let scale = min(1.0, maxSide / max(image.size.width, image.size.height))
        let target = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let resized = UIGraphicsImageRenderer(size: target).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
        guard let jpeg = resized.jpegData(compressionQuality: 0.85) else { return }
        let node = CanvasNode(kind: .image, prompt: "",
                              position: centerPoint,
                              size: CGSize(width: max(240, target.width * 0.6),
                                           height: max(240, target.height * 0.6)))
        pushUndo()
        nodes.append(node)
        if let name = CanvasStore.writeImage(jpeg, for: node.id) {
            nodes[nodes.count - 1].imageName = name
        }
        nodes[nodes.count - 1].status = .done
        selectedNodeId = node.id
        scheduleSave()
    }

    /// 取节点图片数据（供保存到相册）
    func imageDataURL(for nodeId: String) -> URL? {
        guard let node = nodes.first(where: { $0.id == nodeId }),
              let name = node.imageName else { return nil }
        let url = CanvasStore.imageURL(name)
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }

    func selectNode(_ id: String?) {
        selectedNodeId = id
    }

    func deleteNode(_ id: String) {
        pushUndo()
        nodes.removeAll { $0.id == id }
        if selectedNodeId == id { selectedNodeId = nil }
        CanvasStore.deleteImages(for: [id])
        scheduleSave()
    }

    /// 把节点图片重新落盘（供远程 URL 下载成功后回填缓存）
    func cacheImage(_ data: Data, for nodeId: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == nodeId }) else { return }
        guard let name = CanvasStore.writeImage(data, for: nodeId) else { return }
        nodes[idx].imageName = name
        scheduleSave()
    }

    func updateNodePosition(_ id: String, position: CGPoint) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].position = position
        scheduleSave()
    }

    func updateNodeSize(_ id: String, size: CGSize) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        nodes[idx].size = size
        scheduleSave()
    }

    func updatePrompt(_ id: String, _ prompt: String) {
        guard let idx = nodes.firstIndex(where: { $0.id == id }) else { return }
        guard nodes[idx].prompt != prompt else { return }
        nodes[idx].prompt = prompt
        scheduleSave()
    }

    func clearAll() {
        undoStack.removeAll()
        nodes.removeAll()
        selectedNodeId = nil
        CanvasStore.clearAll()
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
            // base64 结果直接落盘，节点里只留文件名，避免存档膨胀
            if let data = result.imageData {
                let name = CanvasStore.writeImage(data, for: nodeId)
                nodes[cur].setDone(imageURL: nil, imageName: name)
            } else {
                nodes[cur].setDone(imageURL: result.url)
            }
            scheduleSave()
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

    // MARK: - 画布持久化（防抖 0.6s，避免拖拽时每帧写盘）

    private func scheduleSave() {
        saveTask?.cancel()
        let snapshot = nodes
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard !Task.isCancelled else { return }
            CanvasStore.saveNodes(snapshot)
            _ = self
        }
    }

    /// 退出前台时立刻落盘，防防抖窗口内被杀
    func flushNow() {
        saveTask?.cancel()
        CanvasStore.saveNodes(nodes)
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
