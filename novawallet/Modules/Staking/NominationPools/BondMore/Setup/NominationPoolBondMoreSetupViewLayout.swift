import UIKit

final class NominationPoolBondMoreSetupViewLayout: SCLoadableActionLayoutView {
    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    let networkFeeView = UIFactory.default.createNetworkFeeView()

    let hintListView = HintListView()

    var actionButton: TriangularedButton {
        genericActionView.actionButton
    }

    var loadingView: LoadableActionView {
        genericActionView
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
        actionButton.applyDefaultStyle()
        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(amountView, spacingAfter: 8)
        amountView.snp.makeConstraints { make in
            make.height.equalTo(34)
        }

        addArrangedSubview(amountInputView, spacingAfter: 16)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        addArrangedSubview(networkFeeView, spacingAfter: 16)
        addArrangedSubview(hintListView)
    }
}
