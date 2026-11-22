import Foundation

public enum DefaultFileTemplates {
    public static func url(for extensionName: String) -> URL? {
        guard ["docx", "xlsx", "pptx"].contains(extensionName) else { return nil }
        return Bundle.main.url(forResource: "Blank", withExtension: extensionName, subdirectory: "Templates")
            ?? Bundle.module.url(forResource: "Blank", withExtension: extensionName)
    }
}
