import Foundation
import SoraUI

extension RoundedButton {
    func applyAccessoryStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorWhite8()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorWhite8()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorAccent()!

        changesContentOpacityWhenHighlighted = true
    }

    func applyEnabledStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorDarkGray()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorDarkGray()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite()!

        changesContentOpacityWhenHighlighted = true
    }

    func applyDisabledStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorAlmostBlack()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorAlmostBlack()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorDarkGray()

        contentOpacityWhenDisabled = 1.0
    }

    func applyIconStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.highlightedFillColor = .clear
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        changesContentOpacityWhenHighlighted = true
    }
}
