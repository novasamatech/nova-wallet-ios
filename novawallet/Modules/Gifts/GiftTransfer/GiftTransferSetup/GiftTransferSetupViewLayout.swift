import Foundation

final class GiftTransferSetupViewLayout: SCSingleActionLayoutView {
    let networkContainerView = GiftSetupNetworkContainerView()

    let feeView: NetworkFeeInfoView = .create { view in
        view.hideInfoIcon()
    }

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func setupLayout() {
        super.setupLayout()

        addArrangedSubview(networkContainerView, spacingAfter: 16.0)
        addArrangedSubview(amountView)
        addArrangedSubview(amountInputView, spacingAfter: 16.0)
        addArrangedSubview(feeView)

        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
    }
}
