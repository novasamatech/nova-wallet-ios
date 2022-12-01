import UIKit

final class ReferendumVoteSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0, bottom: 0, right: 0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .center
        return view
    }()

    let ayeButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.triangularedView?.fillColor = R.color.colorButtonBackgroundApprove()!
        button.triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundApprove()!
        return button
    }()

    let nayButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        button.triangularedView?.fillColor = R.color.colorButtonBackgroundReject()!
        button.triangularedView?.highlightedFillColor = R.color.colorButtonBackgroundReject()!
        return button
    }()

    let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle2
        view.numberOfLines = 0
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

    var lockPeriodTitleLabel: UILabel {
        lockedPeriodView.titleView.detailsLabel
    }

    let lockedPeriodView: TitleValueDiffView = .create { view in
        view.applyDefaultStyle()
        view.titleView.imageView.image = R.image.iconGovPeriodLock()
    }

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
            govLocksReuseButton?.imageWithTitleView?.title = R.string.localizable.govReuseGovernanceLocks(
                governance,
                preferredLanguages: locale.rLanguages
            )

            govLocksReuseButton?.invalidateLayout()
        }

        if let all = viewModel.all {
            allLocksReuseButton?.imageWithTitleView?.title = R.string.localizable.govReuseAllLocks(
                all,
                preferredLanguages: locale.rLanguages
            )

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

        containerView.stackView.addArrangedSubview(lockReuseContainerView)
        lockReuseContainerView.snp.makeConstraints { make in
            make.height.equalTo(32.0)
            make.width.equalTo(self)
        }

        containerView.stackView.setCustomSpacing(16.0, after: lockReuseContainerView)

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
