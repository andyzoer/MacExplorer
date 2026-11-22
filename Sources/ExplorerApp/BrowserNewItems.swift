import AppKit
import ExplorerCore

extension BrowserViewController {
    func createMenu(destination: URL?) -> NSMenuItem {
        let parent = NSMenuItem(title: L10n.text("Create"), action: nil, keyEquivalent: "")
        parent.image = Palette.symbol("plus.circle")
        let menu = NSMenu(); menu.autoenablesItems = false
        let available = destination != nil && !operations.busy
        menu.addItem(ContextMenu.item(L10n.text("New Folder…"), symbol: "folder.badge.plus", enabled: available) { [weak self] in
            guard let self, let folder = destination, let window = self.view.window else { return }
            self.operations.askName(title: L10n.text("New Folder"), initial: L10n.text("New folder"), selectStem: false, window: window) { [weak self] name in
                self?.operations.run(.newFolder(in: folder, name: name), window: window)
            }
        })
        menu.addItem(ContextMenu.item(L10n.text("Alias…"), symbol: "arrowshape.turn.up.right", enabled: available) { [weak self] in self?.createAlias(in: destination) })
        menu.addItem(.separator())
        let store = NewItemTemplates.shared
        for entry in store.entries where entry.enabled && store.available(entry) {
            let item = ContextMenu.item(L10n.text(entry.title) + "…", symbol: "doc.badge.plus", enabled: available) { [weak self] in
                self?.createDocument(entry, in: destination)
            }
            if let app = store.application(for: entry) { item.toolTip = ExternalApplications.name(of: app) }
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(ContextMenu.item(L10n.text("Configure Create Menu…"), symbol: "gearshape") { NewItemSettingsWindow.show() })
        parent.submenu = menu; return parent
    }
    private func copyCreatedFile(_ staged: (file: URL, directory: URL), into folder: URL, entry: NewItemTemplate? = nil) {
        guard let window = view.window, !operations.busy else { try? FileManager.default.removeItem(at: staged.directory); return }
        let application = entry.flatMap { NewItemTemplates.shared.application(for: $0) }
        operations.run(.copy([staged.file], to: folder), window: window) { report in
            defer { try? FileManager.default.removeItem(at: staged.directory) }
            if entry?.openAfterCreation == true, report.error == nil, !report.cancelled, let output = report.completed.first {
                if let application { ExternalApplications.open([output], with: application, window: window) }
                else { NSWorkspace.shared.open(output) }
            }
        }
    }
    private func createDocument(_ entry: NewItemTemplate, in folder: URL?) {
        guard let folder, let window = view.window, !operations.busy, window.attachedSheet == nil else { return }
        let store = NewItemTemplates.shared
        let ext = store.source(for: entry)?.pathExtension ?? "txt"
        operations.askName(title: L10n.text("Create"), initial: L10n.text(entry.title) + "." + ext, selectStem: true, confirmTitle: L10n.text("Create"), window: window) { [weak self] name in
            guard let self else { return }
            do {
                let filename = (name as NSString).pathExtension.isEmpty ? name + "." + ext : name
                let staged = try store.stage(entry, name: filename)
                self.copyCreatedFile(staged, into: folder, entry: entry)
            } catch { ExternalApplications.showError(error.localizedDescription, window: window) }
        }
    }
    private func createAlias(in folder: URL?) {
        guard let folder, let window = view.window, !operations.busy, window.attachedSheet == nil else { return }
        let panel = NSOpenPanel(); panel.canChooseFiles = true; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = L10n.text("Choose")
        panel.message = L10n.text("Choose the file or folder for the alias.")
        panel.beginSheetModal(for: window) { [weak self] response in
            guard let self, response == .OK, let target = panel.url else { return }
            DispatchQueue.main.async {
                self.operations.askName(title: L10n.text("Alias"), initial: target.lastPathComponent + " alias", selectStem: false, confirmTitle: L10n.text("Create"), window: window) { name in
                    let staging = FileManager.default.temporaryDirectory.appendingPathComponent("Explorer-Alias-" + UUID().uuidString)
                    do {
                        try FileOperationEngine.validateName(name)
                        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
                        let file = staging.appendingPathComponent(name)
                        let data = try target.bookmarkData(options: .suitableForBookmarkFile, includingResourceValuesForKeys: nil, relativeTo: nil)
                        try URL.writeBookmarkData(data, to: file)
                        self.copyCreatedFile((file, staging), into: folder)
                    } catch { try? FileManager.default.removeItem(at: staging); ExternalApplications.showError(error.localizedDescription, window: window) }
                }
            }
        }
    }
}

@MainActor
enum NewItemSettingsWindow {
    private static var controller: NSWindowController?
    static func show() {
        if controller == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 590, height: 540), styleMask: [.titled, .closable], backing: .buffered, defer: false)
            window.title = L10n.text("Create files"); window.isReleasedWhenClosed = false
            window.contentViewController = NewItemSettings(); window.center()
            controller = NSWindowController(window: window)
        }
        controller?.showWindow(nil); controller?.window?.makeKeyAndOrderFront(nil)
    }
}
