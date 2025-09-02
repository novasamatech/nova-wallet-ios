import UIKit
import Foundation_iOS

final class TxExpirationMessageSheetTimerLabel: MessageSheetTimerLabel {
    private lazy var viewModelFactory = TxExpirationViewModelFactory()

    override func updateView() {
        if
            let remainedInterval = viewModel?.remainedInterval,
            let locale,
            let viewModel = try? viewModelFactory.createViewModel(from: remainedInterval) {
            bindTransaction(viewModel: viewModel, locale: locale)
        } else {
            text = ""
        }

        setNeedsLayout()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        apply(style: .footnotePrimary)
        textAlignment = .center
    }
}
