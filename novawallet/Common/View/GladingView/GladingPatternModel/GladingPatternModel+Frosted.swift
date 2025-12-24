import UIKit

extension GladingPatternModel {
    private static var frostHighlightGradient: GradientModel {
        .init(
            startPoint: .init(x: 0.5, y: 0.5),
            endPoint: .init(x: 1.0, y: 0),
            colors: [
                UIColor.white,
                UIColor.white.withAlphaComponent(0.85),
                UIColor.white.withAlphaComponent(0.56),
                UIColor.white.withAlphaComponent(0.39),
                UIColor.white.withAlphaComponent(0.25),
                UIColor.white.withAlphaComponent(0.14),
                UIColor.white.withAlphaComponent(0.06),
                UIColor.white.withAlphaComponent(0.02),
                UIColor.white.withAlphaComponent(0.0)
            ],
            locations: [0.0, 0.12, 0.25, 0.37, 0.50, 0.62, 0.75, 0.87, 1.0]
        )
    }

    static var frostPattern: GladingPatternModel {
        .init(
            gradient: Self.frostHighlightGradient,
            slidingX: .init(min: 0.5, max: -0.5),
            slidingY: .init(min: 0.5, max: -0.5),
            gradientRotation: -CGFloat.pi / 4,
            gradientSize: CGSize(width: 800, height: 240),
            pattern: R.image.frostCardPatternHighlighted()!,
            opacity: 0.75,
            maskContentsGravity: .resizeAspectFill
        )
    }
}

extension GladingRectModel {
    private static var frostStrokeGradient: GradientModel {
        .init(
            startPoint: .init(x: 0.0, y: 0.5),
            endPoint: .init(x: 1.0, y: 0.5),
            colors: [
                UIColor.white.withAlphaComponent(0.0),
                UIColor.white.withAlphaComponent(0.25),
                UIColor.white.withAlphaComponent(0.0)
            ],
            locations: [0.0, 0.5, 1.0]
        )
    }
}
