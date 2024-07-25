import UIKit
import SoraUI

final class ReferendumVoteSetupViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView(axis: .vertical, respectsSafeArea: true)
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 0, bottom: 0, right: 0)
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.alignment = .center
        return view
    }()

    let ayeButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundApprove()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundApprove()!
        button.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconThumbsUpFilled()
        return button
    }()

    let abstainButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundSecondary()!
        button.roundedBackgroundView?.cornerRadius = Constants.smallButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconAbstain()
        return button
    }()

    let nayButton: RoundedButton = {
        let button = RoundedButton()
        button.applyIconWithBackgroundStyle()
        button.roundedBackgroundView?.fillColor = R.color.colorButtonBackgroundReject()!
        button.roundedBackgroundView?.highlightedFillColor = R.color.colorButtonBackgroundReject()!
        button.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        button.imageWithTitleView?.iconImage = R.image.iconThumbsDownFilled()
        return button
    }()

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

    func showAbstain() {
        convictionHintView.isHidden = false
        showAbstainButton()
    }

    func hideAbstain() {
        convictionHintView.isHidden = true
        hideAbstainButton()
    }
}

// MARK: Private

extension ReferendumVoteSetupViewLayout {
    private func showAbstainButton() {
        guard abstainButton.isHidden else {
            return
        }

        abstainButton.isHidden = false

        nayButton.snp.remakeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(abstainButton.snp.leading).offset(-40)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        ayeButton.snp.remakeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.equalTo(abstainButton.snp.trailing).offset(40)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        abstainButton.snp.remakeConstraints { make in
            make.size.equalTo(Constants.smallButtonSize)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        nayButton.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
        ayeButton.roundedBackgroundView?.cornerRadius = Constants.bigButtonSize / 2
    }

    private func hideAbstainButton() {
        guard !abstainButton.isHidden else {
            return
        }

        abstainButton.isHidden = true

        nayButton.snp.remakeConstraints { make in
            make.height.equalTo(52)
            make.leading.equalToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(snp.centerX).offset(-8)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        ayeButton.snp.remakeConstraints { make in
            make.height.equalTo(52)
            make.leading.equalTo(snp.centerX).offset(8)
            make.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        nayButton.roundedBackgroundView?.cornerRadius = 12
        ayeButton.roundedBackgroundView?.cornerRadius = 12
    }

    private func createReuseLockButton() -> TriangularedButton {
        let button = TriangularedButton()
        button.applySecondaryDefaultStyle()
        button.contentInsets = UIEdgeInsets(top: 6, left: 12, bottom: 6, right: 12)
        button.imageWithTitleView?.titleFont = .semiBoldFootnote
        return button
    }

    private func setupLayout() {
        addSubview(abstainButton)
        abstainButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.smallButtonSize)
            make.centerX.equalToSuperview()
            make.bottom.equalTo(safeAreaLayoutGuide).inset(Constants.buttonsBottomInset)
        }

        addSubview(nayButton)
        nayButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.greaterThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.trailing.equalTo(abstainButton.snp.leading).offset(-40)
            make.centerY.equalTo(abstainButton.snp.centerY)
        }

        addSubview(ayeButton)
        ayeButton.snp.makeConstraints { make in
            make.size.equalTo(Constants.bigButtonSize)
            make.leading.equalTo(abstainButton.snp.trailing).offset(40)
            make.trailing.lessThanOrEqualToSuperview().inset(UIConstants.horizontalInset)
            make.centerY.equalTo(abstainButton.snp.centerY)
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

        containerView.stackView.addArrangedSubview(convictionHintView)

        containerView.stackView.setCustomSpacing(16, after: convictionHintView)

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

// MARK: Constants

extension ReferendumVoteSetupViewLayout {
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
