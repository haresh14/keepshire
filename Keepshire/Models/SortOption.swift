//
//  SortOption.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import Foundation

enum SortOption: String, CaseIterable {
    case userDefault = "User Default"
    case name = "Name"
    case size = "Size"
    case date = "Date"
    case duration = "Duration"
    case kind = "Kind"
    case favorites = "Favorites"
    
    var systemImage: String {
        switch self {
        case .userDefault:
            return "person"
        case .name:
            return "textformat.abc"
        case .size:
            return "arrow.up.arrow.down"
        case .date:
            return "calendar"
        case .duration:
            return "timer"
        case .kind:
            return "folder"
        case .favorites:
            return "heart.fill"
        }
    }

    func isOrderedBefore(_ lhs: VaultItem, _ rhs: VaultItem) -> Bool {
        switch self {
        case .userDefault, .date:
            return (lhs.createdAt ?? .distantPast) < (rhs.createdAt ?? .distantPast)
        case .name:
            return (lhs.fileName ?? "") < (rhs.fileName ?? "")
        case .size:
            return lhs.fileSize < rhs.fileSize
        case .duration:
            let leftDuration = lhs.isVideo ? lhs.durationSeconds : 0
            let rightDuration = rhs.isVideo ? rhs.durationSeconds : 0
            if leftDuration != rightDuration {
                return leftDuration < rightDuration
            }
            return lhs.fileSize < rhs.fileSize
        case .kind:
            return (lhs.fileType ?? "") < (rhs.fileType ?? "")
        case .favorites:
            return (lhs.isFavorite && !rhs.isFavorite)
                || (lhs.isFavorite == rhs.isFavorite && (lhs.fileName ?? "") < (rhs.fileName ?? ""))
        }
    }
}

extension Array where Element == VaultItem {
    func sorted(by option: SortOption, ascending: Bool) -> [VaultItem] {
        let ordered = sorted { option.isOrderedBefore($0, $1) }
        return ascending ? ordered : ordered.reversed()
    }
}