import Foundation
import SoraUI

extension TriangularedButton {
    func applyDefaultStyle() {
        imageWithTitleView?.titleFont = UIFont.h5Title
        applyEnabledStyle()
    }

    func applySecondaryDefaultStyle() {
        imageWithTitleView?.titleFont = UIFont.h5Title
        applySecondaryEnabledStyle()
    }

    func applyAccessoryStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = .clear
        triangularedView?.highlightedFillColor = .clear
        triangularedView?.strokeColor = R.color.colorDarkGray()!
        triangularedView?.highlightedStrokeColor = R.color.colorDarkGray()!
        triangularedView?.strokeWidth = 2.0

        imageWithTitleView?.titleColor = R.color.colorWhite()!
        imageWithTitleView?.titleFont = UIFont.h5Title

        changesContentOpacityWhenHighlighted = true
    }

    func applyEnabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorAccent()!
        triangularedView?.highlightedFillColor = R.color.colorAccent()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite()!

        changesContentOpacityWhenHighlighted = true
    }

    func applySecondaryEnabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorWhite16()!
        triangularedView?.highlightedFillColor = R.color.colorWhite16()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite()!

        changesContentOpacityWhenHighlighted = true
    }

    func applyDisabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorDarkGray()!
        triangularedView?.highlightedFillColor = R.color.colorDarkGray()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorStrokeGray()

        contentOpacityWhenDisabled = 1.0
    }

    func applyTranslucentDisabledStyle() {
        triangularedView?.shadowOpacity = 0.0
        triangularedView?.fillColor = R.color.colorWhite8()!
        triangularedView?.highlightedFillColor = R.color.colorWhite8()!
        triangularedView?.strokeColor = .clear
        triangularedView?.highlightedStrokeColor = .clear

        imageWithTitleView?.titleColor = R.color.colorWhite32()!

        contentOpacityWhenDisabled = 1.0
    }
}
