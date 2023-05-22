import UIKit

struct GladingRectModel {
    enum Mode {
        case fill
        case stroke(width: CGFloat)
    }

    let gradient: GradientModel
    let mode: Mode
    let cornerRadius: CGFloat
    let slidingMin: CGFloat
    let slidingMax: CGFloat
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

    private static var cardGradient: GradientModel {
        .init(
            startPoint: .init(x: 0.0, y: 0.5),
            endPoint: .init(x: 1.0, y: 0.5),
            colors: [
                UIColor(hex: "#70A1FF")!.withAlphaComponent(0.0),
                UIColor(hex: "#70C3FF")!.withAlphaComponent(0.10),
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
            slidingMin: 1,
            slidingMax: -1,
            gradientSize: CGSize(width: 127, height: 205)
        )
    }

    static var cardActionsStrokeGlading: GladingRectModel {
        .init(
            gradient: Self.cardActionsGradient,
            mode: .stroke(width: 1.0),
            cornerRadius: 12,
            slidingMin: 1,
            slidingMax: -1,
            gradientSize: CGSize(width: 127, height: 84)
        )
    }

    static var cardGlading: GladingRectModel {
        .init(
            gradient: Self.cardStrokeGradient,
            mode: .fill,
            cornerRadius: 12,
            slidingMin: 1,
            slidingMax: -1,
            gradientSize: CGSize(width: 217, height: 200)
        )
    }
}
