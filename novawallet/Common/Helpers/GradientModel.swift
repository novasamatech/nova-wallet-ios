import Foundation
import UIKit

struct GradientModel: Equatable {
    let startPoint: CGPoint
    let endPoint: CGPoint
    let colors: [UIColor]
    let locations: [Float]?

    init(startPoint: CGPoint, endPoint: CGPoint, colors: [UIColor], locations: [Float]?) {
        self.startPoint = startPoint
        self.endPoint = endPoint
        self.colors = colors
        self.locations = locations
    }

    init(angle: Int, colors: [UIColor], locations: [Float]?) {
        self.colors = colors
        self.locations = locations

        switch angle.quantized(by: 45) {
        case 0:
            startPoint = CGPoint(x: 0.0, y: 0.5)
            endPoint = CGPoint(x: 1.0, y: 0.5)
        case 45:
            startPoint = CGPoint(x: 0.0, y: 1.0)
            endPoint = CGPoint(x: 1.0, y: 0.0)
        case 90:
            startPoint = CGPoint(x: 0.5, y: 1.0)
            endPoint = CGPoint(x: 0.5, y: 0.0)
        case 135:
            startPoint = CGPoint(x: 1.0, y: 1.0)
            endPoint = CGPoint(x: 0.0, y: 0.0)
        case 180:
            startPoint = CGPoint(x: 1.0, y: 0.5)
            endPoint = CGPoint(x: 0.0, y: 0.5)
        case 225:
            startPoint = CGPoint(x: 1.0, y: 0.0)
            endPoint = CGPoint(x: 0.0, y: 1.0)
        case 270:
            startPoint = CGPoint(x: 0.5, y: 0.0)
            endPoint = CGPoint(x: 0.5, y: 1.0)
        case 315:
            startPoint = CGPoint(x: 0.0, y: 0.0)
            endPoint = CGPoint(x: 1.0, y: 1.0)
        default:
            startPoint = CGPoint(x: 0.0, y: 0.5)
            endPoint = CGPoint(x: 1.0, y: 0.5)
        }
    }
}

extension GradientModel {
    static var defaultGradient: GradientModel {
        GradientModel(
            startPoint: CGPoint(x: 1.0, y: 1.0),
            endPoint: CGPoint(x: 0.0, y: 0.0),
            colors: [
                UIColor(hex: "#434852")!,
                UIColor(hex: "#787F92")!
            ],
            locations: [0.0, 1.0]
        )
    }

    static var tinderGovBackgroundGradient: GradientModel {
        GradientModel(
            startPoint: .init(x: 0.5, y: 0),
            endPoint: .init(x: 0.5, y: 1),
            colors: [
                .init(
                    red: 83.0 / 255.0,
                    green: 96.0 / 255.0,
                    blue: 161.0 / 255.0,
                    alpha: 1.0
                ),
                .init(
                    red: 8.0 / 255.0,
                    green: 9.0 / 255.0,
                    blue: 14.0 / 255.0,
                    alpha: 1.0
                )
            ],
            locations: [0.0, 0.25, 0.35, 1.0]
        )
    }
}
