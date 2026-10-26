//
//  FilePreviewErrorView.swift
//  Keepshire
//
//  Error view for file preview
//

import SwiftUI

struct FilePreviewErrorView: View {
    let message: String
    let onRetry: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            KeepshireIconTile(systemName: "exclamationmark.triangle.fill", tint: .red, size: 72)
            
            Text("Failed to Load File")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(message)
                .font(.body)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("Try Again") {
                onRetry()
            }
            .buttonStyle(KeepshirePrimaryButtonStyle())
            .frame(maxWidth: 260)
        }
        .padding()
    }
}

#Preview {
    FilePreviewErrorView(
        message: "Network connection failed",
        onRetry: { }
    )
    .background(Color.black)
}