import Foundation
import ExplorerCore

/// Detach the complete disk-image attachment, including its backing device.
/// Unmounting only an APFS volume can leave DiskImageMounter unable to reopen it.
enum DiskImageEjection {
    static func device(for volume: URL, info: Data) throws -> String? {
        guard let root = try PropertyListSerialization.propertyList(from: info, format: nil) as? [String: Any],
              let images = root["images"] as? [[String: Any]] else {
            throw FileOperationError(L10n.text("Couldn’t Eject Volume"))
        }
        for image in images {
            guard let entities = image["system-entities"] as? [[String: Any]],
                  entities.contains(where: { entity in
                      guard let path = entity["mount-point"] as? String else { return false }
                      return URL(fileURLWithPath: path).standardizedFileURL.path == volume.standardizedFileURL.path
                  }) else { continue }
            guard let device = entities.compactMap({ $0["dev-entry"] as? String }).first(where: {
                $0.range(of: "^/dev/disk[0-9]+$", options: .regularExpression) != nil
            }) else { throw FileOperationError(L10n.text("Couldn’t Eject Volume")) }
            return device
        }
        return nil
    }

    static func detachIfImage(_ volume: URL) throws -> Bool {
        let info = try run(["info", "-plist"])
        guard let device = try device(for: volume, info: info) else { return false }
        // No force flag: a busy volume must remain attached with an error.
        _ = try run(["detach", device])
        return true
    }

    @discardableResult
    static func run(_ arguments: [String]) throws -> Data {
        let process = Process(), output = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        process.arguments = arguments
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = output; process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let detail = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
            throw FileOperationError(detail.flatMap { $0.isEmpty ? nil : $0 } ?? L10n.text("Couldn’t Eject Volume"))
        }
        return data
    }
}
