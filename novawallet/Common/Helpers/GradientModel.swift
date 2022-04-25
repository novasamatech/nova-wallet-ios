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
}
