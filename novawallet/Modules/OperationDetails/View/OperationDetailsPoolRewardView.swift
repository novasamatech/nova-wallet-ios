import UIKit

final class OperationDetailsPoolRewardView: LocalizableView {
    let stakingTableView = StackTableView()
    let eventTableView = StackTableView()
    let poolTableView = StackTableView()

    let networkView = StackNetworkCell()
    let networkFeeView = StackNetworkFeeCell()
    let poolView = StackInfoTableCell()
    let eventIdView = StackInfoTableCell()

    var locale = Locale.current {
        didSet {
            if oldValue != locale {
                setupLocalization()
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)

        backgroundColor = .clear

        setupLayout()
        setupLocalization()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func bindReward(viewModel: OperationPoolRewardViewModel, networkViewModel: NetworkViewModel) {
        networkView.bind(viewModel: networkViewModel)
        networkFeeView.rowContentView.bind(viewModel: viewModel.fee)
        if let poolViewModel = viewModel.pool {
            poolView.isHidden = false
            poolView.detailsLabel.lineBreakMode = poolViewModel.lineBreakMode
            poolView.bind(viewModel: poolViewModel.cellViewModel)
        } else {
            poolView.isHidden = true
        }
        eventIdView.bind(details: viewModel.eventId)
    }

    private func setupLocalization() {
        networkView.titleLabel.text = R.string.localizable.commonNetwork(preferredLanguages: locale.rLanguages
        )
        networkFeeView.rowContentView.locale = locale

        eventIdView.titleLabel.text = R.string.localizable.commonTxId(
            preferredLanguages: locale.rLanguages
        )

        poolView.titleLabel.text = R.string.localizable.stakingPool(preferredLanguages: locale.rLanguages)
    }

    private func setupLayout() {
        addSubview(stakingTableView)
        stakingTableView.snp.makeConstraints { make in
            make.top.trailing.leading.equalToSuperview()
        }
        stakingTableView.addArrangedSubview(networkView)
        stakingTableView.addArrangedSubview(networkFeeView)

        addSubview(poolTableView)
        poolTableView.snp.makeConstraints { make in
            make.top.equalTo(stakingTableView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
        }
        poolTableView.addArrangedSubview(poolView)

        addSubview(eventTableView)
        eventTableView.snp.makeConstraints { make in
            make.top.equalTo(poolTableView.snp.bottom).offset(12)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
        eventTableView.addArrangedSubview(eventIdView)
    }
}
