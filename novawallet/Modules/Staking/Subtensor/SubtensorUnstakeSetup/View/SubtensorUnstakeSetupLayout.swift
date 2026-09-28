import UIKit

final class SubtensorUnstakeSetupLayout: CollatorStkBaseUnstakeSetupLayout {
    let quoteTableView: StackTableView = {
        let view = StackTableView()
        view.cellHeight = 44.0
        view.contentInsets = UIEdgeInsets(top: 4.0, left: 16.0, bottom: 4.0, right: 16.0)
        return view
    }()

    let receiveCell = StackTableCell()

    let poolFeeCell = StackTableCell()

    let priceImpactCell = StackTableCell()

    let slippageCell = StackTableCell()

    override func setupLayout() {
        super.setupLayout()

        quoteTableView.addArrangedSubview(receiveCell)
        quoteTableView.addArrangedSubview(poolFeeCell)
        quoteTableView.addArrangedSubview(priceImpactCell)
        quoteTableView.addArrangedSubview(slippageCell)

        let stackView = containerView.stackView

        stackView.removeArrangedSubview(amountView)
        stackView.insertArrangedSubview(amountView, at: 0)
        stackView.removeArrangedSubview(amountInputView)
        stackView.insertArrangedSubview(amountInputView, at: 1)
        stackView.setCustomSpacing(16.0, after: amountInputView)

        if let feeIndex = stackView.arrangedSubviews.firstIndex(of: networkFeeView) {
            stackView.insertArrangedSubview(quoteTableView, at: feeIndex)
        } else {
            stackView.addArrangedSubview(quoteTableView)
        }

        stackView.setCustomSpacing(8.0, after: quoteTableView)
    }
}
