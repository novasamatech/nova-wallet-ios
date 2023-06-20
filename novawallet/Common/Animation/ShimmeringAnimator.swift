import Foundation
import CoreFoundation
import UIKit

protocol ShimmeringAnimatorProtocol {
    func startAnimation(on layer: CAGradientLayer)
    func stopAnimation(on layer: CAGradientLayer)
}

final class ShimmeringAnimator: ShimmeringAnimatorProtocol {
    let duration: TimeInterval
    let timingFunction: CAMediaTimingFunction

    let animationKey = "location.animation.\(UUID().uuidString)"

    init(
        duration: TimeInterval = 0.25,
        timingFunction: CAMediaTimingFunction = CAMediaTimingFunction(name: .linear)
    ) {
        self.duration = duration
        self.timingFunction = timingFunction
    }

    func startAnimation(on layer: CAGradientLayer) {
        let layerWidth = layer.frame.width

        let animation = CABasicAnimation(keyPath: "transform.translation.x")
        animation.fromValue = -layerWidth
        animation.toValue = layerWidth
        animation.duration = duration
        animation.timingFunction = timingFunction
        animation.repeatCount = Float.infinity

        layer.add(animation, forKey: animationKey)
    }

    func stopAnimation(on layer: CAGradientLayer) {
        layer.removeAnimation(forKey: animationKey)
    }
}
