//
//  TrashView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI
import CoreData

struct TrashView: View {
    @StateObject private var viewModel = TrashViewModel()
    
    var body: some View {
        // Full width on every device; items open in the full-screen viewer.
        trashContent
    }

    private var trashContent: some View {
        VStack(spacing: 0) {
            if viewModel.deletedItems.isEmpty {
                emptyTrashView
            } else {
                // Use the existing VaultGridView for consistency
                VaultGridView(
                    items: viewModel.deletedItems,
                    searchText: "",
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedItems: viewModel.selectedItems,
                    isImporting: false,
                    emptyStateConfig: .emptyTrash(),
                    onItemTap: { item in
                        if viewModel.isSelectionMode {
                            viewModel.toggleSelection(item)
                        } else {
                            viewModel.viewFile(item)
                        }
                    },
                    onItemLongPress: { item in
                        if !viewModel.isSelectionMode {
                            viewModel.enterSelectionMode()
                            viewModel.toggleSelection(item)
                        }
                    },
                    onFavoriteToggle: nil,  // Remove favorite functionality in trash
                    onShare: nil,           // Remove share functionality in trash
                    onRename: nil,          // Remove rename functionality in trash
                    onMove: nil,            // Remove move functionality in trash
                    onDelete: nil,          // Remove delete functionality in trash
                    onSelect: nil,          // Remove context menu selection
                    showFavoriteIndicator: true
                )
                
                // Bottom action bar (when items are selected)
                if viewModel.isSelectionMode && !viewModel.selectedItems.isEmpty {
                    bottomActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !viewModel.deletedItems.isEmpty {
                        if viewModel.isSelectionMode {
                            Button("Select All") {
                                viewModel.selectAllItems()
                            }
                            Button("Cancel") {
                                viewModel.exitSelectionMode()
                            }
                        } else {
                            // Empty Trash button (only show when not in selection mode)
                            Button("Empty Trash") {
                                viewModel.showEmptyTrashAlert = true
                            }
                            .foregroundColor(.red)
                            
                            Button("Select") {
                                viewModel.enterSelectionMode()
                            }
                        }
                    }
                }
            }
        }
        .alert("Permanently Delete", isPresented: $viewModel.showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.permanentlyDeleteSelected()
            }
        } message: {
            Text("Are you sure you want to permanently delete \(viewModel.selectedItems.count) item(s)? This action cannot be undone.")
        }
        .alert("Restore Items", isPresented: $viewModel.showRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restore") {
                viewModel.restoreSelected()
            }
        } message: {
            Text("Restore \(viewModel.selectedItems.count) item(s) to their original location?")
        }
        .alert("Empty Trash", isPresented: $viewModel.showEmptyTrashAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Empty Trash", role: .destructive) {
                viewModel.emptyAllTrash()
            }
        } message: {
            Text("Are you sure you want to permanently delete all \(viewModel.deletedItems.count) items in trash? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: viewModel.isMediaViewerPresented) {
            UnifiedMediaViewerView(
                mediaItems: viewModel.getMediaFiles(),
                initialIndex: viewModel.mediaViewerIndex
            )
        }
        .fullScreenCover(isPresented: $viewModel.showFilePreview) {
            if let filePreviewItem = viewModel.filePreviewItem {
                FilePreviewView(vaultItem: filePreviewItem)
            }
        }
        .onAppear {
            viewModel.loadDeletedItems()
        }
    }
    

    
    private var emptyTrashView: some View {
        VStack(spacing: 28) {
            KeepshireHero(
                artwork: .symbol("trash.fill"),
                title: "Trash is Empty",
                subtitle: "When you delete files with trash enabled, they appear here. You can restore them or delete them for good.",
                artworkSize: 68
            )
            
            VStack(spacing: 12) {
                trashTip(
                    systemImage: "arrow.uturn.backward",
                    tint: KeepshireTheme.accent,
                    text: "Select items and restore them to their original location"
                )
                trashTip(
                    systemImage: "trash.slash.fill",
                    tint: .red,
                    text: "Permanently delete items you no longer need"
                )
            }
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 520)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(KeepshireBackground())
    }

    private func trashTip(systemImage: String, tint: Color, text: String) -> some View {
        HStack(spacing: 12) {
            KeepshireIconTile(systemName: systemImage, tint: tint, size: 36)
            Text(text)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .keepshireCard(padding: 12)
    }
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 0) {
                // Restore button
                Button(action: {
                    viewModel.showRestoreAlert = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                        Text("Restore (\(viewModel.selectedItems.count))")
                            .font(.caption)
                    }
                    .foregroundColor(KeepshireTheme.accent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .accessibilityLabel("Restore \(viewModel.selectedItems.count) selected items")
                
                Divider()
                    .frame(height: 40)
                
                // Delete button
                Button(action: {
                    viewModel.showDeleteAlert = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Delete (\(viewModel.selectedItems.count))")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .accessibilityLabel("Permanently delete \(viewModel.selectedItems.count) selected items")
            }
            .padding(.horizontal)
            .background(.bar)
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}



#Preview {
    TrashView()
}