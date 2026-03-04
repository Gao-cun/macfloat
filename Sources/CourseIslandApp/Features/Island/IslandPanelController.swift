import AppKit
import Combine
import SwiftUI

final class FloatingIslandPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class IslandPanelController {
    private let panel: FloatingIslandPanel
    private var cancellables: Set<AnyCancellable> = []
    private let collapsedHeight: CGFloat = 120
    private let expandedHeight: CGFloat = 260

    init(viewModel: IslandViewModel, rootView: AnyView) {
        panel = FloatingIslandPanel(
            contentRect: .init(x: 0, y: 0, width: 440, height: collapsedHeight),
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

        viewModel.$isExpanded
            .receive(on: RunLoop.main)
            .sink { [weak self] isExpanded in
                self?.updatePanelSize(isExpanded: isExpanded)
            }
            .store(in: &cancellables)
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
            y: frame.maxY - panel.frame.height
        )
        panel.setFrameOrigin(origin)
    }

    private func updatePanelSize(isExpanded: Bool) {
        let targetSize = NSSize(width: 440, height: isExpanded ? expandedHeight : collapsedHeight)
        var nextFrame = panel.frame
        nextFrame.origin.y += nextFrame.height - targetSize.height
        nextFrame.size = targetSize
        panel.setFrame(nextFrame, display: true, animate: true)
        positionPanel()
    }
}
