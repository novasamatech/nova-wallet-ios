import UIKit

struct GladingRectModel {
    enum Mode {
        case fill
        case stroke(width: CGFloat)
    }

    let gradient: GradientModel
    let mode: Mode
    let cornerRadius: CGFloat
    let slidingX: GlareInterval
    let slidingY: GlareInterval
    let rotation: CGFloat
    let gradientSize: CGSize
}

extension GladingRectModel {
    private static var cardStrokeGradient: GradientModel {
        .init(
            startPoint: .init(x: 0.0, y: 0.5),
            endPoint: .init(x: 1.0, y: 0.5),
            colors: [
                UIColor(hex: "#BC92FF")!.withAlphaComponent(0.0),
                UIColor(hex: "#BC92FF")!.withAlphaComponent(0.15),
                UIColor(hex: "#BC92FF")!.withAlphaComponent(0.0)
            ],
            locations: [0.0, 0.5, 1.0]
        )
    }

    private static var cardFillGradient: GradientModel {
        .init(
            startPoint: .init(x: 0.0, y: 0.5),
            endPoint: .init(x: 1.0, y: 0.5),
            colors: [
                UIColor(hex: "#70A1FF")!.withAlphaComponent(0.0),
                UIColor(hex: "#70C3FF")!.withAlphaComponent(0.1),
                UIColor(hex: "#70A1FF")!.withAlphaComponent(0.0)
            ],
            locations: [0.0, 0.5, 1.0]
        )
    }

    private static var cardActionsGradient: GradientModel {
        .init(
            startPoint: .init(x: 0.0, y: 0.5),
            endPoint: .init(x: 1.0, y: 0.5),
            colors: [
                UIColor(hex: "#FFFFFF")!.withAlphaComponent(0.0),
                UIColor(hex: "#FFFFFF")!.withAlphaComponent(0.15),
                UIColor(hex: "#FFFFFF")!.withAlphaComponent(0.0)
            ],
            locations: [0.21, 0.5, 0.75]
        )
    }

    static var cardStrokeGlading: GladingRectModel {
        .init(
            gradient: Self.cardStrokeGradient,
            mode: .stroke(width: 2.0),
            cornerRadius: 12,
            slidingX: .init(min: 0.5, max: -0.5),
            slidingY: .init(min: 0.5, max: -0.5),
            rotation: CGFloat.pi / 8.0,
            gradientSize: CGSize(width: 127, height: 600)
        )
    }

    static var cardActionsStrokeGlading: GladingRectModel {
        .init(
            gradient: Self.cardActionsGradient,
            mode: .stroke(width: 1.0),
            cornerRadius: 12,
            slidingX: .init(min: 0.5, max: -0.5),
            slidingY: .init(min: 0.5, max: -0.5),
            rotation: CGFloat.pi / 8.0,
            gradientSize: CGSize(width: 127, height: 300)
        )
    }

    static var cardFillGlading: GladingRectModel {
        .init(
            gradient: Self.cardFillGradient,
            mode: .fill,
            cornerRadius: 12,
            slidingX: .init(min: 0.3, max: -0.3),
            slidingY: .init(min: 0.1, max: -0.1),
            rotation: CGFloat.pi / 8.0,
            gradientSize: CGSize(width: 217, height: 800)
        )
    }
}
