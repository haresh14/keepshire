//
//  FolderView.swift
//  Keepshire
//
//  Created on 12/07/25.
//

import SwiftUI
import CoreData

struct FolderView: View {
    @State private var navigationPath = NavigationPath()
    @State private var compactNavigationPath = NavigationPath()
    @State private var selectedFolder: Folder?
    @State private var previewItem: VaultItem?
    @State private var previewMediaItems: [VaultItem] = []
    @StateObject private var loginStateManager = LoginStateManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        predicate: NSPredicate(format: "parent == nil")
    ) private var rootFolders: FetchedResults<Folder>

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                List {
                    Button {
                        select(nil)
                    } label: {
                        HStack(spacing: 12) {
                            KeepshireIconTile(systemName: "tray.full.fill", size: 32, filled: selectedFolder == nil)
                            Text("All Folders")
                                .font(.system(.body, design: .rounded, weight: .medium))
                            Spacer()
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedFolder == nil ? KeepshireTheme.accent : Color.primary)
                    .listRowBackground(selectedFolder == nil ? KeepshireTheme.accent.opacity(0.12) : nil)
                    .accessibilityLabel("All Folders")
                    .accessibilityValue(selectedFolder == nil ? "Selected" : "")

                    if !loginStateManager.shouldShowEmptyVault {
                        ForEach(sidebarItems) { item in
                            Button {
                                select(item.folder)
                            } label: {
                                HStack(spacing: 12) {
                                    KeepshireIconTile(systemName: "folder.fill", size: 32, filled: selectedFolder == item.folder)
                                    Text(item.folder.displayName)
                                        .font(.system(.body, design: .rounded, weight: .medium))
                                        .lineLimit(1)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, CGFloat(item.depth) * 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(
                                selectedFolder == item.folder ? KeepshireTheme.accent : Color.primary
                            )
                            .listRowBackground(
                                selectedFolder == item.folder ? KeepshireTheme.accent.opacity(0.12) : nil
                            )
                            .accessibilityLabel(item.folder.displayName)
                            .accessibilityValue(selectedFolder == item.folder ? "Selected" : "")
                        }
                    }
                }
                .navigationTitle("Folders")
                .keepshireBackground(hidesScrollBackground: true)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                } content: {
                FolderContentView(
                    folder: selectedFolder,
                    navigationPath: $navigationPath,
                    onNavigateToFolder: select,
                    onPreviewFile: showPreview
                )
                .id(selectedFolder?.objectID)
                .navigationSplitViewColumnWidth(min: 360, ideal: 500)
                } detail: {
                VaultPreviewDetail(
                    item: previewItem,
                    mediaItems: previewMediaItems,
                    onClose: clearPreview
                )
                }
            } else {
                NavigationStack(path: $compactNavigationPath) {
                // FolderContentView already titles itself ("Folders" at the root, the
                // folder name when pushed). Setting a second title here competes with
                // it, which drops the title on first layout and flashes the root title
                // over each pushed folder.
                FolderContentView(
                    folder: nil,
                    navigationPath: $compactNavigationPath
                )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshVaultItems)) { _ in
            if selectedFolder?.isDeleted == true {
                select(nil)
            }
        }
    }

    private func select(_ folder: Folder?) {
        selectedFolder = folder
        navigationPath = NavigationPath()
        clearPreview()
    }

    private func showPreview(_ item: VaultItem, mediaItems: [VaultItem]) {
        previewItem = item
        previewMediaItems = mediaItems
    }

    private func clearPreview() {
        previewItem = nil
        previewMediaItems = []
    }

    private var sidebarItems: [FolderSidebarItem] {
        rootFolders.flatMap { flatten($0, depth: 0) }
    }

    private func flatten(_ folder: Folder, depth: Int) -> [FolderSidebarItem] {
        let item = FolderSidebarItem(folder: folder, depth: depth)
        let children = folder.subfoldersArray.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
        return [item] + children.flatMap { flatten($0, depth: depth + 1) }
    }
}

private struct FolderSidebarItem: Identifiable {
    let folder: Folder
    let depth: Int
    var id: NSManagedObjectID { folder.objectID }
}

#Preview {
    FolderView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 