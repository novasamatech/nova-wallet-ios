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

    func applyIconStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.highlightedFillColor = .clear
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        changesContentOpacityWhenHighlighted = true
    }

    func applySecondaryStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.color0x1D1D20()!
        roundedBackgroundView?.highlightedFillColor = R.color.color0x1D1D20()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear
        roundedBackgroundView?.cornerRadius = 10.0

        imageWithTitleView?.titleFont = .semiBoldFootnote

        contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)

        changesContentOpacityWhenHighlighted = true
    }

    func applyEnabledSecondaryStyle() {
        imageWithTitleView?.titleColor = R.color.colorWhite()!
    }

    func applyDisabledSecondaryStyle() {
        imageWithTitleView?.titleColor = R.color.colorWhite48()!
    }
}
