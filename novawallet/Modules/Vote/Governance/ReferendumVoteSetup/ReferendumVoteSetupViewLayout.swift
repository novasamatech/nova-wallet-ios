import UIKit

final class ReferendumVoteSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        return view
    }()

    let ayeButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.triangularedView?.fillColor = R.color.colorGreen()!
        return button
    }()

    let nayButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.triangularedView?.fillColor = R.color.colorRed()!
        return button
    }()

    let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorWhite()
        view.font = .regularSubheadline
        view.numberOfLines = 0
    }

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    let lockedAmountView = ReferendumVoteSetupViewLayout.createMultiValueView()

    let lockedPeriodView = ReferendumVoteSetupViewLayout.createMultiValueView()

    let feeView: NetworkFeeView = {
        let view = UIFactory.default.createNetwork26FeeView()
        view.verticalOffset = 13.0
        return view
    }()

    let hintListView = HintListView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupLayout() {
        addSubview(nayButton)
        nayButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(safeAreaLayoutGuide.snp.centerX).inset(8.0)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(ayeButton)
        ayeButton.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide.snp.centerX).inset(8.0)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(ayeButton.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)
        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.addArrangedSubview(amountInputView)

        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        containerView.stackView.setCustomSpacing(16.0, after: amountInputView)

        containerView.stackView.addArrangedSubview(lockedAmountView)
        containerView.stackView.addArrangedSubview(lockedPeriodView)
        containerView.stackView.addArrangedSubview(feeView)
        containerView.stackView.addArrangedSubview(hintListView)
    }

    static func createMultiValueView(
    ) -> GenericTitleValueView<UILabel, GenericMultiValueView<IconDetailsView>> {
        let view = GenericTitleValueView<UILabel, GenericMultiValueView<IconDetailsView>>()
        view.titleView.textColor = R.color.colorWhite()
        view.titleView.font = .regularSubheadline
        view.valueView.valueTop.textColor = R.color.colorTransparentText()
        view.valueView.valueTop.font = .regularFootnote
        view.valueView.valueBottom.detailsLabel.textColor = R.color.colorNovaBlue()
        view.valueView.valueBottom.detailsLabel.font = .regularFootnote

        return view
    }
}
