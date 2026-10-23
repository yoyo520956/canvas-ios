import SwiftUI

@main
struct CanvasApp: App {
    @StateObject private var state = CanvasState()
    @Environment(\.scenePhase) private var scenePhase
    @State private var showPromptSheet = false
    @State private var showSettings = false
    @State private var promptKind: NodeKind = .image

    private var accent: Color { Color(uiColor: CanvasTheme.accent) }
    private var chipBG: Color { Color(uiColor: CanvasTheme.chipBG) }
    private var fg: Color { Color(uiColor: CanvasTheme.textPrimary) }

    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                topBar
                    .padding(.top, 8)
                    .padding(.bottom, 6)

                CanvasView(state: state)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                ToolbarView(
                    state: state,
                    onAddImage: { presentAdd(.image) },
                    onAddText: { presentAdd(.text) },
                    onSettings: { showSettings = true }
                )
            }
            .background(Color(uiColor: CanvasTheme.canvasBG))
            .tint(accent)
            .preferredColorScheme(.dark)
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

    // MARK: - 顶栏

    private var topBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 19, weight: .semibold))
                .foregroundColor(accent)
            Text("无限画布")
                .font(.system(size: 19, weight: .heavy))
                .foregroundColor(fg)

            Spacer()

            if !state.generatingIds.isEmpty {
                HStack(spacing: 6) {
                    ProgressView().controlSize(.mini)
                    Text("\(state.generatingIds.count) 个生成中")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(accent)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(chipBG)
                .cornerRadius(10)
            }

            HStack(spacing: 5) {
                Circle()
                    .fill(state.hasUsableKey ? Color.green : Color.orange)
                    .frame(width: 7, height: 7)
                Text("\(state.nodes.count) 节点")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(fg)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(chipBG)
            .cornerRadius(10)
        }
        .padding(.horizontal, 14)
    }

    private func presentAdd(_ kind: NodeKind) {
        promptKind = kind
        showPromptSheet = true
    }
}
