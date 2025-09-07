import UIKit
import UIKit_iOS

class BaseReferendumVoteSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0, bottom: 0, right: 0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .center
        return view
    }()

    let buttonContainer: UIView = .create { view in
        view.backgroundColor = .clear
    }

    let convictionHintView: BorderedIconLabelView = .create { view in
        view.iconDetailsView.spacing = Constants.convictionHintContentSpacing
        view.iconDetailsView.imageView.image = R.image.iconInfoAccent()
        view.iconDetailsView.detailsLabel.apply(style: .caption1Primary)

        view.backgroundView.cornerRadius = Constants.convictionHintCornerRadius
        view.backgroundView.fillColor = R.color.colorIndividualChipBackground()!
        view.contentInsets = Constants.convictionHintContentInsets
    }

    let titleLabel: UILabel = .create { view in
        view.textColor = R.color.colorTextPrimary()
        view.font = .boldTitle3
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
            govLocksReuseButton?.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.govReuseGovernanceLocks(governance)

            govLocksReuseButton?.invalidateLayout()
        }

        if let all = viewModel.all {
            allLocksReuseButton?.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.govReuseAllLocks(all)

            allLocksReuseButton?.invalidateLayout()
        }

        lockReuseContainerView.isHidden = !viewModel.hasLocks

        lockReuseContainerView.setNeedsLayout()
    }

    func setupButtonsLayout() {
        fatalError("Must be overriden by subsclass")
    }

    func setupLayout() {
        addSubview(buttonContainer)
        buttonContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide.snp.bottom)
        }

        setupButtonsLayout()

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(buttonContainer.snp.top).offset(-8.0)
        }

        containerView.stackView.addArrangedSubview(titleLabel)

        setupAmountViewsLayout()

        setupLockReuseContainerLayout()

        containerView.stackView.setCustomSpacing(12.0, after: amountInputView)

        containerView.stackView.addArrangedSubview(convictionView)
        containerView.stackView.setCustomSpacing(16.0, after: convictionView)

        containerView.stackView.addArrangedSubview(convictionHintView)
        containerView.stackView.setCustomSpacing(16, after: convictionHintView)

        setupLockedViewsLayout()

        setupContentWidth()
    }

    func setupContentWidth() {
        containerView.stackView.arrangedSubviews
            .filter { $0 !== lockReuseContainerView }
            .forEach {
                $0.snp.makeConstraints { make in
                    make.width.equalTo(self).offset(-2 * UIConstants.horizontalInset)
                }
            }
    }
}

// MARK: Private

private extension BaseReferendumVoteSetupViewLayout {
    func createReuseLockButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.imageWithTitleView?.titleFont = .semiBoldFootnote
        return button
    }

    func setupAmountViewsLayout() {
        containerView.stackView.addArrangedSubview(amountView)
        containerView.stackView.addArrangedSubview(amountInputView)

        amountView.snp.makeConstraints { make in
            make.height.equalTo(34.0)
        }

        amountInputView.snp.makeConstraints { make in
            make.height.equalTo(64)
        }
    }

    func setupLockedViewsLayout() {
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

    func setupLockReuseContainerLayout() {
        containerView.stackView.addArrangedSubview(lockReuseContainerView)

        lockReuseContainerView.snp.makeConstraints { make in
            make.height.equalTo(32.0)
            make.width.equalTo(self)
        }

        containerView.stackView.setCustomSpacing(16.0, after: lockReuseContainerView)
    }
}

// MARK: Constants

extension BaseReferendumVoteSetupViewLayout {
    enum Constants {
        static let bigButtonSize: CGFloat = 64
        static let smallButtonSize: CGFloat = 56
        static let buttonsBottomInset: CGFloat = 20
        static let convictionHintContentSpacing: CGFloat = 12
        static let convictionHintCornerRadius: CGFloat = 10
        static let convictionHintContentInsets = UIEdgeInsets(
            top: 10,
            left: 12,
            bottom: 10,
            right: 12
        )
    }
}
