//
//  CategoryView.swift
//  Keepshire
//
//  Created on 12/07/25.
//

import SwiftUI
import CoreData

// `CategoryType` has been moved to Models/CategoryType.swift
struct CategoryView: View {
    /// Owns the data-loading logic so that this view remains declarative.
    @StateObject private var viewModel = CategoryViewModel()
    /// iPad opens on All Files rather than an empty column.
    @State private var selectedCategory: CategoryType? = .allFiles

    @Environment(\.managedObjectContext) var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Item filtering is now handled by CategoryViewModel.
    
    private func getItemCount(for categoryType: CategoryType) -> Int {
        viewModel.itemCount(for: categoryType)
    }
    
    private func getItems(for categoryType: CategoryType) -> [VaultItem] {
        viewModel.items(for: categoryType)
    }
    
    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(CategoryType.allCases, id: \.self) { categoryType in
                    Button {
                        selectedCategory = categoryType
                    } label: {
                        HStack(spacing: 12) {
                            KeepshireIconTile(systemName: categoryType.systemImage, tint: categoryType.color, size: 32)
                            Text(categoryType.rawValue)
                                .font(.system(.body, design: .rounded, weight: .medium))
                            Spacer()
                            Text("\(getItemCount(for: categoryType))")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedCategory == categoryType ? KeepshireTheme.accent : Color.primary)
                    .listRowBackground(
                        selectedCategory == categoryType ? KeepshireTheme.accent.opacity(0.12) : nil
                    )
                }
                .navigationTitle("Categories")
                .keepshireBackground(hidesScrollBackground: true)
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } detail: {
                // Two columns: the grid gets the full width, and files open in the
                // same full-screen viewer as on iPhone instead of a narrow third column.
                if let selectedCategory {
                    CategoryFilesView(categoryType: selectedCategory)
                        .id(selectedCategory)
                } else {
                    KeepshirePlaceholder(
                        title: "Select a Category",
                        message: "Choose a category from the sidebar.",
                        systemName: "square.grid.2x2.fill"
                    )
                }
            }
            // The split container draws a plain fill under the floating tab bar;
            // the brand background goes behind it so the top matches other tabs.
            .background(KeepshireBackground())
        } else {
            NavigationStack {
                categoryGrid
            }
        }
    }

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 14)
            ], spacing: 14) {
                ForEach(CategoryType.allCases, id: \.self) { categoryType in
                    NavigationLink(destination: CategoryFilesView(
                        categoryType: categoryType
                    )
                    .id(categoryType)) {
                        CategoryCard(
                            categoryType: categoryType,
                            itemCount: getItemCount(for: categoryType)
                        )
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
        }
        .keepshireBackground()
        .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.large)
    }

    
    // loadVaultItems removed – logic now lives in CategoryViewModel.
}

// `CategoryCard` has been moved to Views/Categories/CategoryCard.swift

// `CategoryFilesView` and `CategoryFolderPickerView` have been moved to Views/Categories/CategoryFilesView.swift

#Preview {
    CategoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 