import SwiftUI

/// Represents the top-level item categories displayed in the vault.
///
/// Keeping this model separate from any particular view makes it reusable
/// across the project (e.g. in `VaultMainView`, filters, etc.).
public enum CategoryType: String, CaseIterable {
    case favorites = "Favorites"
    case photos = "Photos"
    case videos = "Videos"
    case audio = "Audio"
    case documents = "Documents"
    case other = "Other"
    case allFiles = "All Files"

    /// System SF Symbol associated with each category.
    var systemImage: String {
        switch self {
        case .favorites: return "heart.fill"
        case .photos: return "photo.fill"
        case .videos: return "video.fill"
        case .audio: return "music.note"
        case .documents: return "doc.text.fill"
        case .other: return "questionmark.folder.fill"
        case .allFiles: return "tray.full.fill"
        }
    }

    /// Primary accent color used for iconography in the UI.
    var color: Color {
        switch self {
        case .favorites: return .pink
        case .photos: return .blue
        case .videos: return .indigo
        case .audio: return .green
        case .documents: return .orange
        case .other: return .brown
        case .allFiles: return KeepshireTheme.accent
        }
    }
} 