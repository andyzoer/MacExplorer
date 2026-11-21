import AppKit
import ExplorerCore
import Testing
@testable import ExplorerApp

@Suite @MainActor
struct RecentFolderTests {
    @Test func addressBarBackgroundClickStartsEditingInAWindow() throws {
        _ = NSApplication.shared
        let window = ExplorerWindow(contentRect: NSRect(x: 0, y: 0, width: 900, height: 500),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = Surface(frame: NSRect(x: 0, y: 0, width: 900, height: 500))
        window.contentView = root
        NSLayoutConstraint.activate([
            root.widthAnchor.constraint(equalToConstant: 900),
            root.heightAnchor.constraint(equalToConstant: 500)
        ])
        let bar = PathBar(frame: NSRect(x: 150, y: 60, width: 600, height: 34))
        root.addSubview(bar)
        bar.update(URL(fileURLWithPath: "/tmp/Original"))
        root.layoutSubtreeIfNeeded()
        window.makeKeyAndOrderFront(nil)
        window.setContentSize(NSSize(width: 900, height: 500))
        let location = bar.convert(NSPoint(x: 450, y: 17), to: nil)
        #expect(window.contentHit(at: location) === bar)
        let event = try #require(NSEvent.mouseEvent(with: .leftMouseDown, location: location,
            modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber, context: nil,
            eventNumber: 0, clickCount: 1, pressure: 1))
        window.sendEvent(event)
        #expect(!bar.field.isHidden)
        #expect(bar.field.currentEditor() != nil)
        #expect(bar.field.currentEditor()?.selectedRange == NSRange(location: 0, length: "/tmp/Original".utf16.count))
        #expect(!bar.mouseDownCanMoveWindow)
        _ = bar.control(bar.field, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        #expect(bar.field.isHidden)
        let crumbs = try #require(bar.subviews.first as? NSStackView)
        let buttons = crumbs.arrangedSubviews.compactMap { $0 as? ActionButton }
        var navigated: [URL] = []
        bar.onNavigate = { navigated.append($0) }
        let parent = try #require(buttons.first { $0.title == "tmp" })
        parent.performClick(nil)
        #expect(navigated == [URL(fileURLWithPath: "/tmp", isDirectory: true)])
        #expect(bar.field.isHidden)
        let current = try #require(buttons.last)
        current.performClick(nil)
        #expect(!bar.field.isHidden)
        #expect(bar.field.currentEditor() != nil)
        #expect(navigated.count == 1)
    }

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
