import AppKit

final class AppPreferences {
    static let shared = AppPreferences()
    private let key = "allowedBundleIDs"

    var allowedBundleIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: key) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: key) }
    }

    // Returns true if the popup should be shown for the currently frontmost app.
    // An empty allowlist means "show in all applications".
    func shouldShowPopup() -> Bool {
        guard !allowedBundleIDs.isEmpty else { return true }
        guard let id = NSWorkspace.shared.frontmostApplication?.bundleIdentifier else { return false }
        return allowedBundleIDs.contains(id)
    }
}
