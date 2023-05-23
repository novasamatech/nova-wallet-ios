import UIKit

struct GladingPatternModel {
    let gradient: GradientModel
    let slidingMin: CGFloat
    let slidingMax: CGFloat
    let gradientRotation: CGFloat
    let gradientSize: CGSize
    let pattern: UIImage
}

extension GladingPatternModel {
    private static var gladingCard: GradientModel {
        .init(
            startPoint: .init(x: 0.5, y: 0.5),
            endPoint: .init(x: 1.0, y: 0),
            colors: [
                UIColor(hex: "#FBACFF")!,
                UIColor(hex: "#D99EFF")!.withAlphaComponent(0.76),
                UIColor(hex: "#BC92FF")!.withAlphaComponent(0.56),
                UIColor(hex: "#A388FF")!.withAlphaComponent(0.39),
                UIColor(hex: "#8F7FFF")!.withAlphaComponent(0.25),
                UIColor(hex: "#7F79FF")!.withAlphaComponent(0.14),
                UIColor(hex: "#7374FF")!.withAlphaComponent(0.06),
                UIColor(hex: "#6D71FF")!.withAlphaComponent(0.02),
                UIColor(hex: "#6B71FF")!.withAlphaComponent(0.0)
            ],
            locations: [0.0, 0.12, 0.25, 0.37, 0.50, 0.62, 0.75, 0.87, 1.0]
        )
    }

    private static let gradientRotation: CGFloat = -CGFloat.pi / 4
    private static let gradientSize = CGSize(width: 963, height: 246)
    private static let slidingMin: CGFloat = -0.5
    private static let slidingMax: CGFloat = 0.5

    static var bigPattern: GladingPatternModel {
        .init(
            gradient: Self.gladingCard,
            slidingMin: Self.slidingMin,
            slidingMax: Self.slidingMax,
            gradientRotation: Self.gradientRotation,
            gradientSize: Self.gradientSize,
            pattern: R.image.cardBigPattern()!
        )
    }

    static var middlePattern: GladingPatternModel {
        .init(
            gradient: Self.gladingCard,
            slidingMin: Self.slidingMin,
            slidingMax: Self.slidingMax,
            gradientRotation: Self.gradientRotation,
            gradientSize: Self.gradientSize,
            pattern: R.image.cardMiddlePattern()!.blurred(with: 2)!
        )
    }

    static var smallPattern: GladingPatternModel {
        .init(
            gradient: Self.gladingCard,
            slidingMin: Self.slidingMin,
            slidingMax: Self.slidingMax,
            gradientRotation: Self.gradientRotation,
            gradientSize: Self.gradientSize,
            pattern: R.image.cardSmallPattern()!.blurred(with: 4)!
        )
    }
}
