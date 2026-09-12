import AppKit
import SwiftUI

/// Configures the hosting `NSWindow` (fullscreen, resize limits).
struct WindowConfigurator: NSViewRepresentable {
    var disableMinimize = false
    var disableZoom = true
    /// When true, keeps the window sized to its content and not user-resizable.
    var lockToContentSize = false
    /// When true, allows the green zoom button / fullscreen.
    var allowFullScreen = false
    /// When true, keeps `.resizable` on the window (ignored if `lockToContentSize` is true).
    var allowResize = false

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        context.coordinator.scheduleConfigure(for: view, representable: self)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.scheduleConfigure(for: nsView, representable: self)
    }

    final class Coordinator {
        private var configureScheduled = false

        func scheduleConfigure(for view: NSView, representable: WindowConfigurator) {
            guard !configureScheduled else { return }
            configureScheduled = true
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.configureScheduled = false
                guard let window = view.window else { return }
                self.configure(window: window, representable: representable)
            }
        }

        private func configure(window: NSWindow, representable: WindowConfigurator) {
            if representable.allowFullScreen {
                window.collectionBehavior.remove(.fullScreenNone)
                window.collectionBehavior.insert(.fullScreenPrimary)
            } else {
                window.collectionBehavior.remove(.fullScreenPrimary)
                window.collectionBehavior.remove(.fullScreenAuxiliary)
                window.collectionBehavior.insert(.fullScreenNone)
            }

            if representable.disableZoom {
                window.standardWindowButton(.zoomButton)?.isEnabled = false
            } else {
                window.standardWindowButton(.zoomButton)?.isEnabled = true
            }
            if representable.disableMinimize {
                window.standardWindowButton(.miniaturizeButton)?.isEnabled = false
            }

            if representable.lockToContentSize {
                window.styleMask.remove(.resizable)
                window.contentView?.layoutSubtreeIfNeeded()

                let contentSize = window.contentLayoutRect.size
                guard contentSize.width > 1, contentSize.height > 1 else { return }

                let current = window.contentLayoutRect.size
                if abs(current.width - contentSize.width) > 0.5
                    || abs(current.height - contentSize.height) > 0.5 {
                    window.setContentSize(contentSize)
                }

                let frameSize = window.frameRect(forContentRect: NSRect(origin: .zero, size: contentSize)).size
                if window.minSize != frameSize || window.maxSize != frameSize {
                    window.minSize = frameSize
                    window.maxSize = frameSize
                }
                return
            }

            if representable.allowResize {
                window.styleMask.insert(.resizable)
                window.minSize = NSSize(width: 480, height: 280)
                window.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            }
        }
    }
}
