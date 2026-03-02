import AppKit

// MARK: - Model

struct AppInfo {
    let name: String
    let bundleIdentifier: String
    let icon: NSImage
}

// MARK: - Window controller

class AppSelectionWindowController: NSWindowController, NSTableViewDataSource, NSTableViewDelegate {
    private var allApps: [AppInfo] = []
    private var filtered: [AppInfo] = []
    private var pending: Set<String> = []

    private let tableView = NSTableView()
    private let searchField = NSSearchField()
    private let hintLabel = NSTextField(labelWithString: "")

    // MARK: Init

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 480),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Show Popup In"
        window.minSize = NSSize(width: 300, height: 300)
        self.init(window: window)
        buildUI()
    }

    override func showWindow(_ sender: Any?) {
        pending = AppPreferences.shared.allowedBundleIDs
        loadApps()
        updateHint()
        super.showWindow(sender)
        window?.center()
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - UI

    private func buildUI() {
        guard let content = window?.contentView else { return }

        // Hint label
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        hintLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.maximumNumberOfLines = 1
        content.addSubview(hintLabel)

        // Search field
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Search"
        searchField.target = self
        searchField.action = #selector(searchChanged)
        content.addSubview(searchField)

        // Scroll + table
        let scroll = NSScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        scroll.hasVerticalScroller = true
        scroll.borderType = .bezelBorder

        tableView.headerView = nil
        tableView.rowHeight = 30
        tableView.dataSource = self
        tableView.delegate = self
        tableView.selectionHighlightStyle = .none
        tableView.usesAlternatingRowBackgroundColors = true
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("App"))
        col.isEditable = false
        tableView.addTableColumn(col)
        scroll.documentView = tableView
        content.addSubview(scroll)

        // Buttons
        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(cancel))
        cancelBtn.translatesAutoresizingMaskIntoConstraints = false
        cancelBtn.keyEquivalent = "\u{1b}"

        let okBtn = NSButton(title: "OK", target: self, action: #selector(ok))
        okBtn.translatesAutoresizingMaskIntoConstraints = false
        okBtn.keyEquivalent = "\r"
        okBtn.bezelStyle = .rounded

        content.addSubview(cancelBtn)
        content.addSubview(okBtn)

        NSLayoutConstraint.activate([
            hintLabel.topAnchor.constraint(equalTo: content.topAnchor, constant: 12),
            hintLabel.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            hintLabel.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            searchField.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            searchField.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            searchField.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),

            scroll.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scroll.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
            scroll.bottomAnchor.constraint(equalTo: okBtn.topAnchor, constant: -12),

            cancelBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            cancelBtn.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 12),

            okBtn.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -12),
            okBtn.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -12),
        ])
    }

    private func updateHint() {
        if pending.isEmpty {
            hintLabel.stringValue = "Showing in all applications. Check apps to restrict."
        } else {
            let n = pending.count
            hintLabel.stringValue = "Showing in \(n) application\(n == 1 ? "" : "s"). Uncheck all to show everywhere."
        }
    }

    // MARK: - Data

    private func loadApps() {
        let dirs = ["/Applications", "/Applications/Utilities", "/System/Applications"]
        var seen: [String: AppInfo] = [:]

        for dir in dirs {
            let url = URL(fileURLWithPath: dir)
            guard let items = try? FileManager.default.contentsOfDirectory(
                at: url, includingPropertiesForKeys: nil
            ) else { continue }
            for item in items where item.pathExtension == "app" {
                if let info = makeAppInfo(url: item), seen[info.bundleIdentifier] == nil {
                    seen[info.bundleIdentifier] = info
                }
            }
        }

        // Include running regular apps not already found
        for app in NSWorkspace.shared.runningApplications
        where app.activationPolicy == .regular {
            guard let id = app.bundleIdentifier,
                  let url = app.bundleURL,
                  seen[id] == nil,
                  let info = makeAppInfo(url: url) else { continue }
            seen[id] = info
        }

        allApps = seen.values.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
        applyFilter()
    }

    private func makeAppInfo(url: URL) -> AppInfo? {
        guard let bundle = Bundle(url: url),
              let id = bundle.bundleIdentifier else { return nil }
        let name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? url.deletingPathExtension().lastPathComponent
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        return AppInfo(name: name, bundleIdentifier: id, icon: icon)
    }

    private func applyFilter() {
        let q = searchField.stringValue.lowercased()
        filtered = q.isEmpty ? allApps : allApps.filter { $0.name.lowercased().contains(q) }
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func searchChanged() { applyFilter() }

    @objc private func ok() {
        AppPreferences.shared.allowedBundleIDs = pending
        close()
    }

    @objc private func cancel() { close() }

    // MARK: - NSTableViewDataSource

    func numberOfRows(in tableView: NSTableView) -> Int { filtered.count }

    // MARK: - NSTableViewDelegate

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let app = filtered[row]
        let id = NSUserInterfaceItemIdentifier("AppCell")
        var cell = tableView.makeView(withIdentifier: id, owner: nil) as? AppCellView
        if cell == nil {
            cell = AppCellView()
            cell?.identifier = id
        }
        cell?.configure(app: app, checked: pending.contains(app.bundleIdentifier))
        return cell
    }

    // Clicking anywhere on a row toggles the checkbox.
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let id = filtered[row].bundleIdentifier
        if pending.contains(id) { pending.remove(id) } else { pending.insert(id) }
        tableView.reloadData(forRowIndexes: IndexSet(integer: row),
                             columnIndexes: IndexSet(integer: 0))
        updateHint()
        return false
    }
}

// MARK: - Cell view

private class AppCellView: NSTableCellView {
    // NSImageView does not intercept mouse events, so clicks flow through
    // to NSTableRowView and trigger shouldSelectRow as intended.
    private let checkmark = NSImageView()
    private let iconView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")

    override init(frame: NSRect) {
        super.init(frame: frame)

        checkmark.translatesAutoresizingMaskIntoConstraints = false
        checkmark.imageScaling = .scaleProportionallyUpOrDown
        addSubview(checkmark)

        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.imageScaling = .scaleProportionallyDown
        addSubview(iconView)

        nameLabel.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.lineBreakMode = .byTruncatingTail
        addSubview(nameLabel)

        NSLayoutConstraint.activate([
            checkmark.centerYAnchor.constraint(equalTo: centerYAnchor),
            checkmark.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 8),
            checkmark.widthAnchor.constraint(equalToConstant: 16),
            checkmark.heightAnchor.constraint(equalToConstant: 16),

            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.leadingAnchor.constraint(equalTo: checkmark.trailingAnchor, constant: 8),
            iconView.widthAnchor.constraint(equalToConstant: 20),
            iconView.heightAnchor.constraint(equalToConstant: 20),

            nameLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            nameLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
            nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -8),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    func configure(app: AppInfo, checked: Bool) {
        iconView.image = app.icon
        nameLabel.stringValue = app.name

        let symbolName = checked ? "checkmark.square.fill" : "square"
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .regular)
        checkmark.image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)?
            .withSymbolConfiguration(config)
        checkmark.contentTintColor = checked ? .controlAccentColor : .tertiaryLabelColor
    }
}
