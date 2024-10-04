import UIKit

struct GradientBannerModel {
    let left: GradientModel
    let right: GradientModel
}

extension GradientBannerModel {
    static func swipeGovCell() -> GradientBannerModel {
        let color = UIColor(
            red: 59.0 / 255.0,
            green: 61.0 / 255.0,
            blue: 124.0 / 255.0,
            alpha: 1
        )

        let centerColor = UIColor(
            red: 21.0 / 255.0,
            green: 22.0 / 255.0,
            blue: 53.0 / 255.0,
            alpha: 1
        )

        let finalColor = UIColor(
            red: 21.0 / 255.0,
            green: 22.0 / 255.0,
            blue: 53.0 / 255.0,
            alpha: 0
        )

        let left = GradientModel(
            startPoint: CGPoint(x: 0.0, y: 1.0),
            endPoint: CGPoint(x: 1.0, y: 0.0),
            colors: [
                color,
                centerColor,
                finalColor
            ],
            locations: [0, 0.6, 1]
        )

        let right = GradientModel(
            startPoint: CGPoint(x: 1.0, y: 0.0),
            endPoint: CGPoint(x: 0.0, y: 1.0),
            colors: [
                color,
                centerColor,
                finalColor
            ],
            locations: [0, 0.4, 1]
        )

        return GradientBannerModel(left: left, right: right)
    }

    static func networkIntegration() -> GradientBannerModel {
        let color = UIColor(
            red: 102.0 / 255.0,
            green: 29.0 / 255.0,
            blue: 120.0 / 255.0,
            alpha: 1.0
        )

        let finalColor = UIColor(
            red: 0.0 / 255.0,
            green: 7.0 / 255.0,
            blue: 46.0 / 255.0,
            alpha: 1.0
        )

        let locations: [Float] = [0.4, 1.0]

        let left = GradientModel(
            startPoint: CGPoint(x: 1.0, y: 0.0),
            endPoint: CGPoint(x: 0.0, y: 0.0),
            colors: [
                color,
                finalColor
            ],
            locations: locations
        )

        let right = GradientModel(
            startPoint: CGPoint(x: 0.0, y: 0.0),
            endPoint: CGPoint(x: 1.0, y: 0.0),
            colors: [
                finalColor,
                color
            ],
            locations: locations
        )

        return GradientBannerModel(left: left, right: right)
    }

    static func governanceDelegations() -> GradientBannerModel {
        let color = UIColor(
            red: 35.0 / 255.0,
            green: 127.0 / 255.0,
            blue: 212.0 / 255.0,
            alpha: 0.64
        )

        return createModel(with: color)
    }

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

    static func criticalUpdate() -> GradientBannerModel {
        let color = R.color.colorGradientCriticalBanner()!
        return createModel(with: color)
    }

    static func majorUpdate() -> GradientBannerModel {
        let color = R.color.colorGradientMajorBanner()!
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
