import AppKit
import SwiftUI

final class FloatingIslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class IslandPanelController {
    private let panel: FloatingIslandPanel

    init(rootView: AnyView) {
        panel = FloatingIslandPanel(
            contentRect: .init(x: 0, y: 0, width: 440, height: 120),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.contentView = NSHostingView(rootView: rootView)
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        positionPanel()
    }

    func show() {
        positionPanel()
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }

    func toggle() {
        panel.isVisible ? hide() : show()
    }

    private func positionPanel() {
        guard let screen = NSScreen.main else { return }
        let frame = screen.visibleFrame
        let origin = CGPoint(
            x: frame.midX - 220,
            y: frame.maxY - 120
        )
        panel.setFrameOrigin(origin)
    }
}
