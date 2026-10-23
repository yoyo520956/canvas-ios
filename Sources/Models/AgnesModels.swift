import Foundation

struct AgnesConfig: Codable {
    var baseURL: String
    var apiKey: String
    var model: String
    
    static let `default` = AgnesConfig(
        baseURL: "https://api.agnes-ai.cn/v1",
        apiKey: "c2stWGFHalhKUzc3FnpRVmYwYWNkYnNmVXdmMU9SNHd0VXhUU050Q0ZnNGNWMUhlUzgy",
        model: "agnes-image-2.5-flash"
    )
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
