import UIKit_iOS
import UIKit

final class SwipeGovGradientFactory {
    private var currentIndex: Int = 0

    func createCardGradient() -> GradientModel {
        let gradientArray = [
            gradient1,
            gradient2,
            gradient3,
            gradient4,
            gradient5,
            gradient6,
            gradient7
        ]

        let gradientIndex = currentIndex % gradientArray.count

        currentIndex = (currentIndex + 1) % gradientArray.count

        return gradientArray[gradientIndex]
    }
}

private extension SwipeGovGradientFactory {
    var gradient1: GradientModel {
        GradientModel(
            startPoint: .init(x: 1.0, y: 0),
            endPoint: .init(x: 0.0, y: 1.0),
            colors: [
                UIColor(hex: "#58378E")!,
                UIColor(hex: "#3C265C")!,
                UIColor(hex: "#2C1D3A")!,
                UIColor(hex: "#3A2558")!,
                UIColor(hex: "#58378E")!
            ],
            locations: [0.0, 0.25, 0.5, 0.75, 1.0]
        )
    }

    var gradient2: GradientModel {
        GradientModel(
            startPoint: .init(x: 1.0, y: 0),
            endPoint: .init(x: 0.0, y: 1.0),
            colors: [
                UIColor(hex: "#3B3D7C")!,
                UIColor(hex: "#222350")!,
                UIColor(hex: "#1A1B3C")!,
                UIColor(hex: "#22244F")!,
                UIColor(hex: "#3B3D7C")!
            ],
            locations: [0.0, 0.25, 0.5, 0.75, 1.0]
        )
    }

    var gradient3: GradientModel {
        GradientModel(
            startPoint: .init(x: 1.0, y: 0),
            endPoint: .init(x: 0.0, y: 1.0),
            colors: [
                UIColor(hex: "#3A5D94")!,
                UIColor(hex: "#274066")!,
                UIColor(hex: "#192942")!,
                UIColor(hex: "#1D2F4C")!,
                UIColor(hex: "#3A5D94")!
            ],
            locations: [0.0, 0.25, 0.5, 0.75, 1.0]
        )
    }

    var gradient4: GradientModel {
        GradientModel(
            startPoint: .init(x: 1.0, y: 0),
            endPoint: .init(x: 0.0, y: 1.0),
            colors: [
                UIColor(hex: "#136A9B")!,
                UIColor(hex: "#0D4A6C")!,
                UIColor(hex: "#0A3146")!,
                UIColor(hex: "#09354E")!,
                UIColor(hex: "#136A9B")!
            ],
            locations: [0.0, 0.25, 0.5, 0.75, 1.0]
        )
    }

    var gradient5: GradientModel {
        GradientModel(
            startPoint: .init(x: 1.0, y: 0),
            endPoint: .init(x: 0.0, y: 1.0),
            colors: [
                UIColor(hex: "#18807A")!,
                UIColor(hex: "#0C524E")!,
                UIColor(hex: "#043B37")!,
                UIColor(hex: "#08423E")!,
                UIColor(hex: "#18807A")!
            ],
            locations: [0.0, 0.25, 0.5, 0.75, 1.0]
        )
    }

    var gradient6: GradientModel {
        GradientModel(
            startPoint: .init(x: 1.0, y: 0),
            endPoint: .init(x: 0.0, y: 1.0),
            colors: [
                UIColor(hex: "#18807A")!,
                UIColor(hex: "#126B52")!,
                UIColor(hex: "#0B4C19")!,
                UIColor(hex: "#0B5328")!,
                UIColor(hex: "#0A631B")!
            ],
            locations: [0.0, 0.25, 0.5, 0.75, 1.0]
        )
    }

    var gradient7: GradientModel {
        GradientModel(
            startPoint: .init(x: 1.0, y: 0),
            endPoint: .init(x: 0.0, y: 1.0),
            colors: [
                UIColor(hex: "#537B10")!,
                UIColor(hex: "#43640C")!,
                UIColor(hex: "#334B0A")!,
                UIColor(hex: "#2E4608")!,
                UIColor(hex: "#537B10")!
            ],
            locations: [0.0, 0.25, 0.5, 0.75, 1.0]
        )
    }
}
