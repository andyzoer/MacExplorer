import AppKit
import ExplorerCore
import Testing
@testable import ExplorerApp

@Suite @MainActor
struct InlineRenameTests {
    @Test func slowClickDiffersFromOpeningDoubleClickAndDragging() {
        var gesture = SlowRenameGesture()
        let point = NSPoint(x: 10, y: 10)
        let result0 = gesture.click(id: "file", selected: false, count: 1, time: 1, point: point, doubleClickInterval: 0.5)
        #expect(result0 == false)
        let result1 = gesture.click(id: "file", selected: true, count: 1, time: 1.8, point: point, doubleClickInterval: 0.5)
        #expect(result1 == true)
        gesture.reset()
        let result2 = gesture.click(id: "file", selected: false, count: 1, time: 2, point: point, doubleClickInterval: 0.5)
        #expect(result2 == false)
        let result3 = gesture.click(id: "file", selected: true, count: 2, time: 2.2, point: point, doubleClickInterval: 0.5)
        #expect(result3 == false)
        let result4 = gesture.click(id: "file", selected: true, count: 1, time: 3, point: point, doubleClickInterval: 0.5)
        #expect(result4 == false)
        let result5 = gesture.click(id: "other", selected: true, count: 1, time: 3.8, point: point, doubleClickInterval: 0.5)
        #expect(result5 == false)
        let result6 = gesture.click(id: "other", selected: true, count: 1, time: 7, point: point, doubleClickInterval: 0.5)
        #expect(result6 == false)
        let result7 = gesture.click(id: "other", selected: true, count: 1, time: 7.8, point: NSPoint(x: 30, y: 10), doubleClickInterval: 0.5)
        #expect(result7 == false)
    }
    @Test func aSlowSecondClickStartsEditingAndAnOutsideClickCommits() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = Surface(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        window.contentView = root
        NSLayoutConstraint.activate([root.widthAnchor.constraint(equalToConstant: 500), root.heightAnchor.constraint(equalToConstant: 200)])
        let label = NSTextField(labelWithString: "report.txt")
        label.frame = NSRect(x: 40, y: 50, width: 300, height: 20); root.addSubview(label)
        let rename = InlineRename(schedule: { $0() })
        let file = FileItem(url: URL(fileURLWithPath: "/tmp/report.txt"), name: "report.txt", isDirectory: false)
        var selected = false
        var submissions = 0
        rename.install(window: { window }, target: { event in
            guard label.bounds.contains(label.convert(event.locationInWindow, from: nil)) else { return nil }
            return .init(item: file, label: label, selected: selected)
        }, allowed: { _ in selected }, submit: { _, _ in submissions += 1 })
        root.layoutSubtreeIfNeeded()
        let inside = label.convert(NSPoint(x: 20, y: 10), to: nil)
        func event(_ type: NSEvent.EventType, time: Double, point: NSPoint? = nil, clicks: Int = 1) throws -> NSEvent {
            try #require(NSEvent.mouseEvent(with: type, location: point ?? inside, modifierFlags: [], timestamp: time,
                windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: clicks, pressure: 0))
        }
        func send(_ event: NSEvent) { rename.handle(event, in: window) }
        let firstDown = try event(.leftMouseDown, time: 10)
        send(firstDown)
        selected = true // Native selection is processed between mouse-down and mouse-up.
        send(try event(.leftMouseUp, time: 10.05))
        #expect(rename.editor == nil)
        let second = 10 + NSEvent.doubleClickInterval + 0.2
        send(try event(.leftMouseDown, time: second))
        send(try event(.leftMouseUp, time: second + 0.05))
        let editor = try #require(rename.editor)
        editor.stringValue = "discard.txt"
        send(try event(.leftMouseDown, time: second + 1, point: root.convert(NSPoint(x: 450, y: 150), to: nil)))
        #expect(rename.editor == nil)
        #expect(!label.isHidden)
        #expect(submissions == 1)
        rename.begin(file, at: label)
        send(try event(.leftMouseDown, time: second + 2, point: root.convert(NSPoint(x: 450, y: 150), to: nil)))
        #expect(rename.editor == nil)
        #expect(submissions == 1)
        send(try event(.leftMouseDown, time: 20))
        send(try event(.leftMouseUp, time: 20.01))
        send(try event(.leftMouseDown, time: 20.1, clicks: 2))
        send(try event(.leftMouseUp, time: 20.15, clicks: 2))
        #expect(rename.editor == nil)
    }

    @Test func editorGrowsWithRowTextAndWrapsWithinIconTiles() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 300), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = Surface(frame: NSRect(x: 0, y: 0, width: 500, height: 300))
        window.contentView = root
        NSLayoutConstraint.activate([root.widthAnchor.constraint(equalToConstant: 500), root.heightAnchor.constraint(equalToConstant: 300)])
        let rowLabel = NSTextField(labelWithString: "x.txt")
        rowLabel.frame = NSRect(x: 35, y: 25, width: 400, height: 16); root.addSubview(rowLabel)
        let rename = InlineRename()
        let file = FileItem(url: URL(fileURLWithPath: "/tmp/x.txt"), name: "x.txt", isDirectory: false)
        rename.begin(file, at: rowLabel)
        let field = try #require(rename.editor)
        let initialWidth = field.frame.width
        #expect(initialWidth < 150)
        field.stringValue = "A substantially longer filename.txt"
        rename.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        #expect(field.frame.width > initialWidth)
        let long = String(repeating: "long", count: 100) + ".txt"
        field.stringValue = long
        rename.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        #expect(field.frame.width <= rowLabel.frame.width + 6)
        #expect(field.stringValue == long)
        field.stringValue = "x"
        rename.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: field))
        #expect(field.frame.width <= initialWidth)
        rename.cancel()
        let tile = Surface(frame: NSRect(x: 100, y: 80, width: 120, height: 115)); root.addSubview(tile)
        let iconLabel = NSTextField(wrappingLabelWithString: "")
        iconLabel.font = .systemFont(ofSize: 12); iconLabel.alignment = .center; iconLabel.maximumNumberOfLines = 2
        iconLabel.frame = NSRect(x: 6, y: 70, width: 108, height: 35); tile.addSubview(iconLabel)
        let folder = FileItem(url: URL(fileURLWithPath: "/tmp/platform-tools-and-documents"), name: "platform-tools-and-documents", isDirectory: true)
        rename.begin(folder, at: iconLabel)
        let wrapped = try #require(rename.editor)
        let frameInTile = tile.convert(wrapped.frame, from: root)
        #expect(frameInTile.minX >= 0 && frameInTile.maxX <= tile.bounds.width)
        #expect(wrapped.maximumNumberOfLines == 2)
        #expect(wrapped.cell?.wraps == true)
        #expect(wrapped.cell?.isScrollable == false)
        #expect(wrapped.frame.height > field.frame.height)
        let text = try #require(wrapped.currentEditor() as? NSTextView)
        #expect(!text.isHorizontallyResizable)
        #expect(text.textContainer?.widthTracksTextView == true)
        #expect(wrapped.stringValue == folder.name)
        wrapped.stringValue = "short"
        rename.controlTextDidChange(Notification(name: NSControl.textDidChangeNotification, object: wrapped))
        #expect(wrapped.frame.height <= field.frame.height + 1)
        rename.cancel()
    }

    @Test func inlineEditorSelectsTheStemCommitsOnFocusLossAndEscapeDiscardsChanges() throws {
        _ = NSApplication.shared
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 500, height: 200), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let root = Surface(frame: NSRect(x: 0, y: 0, width: 500, height: 200))
        window.contentView = root
        NSLayoutConstraint.activate([root.widthAnchor.constraint(equalToConstant: 500), root.heightAnchor.constraint(equalToConstant: 200)])
        let label = NSTextField(labelWithString: "report.txt")
        label.frame = NSRect(x: 40, y: 50, width: 300, height: 20); root.addSubview(label)
        let rename = InlineRename()
        var submissions: [String] = []
        rename.install(window: { window }, target: { _ in nil }, allowed: { _ in true }, submit: { _, name in submissions.append(name) })
        let file = FileItem(url: URL(fileURLWithPath: "/tmp/report.txt"), name: "report.txt", isDirectory: false)
        rename.begin(file, at: label)
        let editor = try #require(rename.editor)
        #expect(editor.currentEditor()?.selectedRange == NSRange(location: 0, length: 6))
        #expect(editor.superview === root)
        editor.stringValue = "renamed.txt"
        let committed = rename.control(editor, textView: NSTextView(), doCommandBy: #selector(NSResponder.insertNewline(_:)))
        #expect(committed)
        #expect(submissions == ["renamed.txt"])
        #expect(rename.editor == nil)
        #expect(label.stringValue == "report.txt") // File-operation completion supplies the real new name.
        rename.begin(file, at: label)
        let second = try #require(rename.editor)
        second.stringValue = "cancelled.txt"
        rename.controlTextDidEndEditing(Notification(name: NSControl.textDidEndEditingNotification, object: second))
        #expect(rename.editor == nil)
        #expect(submissions == ["renamed.txt", "cancelled.txt"])
        let folder = FileItem(url: URL(fileURLWithPath: "/tmp/Folder.name"), name: "Folder.name", isDirectory: true)
        rename.begin(folder, at: label)
        let third = try #require(rename.editor)
        #expect(third.currentEditor()?.selectedRange == NSRange(location: 0, length: 11))
        third.stringValue = "../invalid"
        rename.commit()
        #expect(rename.editor != nil)
        #expect(submissions.count == 2)
        _ = rename.control(third, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        #expect(rename.editor == nil)
        rename.begin(file, at: label)
        let fourth = try #require(rename.editor)
        fourth.stringValue = "discard-this.txt"
        _ = rename.control(fourth, textView: NSTextView(), doCommandBy: #selector(NSResponder.cancelOperation(_:)))
        #expect(submissions.count == 2)
    }
}
