import Foundation
import KXSFCore
import UIKit

enum KXSFArtworkRepository {
    /// Prepare show artwork for compact Live Activity / widget tiles.
    /// Non-square sources are center-cropped to a square JPEG so Dynamic Island
    /// and Lock Screen can show real program art instead of only the logo fallback.
    static func store(_ data: Data, revision: String) throws {
        guard let image = UIImage(data: data) else { throw ArtworkError.invalidImage }
        guard let squareData = squareJPEGData(from: image) else {
            throw ArtworkError.invalidImage
        }
        guard let cache else { throw ArtworkError.unavailableAppGroup }
        try cache.store(squareData, revision: revision)
    }

    static func data(matching revision: String?) -> Data? {
        cache?.data(matching: revision)
    }

    static func squareJPEGData(from image: UIImage, maxPixelSize: CGFloat = 512, quality: CGFloat = 0.86) -> Data? {
        let pixelWidth = image.size.width * image.scale
        let pixelHeight = image.size.height * image.scale
        guard pixelWidth > 0, pixelHeight > 0 else { return nil }

        let side = min(pixelWidth, pixelHeight)
        let cropRect = CGRect(
            x: (pixelWidth - side) / 2,
            y: (pixelHeight - side) / 2,
            width: side,
            height: side
        )

        guard let cgImage = image.cgImage else {
            // Fallback path for images without an immediate CGImage.
            let format = UIGraphicsImageRendererFormat.default()
            format.scale = 1
            format.opaque = true
            let outputSide = min(side, maxPixelSize)
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format)
            let squared = renderer.image { _ in
                let drawRect = CGRect(
                    x: -(pixelWidth - side) / 2 * (outputSide / side),
                    y: -(pixelHeight - side) / 2 * (outputSide / side),
                    width: pixelWidth * (outputSide / side),
                    height: pixelHeight * (outputSide / side)
                )
                image.draw(in: drawRect)
            }
            return squared.jpegData(compressionQuality: quality)
        }

        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        let croppedImage = UIImage(cgImage: cropped, scale: 1, orientation: image.imageOrientation)

        let outputSide = min(side, maxPixelSize)
        if abs(croppedImage.size.width - outputSide) < 0.5,
           abs(croppedImage.size.height - outputSide) < 0.5 {
            return croppedImage.jpegData(compressionQuality: quality)
        }

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: outputSide, height: outputSide), format: format)
        let resized = renderer.image { _ in
            croppedImage.draw(in: CGRect(x: 0, y: 0, width: outputSide, height: outputSide))
        }
        return resized.jpegData(compressionQuality: quality)
    }

    private static var cache: KXSFArtworkFileCache? {
        guard let groupURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: KXSFConstants.appGroup
        ) else { return nil }
        return KXSFArtworkFileCache(
            directoryURL: groupURL.appendingPathComponent("Artwork", isDirectory: true)
        )
    }

    private enum ArtworkError: Error {
        case invalidImage
        case unavailableAppGroup
    }
}
