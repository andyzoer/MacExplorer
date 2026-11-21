import AppKit
import ExplorerCore

@MainActor
enum FileTooltip {
    static func text(for item: FileItem) -> String {
        var lines = [item.name, item.url.path, L10n.text("Type: %1$@", item.kind)]
        let date = DateFormatter()
        date.locale = L10n.locale
        date.dateStyle = .medium
        date.timeStyle = .short
        if let created = item.created {
            lines.append(L10n.text("Date created") + ": " + date.string(from: created))
        }
        if let modified = item.modified {
            lines.append(L10n.text("Date modified: %1$@", date.string(from: modified)))
        }
        // Directory metadata size is not the size of its contents.
        if !item.isDirectory, let size = item.size {
            lines.append(L10n.text("Size: ") + L10n.byteCount(size))
        }
        let tags = FileColors.description(item.finderColors)
        if !tags.isEmpty { lines.append(tags) }
        return lines.joined(separator: "\n")
    }
}
