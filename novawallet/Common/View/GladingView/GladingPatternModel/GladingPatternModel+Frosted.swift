import UIKit

extension GladingPatternModel {
    private static var frostHighlightGradient: GradientModel {
        .init(
            startPoint: .init(x: 0.5, y: 0.5),
            endPoint: .init(x: 1.0, y: 0),
            colors: [
                UIColor.white,
                UIColor.white,
                UIColor.white,
                UIColor.white.withAlphaComponent(0.65),
                UIColor.white.withAlphaComponent(0.35),
                UIColor.white.withAlphaComponent(0.15),
                UIColor.white.withAlphaComponent(0.0)
            ],
            locations: [0.0, 0.2, 0.4, 0.55, 0.7, 0.85, 1.0]
        )
    }

    static var frostPattern: GladingPatternModel {
        .init(
            gradient: Self.frostHighlightGradient,
            slidingX: .init(min: 0.5, max: -0.5),
            slidingY: .init(min: 0.5, max: -0.5),
            gradientRotation: -CGFloat.pi / 4,
            gradientSize: CGSize(width: 500, height: 150),
            pattern: R.image.frostCardPattern()!,
            opacity: 0.5,
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
