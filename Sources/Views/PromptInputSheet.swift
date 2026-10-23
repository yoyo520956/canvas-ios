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
                    .font(.body)
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .frame(maxHeight: .infinity)
                    .background(Color(uiColor: UIColor(white: 0.12, alpha: 1)))
                    .cornerRadius(12)

                if kind == .image {
                    Text("提示词越具体越好：主体 + 风格 + 光线 + 构图")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
}
