import UIKit

extension UIView {
    func removeEffectIfNeeded(_ effect: UIMotionEffect?) {
        if let effect = effect {
            removeMotionEffect(effect)
        }
    }

    @discardableResult
    func addMotion(minX: CGFloat, maxX: CGFloat, minY: CGFloat, maxY: CGFloat) -> UIMotionEffectGroup {
        let xTilt = PartialInterpolatingMotionEffect.pareto(
            for: "center.x",
            type: .tiltAlongHorizontalAxis,
            minValue: minX,
            maxValue: maxX
        )

        let yTilt = PartialInterpolatingMotionEffect.pareto(
            for: "center.y",
            type: .tiltAlongVerticalAxis,
            minValue: minY,
            maxValue: maxY
        )

        let tilt = UIMotionEffectGroup()
        tilt.motionEffects = [xTilt, yTilt]

        addMotionEffect(tilt)

        return tilt
    }
}
