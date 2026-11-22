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
    @Test(.enabled(if: ProcessInfo.processInfo.environment["EXPLORER_EJECT_TEST_VOLUME"] != nil))
    func ejectTemporaryDiskImageUsingNativeAPI() async throws {
        let path = try #require(ProcessInfo.processInfo.environment["EXPLORER_EJECT_TEST_VOLUME"])
        let url = URL(fileURLWithPath: path, isDirectory: true)
        // This opt-in integration test only accepts a disposable image made by the test harness.
        try #require(url.lastPathComponent.hasPrefix("Explorer Eject Integration "))
        let marker = try String(contentsOf: url.appendingPathComponent("eject-test-marker"), encoding: .utf8)
        try #require(marker == "Disposable Explorer eject integration image\n")
        try #require(StorageDiscovery.canEject(url))
        #expect(StorageDiscovery.volume(url).canEject)
        let result = await VolumeEjector.perform(url)
        if case .failure(let error) = result { Issue.record(error) }
        #expect(!FileManager.default.fileExists(atPath: path))
    }
}
