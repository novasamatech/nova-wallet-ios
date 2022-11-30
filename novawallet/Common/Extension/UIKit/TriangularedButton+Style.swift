import Foundation
import SoraUI

extension TriangularedButton {
    func applyDefaultStyle() {
        imageWithTitleView?.titleFont = .semiBoldSubheadline
        applyEnabledStyle()
    }

    func applySecondaryDefaultStyle() {
        imageWithTitleView?.titleFont = .semiBoldSubheadline
        applySecondaryEnabledStyle()
    }

    func applyAccessoryStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = .clear
        triangularedView?.highlightedFillColor = .clear
        triangularedView?.strokeColor = R.color.colorIconSecondary()!
        triangularedView?.highlightedStrokeColor = R.color.colorIconSecondary()!
        triangularedView?.strokeWidth = 2.0

        imageWithTitleView?.titleColor = R.color.colorTextPrimary()!
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }

    func applyEnabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorButtonBackgroundPrimary()!
        triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundPrimary()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorButtonText()!

        changesContentOpacityWhenHighlighted = true
    }

    func applySecondaryEnabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorButtonText()!

        changesContentOpacityWhenHighlighted = true
    }

    func applyDisabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorButtonBackgroundInactive()!
        triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundInactive()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorButtonTextInactive()!

        contentOpacityWhenDisabled = 1.0
    }

    func applyTranslucentDisabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorButtonBackgroundInactive()!
        triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundInactive()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorButtonTextInactive()!

        contentOpacityWhenDisabled = 1.0
    }

    func applyState(title: String, enabled: Bool) {
        if enabled {
            applyEnabledStyle()
        } else {
            applyDisabledStyle()
        }

        isUserInteractionEnabled = enabled

        imageWithTitleView?.title = title
        invalidateLayout()
    }
}
