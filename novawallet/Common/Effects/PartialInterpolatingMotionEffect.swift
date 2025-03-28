import UIKit

class PartialInterpolatingMotionEffect: UIMotionEffect {
    var keyPath: String
    var type: UIInterpolatingMotionEffect.EffectType
    var minimumValue: CGFloat?
    var minimumProgress: CGFloat?
    var minimumThresholdValue: CGFloat?
    var absoluteThresholdProgress: CGFloat?
    var maximumValue: CGFloat?
    var maximumProgress: CGFloat?
    var maximumThresholdValue: CGFloat?

    init(keyPath: String, type: UIInterpolatingMotionEffect.EffectType) {
        self.keyPath = keyPath
        self.type = type

        super.init()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func interpolateValue(
        progress: CGFloat,
        minProgress: CGFloat,
        maxProgress: CGFloat,
        minValue: CGFloat,
        maxValue: CGFloat
    ) -> CGFloat {
        let progressDiff = maxProgress - minProgress

        guard abs(progressDiff) > CGFloat.leastNonzeroMagnitude else {
            return maxValue
        }

        let tangent = (maxValue - minValue) / progressDiff
        let offset = maxValue - tangent * maxProgress

        return tangent * progress + offset
    }

    private func keyPathsAndRelativeValues(forProgress progress: CGFloat) -> Any? {
        guard let minimumValue = minimumValue, let maximumValue = maximumValue else {
            return nil
        }

        // stop moving if we reached maximum allowed rotation

        if let maximumProgress = maximumProgress, progress >= maximumProgress {
            Logger.shared.info("Maximum: \(maximumProgress)")
            return maximumValue
        }

        // stop moving if we reached minimum allowed rotation

        if let minimumProgress = minimumProgress, progress <= minimumProgress {
            Logger.shared.info("Maximum: \(minimumProgress)")
            return minimumValue
        }

        let thresholdProgress = absoluteThresholdProgress ?? 1

        let minThresholdValue = max(minimumThresholdValue ?? minimumValue, minimumValue)

        // apply separate interpolation function after min threshold rotation

        if progress < -thresholdProgress {
            let value = interpolateValue(
                progress: progress,
                minProgress: -1,
                maxProgress: -thresholdProgress,
                minValue: minimumValue,
                maxValue: minThresholdValue
            )

            Logger.shared.info("Before threshold: \(progress)")

            return value
        }

        // apply separate interpolation function after max threshold rotation

        let maxThresholdValue = min(maximumThresholdValue ?? maximumValue, maximumValue)

        if progress > thresholdProgress {
            let value = interpolateValue(
                progress: progress,
                minProgress: thresholdProgress,
                maxProgress: 1,
                minValue: maxThresholdValue,
                maxValue: maximumValue
            )

            Logger.shared.info("After threshold: \(progress)")

            return value
        }

        let value = interpolateValue(
            progress: progress,
            minProgress: -thresholdProgress,
            maxProgress: thresholdProgress,
            minValue: minThresholdValue,
            maxValue: maxThresholdValue
        )

        Logger.shared.info("Inside threshold: \(progress)")

        return value
    }

    override func keyPathsAndRelativeValues(forViewerOffset viewerOffset: UIOffset) -> [String: Any]? {
        Logger.shared.info("Motion offset: \(viewerOffset)")

        switch type {
        case .tiltAlongHorizontalAxis:
            if let result = keyPathsAndRelativeValues(forProgress: viewerOffset.horizontal) {
                return [keyPath: result]
            } else {
                return [:]
            }
        case .tiltAlongVerticalAxis:
            if let result = keyPathsAndRelativeValues(forProgress: viewerOffset.vertical) {
                return [keyPath: result]
            } else {
                return [:]
            }
        @unknown default:
            return [:]
        }
    }
}

extension PartialInterpolatingMotionEffect {
    static func pareto(
        for keyPath: String,
        type: UIInterpolatingMotionEffect.EffectType,
        minValue: CGFloat,
        maxValue: CGFloat
    ) -> PartialInterpolatingMotionEffect {
        let thresholdAngle = CGFloat.pi / 8
        let clampingAngle: CGFloat = 4 * CGFloat.pi / 10

        let effect = PartialInterpolatingMotionEffect(keyPath: keyPath, type: type)
        effect.minimumValue = minValue
        effect.maximumValue = maxValue

        let maxAngle = CGFloat.pi / 2

        let clampingProgress = min(clampingAngle, maxAngle) / maxAngle
        effect.minimumProgress = -clampingProgress
        effect.maximumProgress = clampingProgress

        let thresholdProgress = min(thresholdAngle, maxAngle) / maxAngle
        effect.absoluteThresholdProgress = thresholdProgress

        let whenZeroValue = (minValue + maxValue) / 2

        let thresholdPercent = 0.7
        let thresholdValue = (maxValue - whenZeroValue) * thresholdPercent
        effect.minimumThresholdValue = whenZeroValue - thresholdValue
        effect.maximumThresholdValue = whenZeroValue + thresholdValue

        return effect
    }
}
