import Foundation

enum NodeKind: String, CaseIterable, Codable {
    case image = "image"
    case text = "text"
    
    var label: String {
        switch self {
        case .image: return "🖼️ 图片"
        case .text: return "📝 文字"
        }
    }
}

enum NodeStatus: String, Codable {
    case idle = "idle"
    case generating = "generating"
    case done = "done"
    case error = "error"
}

struct CanvasNode: Identifiable, Codable, Hashable {
    let id: String
    var kind: NodeKind
    var prompt: String
    var status: NodeStatus
    var resultImageURL: String?
    var errorMessage: String?
    var position: CGPoint
    var size: CGSize
    
    init(id: String = UUID().uuidString, kind: NodeKind = .image, prompt: String = "", position: CGPoint = .zero, size: CGSize = CGSize(width: 280, height: 360)) {
        self.id = id
        self.kind = kind
        self.prompt = prompt
        self.status = kind == .image ? .idle : .done
        self.resultImageURL = nil
        self.errorMessage = nil
        self.position = position
        self.size = size
    }
    
    mutating func startGenerating() {
        status = .generating
        errorMessage = nil
        resultImageURL = nil
    }
    
    mutating func setDone(imageURL: String?) {
        status = .done
        resultImageURL = imageURL
    }
    
    mutating func setError(_ msg: String) {
        status = .error
        errorMessage = msg
    }
}
