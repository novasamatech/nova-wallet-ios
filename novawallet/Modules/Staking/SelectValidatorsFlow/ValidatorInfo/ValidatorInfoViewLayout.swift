import UIKit
import UIKit_iOS

final class ValidatorInfoViewLayout: UIView {
    let contentView: ScrollableContainerView = {
        let view = ScrollableContainerView()
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)
        view.stackView.alignment = .fill
        view.stackView.spacing = 12.0
        return view
    }()

    var stackView: UIStackView {
        contentView.stackView
    }

    private(set) var stakingTableView: StackTableView?
    private(set) var identityTableView: StackTableView?

    let factory = UIFactory.default

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = R.color.colorSecondaryScreenBackground()

        setupLayout()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func clearStackView() {
        let arrangedSubviews = stackView.arrangedSubviews

        arrangedSubviews.forEach {
            contentView.stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        stakingTableView = nil
        identityTableView = nil
    }

    @discardableResult
    func addWalletAccountView(for viewModel: WalletAccountViewModel) -> WalletAccountInfoView {
        let accountView = WalletAccountInfoView()

        stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.height.equalTo(56)
        }

        accountView.bind(viewModel: viewModel)

        return accountView
    }

    @discardableResult
    func addIdentityAccountView(for viewModel: DisplayAddressViewModel) -> IdentityAccountInfoView {
        let accountView = IdentityAccountInfoView()

        stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.height.equalTo(56)
        }

        accountView.bind(viewModel: viewModel)

        return accountView
    }

    @discardableResult
    func addStakingSection(with title: String) -> UIView {
        if let stakingTableView = stakingTableView {
            return stakingTableView
        }

        let tableView = addStackTableView(with: title)

        stakingTableView = tableView

        return tableView
    }

    @discardableResult
    func addIdentitySection(with title: String) -> UIView {
        if let identityTableView = identityTableView {
            return identityTableView
        }

        let tableView = addStackTableView(with: title)

        identityTableView = tableView

        return tableView
    }

    @discardableResult
    func addWarningView(message: String) -> UIView {
        let alert = InlineAlertView.warning()
        alert.contentView.detailsLabel.text = message

        stackView.addArrangedSubview(alert)

        return alert
    }

    @discardableResult
    func addErrorView(message: String) -> UIView {
        let alert = InlineAlertView.error()
        alert.contentView.detailsLabel.text = message

        stackView.addArrangedSubview(alert)

        return alert
    }

    @discardableResult
    func addStakingStatusView(
        _ viewModel: ValidatorInfoViewModel.Staking,
        locale: Locale
    ) -> UIView {
        let statusCell = StackTableCell()
        statusCell.rowContentView.valueView.mode = .detailsIcon
        statusCell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages
        ).localizable.stakingRewardDetailsStatus()

        switch viewModel.status {
        case .elected:
            statusCell.detailsLabel.text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.stakingValidatorStatusElected()

            statusCell.iconImageView.image = R.image.iconValid()

        case .unelected:
            statusCell.detailsLabel.text = R.string(preferredLanguages: locale.rLanguages
            ).localizable.stakingValidatorStatusUnelected()

            statusCell.iconImageView.image = R.image.iconPending()
        }

        stakingTableView?.addArrangedSubview(statusCell)

        return statusCell
    }

    @discardableResult
    func addNominatorsView(_ exposure: ValidatorInfoViewModel.Exposure, title: String) -> UIView {
        let cell = StackTitleMultiValueCell()
        cell.canSelect = false

        cell.titleLabel.text = title

        cell.rowContentView.valueView.bind(
            topValue: exposure.nominators,
            bottomValue: exposure.maxNominators
        )

        stakingTableView?.addArrangedSubview(cell)

        return cell
    }

    @discardableResult
    func addTotalStakeView(
        _ exposure: ValidatorInfoViewModel.Exposure,
        locale: Locale
    ) -> UIControl {
        let cell = StackTitleMultiValueCell()
        cell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages
        ).localizable.stakingValidatorTotalStake()

        cell.rowContentView.valueView.bind(
            topValue: exposure.totalStake.amount,
            bottomValue: exposure.totalStake.price
        )

        stakingTableView?.addArrangedSubview(cell)

        return cell
    }

    @discardableResult
    func addMinimumStakeView(
        _ minimumStake: BalanceViewModelProtocol,
        locale: Locale
    ) -> UIControl {
        let cell = StackTitleMultiValueCell()
        cell.canSelect = false

        cell.titleLabel.text = R.string(preferredLanguages: locale.rLanguages
        ).localizable.stakingMainMinimumStakeTitle()

        cell.rowContentView.valueView.bind(topValue: minimumStake.amount, bottomValue: minimumStake.price)

        stakingTableView?.addArrangedSubview(cell)

        return cell
    }

    @discardableResult
    func addTitleValueView(for title: String, value: String, to tableView: StackTableView) -> UIView {
        let cell = StackTableCell()
        cell.titleLabel.text = title
        cell.detailsLabel.text = value

        tableView.addArrangedSubview(cell)

        return cell
    }

    @discardableResult
    func addIdentityLinkView(for title: String, url: String) -> UIControl {
        let cell = StackUrlCell()

        cell.titleLabel.text = title
        cell.actionButton.imageWithTitleView?.title = url

        identityTableView?.addArrangedSubview(cell)

        return cell.actionButton
    }

    // MARK: Private

    private func addStackTableView(with title: String) -> StackTableView {
        let headerCell = StackTableHeaderCell()
        headerCell.titleLabel.text = title

        let stackTableView = StackTableView()
        stackTableView.addArrangedSubview(headerCell)

        stackView.addArrangedSubview(stackTableView)

        stackTableView.setCustomHeight(32.0, at: 0)
        stackTableView.contentInsets = UIEdgeInsets(top: 8.0, left: 16.0, bottom: 0.0, right: 16.0)

        return stackTableView
    }

    private func setupLayout() {
        addSubview(contentView)
        contentView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
}
