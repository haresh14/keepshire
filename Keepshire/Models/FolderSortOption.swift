import SwiftUI

public enum FolderSortOption: String, CaseIterable {
    case userDefault = "User Default"
    case name = "Name"
    case date = "Date"
    case size = "Size"
    case duration = "Duration"
    case kind = "Kind"
    case favorites = "Favorites"

    var systemImage: String {
        switch self {
        case .userDefault: return "person"
        case .name: return "textformat.abc"
        case .date: return "calendar"
        case .size: return "arrow.up.arrow.down"
        case .duration: return "timer"
        case .kind: return "folder"
        case .favorites: return "heart.fill"
        }
    }

    var asFileSort: SortOption {
        SortOption(rawValue: rawValue) ?? .userDefault
    }
} 