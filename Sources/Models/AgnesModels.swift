import Foundation

struct AgnesConfig: Codable {
    var baseURL: String
    var apiKey: String
    var model: String
    /// 出图尺寸，OpenAI 兼容接口通用取值
    var size: String

    static let sizes = ["1024x1024", "1024x1536", "1536x1024", "512x512"]

    /// 写了自定义 init(from:) 之后 Swift 不再合成成员初始化器，这里手动补一个
    init(baseURL: String, apiKey: String, model: String, size: String = "1024x1024") {
        self.baseURL = baseURL
        self.apiKey = apiKey
        self.model = model
        self.size = size
    }

    static let `default` = AgnesConfig(
        baseURL: "https://api.agnes-ai.cn/v1",
        apiKey: "sk-XaGjXJS77FniRVmacdbsfUwf1OR4wtUxTSNtCFg4cV1HeS82",
        model: "agnes-image-2.5-flash",
        size: "1024x1024"
    )

    /// 兼容旧存档：缺字段时用默认值补齐，而不是整份配置解不开
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try c.decodeIfPresent(String.self, forKey: .baseURL) ?? Self.default.baseURL
        apiKey = try c.decodeIfPresent(String.self, forKey: .apiKey) ?? Self.default.apiKey
        model = try c.decodeIfPresent(String.self, forKey: .model) ?? Self.default.model
        size = try c.decodeIfPresent(String.self, forKey: .size) ?? "1024x1024"
    }

    private enum CodingKeys: String, CodingKey {
        case baseURL, apiKey, model, size
    }

    /// 历史上曾把 key 多包了一层 base64（sk- 变成 c2st），这里统一还原成真实值
    var effectiveAPIKey: String {
        let trimmed = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("c2st") else { return trimmed }
        if let data = Data(base64Encoded: trimmed),
           let decoded = String(data: data, encoding: .utf8),
           decoded.hasPrefix("sk-") {
            return decoded
        }
        return trimmed
    }
}

struct ImageGenRequest: Encodable {
    let model: String
    let prompt: String
    let n: Int
    let size: String
}

struct ImageGenResponse: Decodable {
    let data: [ImageData]
    
    struct ImageData: Decodable {
        let url: String?
        let b64_json: String?
    }
}
