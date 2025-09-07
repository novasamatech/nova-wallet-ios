import UIKit

final class GovernanceDelegateSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 12.0, left: 0, bottom: 0, right: 0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .center
        return view
    }()

    let proceedButton: TriangularedButton = .create {
        $0.applyDefaultStyle()
    }

    let amountView = TitleHorizontalMultiValueView()

    let amountInputView = NewAmountInputView()

    private(set) var govLocksReuseButton: TriangularedButton?
    private(set) var allLocksReuseButton: TriangularedButton?

    let lockReuseContainerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .horizontal)
        view.stackView.layoutMargins = UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 16)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .fill
        view.stackView.spacing = 8.0
        view.scrollView.showsHorizontalScrollIndicator = false
        return view
    }()

    let convictionView = ReferendumConvictionView()

    var lockAmountTitleLabel: UILabel {
        lockedAmountView.titleView.detailsLabel
    }

    let lockedAmountView: TitleValueDiffView = .create { view in
        view.applyDefaultStyle()
        view.titleView.imageView.image = R.image.iconGovAmountLock()
    }

    var undelegatingPeriodTitleLabel: UILabel {
        undelegatingPeriodView.titleLabel
    }

    let undelegatingPeriodView: IconTitleValueView = .create {
        $0.borderView.borderType = .none
        $0.imageView.image = R.image.iconGovPeriodLock()
    }

    let hintView = HintListView()

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindReuseLocks(viewModel: ReferendumLockReuseViewModel, locale: Locale) {
        if viewModel.governance != nil, govLocksReuseButton == nil {
            let button = createReuseLockButton()
            lockReuseContainerView.stackView.insertArrangedSubview(button, at: 0)

            govLocksReuseButton = button
        } else if viewModel.governance == nil, govLocksReuseButton != nil {
            govLocksReuseButton?.removeFromSuperview()
            govLocksReuseButton = nil
        }

        if viewModel.all != nil, allLocksReuseButton == nil {
            let button = createReuseLockButton()
            lockReuseContainerView.stackView.addArrangedSubview(button)

            allLocksReuseButton = button
        } else if viewModel.all == nil, allLocksReuseButton != nil {
            allLocksReuseButton?.removeFromSuperview()
            allLocksReuseButton = nil
        }

        if let governance = viewModel.governance {
            govLocksReuseButton?.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages
            ).localizable.govReuseGovernanceLocks(governance)

            govLocksReuseButton?.invalidateLayout()
        }

        if let all = viewModel.all {
            allLocksReuseButton?.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages
            ).localizable.govReuseAllLocks(all)

            allLocksReuseButton?.invalidateLayout()
        }

        lockReuseContainerView.isHidden = !viewModel.hasLocks

        lockReuseContainerView.setNeedsLayout()
    }

    private func createReuseLockButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.imageWithTitleView?.titleFont = .semiBoldFootnote
        return button
    }

    private func setupLayout() {
        addSubview(proceedButton)
        proceedButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(proceedButton.snp.top).offset(-8)
        }

        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.addArrangedSubview(amountInputView)

        amountView.snp.makeConstraints { make in
            make.height.equalTo(34)
        }

        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }

        containerView.stackView.addArrangedSubview(lockReuseContainerView)
        lockReuseContainerView.snp.makeConstraints { make in
            make.height.equalTo(32)
            make.width.equalTo(self)
        }

        containerView.stackView.setCustomSpacing(16, after: lockReuseContainerView)

        containerView.stackView.setCustomSpacing(12, after: amountInputView)

        containerView.stackView.addArrangedSubview(convictionView)

        containerView.stackView.setCustomSpacing(16, after: convictionView)

        containerView.stackView.addArrangedSubview(lockedAmountView)

        lockedAmountView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }

        containerView.stackView.addArrangedSubview(undelegatingPeriodView)

        undelegatingPeriodView.snp.makeConstraints { make in
            make.height.equalTo(44)
        }

        containerView.stackView.setCustomSpacing(16, after: undelegatingPeriodView)

        containerView.stackView.addArrangedSubview(hintView)

        setupContentWidth()
    }

    private func setupContentWidth() {
        containerView.stackView.arrangedSubviews
            .filter { $0 !== lockReuseContainerView }
            .forEach {
                $0.snp.makeConstraints { make in
                    make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
                }
            }
    }
}
