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
        view.font = .boldTitle2
        view.numberOfLines = 0
    }

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    let convictionView = ReferendumConvictionView()

    var lockAmountTitleLabel: UILabel {
        lockedAmountView.titleView.detailsLabel
    }

    let lockedAmountView: TitleValueDiffView = .create { view in
        view.titleView.imageView.image = R.image.iconGovAmountLock()
    }

    var lockPeriodTitleLabel: UILabel {
        lockedPeriodView.titleView.detailsLabel
    }

    let lockedPeriodView: TitleValueDiffView = .create { view in
        view.titleView.imageView.image = R.image.iconGovPeriodLock()
    }

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
            make.trailing.equalTo(safeAreaLayoutGuide.snp.centerX).offset(-8.0)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(ayeButton)
        ayeButton.snp.makeConstraints { make in
            make.leading.equalTo(safeAreaLayoutGuide.snp.centerX).offset(8.0)
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

        containerView.stackView.setCustomSpacing(12.0, after: titleLabel)

        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.addArrangedSubview(amountInputView)

        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        containerView.stackView.setCustomSpacing(12.0, after: amountInputView)

        containerView.stackView.addArrangedSubview(convictionView)

        containerView.stackView.setCustomSpacing(16.0, after: convictionView)

        containerView.stackView.addArrangedSubview(lockedAmountView)

        containerView.stackView.setCustomSpacing(10.0, after: lockedAmountView)

        lockedAmountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        containerView.stackView.addArrangedSubview(lockedPeriodView)

        lockedPeriodView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }
    }
}
