import SwiftUI

@main
struct CanvasApp: App {
    @StateObject private var state = CanvasState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPromptSheet = false
    @State private var showSettings = false
    @State private var promptKind: NodeKind = .image

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 6)
                    .padding(.bottom, 4)

                CanvasView(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ToolbarView(
                    state: state,
                    onAddImage: { presentAdd(.image) },
                    onAddText: { presentAdd(.text) },
                    onSettings: { showSettings = true }
                )
            }
            .background(Color(uiColor: UIColor(white: 0.055, alpha: 1)))
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: scenePhase) { phase in
                // 离开前台立刻落盘，避开 0.6s 防抖窗口被系统杀掉
                if phase != .active { state.flushNow() }
            }
            .sheet(isPresented: $showPromptSheet) {
                PromptInputSheet(kind: promptKind) { kind, prompt in
                    state.addNode(kind: kind, prompt: prompt)
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(state: state)
            }
        }
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "square.on.square.dashed")
                    .foregroundColor(Color(uiColor: UIColor(red: 0, green: 0.83, blue: 1, alpha: 1)))
                Text("无限画布")
                    .font(.headline)
            }

            Spacer()

            if state.generatingIds.isEmpty == false {
                HStack(spacing: 5) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("\(state.generatingIds.count) 个生成中")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(9)
            }

            Text("\(state.nodes.count) 节点")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(9)
        }
        .padding(.horizontal, 16)
    }

    private func presentAdd(_ kind: NodeKind) {
        promptKind = kind
        showPromptSheet = true
    }
}
