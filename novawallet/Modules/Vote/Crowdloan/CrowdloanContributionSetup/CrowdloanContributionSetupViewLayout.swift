import UIKit

class CrowdloanContributionSetupViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 24.0, left: 0.0, bottom: 0.0, right: 0.0)
        return view
    }()

    let contributionTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()!
        label.font = .h4Title
        return label
    }()

    let amountInputView = UIFactory.default.createAmountInputView(filled: false)

    let hintView = UIFactory.default.createHintView()

    let rewardDestinationTitleLabel: UILabel = {
        let label = UILabel()
        label.textColor = R.color.colorWhite()!
        label.font = .h4Title
        return label
    }()

    private(set) var rewardDestinationAccountView: CrowdloanRewardDestinationView?

    let networkFeeView = NetworkFeeView()

    private(set) var estimatedRewardView: TitleValueView?

    private(set) var bonusView: RowView<TitleValueSelectionView>?

    private var assetViewModel: AssetBalanceViewModelProtocol?

    let leasingPeriodView = TitleMultiValueView()

    private(set) var learnMoreView: LearnMoreView?

    let actionButton: TriangularedButton = {
        let button = TriangularedButton()
        button.applyDefaultStyle()
        return button
    }()

    var locale = Locale.current {
        didSet {
            if locale != oldValue {
                applyLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorBlack()

        setupLayout()
        applyLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(assetViewModel: AssetBalanceViewModelProtocol) {
        self.assetViewModel?.iconViewModel?.cancel(on: amountInputView.iconView)
        amountInputView.iconView.image = nil

        self.assetViewModel = assetViewModel

        amountInputView.priceText = assetViewModel.price

        if let balance = assetViewModel.balance {
            amountInputView.balanceText = R.string.localizable.commonAvailableFormat(
                balance,
                preferredLanguages: locale.rLanguages
            )
        } else {
            amountInputView.balanceText = nil
        }

        let symbol = assetViewModel.symbol.uppercased()
        amountInputView.symbol = symbol

        assetViewModel.iconViewModel?.loadAmountInputIcon(on: amountInputView.iconView, animated: true)

        hintView.titleLabel.text = R.string.localizable.crowdloanUnlockHint(
            symbol,
            preferredLanguages: locale.rLanguages
        )
    }

    func bind(rewardDestination viewModel: CrowdloanRewardDestinationVM) {
        createRewardDestinationViewIfNeeded()
        rewardDestinationAccountView?.bind(viewModel: viewModel)
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeView.bind(viewModel: feeViewModel)
    }

    func bind(crowdloanViewModel: CrowdloanContributionSetupViewModel) {
        leasingPeriodView.valueTop.text = crowdloanViewModel.leasingPeriod
        leasingPeriodView.valueBottom.text = crowdloanViewModel.leasingCompletionDate

        if let learnMore = crowdloanViewModel.learnMore {
            createLearnMoreViewIfNeeded()
            learnMoreView?.bind(viewModel: learnMore)
        } else {
            removeLearnMoreViewIfNeeded()
        }
    }

    func bind(estimatedReward: String?) {
        if let estimatedReward = estimatedReward {
            createEstimatedRewardViewIfNeeded()
            estimatedRewardView?.valueLabel.text = estimatedReward
        } else {
            removeEstimatedRewardViewIfNeeded()
        }
    }

    func bind(bonus: String?) {
        if let bonus = bonus {
            createBonusViewIfNeeded()
            bonusView?.rowContentView.detailsLabel.text = bonus
        } else {
            removeBonusViewIfNeeded()
        }
    }

    func applyLocalization() {
        contributionTitleLabel.text = R.string.localizable.crowdloanContributeTitle(
            preferredLanguages: locale.rLanguages
        )

        networkFeeView.locale = locale
        leasingPeriodView.titleLabel.text = R.string.localizable.crowdloanLeasingPeriod(
            preferredLanguages: locale.rLanguages
        )

        amountInputView.title = R.string.localizable
            .walletSendAmountTitle(preferredLanguages: locale.rLanguages)

        actionButton.imageWithTitleView?.title = R.string.localizable
            .commonContinue(preferredLanguages: locale.rLanguages)

        estimatedRewardView?.titleLabel.text = R.string.localizable.crowdloanReward(
            preferredLanguages: locale.rLanguages
        )

        bonusView?.rowContentView.titleLabel.text = R.string.localizable.commonBonus(
            preferredLanguages: locale.rLanguages
        )
    }

    func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }

        contentView.stackView.addArrangedSubview(contributionTitleLabel)
        contributionTitleLabel.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: contributionTitleLabel)

        contentView.stackView.addArrangedSubview(amountInputView)
        amountInputView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(72.0)
        }

        contentView.stackView.setCustomSpacing(16.0, after: amountInputView)

        contentView.stackView.addArrangedSubview(hintView)
        hintView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        contentView.stackView.setCustomSpacing(16.0, after: hintView)

        contentView.stackView.addArrangedSubview(networkFeeView)
        networkFeeView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        contentView.stackView.addArrangedSubview(leasingPeriodView)
        leasingPeriodView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        let spacingView = UIView()
        contentView.stackView.addArrangedSubview(spacingView)
        spacingView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(24)
        }

        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        contentView.scrollBottomOffset = 100
    }

    private func createEstimatedRewardViewIfNeeded() {
        guard estimatedRewardView == nil else {
            return
        }

        guard
            let leasingPeriodIndex = contentView.stackView.arrangedSubviews.firstIndex(of: leasingPeriodView) else {
            return
        }

        let view = TitleValueView()
        view.titleLabel.text = R.string.localizable.crowdloanReward(preferredLanguages: locale.rLanguages)

        contentView.stackView.insertArrangedSubview(view, at: leasingPeriodIndex + 1)
        view.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
            make.height.equalTo(48.0)
        }

        estimatedRewardView = view
    }

    private func createRewardDestinationViewIfNeeded() {
        guard rewardDestinationAccountView == nil else {
            return
        }

        guard
            let hindIndex = contentView.stackView.arrangedSubviews.firstIndex(of: hintView) else {
            return
        }
        let view = CrowdloanRewardDestinationView()

        contentView.stackView.insertArrangedSubview(view, at: hindIndex + 1)
        view.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        rewardDestinationAccountView = view
    }

    private func removeEstimatedRewardViewIfNeeded() {
        guard let estimatedRewardView = estimatedRewardView else {
            return
        }

        contentView.stackView.removeArrangedSubview(estimatedRewardView)
        estimatedRewardView.removeFromSuperview()

        self.estimatedRewardView = nil
    }

    private func createBonusViewIfNeeded() {
        guard bonusView == nil else {
            return
        }

        let maybeLastViewIndex: Int? = {
            if let estimatedRewardView = estimatedRewardView {
                return contentView.stackView.arrangedSubviews.firstIndex(
                    of: estimatedRewardView
                )
            }

            return contentView.stackView.arrangedSubviews.firstIndex(of: leasingPeriodView)
        }()

        guard
            let lastIndex = maybeLastViewIndex else {
            return
        }

        let view = RowView(contentView: TitleValueSelectionView(), preferredHeight: 48.0)
        view.borderView.strokeWidth = 1.0

        view.rowContentView.titleLabel.text = R.string.localizable.commonBonus(
            preferredLanguages: locale.rLanguages
        )

        view.rowContentView.iconView.image = R.image.iconBonus()

        contentView.stackView.insertArrangedSubview(view, at: lastIndex + 1)
        view.snp.makeConstraints { make in
            make.width.equalTo(self)
        }

        view.contentInsets = UIEdgeInsets(
            top: 0.0,
            left: UIConstants.horizontalInset,
            bottom: 0.0,
            right: UIConstants.horizontalInset
        )

        bonusView = view
    }

    private func removeBonusViewIfNeeded() {
        guard let bonusView = bonusView else {
            return
        }

        contentView.stackView.removeArrangedSubview(bonusView)
        bonusView.removeFromSuperview()

        self.bonusView = nil
    }

    private func createLearnMoreViewIfNeeded() {
        guard learnMoreView == nil else {
            return
        }

        let maybeLastViewIndex: Int? = {
            if let bonusView = bonusView {
                return contentView.stackView.arrangedSubviews.firstIndex(
                    of: bonusView
                )
            } else if let estimatedRewardView = estimatedRewardView {
                return contentView.stackView.arrangedSubviews.firstIndex(
                    of: estimatedRewardView
                )
            } else {
                return contentView.stackView.arrangedSubviews.firstIndex(of: leasingPeriodView)
            }
        }()

        guard
            let lastIndex = maybeLastViewIndex else {
            return
        }

        let view = UIFactory.default.createLearnMoreView()

        contentView.stackView.insertArrangedSubview(view, at: lastIndex + 1)
        view.snp.makeConstraints { make in
            make.width.equalTo(self)
            make.height.equalTo(48.0)
        }

        learnMoreView = view
    }

    private func removeLearnMoreViewIfNeeded() {
        guard let learnMoreView = learnMoreView else {
            return
        }

        contentView.stackView.removeArrangedSubview(learnMoreView)
        learnMoreView.removeFromSuperview()
        self.learnMoreView = nil
    }
}
