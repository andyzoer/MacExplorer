import AppKit
import ExplorerCore
import Testing
@testable import ExplorerApp

@Suite @MainActor
struct HoverTests {
    @Test func hoveringDoesNotChangeSelectionAndGroupHeadersStayUnhighlighted() throws {
        let row = FileRowView(frame: NSRect(x: 0, y: 0, width: 400, height: 29))
        let event = try #require(NSEvent.mouseEvent(with: .mouseMoved, location: .zero,
                                                    modifierFlags: [], timestamp: 0,
                                                    windowNumber: 0, context: nil, eventNumber: 0,
                                                    clickCount: 0, pressure: 0))
        row.mouseEntered(with: event)
        #expect(row.hovering)
        #expect(!row.isSelected)
        row.mouseExited(with: event)
        #expect(!row.hovering)
        row.hoverEnabled = false
        row.mouseEntered(with: event)
        #expect(!row.hovering)
        row.isSelected = true
        row.mouseExited(with: event)
        #expect(row.isSelected)
    }

    @Test func reusedItemsReplaceTheirTooltipMetadata() {
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        let file = FileItem(url: URL(fileURLWithPath: "/tmp/report.txt"), name: "report.txt",
                            isDirectory: false, modified: date, created: date, size: 2048)
        let folder = FileItem(url: URL(fileURLWithPath: "/tmp/Folder"), name: "Folder",
                              isDirectory: true, size: 4096)
        let tooltip = FileTooltip.text(for: file)
        #expect(tooltip.contains(L10n.text("Date created") + ": "))
        #expect(tooltip.contains(L10n.text("Date modified: %1$@", "")))
        #expect(tooltip.contains(L10n.text("Size: ") + L10n.byteCount(2048)))
        #expect(!FileTooltip.text(for: folder).contains(L10n.text("Size: ")))

        let icon = FileIconItem()
        icon.configure(file, mode: .large, fallback: NSImage(), dimmed: false, scale: 1)
        #expect(icon.view.toolTip == tooltip)
        icon.prepareForReuse()
        #expect(icon.view.toolTip == nil)
        icon.configure(folder, mode: .small, fallback: NSImage(), dimmed: false, scale: 1)
        #expect(icon.view.toolTip == FileTooltip.text(for: folder))
        #expect(!icon.view.toolTip!.contains("report.txt"))

        let content = ContentResultCell()
        content.configure(file, query: "", icon: NSImage(), modified: "", dimmed: false)
        #expect(content.nameLabel.toolTip == tooltip)
        content.configure(folder, query: "", icon: NSImage(), modified: "", dimmed: false)
        #expect(content.nameLabel.toolTip == FileTooltip.text(for: folder))
    }
}
