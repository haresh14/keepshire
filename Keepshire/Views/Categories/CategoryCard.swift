import SwiftUI

/// A reusable card representing a vault category.
struct CategoryCard: View {
    let categoryType: CategoryType
    let itemCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            KeepshireIconTile(systemName: categoryType.systemImage, tint: categoryType.color, size: 46)

            VStack(alignment: .leading, spacing: 2) {
                Text(categoryType.rawValue)
                    .font(.system(.headline, design: .rounded))
                    .foregroundColor(.primary)

                Text(itemCount == 1 ? "1 item" : "\(itemCount) items")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .keepshireCard()
    }
}

#Preview {
    CategoryCard(categoryType: .photos, itemCount: 42)
} 