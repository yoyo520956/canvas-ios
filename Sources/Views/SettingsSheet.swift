import SwiftUI

// MARK: - 设置

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var state: CanvasState

    @State private var baseURL = ""
    @State private var apiKey = ""
    @State private var model = ""
    @State private var size = "1024x1024"
    @State private var showKey = false
    @State private var confirmClear = false

    private let models = [
        "agnes-image-2.5-flash",
        "agnes-image-2.0-flash",
        "dall-e-3",
        "gpt-image-1",
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("API 配置") {
                    TextField("Base URL", text: $baseURL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                        .keyboardType(.URL)

                    HStack {
                        Group {
                            if showKey {
                                TextField("API Key", text: $apiKey)
                            } else {
                                SecureField("API Key", text: $apiKey)
                            }
                        }
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                        Button {
                            showKey.toggle()
                        } label: {
                            Image(systemName: showKey ? "eye.slash" : "eye")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section("模型") {
                    Picker("生图模型", selection: $model) {
                        ForEach(models, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)

                    // 上面列表之外的模型名，直接在这里填
                    TextField("或手填模型名", text: $model)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)

                    Picker("出图尺寸", selection: $size) {
                        ForEach(AgnesConfig.sizes, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)
                }

                Section("画布") {
                    HStack {
                        Text("当前节点")
                        Spacer()
                        Text("\(state.nodes.count) 个")
                            .foregroundColor(.secondary)
                    }
                    Button("清空画布", role: .destructive) {
                        confirmClear = true
                    }
                }

                Section {
                    Text("Key 与画布存档都只存本机沙盒（Documents/Canvas），不上传服务器。")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .alert("确定清空全部节点和图片缓存？", isPresented: $confirmClear) {
                Button("清空", role: .destructive) {
                    state.clearAll()
                    dismiss()
                }
                Button("取消", role: .cancel) {}
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        let m = model.trimmingCharacters(in: .whitespaces)
                        state.config = AgnesConfig(
                            baseURL: baseURL.trimmingCharacters(in: .whitespaces),
                            apiKey: apiKey.trimmingCharacters(in: .whitespaces),
                            model: m.isEmpty ? AgnesConfig.default.model : m,
                            size: size)
                        dismiss()
                    }
                }
            }
            .onAppear {
                baseURL = state.config.baseURL
                apiKey = state.config.apiKey
                model = state.config.model
                size = state.config.size
            }
        }
    }
}
