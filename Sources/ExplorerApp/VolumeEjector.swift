import AppKit
import ExplorerCore

@MainActor
final class VolumeEjector {
    static let shared = VolumeEjector()
    private(set) var pending = Set<String>()

    func item(for location: StorageLocation, window: NSWindow?) -> NSMenuItem {
        ContextMenu.item(L10n.text("Eject “%1$@”", location.title), symbol: "eject",
                         enabled: !pending.contains(location.url.standardizedFileURL.path) && !FileOperationController.shared.busy) { [weak window] in
            self.eject(location.url, window: window)
        }
    }

    func eject(_ url: URL, window: NSWindow?) {
        guard !DemoData.active, !FileOperationController.shared.busy,
              pending.insert(url.standardizedFileURL.path).inserted else { return }
        Task {
            let result = await Self.perform(url)
            pending.remove(url.standardizedFileURL.path)
            StorageStore.shared.refresh()
            if case .failure(let error) = result {
                let alert = NSAlert(); alert.messageText = L10n.text("Couldn’t Eject Volume")
                alert.informativeText = error.localizedDescription
                alert.addButton(withTitle: L10n.text("OK"))
                if let window, window.attachedSheet == nil { alert.beginSheetModal(for: window) { _ in } }
                else { alert.runModal() }
            }
        }
    }

    // NSWorkspace's eject API is synchronous. Keep disk arbitration off the UI thread.
    nonisolated static func perform(_ url: URL) async -> Result<Void, Error> {
        await Task.detached(priority: .userInitiated) {
            guard StorageDiscovery.canEject(url) else {
                return .failure(FileOperationError(L10n.text("This location cannot be ejected.")))
            }
            do {
                if try !DiskImageEjection.detachIfImage(url) {
                    try NSWorkspace.shared.unmountAndEjectDevice(at: url)
                }
                return .success(())
            }
            catch { return .failure(error) }
        }.value
    }
}
