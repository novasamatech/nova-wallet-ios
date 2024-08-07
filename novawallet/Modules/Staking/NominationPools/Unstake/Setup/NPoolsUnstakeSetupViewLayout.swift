import UIKit

final class NPoolsUnstakeSetupViewLayout: SCLoadableActionLayoutView {
    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    let transferableView = TitleAmountView.dark()

    let networkFeeView = UIFactory.default.createNetworkFeeView()

    let hintListView = HintListView()

    var actionButton: TriangularedButton {
        genericActionView.actionButton
    }

    var loadingView: LoadableActionView {
        genericActionView
    }

    override func setupStyle() {
        super.setupStyle()

        actionButton.applyDefaultStyle()
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(amountView, spacingAfter: 8)
        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        addArrangedSubview(amountInputView, spacingAfter: 16)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        addArrangedSubview(transferableView)
        addArrangedSubview(networkFeeView, spacingAfter: 16)
        addArrangedSubview(hintListView)
    }
}
