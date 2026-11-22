import AppKit
import ExplorerCore
import Testing
@testable import ExplorerApp

@Suite @MainActor
struct VolumeEjectTests {
    @Test func rootsAndOrdinaryFoldersCannotBeEjected() async {
        #expect(!StorageDiscovery.canEject(URL(fileURLWithPath: "/")))
        #expect(!StorageDiscovery.canEject(FileManager.default.temporaryDirectory))
        #expect(!StorageDiscovery.canEject(BrowserLocation.thisMac))
        if case .success = await VolumeEjector.perform(URL(fileURLWithPath: "/")) {
            Issue.record("The system root must never be passed to the eject API")
        }
    }
    @Test func ejectAppearsOnlyForEligibleStorageLocations() {
        let overview = ThisMacView(frame: NSRect(x: 0, y: 0, width: 800, height: 400))
        for eligible in [true, false] {
            let location = StorageLocation(url: URL(fileURLWithPath: "/Volumes/Test Image"), title: "Test Image", kind: .externalDrive, canEject: eligible)
            overview.update([location], query: "", loading: false)
            overview.collection.selectionIndexPaths = [IndexPath(item: 0, section: 0)]
            let menu = NSMenu(); overview.menuNeedsUpdate(menu)
            #expect(menu.items.contains { $0.title == L10n.text("Eject “%1$@”", location.title) } == eligible)
        }
        let sidebar = FolderSidebar()
        _ = sidebar.view
        for eligible in [true, false] {
            let node = FolderNode(title: "Test Image", url: URL(fileURLWithPath: "/Volumes/Test Image"))
            node.canEject = eligible
            let cell = sidebar.outlineView(sidebar.outline, viewFor: nil, item: node)
            #expect(cell?.subviews.contains { $0 is NSButton } == eligible)
        }
    }
    @Test func imageMatchingUsesTheWholeDeviceAndOnlyTheExactMount() throws {
        let info: [String: Any] = ["images": [
            ["system-entities": [["dev-entry": "/dev/disk88"], ["dev-entry": "/dev/disk89s1", "mount-point": "/Volumes/Test Image"]]],
            ["system-entities": [["dev-entry": "/dev/disk90"], ["dev-entry": "/dev/disk90s1", "mount-point": "/Volumes/Other Image"]]]
        ]]
        let data = try PropertyListSerialization.data(fromPropertyList: info, format: .xml, options: 0)
        #expect(try DiskImageEjection.device(for: URL(fileURLWithPath: "/Volumes/Test Image/"), info: data) == "/dev/disk88")
        #expect(try DiskImageEjection.device(for: URL(fileURLWithPath: "/Volumes/Test Image/Folder"), info: data) == nil)
        #expect(try DiskImageEjection.device(for: URL(fileURLWithPath: "/Volumes/Other Image"), info: data) == "/dev/disk90")
        #expect(throws: (any Error).self) { try DiskImageEjection.device(for: URL(fileURLWithPath: "/Volumes/Test Image"), info: Data()) }
    }

    @Test(.enabled(if: ProcessInfo.processInfo.environment["EXPLORER_EJECT_TEST_IMAGE"] != nil))
    func diskImageCanBeReopenedAfterRepeatedEjection() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["EXPLORER_EJECT_TEST_IMAGE"])
        let image = URL(fileURLWithPath: path)
        try #require(image.lastPathComponent == "test.dmg")
        try #require(image.deletingLastPathComponent().lastPathComponent.hasPrefix("Eject-Reopen-Integration."))
        let original = try Data(contentsOf: image)
        for _ in 0..<3 {
            let result = try await Task.detached {
                try DiskImageEjection.run(["attach", "-nobrowse", "-plist", image.path])
            }.value
            let plist = try #require(try PropertyListSerialization.propertyList(from: result, format: nil) as? [String: Any])
            let entities = try #require(plist["system-entities"] as? [[String: Any]])
            let mount = try #require(entities.compactMap { $0["mount-point"] as? String }.first)
            let url = URL(fileURLWithPath: mount, isDirectory: true)
            try #require(url.lastPathComponent.hasPrefix("Explorer Eject Integration "))
            let marker = try String(contentsOf: url.appendingPathComponent("eject-test-marker"), encoding: .utf8)
            try #require(marker == "Disposable Explorer eject integration image\n")
            try #require(StorageDiscovery.canEject(url))
            let outcome = await VolumeEjector.perform(url)
            if case .failure(let error) = outcome { Issue.record(error) }
            #expect(!FileManager.default.fileExists(atPath: mount))
            let info = try await Task.detached { try DiskImageEjection.run(["info", "-plist"]) }.value
            let after = try #require(try PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any])
            let images = try #require(after["images"] as? [[String: Any]])
            #expect(!images.contains { ($0["image-path"] as? String).map { URL(fileURLWithPath: $0).standardizedFileURL.path == image.standardizedFileURL.path } == true })
            #expect(try Data(contentsOf: image) == original)
        }
    }
}
