import Foundation

extension ActionLoadingView {
    func applyPrimaryButtonEnabledStyle() {
        backgroundView.applyPrimaryButtonBackgroundStyle()
        activityIndicator.style = .medium
    }

    func applyDisableButtonStyle() {
        backgroundView.applyDisabledBackgroundStyle()
        activityIndicator.style = .medium
    }
}
