import UIKit

final class StakingRewardDestConfirmViewLayout: UIView {
    let containerView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        return view
    }()

    var stackView: UIStackView { containerView.stackView }

    let walletTableView = StackTableView()

    let walletCell = StackTableCell()

    let accountCell: StackInfoTableCell = {
        let cell = StackInfoTableCell()
        cell.detailsLabel.lineBreakMode = .byTruncatingMiddle
        return cell
    }()

    let networkFeeCell = StackNetworkFeeCell()

    let destinationTableView = StackTableView()

    let destinationCell = StackTableCell()

    private(set) var payoutAccountCell: StackInfoTableCell?

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

        backgroundColor = R.color.colorSecondaryScreenBackground()!

        setupLayout()

        applyLocalization()
    }

    private func insertPayoutViewIfNeeded() {
        guard payoutAccountCell == nil else {
            return
        }

        let payoutAccountCell = StackInfoTableCell()
        payoutAccountCell.detailsLabel.lineBreakMode = .byTruncatingMiddle

        payoutAccountCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardPayoutAccount()

        destinationTableView.addArrangedSubview(payoutAccountCell)

        self.payoutAccountCell = payoutAccountCell
    }

    private func removePayoutViewIfNeeded() {
        payoutAccountCell?.removeFromSuperview()
        payoutAccountCell = nil

        destinationTableView.updateLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bind(confirmationViewModel: StakingRewardDestConfirmViewModel) {
        walletCell.bind(viewModel: confirmationViewModel.walletViewModel.cellViewModel)
        accountCell.bind(viewModel: confirmationViewModel.accountViewModel.cellViewModel)

        switch confirmationViewModel.rewardDestination {
        case .restake:
            destinationCell.detailsLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingRestakeTitle_v2_2_0()

            removePayoutViewIfNeeded()

        case let .payout(details):
            destinationCell.detailsLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingPayoutTitle_v2_2_0()

            insertPayoutViewIfNeeded()

            payoutAccountCell?.bind(viewModel: details.rawDisplayAddress().cellViewModel)
        }

        setNeedsLayout()
    }

    func bind(feeViewModel: BalanceViewModelProtocol?) {
        networkFeeCell.rowContentView.bind(viewModel: feeViewModel)
        setNeedsLayout()
    }

    private func applyLocalization() {
        walletCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonWallet()
        accountCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.commonAccount()

        destinationCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardsDestinationTitle_v2_0_0()

        payoutAccountCell?.titleLabel.text = R.string(preferredLanguages: locale.rLanguages).localizable.stakingRewardPayoutAccount()

        networkFeeCell.rowContentView.locale = locale

        actionButton.imageWithTitleView?.title = R.string(preferredLanguages: locale.rLanguages).localizable.commonConfirm()

        setNeedsLayout()
    }

    private func setupLayout() {
        addSubview(actionButton)
        actionButton.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(UIConstants.horizontalInset)
            make.bottom.equalTo(safeAreaLayoutGuide).inset(UIConstants.actionBottomInset)
            make.height.equalTo(UIConstants.actionHeight)
        }

        addSubview(containerView)
        containerView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            make.bottom.equalTo(actionButton.snp.top).offset(-8.0)
        }

        containerView.stackView.spacing = 12

        containerView.stackView.addArrangedSubview(walletTableView)
        walletTableView.snp.makeConstraints { make in
            make.width.equalTo(self).offset(-2.0 * UIConstants.horizontalInset)
        }

        walletTableView.addArrangedSubview(walletCell)
        walletTableView.addArrangedSubview(accountCell)
        walletTableView.addArrangedSubview(networkFeeCell)

        containerView.stackView.addArrangedSubview(destinationTableView)
        destinationTableView.addArrangedSubview(destinationCell)
    }
}
