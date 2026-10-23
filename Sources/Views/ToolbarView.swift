import SwiftUI
import PhotosUI
import UIKit

struct ToolbarView: View {
    @ObservedObject var state: CanvasState
    var onAddImage: () -> Void
    var onAddText: () -> Void
    var onSettings: () -> Void

    @State private var picked: [PhotosPickerItem] = []
    @State private var pickError: String?
    @State private var savedTip = false

    var body: some View {
        HStack(spacing: 9) {
            toolbarButton(icon: "photo.on.rectangle.angled", title: "AI 生图", color: .cyan, action: onAddImage)
            toolbarButton(icon: "text.quote", title: "文字", color: .mint, action: onAddText)

            // 相册导入：PhotosPicker 不需要额外权限声明
            PhotosPicker(selection: $picked, maxSelectionCount: 6, matching: .images) {
                VStack(spacing: 3) {
                    Image(systemName: "photo.stack")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.orange)
                    Text("相册")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
                .frame(width: 58, height: 52)
                .background(Color(uiColor: UIColor(white: 0.14, alpha: 1)))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)

            if state.canUndo {
                toolbarButton(icon: "arrow.uturn.backward", title: "撤销", color: .yellow) {
                    state.undo()
                }
            }

            if let id = state.selectedNodeId, state.imageDataURL(for: id) != nil {
                toolbarButton(icon: "square.and.arrow.down", title: "存相册", color: .green) {
                    saveToPhotos(nodeId: id)
                }
            }

            Spacer()

            toolbarButton(icon: "gearshape", title: "设置", color: .gray, action: onSettings)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(uiColor: UIColor(white: 0.085, alpha: 1)).opacity(0.97))
        .onChange(of: picked) { items in
            guard !items.isEmpty else { return }
            importItems(items)
        }
        .overlay(alignment: .bottom) {
            if savedTip {
                Text("已保存到相册 ✅")
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .offset(y: -60)
                    .transition(.opacity)
            }
        }
    }

    // MARK: - 相册导入

    private func importItems(_ items: [PhotosPickerItem]) {
        Task {
            var ok = 0
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                await MainActor.run { state.addImageNode(data: data) }
                ok += 1
            }
            await MainActor.run {
                picked = []
                pickError = ok == 0 ? "没有可读的图片" : nil
            }
        }
    }

    // MARK: - 保存到相册

    private func saveToPhotos(nodeId: String) {
        guard let url = state.imageDataURL(for: nodeId),
              let image = UIImage(contentsOfFile: url.path) else { return }
        // 第 3 个参数是 Selector?（完成回调），不需要回调就传 nil
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        withAnimation { savedTip = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
            withAnimation { savedTip = false }
        }
    }

    private func toolbarButton(icon: String, title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .frame(width: 58, height: 52)
            .background(Color(uiColor: UIColor(white: 0.14, alpha: 1)))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }
}
