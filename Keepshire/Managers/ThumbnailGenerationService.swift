import Foundation
import UIKit
import AVFoundation
import CoreMedia
import CryptoKit

struct GeneratedVideoThumbnail {
    let fileName: String?
    let durationSeconds: Double
}

final class ThumbnailGenerationService {
    private let fileManager: FileManager
    private let thumbnailStore: EncryptedFileStore
    private let thumbnailSize = CGSize(width: 200, height: 200)

    init(
        fileManager: FileManager,
        thumbnailStore: EncryptedFileStore
    ) {
        self.fileManager = fileManager
        self.thumbnailStore = thumbnailStore
    }

    func generateImageThumbnail(from data: Data, storageKey: String, key: SymmetricKey) throws -> String? {
        guard let image = UIImage(data: data) else { return nil }
        let thumbnail = UIGraphicsImageRenderer(size: thumbnailSize).image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else { return nil }
        return try write(thumbnailData, storageKey: storageKey, key: key)
    }

    func generateVideoThumbnail(
        from data: Data,
        storageKey: String,
        displayFileName: String,
        key: SymmetricKey
    ) throws -> GeneratedVideoThumbnail {
        let originalExtension = (displayFileName as NSString).pathExtension
        let tempFileName = UUID().uuidString
            + (originalExtension.isEmpty ? ".mov" : ".\(originalExtension)")
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(tempFileName)
        try data.write(to: tempURL)
        defer { try? fileManager.removeItem(at: tempURL) }
        return try generateVideoThumbnail(
            fromFileURL: tempURL,
            storageKey: storageKey,
            displayFileName: displayFileName,
            key: key
        )
    }

    func generateVideoThumbnail(
        fromFileURL fileURL: URL,
        storageKey: String,
        displayFileName: String,
        key: SymmetricKey
    ) throws -> GeneratedVideoThumbnail {
        let asset = AVURLAsset(url: fileURL)
        let durationSeconds = Self.durationSeconds(from: asset)
        // Intentionally retained for behavior compatibility; modernization is a later wave.
        guard !asset.tracks(withMediaType: .video).isEmpty else {
            return GeneratedVideoThumbnail(
                fileName: generateGenericVideoThumbnail(storageKey: storageKey, displayFileName: displayFileName, key: key),
                durationSeconds: durationSeconds
            )
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = thumbnailSize
        let times = [
            CMTime(seconds: 1, preferredTimescale: 60),
            CMTime(seconds: 0.5, preferredTimescale: 60),
            CMTime(seconds: 2, preferredTimescale: 60),
            CMTime.zero
        ]

        for time in times {
            do {
                // Intentionally retained for behavior compatibility; modernization is a later wave.
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                if let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) {
                    return GeneratedVideoThumbnail(
                        fileName: try write(thumbnailData, storageKey: storageKey, key: key),
                        durationSeconds: durationSeconds
                    )
                }
            } catch {
                VaultLog.debug("DEBUG: Error generating video thumbnail at time \(time.seconds): \(error)")
            }
        }
        return GeneratedVideoThumbnail(
            fileName: generateGenericVideoThumbnail(storageKey: storageKey, displayFileName: displayFileName, key: key),
            durationSeconds: durationSeconds
        )
    }

    static func durationSeconds(from asset: AVAsset) -> Double {
        let seconds = CMTimeGetSeconds(asset.duration)
        guard seconds.isFinite, seconds > 0 else { return 0 }
        return seconds
    }

    private func generateGenericVideoThumbnail(
        storageKey: String,
        displayFileName: String,
        key: SymmetricKey
    ) -> String? {
        let thumbnail = UIGraphicsImageRenderer(size: thumbnailSize).image { context in
            let cgContext = context.cgContext
            cgContext.setFillColor(UIColor.systemGray2.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: thumbnailSize))

            let playButtonSize: CGFloat = 60
            let playButtonRect = CGRect(
                x: (thumbnailSize.width - playButtonSize) / 2,
                y: (thumbnailSize.height - playButtonSize) / 2,
                width: playButtonSize,
                height: playButtonSize
            )
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cgContext.fillEllipse(in: playButtonRect)

            let triangleSize: CGFloat = 20
            let triangleRect = CGRect(
                x: playButtonRect.midX - triangleSize / 2 + 2,
                y: playButtonRect.midY - triangleSize / 2,
                width: triangleSize,
                height: triangleSize
            )
            cgContext.setFillColor(UIColor.systemBlue.cgColor)
            cgContext.beginPath()
            cgContext.move(to: CGPoint(x: triangleRect.minX, y: triangleRect.minY))
            cgContext.addLine(to: CGPoint(x: triangleRect.maxX, y: triangleRect.midY))
            cgContext.addLine(to: CGPoint(x: triangleRect.minX, y: triangleRect.maxY))
            cgContext.closePath()
            cgContext.fillPath()

            let fileExtension = (displayFileName as NSString).pathExtension.uppercased()
            if !fileExtension.isEmpty {
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14, weight: .medium),
                    .foregroundColor: UIColor.white
                ]
                let textSize = fileExtension.size(withAttributes: attributes)
                fileExtension.draw(
                    in: CGRect(
                        x: (thumbnailSize.width - textSize.width) / 2,
                        y: thumbnailSize.height - textSize.height - 10,
                        width: textSize.width,
                        height: textSize.height
                    ),
                    withAttributes: attributes
                )
            }
        }

        guard let data = thumbnail.jpegData(compressionQuality: 0.7) else { return nil }
        return try? write(data, storageKey: storageKey, key: key)
    }

    private func write(_ data: Data, storageKey: String, key: SymmetricKey) throws -> String {
        let fileName = "\(storageKey).thumb"
        try thumbnailStore.write(data, fileName: fileName, key: key)
        return fileName
    }
}
