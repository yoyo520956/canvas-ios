import SwiftUI
import PhotosUI
import UIKit

/// 底部工具栏：图标 20pt / 文字 12pt / 按钮高 58pt，点按区域足够大
struct ToolbarView: View {
    @ObservedObject var state: CanvasState
    var onAddImage: () -> Void
    var onAddText: () -> Void
    var onSettings: () -> Void

    @State private var picked: [PhotosPickerItem] = []
    @State private var tip = ""

    private var barColor: Color { Color(uiColor: CanvasTheme.cardBG) }
    private var iconColor: Color { Color(uiColor: CanvasTheme.textPrimary) }

    var body: some View {
        HStack(spacing: 10) {
            toolbarButton(icon: "sparkles.rectangle.stack", title: "AI 生图", tint: .violet, action: onAddImage)
            toolbarButton(icon: "textformat.size", title: "文字", tint: .green, action: onAddText)

            PhotosPicker(selection: $picked, maxSelectionCount: 6, matching: .images) {
                toolbarIcon(icon: "photo.on.square", title: "相册", tint: .orange)
            }
            .buttonStyle(.plain)

            if state.canUndo {
                toolbarButton(icon: "arrow.uturn.backward", title: "撤销", tint: .yellow) {
                    state.undo()
                }
            }

            if let id = state.selectedNodeId, state.imageDataURL(for: id) != nil {
                toolbarButton(icon: "square.and.arrow.down", title: "存相册", tint: .teal) {
                    saveToPhotos(nodeId: id)
                }
            }

            Spacer(minLength: 4)

            toolbarButton(icon: "gearshape", title: "设置", tint: .gray, action: onSettings)
        }
        .padding(.horizontal, 14)
        .padding(.top, 8)
        .padding(.bottom, 6)
        .background(
            ZStack {
                barColor.opacity(0.98)
                Rectangle()
                    .fill(Color(uiColor: CanvasTheme.cardBorder))
                    .frame(height: 1)
                    .frame(maxHeight: .infinity, alignment: .top)
            }
        )
        .overlay(alignment: .bottom) {
            if !tip.isEmpty {
                Text(tip)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(uiColor: CanvasTheme.textPrimary))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(barColor)
                    .cornerRadius(10)
                    .offset(y: -74)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onChange(of: picked) { items in
            guard !items.isEmpty else { return }
            importItems(items)
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
                showToast(ok == 0 ? "没有可读的图片" : "已导入 \(ok) 张图 ✅")
            }
        }
    }

    // MARK: - 保存到相册

    private func saveToPhotos(nodeId: String) {
        guard let url = state.imageDataURL(for: nodeId),
              let image = UIImage(contentsOfFile: url.path) else { return }
        // 第 3 个参数是 Selector?（完成回调），不需要回调就传 nil
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
        showToast("已保存到相册 ✅")
    }

    private func showToast(_ text: String) {
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) { tip = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
            withAnimation { tip = "" }
        }
    }

    // MARK: - 按钮

    private func toolbarButton(icon: String, title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            toolbarIcon(icon: icon, title: title, tint: tint)
        }
        .buttonStyle(.plain)
    }

    private func toolbarIcon(icon: String, title: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(tint)
                .frame(height: 22)
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(iconColor)
                .lineLimit(1)
                .frame(height: 15)
        }
        .frame(minWidth: 62, minHeight: 58)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: CanvasTheme.chipBG))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
