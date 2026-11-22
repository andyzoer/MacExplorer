import AppKit
import ExplorerCore

struct NewItemTemplate: Codable, Equatable {
    var id: String
    var title: String
    var enabled = true
    var templatePath: String?
    var applicationPath: String?
    var openAfterCreation = false
}

@MainActor
final class NewItemTemplates {
    static let shared = NewItemTemplates()
    private let defaults: UserDefaults
    private let directory: URL
    private(set) var entries: [NewItemTemplate]
    init(defaults: UserDefaults = .standard, directory: URL = URL.applicationSupportDirectory.appendingPathComponent("Explorer/File Templates")) {
        self.defaults = defaults; self.directory = directory
        entries = defaults.data(forKey: "explorer.newItemTemplates").flatMap { try? JSONDecoder().decode([NewItemTemplate].self, from: $0) } ?? [
            .init(id: "txt", title: "Text Document"),
            .init(id: "docx", title: "Word Document"),
            .init(id: "xlsx", title: "Excel Workbook"),
            .init(id: "pptx", title: "PowerPoint Presentation"),
            .init(id: "psd", title: "Photoshop Document"),
            .init(id: "ai", title: "Illustrator Document")
        ]
    }
    func save(_ entry: NewItemTemplate) {
        if let index = entries.firstIndex(where: { $0.id == entry.id }) { entries[index] = entry }
        else { entries.append(entry) }
        persist()
    }
    func remove(_ id: String) {
        entries.removeAll { $0.id == id }; persist()
    }
    private func persist() { defaults.set(try? JSONEncoder().encode(entries), forKey: "explorer.newItemTemplates") }
    func source(for entry: NewItemTemplate) -> URL? {
        if let path = entry.templatePath { return URL(fileURLWithPath: path) }
        return DefaultFileTemplates.url(for: entry.id)
    }
    func application(for entry: NewItemTemplate) -> URL? {
        if let path = entry.applicationPath {
            let url = URL(fileURLWithPath: path)
            return Bundle(url: url)?.bundleIdentifier == nil ? nil : url
        }
        return source(for: entry).flatMap { NSWorkspace.shared.urlForApplication(toOpen: $0) }
    }
    func available(_ entry: NewItemTemplate) -> Bool {
        if entry.id == "txt", entry.templatePath == nil { return true }
        guard let source = source(for: entry), FileManager.default.fileExists(atPath: source.path) else { return false }
        return application(for: entry) != nil
    }
    func importTemplate(_ url: URL, for entry: NewItemTemplate) throws {
        let values = try url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true, !url.pathExtension.isEmpty,
              url.pathExtension.lowercased() != "app" else {
            throw FileOperationError(L10n.text("Choose a regular document with a file extension."))
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let copy = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension(url.pathExtension)
        try FileManager.default.copyItem(at: url, to: copy)
        var updated = entry; updated.templatePath = copy.path; save(updated)
    }
    func stage(_ entry: NewItemTemplate, name: String) throws -> (file: URL, directory: URL) {
        try FileOperationEngine.validateName(name)
        let staging = FileManager.default.temporaryDirectory.appendingPathComponent("Explorer-New-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            let output = staging.appendingPathComponent(name)
            if entry.id == "txt", entry.templatePath == nil { try Data().write(to: output, options: .withoutOverwriting) }
            else if let source = source(for: entry) { try FileManager.default.copyItem(at: source, to: output) }
            else { throw FileOperationError(L10n.text("Add a document template in Settings → Create.")) }
            return (output, staging)
        } catch { try? FileManager.default.removeItem(at: staging); throw error }
    }
}
