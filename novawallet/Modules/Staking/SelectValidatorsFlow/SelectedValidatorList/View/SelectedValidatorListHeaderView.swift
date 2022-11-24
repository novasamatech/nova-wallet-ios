import UIKit

final class SelectedValidatorListHeaderView: CustomValidatorListHeaderView {
    func bind(viewModel: TitleWithSubtitleViewModel, shouldAlert: Bool) {
        bind(viewModel: viewModel)

        let color: UIColor = shouldAlert ? R.color.colorTextNegative()! : R.color.colorTextSecondary()!

        titleLabel.textColor = color
    }
}
