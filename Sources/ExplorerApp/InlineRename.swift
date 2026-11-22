import AppKit
import ExplorerCore

struct SlowRenameGesture {
    private var previous: (id: String, time: TimeInterval, point: NSPoint)?
    mutating func reset() { previous = nil }
    mutating func click(id: String, selected: Bool, count: Int, time: TimeInterval,
                        point: NSPoint, doubleClickInterval: TimeInterval) -> Bool {
        guard count == 1 else { reset(); return false }
        defer { previous = (id, time, point) }
        guard selected, let previous, previous.id == id else { return false }
        let interval = time - previous.time
        return interval > doubleClickInterval && interval <= max(2, doubleClickInterval * 3)
            && hypot(point.x - previous.point.x, point.y - previous.point.y) <= 5
    }
}

@MainActor
final class InlineRename: NSObject, NSTextFieldDelegate {
    struct Target { let item: FileItem; let label: NSTextField; let selected: Bool }
    nonisolated(unsafe) private var monitor: Any?
    private let schedule: (@escaping @MainActor () -> Void) -> Void
    init(schedule: @escaping (@escaping @MainActor () -> Void) -> Void = { action in DispatchQueue.main.async { action() } }) {
        self.schedule = schedule; super.init()
    }
    private var gesture = SlowRenameGesture()
    private var generation = UUID()
    private var pending: Target?
    private var anchor: NSPoint?
    private(set) var editor: NSTextField?
    private var original: FileItem?
    private weak var label: NSTextField?
    private weak var previousResponder: NSResponder?
    private var windowProvider: (() -> NSWindow?)?
    private var targetProvider: ((NSEvent) -> Target?)?
    private var allowed: ((FileItem) -> Bool)?
    private var submit: ((FileItem, String) -> Void)?

    func install(window: @escaping () -> NSWindow?, target: @escaping (NSEvent) -> Target?,
                 allowed: @escaping (FileItem) -> Bool, submit: @escaping (FileItem, String) -> Void) {
        windowProvider = window; targetProvider = target; self.allowed = allowed; self.submit = submit
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown, .leftMouseUp, .leftMouseDragged, .rightMouseDown, .scrollWheel, .keyDown]) { [weak self] event in
            return self?.handle(event, in: event.window) == false ? nil : event
        }
        NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: NSWindow.didResignKeyNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(windowChanged(_:)), name: NSWindow.didResizeNotification, object: nil)
    }
    deinit {
        if let monitor { NSEvent.removeMonitor(monitor) }
        NotificationCenter.default.removeObserver(self)
    }
    @objc private func windowChanged(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window === editor?.window {
            if notification.name == NSWindow.didResignKeyNotification { commit() } else { cancel() }
        }
    }
    @discardableResult
    func handle(_ event: NSEvent, in eventWindow: NSWindow?) -> Bool {
        guard eventWindow === windowProvider?() else {
            if event.type == .leftMouseDown || event.type == .rightMouseDown { return commit() }
            return true
        }
        if let editor {
            switch event.type {
            case .leftMouseDown, .rightMouseDown:
                if !editor.bounds.contains(editor.convert(event.locationInWindow, from: nil)) { return commit() }
            case .scrollWheel: return commit()
            case .keyDown:
                if event.modifierFlags.contains(.command), !["a", "c", "v", "x", "z"].contains(event.charactersIgnoringModifiers?.lowercased() ?? "") { return commit() }
            default: break
            }
            return true
        }
        switch event.type {
        case .leftMouseDown:
            generation = UUID(); pending = nil; anchor = event.locationInWindow
            guard event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  let target = targetProvider?(event) else { gesture.reset(); return true }
            if gesture.click(id: target.item.id, selected: target.selected && (allowed?(target.item) ?? false), count: event.clickCount,
                             time: event.timestamp, point: event.locationInWindow, doubleClickInterval: NSEvent.doubleClickInterval) { pending = target }
        case .leftMouseDragged:
            if let anchor, hypot(event.locationInWindow.x - anchor.x, event.locationInWindow.y - anchor.y) > 5 { generation = UUID(); pending = nil; gesture.reset() }
        case .leftMouseUp:
            guard let pending else { return true }; self.pending = nil
            guard let current = targetProvider?(event), current.selected, current.item.id == pending.item.id else { return true }
            let token = generation
            schedule { [weak self, weak label = current.label] in
                guard let self, let label, self.generation == token, self.allowed?(current.item) == true else { return }
                self.begin(current.item, at: label)
            }
        case .scrollWheel, .rightMouseDown, .keyDown: generation = UUID(); gesture.reset(); pending = nil
        default: break
        }
        return true
    }
    // NSTableView/NSCollectionView may consume mouse-up in their own tracking loop,
    // so finish an armed click after native tracking returns as well as in the monitor.
    func mouseTrackingEnded(_ event: NSEvent, window: NSWindow?) {
        guard pending != nil, NSEvent.pressedMouseButtons & 1 == 0, let window,
              let anchor else { return }
        let point = window.mouseLocationOutsideOfEventStream
        guard hypot(point.x - anchor.x, point.y - anchor.y) <= 5 else { pending = nil; gesture.reset(); return }
        guard let up = NSEvent.mouseEvent(with: .leftMouseUp, location: point, modifierFlags: event.modifierFlags,
            timestamp: event.timestamp, windowNumber: window.windowNumber, context: nil,
            eventNumber: event.eventNumber, clickCount: event.clickCount, pressure: 0) else { return }
        handle(up, in: window)
    }

    func begin(_ item: FileItem, at label: NSTextField) {
        cancel()
        guard let host = label.window?.contentView, !label.visibleRect.isEmpty else { return }
        let field = NSTextField(string: item.name)
        field.font = label.font; field.alignment = label.alignment
        field.isEditable = true; field.isSelectable = true; field.isBordered = true
        field.backgroundColor = .textBackgroundColor; field.textColor = .textColor
        field.cell?.usesSingleLineMode = true; field.cell?.isScrollable = true
        field.setAccessibilityLabel(L10n.text("Rename")); field.delegate = self
        var rect = label.convert(label.bounds, to: host).insetBy(dx: -3, dy: -2)
        let top = host.isFlipped ? rect.minY : rect.maxY - 24
        rect.origin.y = top; rect.size.height = 24
        field.frame = rect.intersection(host.bounds)
        previousResponder = label.window?.firstResponder
        original = item; self.label = label; editor = field
        label.isHidden = true
        host.addSubview(field)
        field.selectText(nil)
        if !item.isDirectory, let text = field.currentEditor() {
            let ext = (item.name as NSString).pathExtension
            text.selectedRange = NSRange(location: 0, length: (item.name as NSString).length - (ext.isEmpty ? 0 : (ext as NSString).length + 1))
        }
    }
    func cancel() {
        generation = UUID(); pending = nil; gesture.reset()
        guard let field = editor else { return }
        let responder = previousResponder; previousResponder = nil
        editor = nil; original = nil; label?.isHidden = false; label = nil
        if field.currentEditor() != nil {
            if let view = responder as? NSView, view.window !== field.window { field.window?.makeFirstResponder(nil) }
            else { field.window?.makeFirstResponder(responder) }
        }
        field.removeFromSuperview()
    }
    @discardableResult
    func commit() -> Bool {
        guard let field = editor, let item = original else { cancel(); return true }
        let name = field.stringValue
        do { try FileOperationEngine.validateName(name) }
        catch {
            field.toolTip = error.localizedDescription
            field.wantsLayer = true; field.layer?.borderColor = NSColor.systemRed.cgColor; field.layer?.borderWidth = 1
            NSSound.beep(); return false
        }
        guard allowed?(item) ?? true else { cancel(); return true }
        cancel()
        if name != item.name { submit?(item, name) }
        return true
    }
    func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
        if selector == #selector(NSResponder.cancelOperation(_:)) { cancel(); return true }
        if selector == #selector(NSResponder.insertNewline(_:)) { commit(); return true }
        return false
    }
    func controlTextDidEndEditing(_ notification: Notification) { commit() }
    func controlTextDidChange(_ notification: Notification) {
        editor?.toolTip = nil; editor?.layer?.borderWidth = 0
    }
}

extension BrowserViewController {
    func installInlineRename() {
        let trackingEnded: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            self.inlineRename.mouseTrackingEnded(event, window: self.view.window)
        }
        table.onMouseTrackingEnded = trackingEnded; collection.onMouseTrackingEnded = trackingEnded
        inlineRename.install(window: { [weak self] in self?.view.window }, target: { [weak self] event in self?.renameTarget(at: event) }, allowed: { [weak self] item in
            guard let self else { return false }
            return !self.operations.busy && self.view.window?.attachedSheet == nil && !self.tab.isThisMac
                && self.selectedItems.count == 1 && self.selectedItems.first?.id == item.id
        }, submit: { [weak self] item, name in
            guard let self, let window = self.view.window else { return }
            self.operations.run(.rename(item.url, to: name), window: window)
        })
    }
    private func renameTarget(at event: NSEvent) -> InlineRename.Target? {
        guard !tab.isThisMac else { return nil }
        if viewMode.usesTable {
            let row = table.row(at: table.convert(event.locationInWindow, from: nil))
            guard let item = file(atRow: row), let column = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == "name" }),
                  let cell = table.view(atColumn: column, row: row, makeIfNecessary: false) as? NSTableCellView,
                  let label = cell.textField, label.visibleRect.contains(label.convert(event.locationInWindow, from: nil)) else { return nil }
            return .init(item: item, label: label, selected: selectedItems.count == 1 && selectedItems.first?.id == item.id)
        }
        guard let path = collection.indexPathForItem(at: collection.convert(event.locationInWindow, from: nil)), let item = file(at: path),
              let label = collection.item(at: path)?.textField,
              label.visibleRect.contains(label.convert(event.locationInWindow, from: nil)) else { return nil }
        return .init(item: item, label: label, selected: selectedItems.count == 1 && selectedItems.first?.id == item.id)
    }
    func renameSelectedInline() {
        guard let item = selectedItems.first, let index = tab.visible.firstIndex(where: { $0.id == item.id }) else { return }
        if viewMode.usesTable {
            guard let row = tab.displayIndex.row(forItem: index), let column = table.tableColumns.firstIndex(where: { $0.identifier.rawValue == "name" }) else { return }
            table.scrollRowToVisible(row); table.layoutSubtreeIfNeeded()
            if let cell = table.view(atColumn: column, row: row, makeIfNecessary: true) as? NSTableCellView, let label = cell.textField { inlineRename.begin(item, at: label) }
        } else if let path = iconPath(for: index) {
            collection.scrollToItems(at: [path], scrollPosition: .nearestVerticalEdge); collection.layoutSubtreeIfNeeded()
            if let label = collection.item(at: path)?.textField { inlineRename.begin(item, at: label) }
        }
    }
}
