import UIKit

extension GradientModel {
    static var polkadotPay: GradientModel {
        GradientModel(
            startPoint: CGPoint(x: 0.0, y: 0.5),
            endPoint: CGPoint(x: 1.0, y: 0.5),
            colors: [
                UIColor(hex: "#E53B96")!,
                UIColor(hex: "#C6287C")!
            ],
            locations: [0.0, 1.0]
        )
    }
}
