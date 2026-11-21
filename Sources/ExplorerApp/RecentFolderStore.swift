import Foundation

@MainActor
final class RecentFolderStore {
    static let shared = RecentFolderStore()
    private let defaults: UserDefaults
    private let key = "explorer.recentFolders"
    private let limit = 20

    init(defaults: UserDefaults = .standard) { self.defaults = defaults }

    var paths: [String] {
        Array((defaults.stringArray(forKey: key) ?? []).filter { $0.hasPrefix("/") }.prefix(limit))
    }

    func record(_ url: URL) {
        guard url.isFileURL else { return }
        let path = url.standardizedFileURL.path
        defaults.set(Array(([path] + paths.filter { $0 != path }).prefix(limit)), forKey: key)
    }
}
