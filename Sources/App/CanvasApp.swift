import SwiftUI

@main
struct CanvasApp: App {
    @StateObject private var state = CanvasState()
    @State private var showPromptSheet = false
    @State private var showSettings = false
    @State private var promptKind: NodeKind = .image
    
    var body: some Scene {
        WindowGroup {
            VStack(spacing: 0) {
                // Top bar
                topBar
                    .padding(.top, 8)
                
                // Canvas
                CanvasView(state: state)
                    .flexibleHeight()
                
                // Bottom toolbar
                ToolbarView(
                    state: state,
                    onAddImage: { showAddNode(.image) },
                    onAddText: { showAddNode(.text) },
                    onSettings: { showSettings = true }
                )
                .padding(.bottom, 8)
            }
            .background(Color(uiColor: UIColor(white: 0.06, alpha: 1)))
            .sheet(isPresented: $showPromptSheet) {
                PromptInputSheet(
                    kind: promptKind,
                    onSubmit: { kind, prompt in
                        state.addNode(kind: kind, prompt: prompt)
                    }
                )
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet(state: state)
            }
        }
    }
    
    private var topBar: some View {
        HStack {
            Text("无限画布")
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Node count
            Text("\(state.nodes.count) 个节点")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color(uiColor: .systemGray5))
                .cornerRadius(8)
        }
        .padding(.horizontal, 16)
    }
    
    private func showAddNode(_ kind: NodeKind) {
        promptKind = kind
        showPromptSheet = true
    }
}
