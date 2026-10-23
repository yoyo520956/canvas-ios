import SwiftUI

struct ToolbarView: View {
    @ObservedObject var state: CanvasState
    var onAddImage: () -> Void
    var onAddText: () -> Void
    var onSettings: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            toolbarButton(icon: "photo.on.rectangle.angled", title: "图片", color: .cyan, action: onAddImage)
            toolbarButton(icon: "text.quote", title: "文字", color: .mint, action: onAddText)

            if state.selectedNodeId != nil {
                toolbarButton(icon: "trash", title: "删除", color: .red) {
                    if let id = state.selectedNodeId {
                        state.deleteNode(id)
                    }
                }
            }

            Spacer()

            toolbarButton(icon: "gearshape", title: "设置", color: .gray, action: onSettings)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(Color(uiColor: UIColor(white: 0.085, alpha: 1)).opacity(0.97))
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

struct PromptInputSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var prompt = ""
    @State private var kind: NodeKind
    let onSubmit: (NodeKind, String) -> Void

    init(kind: NodeKind, onSubmit: @escaping (NodeKind, String) -> Void) {
        _kind = State(initialValue: kind)
        self.onSubmit = onSubmit
    }

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
                            .overlay(alignment: .topLeading) {
                                if prompt.isEmpty {
                                    Text("描述你想要的画面，例如：赛博朋克城市夜景，霓虹灯，暴雨…")
                                        .font(.footnote)
                                        .foregroundColor(.secondary)
                                        .padding(.top, 8)
                                        .padding(.leading, 5)
                                        .allowsHitTesting(false)
                                }
                            }
                        Text("越具体越好；生成后可在节点内重新编辑并再生成。")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Section("文字内容") {
                        TextEditor(text: $prompt)
                            .frame(minHeight: 110)
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
        .presentationDetents([.medium, .large])
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: CanvasState
    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var showKey = false

    var body: some View {
        NavigationStack {
            Form {
                Section("API 配置") {
                    TextField("Base URL", text: $baseURL)
                        .autocapitalization(.none)
                        .keyboardType(.URL)
                    HStack {
                        if showKey {
                            TextField("API Key", text: $apiKey)
                                .autocapitalization(.none)
                        } else {
                            SecureField("API Key", text: $apiKey)
                                .autocapitalization(.none)
                        }
                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    TextField("模型", text: $model)
                        .autocapitalization(.none)
                }

                Section("图片模型") {
                    Picker("图片模型", selection: $model) {
                        Text("agnes-image-2.5-flash").tag("agnes-image-2.5-flash")
                        Text("agnes-image-2.0-flash").tag("agnes-image-2.0-flash")
                    }
                    .pickerStyle(.menu)
                }

                Section {
                    Text("配置保存在本机 UserDefaults，不会同步到服务器。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        state.config = AgnesConfig(baseURL: baseURL, apiKey: apiKey, model: model)
                        dismiss()
                    }
                }
            }
            .onAppear {
                baseURL = state.config.baseURL
                apiKey = state.config.apiKey
                model = state.config.model
            }
        }
    }
}
