import Carbon
import Foundation

class KeyboardLayoutMonitor {
    private let onChange: (String) -> Void

    init(onChange: @escaping (String) -> Void) {
        self.onChange = onChange
    }

    func start() {
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(inputSourceChanged),
            name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
            object: nil
        )
    }

    @objc private func inputSourceChanged() {
        guard let source = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue(),
              let namePtr = TISGetInputSourceProperty(source, kTISPropertyLocalizedName) else {
            return
        }
        let name = Unmanaged<CFString>.fromOpaque(namePtr).takeUnretainedValue() as String
        DispatchQueue.main.async { self.onChange(name) }
    }

    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
