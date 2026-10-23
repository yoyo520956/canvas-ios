import Foundation
import UIKit

/// 生图结果：远程 URL 或已解码的图片二进制（二选一）
struct GenResult {
    var url: String?
    var imageData: Data?
}

struct APIError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

final class ImageGenService {
    static let shared = ImageGenService()
    private init() {}

    /// 调用 OpenAI 兼容的 /images/generations 接口
    func generateImage(config: AgnesConfig, prompt: String) async throws -> GenResult {
        let endpoint = config.baseURL.hasSuffix("/")
            ? "\(config.baseURL)images/generations"
            : "\(config.baseURL)/images/generations"

        guard let url = URL(string: endpoint) else {
            throw APIError(message: "API 地址无效：\(config.baseURL)")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let size = AgnesConfig.sizes.contains(config.size) ? config.size : "1024x1024"
        let body = ImageGenRequest(model: config.model, prompt: prompt, n: 1, size: size)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            throw error
        } catch {
            throw APIError(message: "网络请求失败：\(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw APIError(message: "服务器无响应")
        }
        guard (200..<300).contains(http.statusCode) else {
            throw APIError(message: Self.extractErrorMessage(data) ?? "HTTP \(http.statusCode)")
        }

        guard let result = try? JSONDecoder().decode(ImageGenResponse.self, from: data) else {
            throw APIError(message: "返回数据解析失败")
        }

        guard let first = result.data.first else {
            throw APIError(message: "API 未返回图片")
        }
        if let imgURL = first.url, !imgURL.isEmpty {
            return GenResult(url: imgURL, imageData: nil)
        }
        if let b64 = first.b64_json, !b64.isEmpty {
            // 优先解码成二进制，交给上层落盘；解不出来再退回 data-URL
            var payload = b64
            if let comma = b64.firstIndex(of: ",") {
                // 兼容 "data:image/png;base64,xxxx" 这种把前缀塞进 b64_json 的实现
                payload = String(b64[b64.index(after: comma)...])
            }
            if let data = Data(base64Encoded: payload) {
                return GenResult(url: nil, imageData: data)
            }
            return GenResult(url: "data:image/png;base64,\(b64)", imageData: nil)
        }
        throw APIError(message: "API 返回内容中没有图片")
    }

    /// 尝试从错误响应体提取可读信息
    private static func extractErrorMessage(_ data: Data) -> String? {
        guard let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let raw = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return (raw?.isEmpty == false) ? raw : nil
        }
        if let error = obj["error"] as? [String: Any] {
            if let msg = error["message"] as? String { return msg }
        }
        if let msg = obj["message"] as? String { return msg }
        if let detail = obj["detail"] as? String { return detail }
        return nil
    }
}
