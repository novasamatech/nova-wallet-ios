import Foundation
import UIKit_iOS
import UIKit

extension TriangularedButton {
    func applyCloudBackupEnabledStyle() {
        imageWithTitleView?.titleFont = .semiBoldSubheadline
        applyEnabledStyle(
            colored: R.color.colorCloudBackupButtonBackground()!,
            textColor: R.color.colorCloudBackupButtonText()!
        )
    }

    func applyDefaultStyle() {
        imageWithTitleView?.titleFont = .semiBoldSubheadline
        applyEnabledStyle()
    }

    func applySecondaryDefaultStyle() {
        imageWithTitleView?.titleFont = .semiBoldSubheadline
        applySecondaryEnabledStyle()
    }

    func applyDestructiveDefaultStyle() {
        imageWithTitleView?.titleFont = .semiBoldSubheadline
        applyDestructiveEnabledStyle()
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

    func applyEnabledStyle(
        colored color: UIColor = R.color.colorButtonBackgroundPrimary()!,
        textColor: UIColor = R.color.colorButtonText()!
    ) {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = color
        triangularedView?.highlightedFillColor = color
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = textColor

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

    func applySecondaryEnabledAccentStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()!
        imageWithTitleView?.titleFont = .semiBoldSubheadline

        changesContentOpacityWhenHighlighted = true
    }

    func applyDestructiveEnabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorButtonBackgroundReject()!
        triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundReject()!
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
        triangularedView?.fillColor = R.color.colorButtonBackgroundInactiveOnGradient()!
        triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundInactiveOnGradient()!
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
