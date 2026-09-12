import SwiftUI
import AppKit

struct EmbeddedShellView: View {
    @State private var session = EmbeddedShellSession()
    @FocusState private var inputFocused: Bool
    @State private var keyMonitor: Any?

    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    Text(session.outputAttributed.characters.isEmpty
                         ? AttributedString(" ")
                         : session.outputAttributed)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                        .id("output-bottom")
                }
                .background(Color.black)
                .onChange(of: session.outputRevision) { _, _ in
                    withAnimation(.easeOut(duration: 0.05)) {
                        proxy.scrollTo("output-bottom", anchor: .bottom)
                    }
                }
            }

            Divider()
                .background(Color.white.opacity(0.15))

            HStack(spacing: 8) {
                Text(session.isRunning ? "›" : "•")
                    .font(.system(size: 14, design: .monospaced))
                    .foregroundStyle(session.isRunning ? Color.green : Color.gray)

                TextField(session.isRunning ? "Type input and press Return" : "Session ended", text: $session.inputText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Color.white)
                    .focused($inputFocused)
                    .disabled(!session.isRunning)
                    .onSubmit {
                        session.submitInput()
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.black)
        }
        .frame(minWidth: 720, minHeight: 420)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .background(
            WindowConfigurator(
                disableZoom: false,
                lockToContentSize: false,
                allowFullScreen: true,
                allowResize: true
            )
        )
        .onAppear {
            configureEmbeddedWindow()
            installCtrlCMonitor()
            if !session.isRunning && session.outputAttributed.characters.isEmpty && !session.didFailToStart {
                session.start()
            }
            inputFocused = true
        }
        .onDisappear {
            removeCtrlCMonitor()
            session.stop()
        }
        .onChange(of: session.shouldCloseWindow) { _, shouldClose in
            guard shouldClose else { return }
            closeEmbeddedShellWindow()
        }
    }

    private func configureEmbeddedWindow() {
        DispatchQueue.main.async {
            guard let window = embeddedShellWindow() else { return }
            window.backgroundColor = .black
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.styleMask.insert(.resizable)
            window.styleMask.insert(.fullSizeContentView)
            window.collectionBehavior.insert(.fullScreenPrimary)
            window.standardWindowButton(.zoomButton)?.isEnabled = true
            window.minSize = NSSize(width: 480, height: 280)
        }
    }

    private func installCtrlCMonitor() {
        removeCtrlCMonitor()
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [session] event in
            let isCtrlC = event.modifierFlags.contains(.control)
                && event.charactersIgnoringModifiers?.lowercased() == "c"
            if isCtrlC {
                session.interrupt()
                return nil
            }
            return event
        }
    }

    private func removeCtrlCMonitor() {
        if let keyMonitor {
            NSEvent.removeMonitor(keyMonitor)
            self.keyMonitor = nil
        }
    }

    private func embeddedShellWindow() -> NSWindow? {
        NSApp.windows.first(where: { $0.title == "Embedded Shell" })
    }

    private func closeEmbeddedShellWindow() {
        DispatchQueue.main.async {
            embeddedShellWindow()?.close()
        }
    }
}
