import UIKit

extension UIView {
    func removeEffectIfNeeded(_ effect: UIMotionEffect?) {
        if let effect = effect {
            removeMotionEffect(effect)
        }
    }
    
    func addMotion(
        minX: CGFloat,
        maxX: CGFloat,
        minY: CGFloat,
        maxY: CGFloat
    ) -> UIMotionEffectGroup {
        let xTilt = UIInterpolatingMotionEffect(
            keyPath: "center.x",
            type: .tiltAlongHorizontalAxis
        )

        xTilt.minimumRelativeValue = minX
        xTilt.maximumRelativeValue = maxX

        let yTilt = UIInterpolatingMotionEffect(
            keyPath: "center.y",
            type: .tiltAlongVerticalAxis
        )

        yTilt.minimumRelativeValue = minY
        yTilt.maximumRelativeValue = maxY

        let tilt = UIMotionEffectGroup()
        tilt.motionEffects = [xTilt, yTilt]
        
        addMotionEffect(tilt)
        
        return tilt
    }
}
