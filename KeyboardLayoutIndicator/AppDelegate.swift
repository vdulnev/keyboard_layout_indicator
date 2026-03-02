import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var popupController: PopupWindowController?
    private var monitor: KeyboardLayoutMonitor?
    private let statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            button.title = currentLayoutName()
            button.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
            button.action = #selector(statusButtonClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popupController = PopupWindowController()
        monitor = KeyboardLayoutMonitor { [weak self] (layoutName: String) in
            self?.statusItem?.button?.title = layoutName
            self?.popupController?.show(layoutName: layoutName)
        }
        monitor?.start()
    }

    @objc private func statusButtonClicked() {
        guard NSApp.currentEvent?.type == .rightMouseUp else { return }
        statusItem?.menu = statusMenu
        statusItem?.button?.performClick(nil)
        statusItem?.menu = nil
    }

    func currentLayoutName() -> String {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
            return "?"
        }
        return Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
    }
}
