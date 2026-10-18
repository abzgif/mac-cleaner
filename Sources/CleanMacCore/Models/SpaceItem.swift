import Foundation

/// Represents a directory or file node within the Visual Space Analyzer tree.
public struct SpaceItem: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let url: URL
    public let size: Int64
    public let isDirectory: Bool
    public var children: [SpaceItem]
    public var percentage: Double
    
    public init(
        name: String,
        url: URL,
        size: Int64,
        isDirectory: Bool,
        children: [SpaceItem] = [],
        percentage: Double = 0.0
    ) {
        self.id = url.path
        self.name = name
        self.url = url
        self.size = size
        self.isDirectory = isDirectory
        self.children = children
        self.percentage = percentage
    }
    
    public var formattedSize: String {
        ByteFormatter.format(size)
    }
    
    public var iconName: String {
        if isDirectory {
            switch name.lowercased() {
            case "downloads": return "arrow.down.circle.fill"
            case "documents": return "doc.text.fill"
            case "desktop": return "desktopcomputer"
            case "library": return "books.vertical.fill"
            case "movies": return "film.fill"
            case "music": return "music.note.list"
            case "pictures": return "photo.fill"
            case "applications": return "app.fill"
            case "developer": return "hammer.fill"
            default: return "folder.fill"
            }
        }
        
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "dmg", "pkg", "iso", "zip", "tar", "gz": return "archivebox.fill"
        case "mp4", "mov", "mkv", "avi": return "film"
        case "mp3", "wav", "m4a", "flac": return "music.note"
        case "jpg", "jpeg", "png", "heic", "webp": return "photo"
        case "pdf", "docx", "pages", "txt": return "doc.text"
        case "app": return "app"
        default: return "doc.fill"
        }
    }
}
