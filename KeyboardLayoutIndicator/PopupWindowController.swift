import AppKit

class PopupWindowController: NSObject {
    private var panel: NSPanel?
    private var label: NSTextField?
    private var dismissTimer: Timer?

    func show(layoutName: String) {
        dismissTimer?.invalidate()

        if panel == nil { buildPanel() }

        label?.stringValue = layoutName
        sizeAndPosition()

        panel?.alphaValue = 1
        panel?.orderFrontRegardless()

        dismissTimer = Timer.scheduledTimer(withTimeInterval: 1.8, repeats: false) { [weak self] _ in
            self?.fadeOut()
        }
    }

    // MARK: - Private

    private func buildPanel() {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary]

        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 14
        container.layer?.masksToBounds = true

        // Blur background
        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 14
        blur.layer?.masksToBounds = true
        container.addSubview(blur)

        let label = NSTextField(labelWithString: "")
        label.font = NSFont.systemFont(ofSize: 22, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        container.addSubview(label)

        panel.contentView = container
        self.panel = panel
        self.label = label

        // Constraints wired manually after we know the window
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidResize),
            name: NSWindow.didResizeNotification,
            object: panel
        )

        _ = blur  // keep reference accessible in layout
        self.blurView = blur
    }

    private var blurView: NSVisualEffectView?

    @objc private func windowDidResize() {
        layoutSubviews()
    }

    private func sizeAndPosition() {
        guard let label = label, let panel = panel,
              let container = panel.contentView else { return }

        let padding: CGFloat = 28
        let size = label.sizeThatFits(CGSize(width: 400, height: 60))
        let width = max(size.width + padding * 2, 140)
        let height: CGFloat = 64

        let frame = CGRect(x: 0, y: 0, width: width, height: height)
        panel.setFrame(frame, display: false)

        // Position center of screen, slightly above center
        if let screen = NSScreen.main {
            let sf = screen.visibleFrame
            let x = sf.midX - width / 2
            let y = sf.midY - height / 2 + sf.height * 0.15
            panel.setFrameOrigin(NSPoint(x: x, y: y))
        }

        container.frame = CGRect(x: 0, y: 0, width: width, height: height)
        blurView?.frame = container.bounds
        label.frame = CGRect(x: padding, y: (height - size.height) / 2,
                             width: width - padding * 2, height: size.height)
    }

    private func layoutSubviews() {
        guard let label = label, let panel = panel,
              let container = panel.contentView else { return }
        let width = panel.frame.width
        let height = panel.frame.height
        let padding: CGFloat = 28
        container.frame = CGRect(x: 0, y: 0, width: width, height: height)
        blurView?.frame = container.bounds
        let size = label.sizeThatFits(CGSize(width: width, height: height))
        label.frame = CGRect(x: padding, y: (height - size.height) / 2,
                             width: width - padding * 2, height: size.height)
    }

    private func fadeOut() {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            panel?.animator().alphaValue = 0
        } completionHandler: {
            self.panel?.orderOut(nil)
        }
    }
}
