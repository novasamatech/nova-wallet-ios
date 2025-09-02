import Foundation
import UIKit_iOS

extension RoundedButton {
    func applyAccessoryCaps2Style() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = .clear
        roundedBackgroundView?.highlightedFillColor = .clear
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()!
        imageWithTitleView?.titleFont = .semiBoldCaps2

        imageWithTitleView?.spacingBetweenLabelAndIcon = 4

        changesContentOpacityWhenHighlighted = true
    }

    func applyAccessoryStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorButtonTextAccent()!
        imageWithTitleView?.titleFont = .semiBoldFootnote

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

    func applyIconWithBackgroundStyle() {
        roundedBackgroundView?.shadowOpacity = 0
        roundedBackgroundView?.fillColor = R.color.colorBlockBackground()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorBlockBackground()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear
        roundedBackgroundView?.cornerRadius = 12
        changesContentOpacityWhenHighlighted = true
    }

    func applySecondaryStyle() {
        roundedBackgroundView?.shadowOpacity = 0.0
        roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        roundedBackgroundView?.strokeColor = .clear
        roundedBackgroundView?.highlightedStrokeColor = .clear
        roundedBackgroundView?.cornerRadius = 10.0

        imageWithTitleView?.titleFont = .semiBoldFootnote

        contentInsets = UIEdgeInsets(top: 8.0, left: 12.0, bottom: 8.0, right: 12.0)

        changesContentOpacityWhenHighlighted = true
        opacityAnimationDuration = 0
    }

    func applyEnabledSecondaryStyle() {
        imageWithTitleView?.titleColor = R.color.colorButtonText()!
    }

    func applyDisabledSecondaryStyle() {
        imageWithTitleView?.titleColor = R.color.colorButtonTextInactive()!
    }

    func applyTextStyle() {
        applyIconStyle()

        let color = R.color.colorButtonTextAccent()!
        imageWithTitleView?.titleColor = color
        imageWithTitleView?.titleFont = .semiBoldFootnote

        imageWithTitleView?.spacingBetweenLabelAndIcon = 0
    }

    func applyLinkStyle() {
        applyIconStyle()

        let color = R.color.colorButtonTextAccent()!
        imageWithTitleView?.titleColor = color
        imageWithTitleView?.titleFont = .regularFootnote

        imageWithTitleView?.iconImage = R.image.iconLinkChevron()?.tinted(with: color)
        imageWithTitleView?.layoutType = .horizontalLabelFirst
        contentInsets = .zero

        imageWithTitleView?.spacingBetweenLabelAndIcon = 4.0
    }
}
