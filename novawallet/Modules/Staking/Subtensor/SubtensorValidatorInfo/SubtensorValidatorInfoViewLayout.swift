import UIKit
import UIKit_iOS

final class SubtensorValidatorInfoViewLayout: UIView {
    let containerView: ScrollableContainerView = .create { view in
        view.stackView.isLayoutMarginsRelativeArrangement = true
        view.stackView.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 24, right: 16)
        view.stackView.alignment = .fill
        view.stackView.spacing = 8
    }

    let accountView: IdentityAccountInfoView = .create { view in
        view.actionIcon = nil
        view.isUserInteractionEnabled = false
    }

    let stakingTitleLabel: UILabel = .create { label in
        label.font = .semiBoldCaps1
        label.textColor = R.color.colorTextSecondary()
    }

    let stakingTableView: StackTableView = .create { view in
        view.isHidden = true
    }

    let statusCell: StackTableCell = .create { cell in
        cell.isUserInteractionEnabled = false
    }

    let stakeCell = StackTitleMultiValueCell()

    let takeCell: StackTableCell = .create { cell in
        cell.rowContentView.valueView.mode = .detailsIcon
        cell.iconImageView.image = R.image.iconInfoFilled()
    }

    let rewardCell: StackTitleMultiValueCell = .create { cell in
        cell.canSelect = false
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

    func bind(viewModel: SubtensorValidatorInfoViewModel) {
        accountView.bind(viewModel: viewModel.account)

        guard let staking = viewModel.staking else {
            stakingTitleLabel.isHidden = true
            stakingTableView.isHidden = true
            return
        }

        stakingTitleLabel.isHidden = false
        stakingTableView.isHidden = false

        statusCell.detailsLabel.text = staking.status
        statusCell.detailsLabel.textColor = staking.isActive
            ? R.color.colorTextPositive()
            : R.color.colorTextSecondary()

        stakeCell.titleLabel.text = staking.stakeTitle

        switch staking.stake {
        case .loading:
            stakeCell.bind(loadableViewModel: .loading)
        case let .cached(stake), let .loaded(stake):
            stakeCell.bind(loadableViewModel: .loaded(value: stake.amount))
            stakeCell.rowContentView.valueView.bind(topValue: stake.amount, bottomValue: stake.price)
        }

        takeCell.detailsLabel.text = staking.take

        rewardCell.bind(loadableViewModel: staking.reward)
        rewardCell.rowContentView.valueView.valueTop.textColor = staking.hasReward
            ? R.color.colorTextPositive()
            : R.color.colorTextSecondary()

        setNeedsLayout()
    }

    func setupLocalization(for locale: Locale) {
        let strings = R.string(preferredLanguages: locale.rLanguages).localizable

        stakingTitleLabel.text = strings.stakingSubtensorUiValidatorInfoStaking().uppercased(with: locale)
        statusCell.titleLabel.text = strings.commonStatus()
        takeCell.titleLabel.text = strings.stakingSubtensorUiValidatorInfoTake()
        rewardCell.titleLabel.text = strings.stakingValidatorEstimatedReward()
    }

    private func setupLayout() {
        addSubview(containerView)

        containerView.snp.makeConstraints { make in
            make.top.equalTo(safeAreaLayoutGuide)
            make.leading.trailing.bottom.equalToSuperview()
        }

        containerView.stackView.addArrangedSubview(accountView)
        accountView.snp.makeConstraints { make in
            make.height.equalTo(IdentityAccountInfoView.preferredHeight)
        }

        containerView.stackView.setCustomSpacing(24, after: accountView)

        containerView.stackView.addArrangedSubview(stakingTitleLabel)
        containerView.stackView.addArrangedSubview(stakingTableView)

        stakingTableView.addArrangedSubview(statusCell)
        stakingTableView.addArrangedSubview(stakeCell)
        stakingTableView.addArrangedSubview(takeCell)
        stakingTableView.addArrangedSubview(rewardCell)
    }
}
