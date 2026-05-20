import SwiftUI
import AppKit

/// Forces the host NSWindow to a fixed content size by reaching through the view hierarchy.
struct WindowConfigurator: NSViewRepresentable {
    let width: CGFloat
    let height: CGFloat

    func makeNSView(context: Context) -> NSView {
        let view = HostingView(width: width, height: height)
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    // NSView subclass so we can hook viewDidMoveToWindow
    private class HostingView: NSView {
        let targetWidth: CGFloat
        let targetHeight: CGFloat

        init(width: CGFloat, height: CGFloat) {
            self.targetWidth = width
            self.targetHeight = height
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            guard let w = window else { return }
            let size = NSSize(width: targetWidth, height: targetHeight)
            w.setContentSize(size)
            w.minSize = size
            w.maxSize = size
            w.center()
        }
    }
}
