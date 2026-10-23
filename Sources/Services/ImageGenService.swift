import Foundation
import UIKit

class ImageGenService {
    static let shared = ImageGenService()
    
    private init() {}
    
    func generateImage(config: AgnesConfig, prompt: String) async throws -> String? {
        let url = URL(string: "\(config.baseURL)/images/generations")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ImageGenRequest(model: config.model, prompt: prompt, n: 1, size: "1024x1024")
        request.httpBody = try JSONEncoder().encode(body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let result = try JSONDecoder().decode(ImageGenResponse.self, from: data)
        
        if let first = result.data.first {
            if let url = first.url, !url.isEmpty {
                return url
            }
            if let b64 = first.b64_json, !b64.isEmpty {
                // Return base64 data URL
                return "data:image/png;base64,\(b64)"
            }
        }
        return nil
    }
}
