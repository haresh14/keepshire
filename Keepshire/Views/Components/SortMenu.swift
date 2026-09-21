//
//  SortMenu.swift
//  Keepshire
//
//  Sort control shared by the gallery, folder, and category toolbars.
//

import SwiftUI

/// Protocol that sort option enums must conform to
protocol SortOptionProtocol {
    var systemImage: String { get }
}

// MARK: - Conformances for existing enums

extension SortOption: SortOptionProtocol {}
extension FolderSortOption: SortOptionProtocol {}

/// Sort entry point that sits beside the overflow menu in vault-style toolbars.
/// Options and direction are inline picker sections, so the active choice is
/// checked the same way system menus mark their selection.
struct SortMenu<SortType: RawRepresentable & CaseIterable & Hashable>: View
where SortType.RawValue == String, SortType: SortOptionProtocol {
    let currentSortOption: SortType
    let sortAscending: Bool
    let onSortSelected: (SortType) -> Void
    let onDirectionSelected: (Bool) -> Void

    var body: some View {
        Menu {
            Picker("Sort by", selection: sortSelection) {
                ForEach(Array(SortType.allCases), id: \.self) { option in
                    Label(option.rawValue, systemImage: option.systemImage)
                        .tag(option)
                }
            }
            .pickerStyle(.inline)

            Picker("Order", selection: directionSelection) {
                Label("Ascending", systemImage: "arrow.up")
                    .tag(true)
                Label("Descending", systemImage: "arrow.down")
                    .tag(false)
            }
            .pickerStyle(.inline)
        } label: {
            Image(systemName: "arrow.up.arrow.down.circle")
                .foregroundColor(KeepshireTheme.accent)
        }
        .accessibilityLabel("Sort")
    }

    private var sortSelection: Binding<SortType> {
        Binding(get: { currentSortOption }, set: onSortSelected)
    }

    private var directionSelection: Binding<Bool> {
        Binding(get: { sortAscending }, set: onDirectionSelected)
    }
}

// MARK: - Convenience type aliases

typealias GallerySortMenu = SortMenu<SortOption>
typealias CategorySortMenu = SortMenu<SortOption>
typealias FolderSortMenu = SortMenu<FolderSortOption>
