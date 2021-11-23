import Foundation
import SoraUI

extension GradientButton {
    func applyDefaultStyle() {
        imageWithTitleView?.titleFont = .h6Title
        applyEnabledStyle()
    }

    // FIXME: Replace gradient buttons with rounded buttons with own styles
    func applyEnabledStyle() {
        gradientBackgroundView?.startColor = R.color.colorAccentGradientEnd()!
        gradientBackgroundView?.endColor = R.color.colorAccentGradientEnd()!
        gradientBackgroundView?.startPoint = CGPoint(x: 0.0, y: 0.5)
        gradientBackgroundView?.endPoint = CGPoint(x: 1.0, y: 0.5)

        imageWithTitleView?.titleColor = R.color.colorWhite()

        changesContentOpacityWhenHighlighted = true
    }

    func applyDisabledStyle() {
        gradientBackgroundView?.startColor = R.color.colorGradientDisabled()!
        gradientBackgroundView?.endColor = R.color.colorGradientDisabled()!

        imageWithTitleView?.titleColor = R.color.colorDarkGray()

        contentOpacityWhenDisabled = 1.0
    }
}
