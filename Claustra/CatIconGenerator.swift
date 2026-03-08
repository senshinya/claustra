import AppKit

/// Loads RunCat cat frames from bundle resources as template NSImages for the menu bar.
/// Source: https://github.com/Kyome22/menubar_runcat
final class CatIconGenerator {
    static let shared = CatIconGenerator()

    private let imageSize = NSSize(width: 28, height: 18)

    /// Running animation frames (5 frames)
    func runningFrames() -> [NSImage] {
        return (0..<5).map { n in
            let image = loadImage(named: "cat_page\(n)")
            image.size = imageSize
            return image
        }
    }

    /// Sleeping cat (static)
    func sleepingFrame() -> NSImage {
        let image = loadImage(named: "cat_sleep")
        image.size = imageSize
        return image
    }

    private func loadImage(named name: String) -> NSImage {
        // Load PNG directly from bundle resources
        if let path = Bundle.main.path(forResource: name, ofType: "png"),
           let image = NSImage(contentsOfFile: path) {
            image.isTemplate = true
            return image
        }

        // Fallback: try asset catalog
        if let image = NSImage(named: name) {
            return image
        }

        NSLog("CatIconGenerator: Failed to load '\(name)'")
        let fallback = NSImage(size: imageSize, flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 4, dy: 2)).fill()
            return true
        }
        fallback.isTemplate = true
        return fallback
    }
}
