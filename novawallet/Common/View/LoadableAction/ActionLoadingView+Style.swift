import Foundation

extension ActionLoadingView {
    func applyPrimaryButtonEnabledStyle() {
        backgroundView.applyPrimaryButtonBackgroundStyle()
        activityIndicator.style = .medium
    }
}
