import SwiftUI
import UIKit

struct LiveArtwork: View {
    enum Style {
        /// Lock Screen banner + expanded Dynamic Island.
        case standard
        /// Compact / minimal Dynamic Island — pre-masked circular bitmap.
        case compactIsland
    }

    let revision: String?
    let size: CGFloat
    let style: Style

    init(revision: String?, size: CGFloat = 44, style: Style = .standard) {
        self.revision = revision
        self.size = size
        self.style = style
    }

    var body: some View {
        switch style {
        case .standard:
            standardBody
        case .compactIsland:
            // Compact Dynamic Island is picky: avoid clipShape/Group/fixedSize trees.
            // Render a finished circular UIImage and drop it in as a plain Image.
            Image(uiImage: circularBitmap)
                .resizable()
                .frame(width: size, height: size)
                .accessibilityHidden(true)
        }
    }

    private var standardBody: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFill()
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .accessibilityHidden(true)
    }

    private var uiImage: UIImage? {
        guard
            let data = KXSFArtworkRepository.data(matching: revision),
            let image = UIImage(data: data)
        else { return nil }
        return image
    }

    /// Finished circular tile for compact / minimal Dynamic Island.
    private var circularBitmap: UIImage {
        let scale = max(UITraitCollection.current.displayScale, 2)
        let pixelSide = max(size * scale, 1)
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        format.opaque = false
        let renderer = UIGraphicsImageRenderer(
            size: CGSize(width: size, height: size),
            format: format
        )

        return renderer.image { context in
            let bounds = CGRect(x: 0, y: 0, width: size, height: size)
            let cg = context.cgContext

            cg.saveGState()
            cg.addEllipse(in: bounds)
            cg.clip()

            if let uiImage {
                // Aspect-fill into the circle.
                let imageSize = uiImage.size
                let scaleFill = max(size / max(imageSize.width, 0.001), size / max(imageSize.height, 0.001))
                let drawSize = CGSize(width: imageSize.width * scaleFill, height: imageSize.height * scaleFill)
                let drawOrigin = CGPoint(
                    x: (size - drawSize.width) / 2,
                    y: (size - drawSize.height) / 2
                )
                uiImage.draw(in: CGRect(origin: drawOrigin, size: drawSize))
            } else if let logo = UIImage(named: "KXSFLogo") {
                UIColor.black.setFill()
                cg.fill(bounds)
                let inset = size * 0.12
                logo.draw(in: bounds.insetBy(dx: inset, dy: inset))
            } else {
                UIColor(red: 0.90, green: 0.18, blue: 0.16, alpha: 1).setFill()
                cg.fillEllipse(in: bounds)
            }
            cg.restoreGState()

            // Rim so the tile remains visible against the black island.
            cg.setStrokeColor(UIColor.white.withAlphaComponent(0.35).cgColor)
            cg.setLineWidth(max(0.8, 1.0 / scale))
            cg.strokeEllipse(in: bounds.insetBy(dx: 0.4, dy: 0.4))

            // Keep the compiler happy about unused pixel math in debug.
            _ = pixelSide
        }
    }

    private var fallback: some View {
        ZStack {
            Color.black
            Image("KXSFLogo")
                .resizable()
                .scaledToFit()
                .padding(size * 0.08)
        }
    }
}
