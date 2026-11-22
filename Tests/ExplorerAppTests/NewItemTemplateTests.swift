import AppKit
import ExplorerCore
import Testing
@testable import ExplorerApp

@Suite @MainActor
struct NewItemTemplateTests {
    @Test func settingsProvideScrollableContentAtThePreferredWindowSize() throws {
        _ = NSApplication.shared
        let controller = NewItemSettings()
        let scroll = try #require(controller.view as? NSScrollView)
        #expect(controller.preferredContentSize == NSSize(width: 590, height: 540))
        let document = try #require(scroll.documentView)
        #expect(document.isFlipped)
        scroll.layoutSubtreeIfNeeded()
        #expect(document.fittingSize.height > 0)
        #expect(scroll.hasVerticalScroller)
    }

    @Test func templatesPersistCopyBytesAndRejectTraversal() throws {
        let domain = "Explorer.Templates." + UUID().uuidString
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let store = NewItemTemplates(defaults: defaults, directory: directory.appendingPathComponent("Managed"))
        let source = directory.appendingPathComponent("Original.psd")
        let bytes = Data("8BPS template data for byte-copy test".utf8)
        try bytes.write(to: source)
        var entry = NewItemTemplate(id: "custom", title: "Custom", enabled: false, openAfterCreation: true)
        try store.importTemplate(source, for: entry)
        entry = try #require(store.entries.last)
        #expect(entry.templatePath != source.path)
        try FileManager.default.removeItem(at: source)
        let restored = NewItemTemplates(defaults: defaults, directory: directory)
        #expect(restored.entries.last == entry)
        let staged = try restored.stage(entry, name: "New.psd")
        defer { try? FileManager.default.removeItem(at: staged.directory) }
        #expect(try Data(contentsOf: staged.file) == bytes)
        #expect(throws: (any Error).self) { try restored.stage(entry, name: "../escape.psd") }
        let txt = try #require(store.entries.first { $0.id == "txt" })
        let text = try store.stage(txt, name: "Untitled.txt")
        defer { try? FileManager.default.removeItem(at: text.directory) }
        #expect(try Data(contentsOf: text.file).isEmpty)
        #expect(store.available(txt))
        entry.applicationPath = "/does/not/exist.app"
        #expect(!store.available(entry))
        store.remove(entry.id)
        #expect(!store.entries.contains { $0.id == entry.id })
    }
    @Test func bundledOfficeFilesAreRealZipPackagesAndUnsupportedFormatsNeedTemplates() throws {
        for ext in ["docx", "xlsx", "pptx"] {
            let url = try #require(DefaultFileTemplates.url(for: ext))
            let bytes = try Data(contentsOf: url)
            #expect(bytes.starts(with: [0x50, 0x4b, 0x03, 0x04]))
            #expect(bytes.count > 500)
        }
        #expect(DefaultFileTemplates.url(for: "psd") == nil)
        #expect(DefaultFileTemplates.url(for: "../txt") == nil)
    }
}
