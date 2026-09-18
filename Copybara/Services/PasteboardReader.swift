import AppKit

/// Extracts the richest storable representation from a pasteboard change.
///
/// Priority: file URLs → image → rich text (RTF) → plain text. For rich content
/// a plain-text preview is always derived so rows stay readable and searchable.
enum PasteboardReader {
    static func read(_ pasteboard: NSPasteboard, appBundleID: String?) -> ClipCapture? {
        if let capture = readFiles(pasteboard, appBundleID: appBundleID) { return capture }
        if let capture = readImage(pasteboard, appBundleID: appBundleID) { return capture }
        if let capture = readRTF(pasteboard, appBundleID: appBundleID) { return capture }
        return readText(pasteboard, appBundleID: appBundleID)
    }

    private static func readFiles(_ pasteboard: NSPasteboard, appBundleID: String?) -> ClipCapture? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty else { return nil }

        let paths = urls.map(\.path)
        let names = urls.map(\.lastPathComponent).joined(separator: ", ")
        let data = FilePayload.archive(paths)
        return ClipCapture(
            kind: .file,
            text: names,
            data: data,
            contentHash: paths.joined(separator: "\n").sha256Hex,
            appBundleID: appBundleID
        )
    }

    private static func readImage(_ pasteboard: NSPasteboard, appBundleID: String?) -> ClipCapture? {
        guard let raw = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff),
              let image = NSImage(data: raw) else { return nil }

        let png = pngData(from: image) ?? raw
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        return ClipCapture(
            kind: .image,
            text: "Image \(width)×\(height)",
            data: png,
            contentHash: png.sha256Hex,
            appBundleID: appBundleID
        )
    }

    private static func readRTF(_ pasteboard: NSPasteboard, appBundleID: String?) -> ClipCapture? {
        guard let data = pasteboard.data(forType: .rtf) else { return nil }
        let plain = NSAttributedString(rtf: data, documentAttributes: nil)?.string
            ?? pasteboard.string(forType: .string)
            ?? ""
        guard !plain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return ClipCapture(
            kind: .rtf,
            text: plain,
            data: data,
            contentHash: plain.sha256Hex,
            appBundleID: appBundleID
        )
    }

    private static func readText(_ pasteboard: NSPasteboard, appBundleID: String?) -> ClipCapture? {
        guard let string = pasteboard.string(forType: .string),
              !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return ClipCapture(
            kind: .text,
            text: string,
            data: nil,
            contentHash: string.sha256Hex,
            appBundleID: appBundleID
        )
    }

    private static func pngData(from image: NSImage) -> Data? {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else { return nil }
        return rep.representation(using: .png, properties: [:])
    }
}

/// Archives/unarchives file paths for the `.file` payload.
enum FilePayload {
    static func archive(_ paths: [String]) -> Data? {
        try? NSKeyedArchiver.archivedData(withRootObject: paths as NSArray, requiringSecureCoding: true)
    }

    static func paths(from data: Data) -> [String]? {
        let classes = [NSArray.self, NSString.self]
        let array = try? NSKeyedUnarchiver.unarchivedObject(ofClasses: classes, from: data)
        return array as? [String]
    }
}
