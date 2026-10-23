import SwiftUI

// MARK: - 新建节点：输入提示词

struct PromptInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var kind: NodeKind
    var onConfirm: (NodeKind, String) -> Void

    init(kind: NodeKind, onConfirm: @escaping (NodeKind, String) -> Void) {
        self.kind = kind
        self.onConfirm = onConfirm
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Picker("类型", selection: $kind) {
                    ForEach(NodeKind.allCases, id: \.self) { k in
                        Text(k.label).tag(k)
                    }
                }
                .pickerStyle(.segmented)

                TextEditor(text: $prompt)
                    .font(.system(size: 17, weight: .regular))
                    .scrollContentBackground(.hidden)
                    .padding(12)
                    .frame(maxHeight: .infinity)
                    .background(Color(uiColor: CanvasTheme.fieldBG))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(uiColor: CanvasTheme.cardBorder), lineWidth: 1)
                    )

                if kind == .image {
                    Text("提示词越具体越好：主体 + 风格 + 光线 + 构图")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Color(uiColor: CanvasTheme.textSecondary))
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(examples(for: kind), id: \.self) { ex in
                            Button(ex) {
                                withAnimation { prompt = ex }
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(Color(uiColor: CanvasTheme.textPrimary))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(uiColor: CanvasTheme.chipBG))
                            .cornerRadius(10)
                        }
                    }
                }
            }
            .padding(16)
            .navigationTitle(kind == .image ? "新建 AI 生图节点" : "新建文字节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("创建") {
                        onConfirm(kind, prompt.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func examples(for kind: NodeKind) -> [String] {
        kind == .image
            ? ["赛博朋克风格的街道夜景，霓虹灯光，电影感", "极简白色客厅，柔和自然光，室内摄影", "星空下的雪山营地，长曝光，广角镜头", "手绘水彩风的日式庭院，樱花飘落"]
            : ["项目笔记", "灵感记录", "待办清单", "会议纪要"]
    }
}
