import UIKit

class NftSecureImageFactory {
    private let gradientColors: [(UIColor, UIColor)] = [
        (
            UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0),
            UIColor(red: 0.1, green: 0.4, blue: 0.9, alpha: 1.0)
        ), // Blue gradient
        (
            UIColor(red: 1.0, green: 0.9, blue: 0.3, alpha: 1.0),
            UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0)
        ), // Yellow gradient
        (
            UIColor(red: 1.0, green: 0.4, blue: 0.8, alpha: 1.0),
            UIColor(red: 0.9, green: 0.2, blue: 0.7, alpha: 1.0)
        ) // Pink gradient
    ]
    
    private func createPlaceholderImage(with gradientColors: (UIColor, UIColor)) -> UIImage? {
        guard let iconImage = R.image.iconSiriNft() else {
            return nil
        }

        let imageSize = CGSize(width: 32, height: 32)
        let iconSize = CGSize(width: 32, height: 32)

        let renderer = UIGraphicsImageRenderer(size: imageSize)

        let placeholderImage = renderer.image { context in
            let rect = CGRect(origin: .zero, size: imageSize)
            let cgContext = context.cgContext

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let colors = [gradientColors.0.cgColor, gradientColors.1.cgColor]
            let locations: [CGFloat] = [0.0, 1.0]

            guard let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray, locations: locations) else {
                gradientColors.0.setFill()
                cgContext.fill(rect)
                return
            }

            let startPoint = CGPoint(x: 0, y: 0)
            let endPoint = CGPoint(x: imageSize.width, y: imageSize.height)

            cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])

            let iconOrigin = CGPoint(
                x: (imageSize.width - iconSize.width) / 2,
                y: (imageSize.height - iconSize.height) / 2
            )
            let iconRect = CGRect(origin: iconOrigin, size: iconSize)

            iconImage.draw(in: iconRect)
        }

        return placeholderImage
    }
}

// MARK: - Internal

extension NftSecureImageFactory {
    func createPlaceholders(count: Int) -> [UIImage] {
        var placeholderImages: [UIImage] = []

        for index in 0 ..< count {
            let colorIndex = index % gradientColors.count
            let gradientColorPair = gradientColors[colorIndex]

            if let placeholderImage = createPlaceholderImage(with: gradientColorPair) {
                placeholderImages.append(placeholderImage)
            }
        }

        return placeholderImages
    }
}
