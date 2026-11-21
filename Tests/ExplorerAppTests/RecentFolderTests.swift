import AppKit
import ExplorerCore
import Testing
@testable import ExplorerApp

@Suite @MainActor
struct RecentFolderTests {
    @Test func historyPersistsDeduplicatesAndKeepsOnlyTwentyFolders() throws {
        let suite = "Explorer.RecentFolderTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = RecentFolderStore(defaults: defaults)
        for index in 0..<25 {
            store.record(URL(fileURLWithPath: "/tmp/Folder \(index)"))
        }
        store.record(URL(fileURLWithPath: "/tmp/Folder 12"))
        store.record(BrowserLocation.thisMac)
        let restored = RecentFolderStore(defaults: defaults).paths
        #expect(restored.count == 20)
        #expect(restored.first == "/tmp/Folder 12")
        #expect(restored.filter { $0 == "/tmp/Folder 12" }.count == 1)
        #expect(!restored.contains("/tmp/Folder 0"))
    }

    @Test func addressBarCommitsAChosenHistoryEntryAndEscapeCancels() {
        let bar = PathBar(frame: NSRect(x: 0, y: 0, width: 600, height: 34))
        let original = URL(fileURLWithPath: "/tmp/Original")
        bar.update(original)
        var commits: [String] = []
        bar.onCommit = { commits.append($0) }
        bar.beginEditing()
        #expect(!bar.field.isHidden)
        bar.field.removeAllItems()
        bar.field.addItem(withObjectValue: "/tmp/Recent Folder")
        bar.field.selectItem(at: 0)
        bar.comboBoxSelectionDidChange(Notification(name: NSComboBox.selectionDidChangeNotification, object: bar.field))
        #expect(commits == ["/tmp/Recent Folder"])
        #expect(bar.field.isHidden)

        bar.beginEditing()
        bar.field.stringValue = "/tmp/Uncommitted"
        let cancelled = bar.control(bar.field, textView: NSTextView(),
                                    doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        #expect(cancelled)
        #expect(bar.field.isHidden)
        #expect(bar.field.stringValue == original.path)
        #expect(commits == ["/tmp/Recent Folder"])
    }
}
