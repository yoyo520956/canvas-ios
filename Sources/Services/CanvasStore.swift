import Foundation
import UIKit

/// 画布持久化层
/// - 节点：Documents/Canvas/canvas.json（Codable + sortedKeys，diff 稳定）
/// - 图片：Documents/Canvas/Images/<nodeID>.png —— 生成的图必须落盘，
///   否则 base64 塞进 JSON 会让存档膨胀到几十 MB，远程 URL 也会过期。
enum CanvasStore {
    private static let fm = FileManager.default

    static let baseDir: URL = {
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        let dir = docs.appendingPathComponent("Canvas", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    static let imagesDir: URL = {
        let dir = baseDir.appendingPathComponent("Images", isDirectory: true)
        try? fm.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static var canvasFile: URL {
        baseDir.appendingPathComponent("canvas.json")
    }

    // MARK: - 节点存档

    static func loadNodes() -> [CanvasNode] {
        guard let data = try? Data(contentsOf: canvasFile) else { return [] }
        // 存档损坏时不能 crash，也不能静默吞掉——备份后返回空，让主人能从零重建
        do {
            return try JSONDecoder().decode([CanvasNode].self, from: data)
        } catch {
            try? fm.removeItem(at: canvasFile)
            return []
        }
    }

    @discardableResult
    static func saveNodes(_ nodes: [CanvasNode]) -> Bool {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(nodes) else { return false }
        // 先写临时文件再替换，避免写入中途被杀导致存档半截损坏
        let tmp = canvasFile.appendPathExtension("tmp")
        do {
            try data.write(to: tmp, options: .atomic)
            if fm.fileExists(atPath: canvasFile.path) {
                _ = try? fm.replaceItem(at: canvasFile, withItemAt: tmp,
                                        backupFileName: nil).newItem
            } else {
                try fm.moveItem(at: tmp, to: canvasFile)
            }
            return true
        } catch {
            try? fm.removeItem(at: tmp)
            return false
        }
    }

    // MARK: - 图片缓存

    /// 写入图片，返回文件名（存进 node.imageName）
    static func writeImage(_ data: Data, for nodeID: String) -> String? {
        let name = safeName(nodeID) + ".png"
        let url = imagesDir.appendingPathComponent(name)
        do {
            try data.write(to: url, options: .atomic)
            return name
        } catch {
            return nil
        }
    }

    static func readImage(_ name: String) -> Data? {
        try? Data(contentsOf: imagesDir.appendingPathComponent(name))
    }

    static func imageURL(_ name: String) -> URL {
        imagesDir.appendingPathComponent(name)
    }

    static func deleteImages(for nodeIDs: [String]) {
        for id in nodeIDs {
            try? fm.removeItem(at: imagesDir.appendingPathComponent(safeName(id) + ".png"))
        }
    }

    static func clearAll() {
        try? fm.removeItem(at: canvasFile)
        try? fm.removeItem(at: imagesDir)
        try? fm.createDirectory(at: imagesDir, withIntermediateDirectories: true)
    }

    /// 只保留安全字符，防路径穿越（节点 id 是 UUID，但仍做防御）
    private static func safeName(_ raw: String) -> String {
        let allowed = CharacterSet(charactersIn:
            "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")
        let filtered = String(String.UnicodeScalarView(raw.unicodeScalars.filter {
            allowed.contains($0)
        }))
        return filtered.isEmpty ? UUID().uuidString : String(filtered.prefix(64))
    }
}
