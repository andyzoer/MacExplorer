import AppKit

@MainActor
final class FileTableHeaderView: NSTableHeaderView {
    private var hoverTracking: NSTrackingArea?
    private(set) var hoveredColumn = -1

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverTracking { removeTrackingArea(hoverTracking) }
        let area = NSTrackingArea(rect: .zero,
                                  options: [.mouseEnteredAndExited, .mouseMoved, .activeInKeyWindow, .inVisibleRect],
                                  owner: self, userInfo: nil)
        addTrackingArea(area)
        hoverTracking = area
        updateHover(at: window.map { convert($0.mouseLocationOutsideOfEventStream, from: nil) })
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window == nil { updateHover(at: nil) }
    }

    override func mouseEntered(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseMoved(with event: NSEvent) {
        updateHover(at: convert(event.locationInWindow, from: nil))
    }

    override func mouseExited(with event: NSEvent) { updateHover(at: nil) }

    private func updateHover(at point: NSPoint?) {
        let column = point.flatMap { visibleRect.contains($0) ? self.column(at: $0) : nil } ?? -1
        guard column != hoveredColumn else { return }
        hoveredColumn = column
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        // Re-evaluate after scrolling, resizing or reordering columns beneath the pointer.
        if let window { updateHover(at: convert(window.mouseLocationOutsideOfEventStream, from: nil)) }
        super.draw(dirtyRect)
        guard let tableView, tableView.tableColumns.indices.contains(hoveredColumn),
              !tableView.tableColumns[hoveredColumn].isHidden,
              resizedColumn == -1, draggedColumn == -1 else { return }
        let rect = headerRect(ofColumn: hoveredColumn).insetBy(dx: 1, dy: 1)
        guard rect.intersects(dirtyRect), rect.width > 0, rect.height > 0 else { return }
        let outline = NSBezierPath(roundedRect: rect, xRadius: 3, yRadius: 3)
        NSColor.controlAccentColor.withAlphaComponent(0.10).setFill()
        outline.fill()
        NSColor.controlAccentColor.withAlphaComponent(0.55).setStroke()
        outline.lineWidth = 1
        outline.stroke()
    }
}
