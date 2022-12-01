import Foundation

extension TriangularedView {
    func applyDisabledStyle() {
        fillColor = R.color.colorButtonBackgroundInactive()!
        strokeColor = .clear
    }

    func applyEnabledStyle() {
        fillColor = .clear
        strokeColor = R.color.colorContainerBorder()!
    }
}
