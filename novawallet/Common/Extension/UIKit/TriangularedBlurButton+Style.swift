import Foundation

extension TriangularedBlurButton {
    func applyEnabledStyle() {
        imageWithTitleView?.titleColor = R.color.colorButtonText()!

        isUserInteractionEnabled = true
    }

    func applyDisabledStyle() {
        imageWithTitleView?.titleColor = R.color.colorButtonTextInactive()!

        isUserInteractionEnabled = false
    }
}
