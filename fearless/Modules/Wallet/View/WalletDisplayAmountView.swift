import UIKit
import SoraUI
import CommonWallet
import SoraFoundation

final class WalletDisplayAmountView: WalletBaseAmountView {
    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: 72.0)
    }

    var viewModel: RichAmountDisplayViewModelProtocol?
}

extension WalletDisplayAmountView: WalletFormBordering {
    var borderType: BorderType {
        get {
            borderView.borderType
        }
        set(newValue) {
            borderView.borderType = newValue
        }
    }

    func bind(viewModel: RichAmountDisplayViewModel) {
        self.viewModel?.iconViewModel?.cancel(on: amountInputView.iconView)
        amountInputView.iconView.image = nil

        self.viewModel = viewModel

        amountInputView.title = viewModel.title
        amountInputView.textField.text = viewModel.amount
        amountInputView.isUserInteractionEnabled = false

        amountInputView.triangularedBackgroundView?.applyDisabledStyle()

        amountInputView.symbol = viewModel.symbol
        viewModel.iconViewModel?.loadAmountInputIcon(on: amountInputView.iconView, animated: true)

        amountInputView.priceText = viewModel.price
        amountInputView.balanceText = viewModel.balance
    }
}
