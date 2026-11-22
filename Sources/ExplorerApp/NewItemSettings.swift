import AppKit
import ExplorerCore
import UniformTypeIdentifiers

@MainActor
final class NewItemSettings: NSViewController, NSTextFieldDelegate {
    private let store = NewItemTemplates.shared
    private let picker = NSPopUpButton()
    private let enabled = NSButton(checkboxWithTitle: L10n.text("Show in Create menu"), target: nil, action: nil)
    private let titleField = NSTextField()
    private let openAfter = NSButton(checkboxWithTitle: L10n.text("Open after creation"), target: nil, action: nil)
    private let status = NSTextField(wrappingLabelWithString: "")
    private var selected: NewItemTemplate? { store.entries.indices.contains(picker.indexOfSelectedItem) ? store.entries[picker.indexOfSelectedItem] : nil }
    override func loadView() {
        preferredContentSize = NSSize(width: 590, height: 540)
        let content = Surface(frame: NSRect(x: 0, y: 0, width: 590, height: 540))
        let scroll = NSScrollView(frame: content.frame); scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true; scroll.drawsBackground = false; scroll.documentView = content
        view = scroll
        content.translatesAutoresizingMaskIntoConstraints = false
        content.widthAnchor.constraint(equalTo: scroll.contentView.widthAnchor).isActive = true
        let heading = NSTextField(labelWithString: L10n.text("Create files")); heading.font = .systemFont(ofSize: 20, weight: .semibold)
        let note = NSTextField(wrappingLabelWithString: L10n.text("Office formats use blank documents and any registered compatible app. For PSD, AI or other formats, import a blank document saved by your editor. Explorer copies templates without running them."))
        note.font = .systemFont(ofSize: 12); note.textColor = .secondaryLabelColor
        picker.target = self; picker.action = #selector(refresh)
        enabled.target = self; enabled.action = #selector(save)
        openAfter.target = self; openAfter.action = #selector(save)
        titleField.delegate = self
        titleField.placeholderString = L10n.text("Menu title")
        titleField.setAccessibilityLabel(L10n.text("Menu title"))
        func button(_ title: String, _ action: Selector) -> NSButton { NSButton(title: L10n.text(title), target: self, action: action) }
        let templateButtons = NSStackView(views: [button("Import Template…", #selector(importFile)), button("Add Format…", #selector(add)), button("Remove Format", #selector(remove))])
        let appButtons = NSStackView(views: [button("Choose Application…", #selector(chooseApp)), button("Use System Default", #selector(defaultApp))])
        let stack = NSStackView(views: [heading, note, picker, enabled, titleField, openAfter, templateButtons, appButtons, status])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16
        content.addSubview(stack); stack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 28), stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -28), stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 25), stack.bottomAnchor.constraint(equalTo: content.bottomAnchor, constant: -25)])
        for child in [note, picker, titleField, status] { child.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true }
        reload()
    }
    override func viewWillAppear() { super.viewWillAppear(); reload(select: selected?.id) }
    private func reload(select id: String? = nil) {
        picker.removeAllItems(); picker.addItems(withTitles: store.entries.map { L10n.text($0.title) })
        if let id, let index = store.entries.firstIndex(where: { $0.id == id }) { picker.selectItem(at: index) }
        refresh()
    }
    @objc private func refresh() {
        guard let entry = selected else { enabled.isEnabled = false; titleField.isEnabled = false; openAfter.isEnabled = false; status.stringValue = ""; return }
        enabled.isEnabled = true; titleField.isEnabled = true; openAfter.isEnabled = true
        enabled.state = entry.enabled ? .on : .off; openAfter.state = entry.openAfterCreation ? .on : .off
        titleField.stringValue = L10n.text(entry.title)
        let source = store.source(for: entry)
        let app = store.application(for: entry)
        status.stringValue = [L10n.text("Template") + ": " + (source?.path ?? (entry.id == "txt" ? L10n.text("Empty text file") : L10n.text("Import a template to enable this format."))), L10n.text("Application") + ": " + (app.map { ExternalApplications.name(of: $0) } ?? (entry.id == "txt" ? L10n.text("System default") : L10n.text("No compatible application found.")))].joined(separator: "\n\n")
    }
    func controlTextDidChange(_ notification: Notification) {
        guard var entry = selected else { return }
        let name = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        entry.title = name; store.save(entry); picker.selectedItem?.title = name
    }
    @objc private func save() {
        guard var entry = selected else { return }
        entry.enabled = enabled.state == .on; entry.openAfterCreation = openAfter.state == .on
        let name = titleField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != L10n.text(entry.title) { entry.title = name }
        store.save(entry); reload(select: entry.id)
    }
    private func panel(application: Bool, completion: @escaping (URL) -> Void) {
        guard let window = view.window, window.attachedSheet == nil else { return }
        let panel = NSOpenPanel(); panel.allowsMultipleSelection = false; panel.canChooseDirectories = false
        if application { panel.allowedContentTypes = [.applicationBundle]; panel.directoryURL = URL(fileURLWithPath: "/Applications") }
        panel.beginSheetModal(for: window) { response in if response == .OK, let url = panel.url { completion(url) } }
    }
    @objc private func importFile() {
        guard let entry = selected else { return }
        panel(application: false) { [weak self] url in
            guard let self else { return }
            do { try self.store.importTemplate(url, for: entry); self.refresh() }
            catch { ExternalApplications.showError(error.localizedDescription, window: self.view.window) }
        }
    }
    @objc private func add() {
        panel(application: false) { [weak self] url in
            guard let self else { return }
            let entry = NewItemTemplate(id: UUID().uuidString, title: url.deletingPathExtension().lastPathComponent)
            do { try self.store.importTemplate(url, for: entry); self.reload(select: entry.id) }
            catch { ExternalApplications.showError(error.localizedDescription, window: self.view.window) }
        }
    }
    @objc private func remove() { if let entry = selected { store.remove(entry.id); reload() } }
    @objc private func chooseApp() {
        guard var entry = selected else { return }
        panel(application: true) { [weak self] url in
            guard let self, Bundle(url: url)?.bundleIdentifier != Bundle.main.bundleIdentifier else { return }
            entry.applicationPath = url.path; self.store.save(entry); self.refresh()
        }
    }
    @objc private func defaultApp() { if var entry = selected { entry.applicationPath = nil; store.save(entry); refresh() } }
}
