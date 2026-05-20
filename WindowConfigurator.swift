import AppKit
import SwiftUI

/// Configures the hosting `NSWindow` (fullscreen, resize limits, optional quit-on-close).
struct WindowConfigurator: NSViewRepresentable {
    var quitOnClose = false
    var disableMinimize = false
    var disableZoom = true
    /// When true, locks the window to its content size on first layout (no growing or shrinking).
    var lockToContentSize = false

    func makeCoordinator() -> Coordinator {
        Coordinator(quitOnClose: quitOnClose)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            if let window = view.window {
                configure(window: window, coordinator: context.coordinator)
            }
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                configure(window: window, coordinator: context.coordinator)
            }
        }
    }

    private func configure(window: NSWindow, coordinator: Coordinator) {
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.collectionBehavior.remove(.fullScreenAuxiliary)

        if disableZoom {
            window.standardWindowButton(.zoomButton)?.isEnabled = false
        }
        if disableMinimize {
            window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
        }

        if lockToContentSize, !coordinator.didLockSize {
            window.contentView?.layoutSubtreeIfNeeded()
            let contentSize = window.contentLayoutRect.size
            guard contentSize.width > 0, contentSize.height > 0 else { return }

            let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
            window.setContentSize(contentSize)
            window.minSize = frameSize
            window.maxSize = frameSize
            window.styleMask.remove(.resizable)
            coordinator.didLockSize = true
        }

        if quitOnClose {
            coordinator.observeClose(on: window)
        }
    }

    final class Coordinator {
        let quitOnClose: Bool
        var didLockSize = false
        private var closeObserver: NSObjectProtocol?

        init(quitOnClose: Bool) {
            self.quitOnClose = quitOnClose
        }

        func observeClose(on window: NSWindow) {
            guard quitOnClose, closeObserver == nil else { return }
            closeObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                NSApp.terminate(nil)
            }
        }
    }
}
