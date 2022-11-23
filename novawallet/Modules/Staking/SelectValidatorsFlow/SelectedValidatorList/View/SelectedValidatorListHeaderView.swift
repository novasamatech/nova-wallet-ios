import UIKit

final class SelectedValidatorListHeaderView: CustomValidatorListHeaderView {
    func bind(viewModel: TitleWithSubtitleViewModel, shouldAlert: Bool) {
        bind(viewModel: viewModel)

        let color: UIColor = shouldAlert ? R.color.colorTextNegative()! : R.color.colorWhite80()!

        titleLabel.textColor = color
    }
}
