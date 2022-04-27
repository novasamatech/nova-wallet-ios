import UIKit

struct GradientBannerModel {
    let left: GradientModel
    let right: GradientModel
}

extension GradientBannerModel {
    static func stakingController() -> GradientBannerModel {
        let color = UIColor(
            red: 131.0 / 255.0,
            green: 153.0 / 255.0,
            blue: 173.0 / 255.0,
            alpha: 0.64
        )

        return createModel(with: color)
    }

    static func stakingValidators() -> GradientBannerModel {
        let color = UIColor(
            red: 35.0 / 255.0,
            green: 127.0 / 255.0,
            blue: 212.0 / 255.0,
            alpha: 0.64
        )

        return createModel(with: color)
    }

    static func stakingUnpaidRewards() -> GradientBannerModel {
        let color = UIColor(
            red: 226.0 / 255.0,
            green: 207.0 / 255.0,
            blue: 34.0 / 255.0,
            alpha: 0.64
        )

        return createModel(with: color)
    }

    static func createModel(with color: UIColor) -> GradientBannerModel {
        let finalColor = color.withAlphaComponent(0.0)
        let locations: [Float] = [0, 0.48]

        let left = GradientModel(
            startPoint: CGPoint(x: 1.0, y: 0.3),
            endPoint: CGPoint(x: 0.0, y: 0.7),
            colors: [
                color,
                finalColor
            ],
            locations: locations
        )

        let right = GradientModel(
            startPoint: CGPoint(x: 0.0, y: 0.2),
            endPoint: CGPoint(x: 1.0, y: 0.8),
            colors: [
                color,
                finalColor
            ],
            locations: locations
        )

        return GradientBannerModel(left: left, right: right)
    }
}
