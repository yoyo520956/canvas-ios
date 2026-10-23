import SwiftUI

struct ToolbarView: View {
    @ObservedObject var state: CanvasState
    var onAddImage: () -> Void
    var onAddText: () -> Void
    var onSettings: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Add image node
            Button(action: onAddImage) {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title3)
                    Text("图片")
                        .font(.caption2)
                }
                .frame(width: 64, height: 56)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(12)
            }
            
            // Add text node
            Button(action: onAddText) {
                VStack(spacing: 4) {
                    Image(systemName: "text.quote")
                        .font(.title3)
                    Text("文字")
                        .font(.caption2)
                }
                .frame(width: 64, height: 56)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(12)
            }
            
            Spacer()
            
            // Settings
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.title3)
                    .frame(width: 56, height: 56)
                    .background(Color(uiColor: .systemGray5))
                    .cornerRadius(12)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(uiColor: UIColor(white: 0.08, alpha: 1)).opacity(0.95))
    }
}

struct PromptInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var kind: NodeKind = .image
    let onSubmit: (NodeKind, String) -> Void
    
    var body: some View {
        NavigationStack {
            Form {
                Section("节点类型") {
                    Picker("类型", selection: $kind) {
                        ForEach(NodeKind.allCases, id: \.self) { k in
                            Text(k.label).tag(k)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                if kind == .image {
                    Section("提示词") {
                        TextEditor(text: $prompt)
                            .frame(minHeight: 150)
                        Text("输入描述，AI 会为你生成图片。越详细效果越好。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("文字内容") {
                        TextEditor(text: $prompt)
                            .frame(minHeight: 100)
                    }
                }
            }
            .navigationTitle(kind == .image ? "添加图片节点" : "添加文字节点")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("添加") {
                        onSubmit(kind, prompt)
                        dismiss()
                    }
                    .disabled(prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: CanvasState
    @State private var baseURL = AgnesConfig.default.baseURL
    @State private var apiKey = AgnesConfig.default.apiKey
    @State private var model = AgnesConfig.default.model
    
    var body: some View {
        NavigationStack {
            Form {
                Section("API 配置") {
                    TextField("Base URL", text: $baseURL)
                    SecureField("API Key", text: $apiKey)
                    TextField("模型", text: $model)
                        .autocapitalization(.none)
                }
                
                Section("模型选择") {
                    Picker("图片模型", selection: $model) {
                        Text("agnes-image-2.5-flash").tag("agnes-image-2.5-flash")
                        Text("agnes-image-2.0-flash").tag("agnes-image-2.0-flash")
                    }
                }
                
                Section("说明") {
                    Text("配置完成后，所有节点将使用新的 API 配置生成图片。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        state.config = AgnesConfig(baseURL: baseURL, apiKey: apiKey, model: model)
                        dismiss()
                    }
                }
            }
        }
    }
}
