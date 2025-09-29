import UIKit

final class NftSecureImageFactory {
    private func createPlaceholderImage(with gradient: GradientModel) -> UIImage? {
        guard let iconImage = R.image.iconSiriNft() else {
            return nil
        }

        let renderer = UIGraphicsImageRenderer(size: Constants.imageSize)

        let placeholderImage = renderer.image { context in
            let rect = CGRect(origin: .zero, size: Constants.imageSize)
            let cgContext = context.cgContext

            let colorSpace = CGColorSpaceCreateDeviceRGB()
            let cgColors = gradient.colors.map(\.cgColor)

            let cgLocations = if let locations = gradient.locations {
                locations.map { CGFloat($0) }
            } else {
                stride(
                    from: 0.0,
                    through: 1.0,
                    by: 1.0 / Double(gradient.colors.count - 1)
                ).map { CGFloat($0) }
            }

            guard let cgGradient = CGGradient(
                colorsSpace: colorSpace,
                colors: cgColors as CFArray,
                locations: cgLocations
            ) else {
                gradient.colors.first?.setFill()
                cgContext.fill(rect)
                return
            }

            let startPoint = CGPoint(
                x: gradient.startPoint.x * Constants.imageSize.width,
                y: gradient.startPoint.y * Constants.imageSize.height
            )
            let endPoint = CGPoint(
                x: gradient.endPoint.x * Constants.imageSize.width,
                y: gradient.endPoint.y * Constants.imageSize.height
            )

            cgContext.drawLinearGradient(cgGradient, start: startPoint, end: endPoint, options: [])

            let iconOrigin = CGPoint(
                x: (Constants.imageSize.width - Constants.iconSize.width) / 2,
                y: (Constants.imageSize.height - Constants.iconSize.height) / 2
            )
            let iconRect = CGRect(origin: iconOrigin, size: Constants.iconSize)

            iconImage.draw(in: iconRect)
        }

        return placeholderImage
    }
}

// MARK: - Internal

extension NftSecureImageFactory {
    func createPlaceholder(for index: Int) -> UIImage? {
        let gradientIndex = index % Constants.gradients.count

        return createPlaceholderImage(with: Constants.gradients[gradientIndex])
    }
}

// MARK: - Constants

private extension NftSecureImageFactory {
    enum Constants {
        static let imageSize: CGSize = .init(width: 32, height: 32)
        static let iconSize: CGSize = .init(width: 32, height: 32)
        static let gradients: [GradientModel] = [
            // Pink gradient
            GradientModel(
                angle: 135,
                colors: [
                    UIColor(red: 0.936, green: 0.452, blue: 1, alpha: 1),
                    UIColor(red: 0.757, green: 0.015, blue: 0.435, alpha: 1)
                ],
                locations: [0, 1]
            ),
            // Yellow gradient
            GradientModel(
                angle: 135,
                colors: [
                    UIColor(red: 1, green: 0.806, blue: 0.315, alpha: 1),
                    UIColor(red: 0.698, green: 0.423, blue: 0.064, alpha: 1)
                ],
                locations: [0, 1]
            ),
            // Blue gradient
            GradientModel(
                angle: 135,
                colors: [
                    UIColor(red: 0.452, green: 0.67, blue: 1, alpha: 1),
                    UIColor(red: 0.002, green: 0.352, blue: 0.883, alpha: 1)
                ],
                locations: [0, 1]
            )
        ]
    }
}
